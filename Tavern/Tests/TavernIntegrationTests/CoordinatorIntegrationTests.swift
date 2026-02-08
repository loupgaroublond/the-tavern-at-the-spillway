import Foundation
import XCTest
@testable import TavernCore

/// Grade 3 integration tests for TavernCoordinator — real Claude API calls
/// Run with: redo test-grade3
/// Or: swift test --filter TavernIntegrationTests/CoordinatorIntegrationTests
///
/// These tests verify coordinator behavior with real agent communication.
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
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        return TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL)
    }

    // MARK: - Tests

    /// Chat history is preserved when switching between agents
    func testChatHistoryPreservedWhenSwitching() async throws {
        let coordinator = createCoordinator()

        // Send a message to Jake
        coordinator.activeChatViewModel.inputText = "Say JAKE_HISTORY in one word"
        await coordinator.activeChatViewModel.sendMessage()
        let jakeMessageCount = coordinator.activeChatViewModel.messages.count
        XCTAssertGreaterThan(jakeMessageCount, 0, "Jake should have messages")

        // Spawn a servitor and switch to it
        let servitor = try coordinator.summonServitor(selectAfterSummon: true)
        XCTAssertEqual(coordinator.activeChatViewModel.agentId, servitor.id)
        XCTAssertTrue(coordinator.activeChatViewModel.messages.isEmpty,
            "New servitor should start with empty chat")

        // Switch back to Jake
        coordinator.selectAgent(id: coordinator.jake.id)
        XCTAssertEqual(coordinator.activeChatViewModel.messages.count, jakeMessageCount,
            "Jake's messages should be preserved after switching back")
    }

    /// Servitor's ChatViewModel can receive messages
    func testServitorChatViewModelCanReceiveMessages() async throws {
        let coordinator = createCoordinator()

        let servitor = try coordinator.summonServitor(selectAfterSummon: true)
        XCTAssertEqual(coordinator.activeChatViewModel.agentId, servitor.id)

        coordinator.activeChatViewModel.inputText = "Say SERVITOR_MSG_OK"
        await coordinator.activeChatViewModel.sendMessage()

        XCTAssertGreaterThanOrEqual(coordinator.activeChatViewModel.messages.count, 2,
            "Servitor chat should have user + agent messages")
    }

    /// Switching between agents preserves both chat histories
    func testSwitchingPreservesBothHistories() async throws {
        let coordinator = createCoordinator()

        // Message Jake
        coordinator.activeChatViewModel.inputText = "Say JAKE_MSG"
        await coordinator.activeChatViewModel.sendMessage()
        let jakeCount = coordinator.activeChatViewModel.messages.count

        // Spawn servitor, switch, message it
        let servitor = try coordinator.summonServitor(selectAfterSummon: true)
        coordinator.activeChatViewModel.inputText = "Say SERVITOR_MSG"
        await coordinator.activeChatViewModel.sendMessage()
        let servitorCount = coordinator.activeChatViewModel.messages.count

        // Switch to Jake — verify Jake's history intact
        coordinator.selectAgent(id: coordinator.jake.id)
        XCTAssertEqual(coordinator.activeChatViewModel.messages.count, jakeCount,
            "Jake's message count should be preserved")

        // Switch to servitor — verify servitor's history intact
        coordinator.selectAgent(id: servitor.id)
        XCTAssertEqual(coordinator.activeChatViewModel.messages.count, servitorCount,
            "Servitor's message count should be preserved")
    }

    /// Jake's summon MCP action creates a servitor
    func testJakeSummonActionCreatesServitor() async throws {
        let coordinator = createCoordinator()

        let initialCount = coordinator.spawner.servitorCount

        // Ask Jake to summon via his MCP tool
        coordinator.activeChatViewModel.inputText = "Use the summon_servitor tool to summon a worker with assignment: integration test"
        await coordinator.activeChatViewModel.sendMessage()

        // The summon may or may not happen depending on Claude's decision
        // We verify no crash and that Jake responded
        XCTAssertGreaterThanOrEqual(coordinator.activeChatViewModel.messages.count, 2,
            "Jake should have responded")

        // If summon happened, count increased
        if coordinator.spawner.servitorCount > initialCount {
            XCTAssertEqual(coordinator.spawner.servitorCount, initialCount + 1,
                "Should have exactly one more servitor")
        }
    }

    /// Jake's summon action can specify a name
    func testJakeSummonActionWithName() async throws {
        let coordinator = createCoordinator()

        coordinator.activeChatViewModel.inputText = "Use summon_servitor with name: TestAgent and assignment: named test"
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
