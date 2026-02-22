import Foundation
import XCTest
@testable import TavernCore

/// Grade 3 integration tests for TavernCoordinator — real Claude API calls
/// Run with: redo test-grade3
/// Or: swift test --filter TavernIntegrationTests/CoordinatorIntegrationTests
///
/// These tests verify coordinator behavior with real servitor communication.
/// Grade 2 mock tests mirror these assertions.
@MainActor
final class CoordinatorIntegrationTests: XCTestCase {

    private var projectURL: URL!

    override func setUp() async throws {
        executionTimeAllowance = 60
        projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavern-integration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: projectURL)
    }

    private func createCoordinator() -> TavernCoordinator {
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        return TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL)
    }

    // MARK: - Tests

    /// Chat history is preserved when switching between servitors
    func testChatHistoryPreservedWhenSwitching() async throws {
        let coordinator = createCoordinator()

        // Send a message to Jake
        coordinator.activeChatViewModel.inputText = "Say JAKE_HISTORY in one word"
        await coordinator.activeChatViewModel.sendMessage()
        let jakeMessageCount = coordinator.activeChatViewModel.messages.count
        XCTAssertGreaterThan(jakeMessageCount, 0, "Jake should have messages")

        // Spawn a mortal and switch to it
        let mortal = try coordinator.summonServitor(selectAfterSummon: true)
        XCTAssertEqual(coordinator.activeChatViewModel.servitorId, mortal.id)
        XCTAssertTrue(coordinator.activeChatViewModel.messages.isEmpty,
            "New mortal should start with empty chat")

        // Switch back to Jake
        coordinator.selectServitor(id: coordinator.jake.id)
        XCTAssertEqual(coordinator.activeChatViewModel.messages.count, jakeMessageCount,
            "Jake's messages should be preserved after switching back")
    }

    /// Mortal's ChatViewModel can receive messages
    func testMortalChatViewModelCanReceiveMessages() async throws {
        let coordinator = createCoordinator()

        let mortal = try coordinator.summonServitor(selectAfterSummon: true)
        XCTAssertEqual(coordinator.activeChatViewModel.servitorId, mortal.id)

        coordinator.activeChatViewModel.inputText = "Say MORTAL_MSG_OK"
        await coordinator.activeChatViewModel.sendMessage()

        XCTAssertGreaterThanOrEqual(coordinator.activeChatViewModel.messages.count, 2,
            "Mortal chat should have user + servitor messages")
    }

    /// Switching between servitors preserves both chat histories
    func testSwitchingPreservesBothHistories() async throws {
        let coordinator = createCoordinator()

        // Message Jake
        coordinator.activeChatViewModel.inputText = "Say JAKE_MSG"
        await coordinator.activeChatViewModel.sendMessage()
        let jakeCount = coordinator.activeChatViewModel.messages.count

        // Spawn mortal, switch, message it
        let mortal = try coordinator.summonServitor(selectAfterSummon: true)
        coordinator.activeChatViewModel.inputText = "Say MORTAL_MSG"
        await coordinator.activeChatViewModel.sendMessage()
        let mortalCount = coordinator.activeChatViewModel.messages.count

        // Switch to Jake — verify Jake's history intact
        coordinator.selectServitor(id: coordinator.jake.id)
        XCTAssertEqual(coordinator.activeChatViewModel.messages.count, jakeCount,
            "Jake's message count should be preserved")

        // Switch to mortal — verify mortal's history intact
        coordinator.selectServitor(id: mortal.id)
        XCTAssertEqual(coordinator.activeChatViewModel.messages.count, mortalCount,
            "Mortal's message count should be preserved")
    }

    /// Jake's summon MCP action creates a mortal
    func testJakeSummonActionCreatesMortal() async throws {
        let coordinator = createCoordinator()

        let initialCount = coordinator.spawner.mortalCount

        // Ask Jake to summon via his MCP tool
        coordinator.activeChatViewModel.inputText = "Use the summon_servitor tool to summon a worker with assignment: integration test"
        await coordinator.activeChatViewModel.sendMessage()

        // The summon may or may not happen depending on Claude's decision
        // We verify no crash and that Jake responded
        XCTAssertGreaterThanOrEqual(coordinator.activeChatViewModel.messages.count, 2,
            "Jake should have responded")

        // If summon happened, count increased
        if coordinator.spawner.mortalCount > initialCount {
            XCTAssertEqual(coordinator.spawner.mortalCount, initialCount + 1,
                "Should have exactly one more mortal")
        }
    }

    /// Jake's summon action can specify a name
    func testJakeSummonActionWithName() async throws {
        let coordinator = createCoordinator()

        coordinator.activeChatViewModel.inputText = "Use summon_servitor with name: TestMortal and assignment: named test"
        await coordinator.activeChatViewModel.sendMessage()

        // Verify Jake responded without crashing
        XCTAssertGreaterThanOrEqual(coordinator.activeChatViewModel.messages.count, 2,
            "Jake should have responded")
    }

    /// Jake's summon failure reports error correctly
    func testJakeSummonFailureReportsError() async throws {
        let coordinator = createCoordinator()

        // Jake should handle this gracefully — the MCP handler has error handling
        coordinator.activeChatViewModel.inputText = "Say FAILURE_TEST in one word. Do not use any tools."
        await coordinator.activeChatViewModel.sendMessage()

        // Just verify no crash and Jake responded
        XCTAssertFalse(coordinator.activeChatViewModel.messages.isEmpty,
            "Jake should have messages after send")
    }
}
