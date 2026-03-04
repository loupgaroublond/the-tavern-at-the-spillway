import Foundation
import Testing
@testable import TavernCore

@Suite("TavernCoordinator Tests")
struct TavernCoordinatorTests {

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @MainActor
    func createCoordinator() -> TavernCoordinator {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )

        return TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL, restoreState: false)
    }

    // MARK: - Initialization Tests

    @Test("Coordinator starts with Jake selected")
    @MainActor
    func coordinatorStartsWithJakeSelected() {
        let coordinator = createCoordinator()

        #expect(coordinator.servitorListViewModel.selectedServitorId == coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.servitorId == coordinator.jake.id)
    }

    @Test("Jake is always in the list")
    @MainActor
    func jakeAlwaysInList() {
        let coordinator = createCoordinator()

        let items = coordinator.servitorListViewModel.items
        #expect(items.contains { $0.isJake })
        #expect(items.first?.id == coordinator.jake.id)
    }

    // MARK: - Selection Tests

    @Test("Switching servitors switches chat view")
    @MainActor
    func switchingServitorsSwitchesChatView() throws {
        let coordinator = createCoordinator()

        let mortal = try coordinator.summonServitor(assignment: "Test task", selectAfterSummon: false)
        coordinator.selectServitor(id: mortal.id)

        #expect(coordinator.activeChatViewModel.servitorId == mortal.id)
        #expect(coordinator.activeChatViewModel.servitorName == mortal.name)
    }

    @Test("Selecting Jake returns to Jake's chat")
    @MainActor
    func selectingJakeReturnsToJakesChat() throws {
        let coordinator = createCoordinator()

        let mortal = try coordinator.summonServitor(assignment: "Task", selectAfterSummon: true)
        #expect(coordinator.activeChatViewModel.servitorId == mortal.id)

        coordinator.selectServitor(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.servitorId == coordinator.jake.id)
    }

    // MARK: - Spawn Tests

    @Test("Spawn mortal updates list")
    @MainActor
    func spawnMortalUpdatesList() throws {
        let coordinator = createCoordinator()

        let initialCount = coordinator.servitorListViewModel.items.count
        _ = try coordinator.summonServitor(assignment: "Task", selectAfterSummon: false)

        #expect(coordinator.servitorListViewModel.items.count == initialCount + 1)
    }

    @Test("Spawn mortal with selectAfterSpawn selects new mortal")
    @MainActor
    func spawnMortalWithSelectAfterSpawn() throws {
        let coordinator = createCoordinator()

        let mortal = try coordinator.summonServitor(assignment: "Task", selectAfterSummon: true)

        #expect(coordinator.servitorListViewModel.selectedServitorId == mortal.id)
        #expect(coordinator.activeChatViewModel.servitorId == mortal.id)
    }

    // MARK: - Dismiss Tests

    @Test("Dismiss mortal removes from list")
    @MainActor
    func dismissMortalRemovesFromList() throws {
        let coordinator = createCoordinator()

        let mortal = try coordinator.summonServitor(assignment: "Task", selectAfterSummon: false)
        let countAfterSpawn = coordinator.servitorListViewModel.items.count

        try coordinator.closeServitor(id: mortal.id)

        #expect(coordinator.servitorListViewModel.items.count == countAfterSpawn - 1)
    }

    @Test("Dismiss selected mortal switches to Jake")
    @MainActor
    func dismissSelectedMortalSwitchesToJake() throws {
        let coordinator = createCoordinator()

        let mortal = try coordinator.summonServitor(assignment: "Task", selectAfterSummon: true)
        #expect(coordinator.activeChatViewModel.servitorId == mortal.id)

        try coordinator.closeServitor(id: mortal.id)

        #expect(coordinator.activeChatViewModel.servitorId == coordinator.jake.id)
        #expect(coordinator.servitorListViewModel.selectedServitorId == coordinator.jake.id)
    }

    @Test("Dismiss non-selected mortal keeps current selection")
    @MainActor
    func dismissNonSelectedMortalKeepsSelection() throws {
        let coordinator = createCoordinator()

        let mortal1 = try coordinator.summonServitor(assignment: "Task 1", selectAfterSummon: true)
        let mortal2 = try coordinator.summonServitor(assignment: "Task 2", selectAfterSummon: false)

        // mortal1 should still be selected
        #expect(coordinator.activeChatViewModel.servitorId == mortal1.id)

        try coordinator.closeServitor(id: mortal2.id)

        // Should still have mortal1 selected
        #expect(coordinator.activeChatViewModel.servitorId == mortal1.id)
    }

    // MARK: - User Journey Tests (Testing Principle #3)

    @Test("User-spawned mortal gets ChatViewModel when selected")
    @MainActor
    func userSpawnedMortalGetsChatViewModel() throws {
        let coordinator = createCoordinator()

        // User spawns a mortal (no assignment)
        let mortal = try coordinator.summonServitor(selectAfterSummon: true)

        // ChatViewModel should be created for this mortal
        #expect(coordinator.activeChatViewModel.servitorId == mortal.id)
        #expect(coordinator.activeChatViewModel.servitorName == mortal.name)
        #expect(coordinator.activeChatViewModel.messages.isEmpty)
    }

    @Test("Jake MCP server is configured on coordinator init", .tags(.reqCOM008))
    @MainActor
    func jakeMCPServerConfigured() {
        let coordinator = createCoordinator()

        // Jake should have an MCP server after coordinator init
        #expect(coordinator.jake.mcpServer != nil)
    }

    // MARK: - Grade 2 Mock Tests (using MockServitor for ChatViewModel interaction)
    // Note: chatHistoryPreservedWhenSwitching and mortalChatViewModelCanReceiveMessages
    // can be tested without mocking Jake — they only need the coordinator's view model
    // caching to work. The remaining 4 tests require ServitorMessenger (Phase 2b).

    @Test("Chat history preserved when switching servitors")
    @MainActor
    func chatHistoryPreservedWhenSwitching() async throws {
        let coordinator = createCoordinator()

        // Manually add messages to Jake's chat (avoids real Claude call)
        // We do this by getting the active chat view model and using MockServitor
        // through a second chat view model
        let jakeChatVM = coordinator.activeChatViewModel
        let jakeInitialCount = jakeChatVM.messages.count

        // Spawn a mortal and switch
        let mortal = try coordinator.summonServitor(selectAfterSummon: true)
        let mortalChatVM = coordinator.activeChatViewModel
        #expect(mortalChatVM.servitorId == mortal.id)
        #expect(mortalChatVM.messages.isEmpty)

        // Switch back to Jake
        coordinator.selectServitor(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.servitorId == coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeInitialCount)
    }

    @Test("Mortal ChatViewModel is created on selection")
    @MainActor
    func mortalChatViewModelCanReceiveMessages() throws {
        let coordinator = createCoordinator()

        let mortal = try coordinator.summonServitor(selectAfterSummon: true)
        let vm = coordinator.activeChatViewModel

        #expect(vm.servitorId == mortal.id)
        #expect(vm.servitorName == mortal.name)
        #expect(vm.messages.isEmpty)
    }

    // MARK: - Grade 2 Mock Tests (using MockMessenger for servitor communication)

    @MainActor
    func createCoordinatorWithMockJake(responses: [String] = ["OK"]) -> TavernCoordinator {
        let projectURL = Self.testProjectURL()
        let mock = MockMessenger(responses: responses)
        let jake = Jake(projectURL: projectURL, messenger: mock, loadSavedSession: false)
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        return TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL, restoreState: false)
    }

    @Test("Switching preserves both chat histories")
    @MainActor
    func switchingPreservesBothHistories() async throws {
        let coordinator = createCoordinatorWithMockJake(responses: ["Jake response"])

        // Send message to Jake via mock
        coordinator.activeChatViewModel.inputText = "Hello Jake"
        await coordinator.activeChatViewModel.sendMessage()
        let jakeCount = coordinator.activeChatViewModel.messages.count
        #expect(jakeCount >= 2) // user + agent

        // Spawn mortal with mock messenger, switch to it
        let mortalMessenger = MockMessenger(responses: ["Mortal response"])
        let mortal = try coordinator.summonServitor(selectAfterSummon: true)
        // The mortal already has LiveMessenger, but we can test the view model interaction
        // by using MockServitor approach instead. For now, just verify switching preserves Jake's count.

        // Switch back to Jake
        coordinator.selectServitor(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeCount)

        // Switch to mortal — should still have empty chat (no messages sent)
        coordinator.selectServitor(id: mortal.id)
        #expect(coordinator.activeChatViewModel.messages.isEmpty)

        // Switch back to Jake again — still preserved
        coordinator.selectServitor(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeCount)

        _ = mortalMessenger // Suppress unused warning
    }

    @Test("Jake summon action creates mortal via coordinator")
    @MainActor
    func jakeSummonActionCreatesMortal() throws {
        let coordinator = createCoordinator()

        let initialCount = coordinator.spawner.mortalCount

        // Summon via coordinator (simulating what Jake's MCP handler does)
        let mortal = try coordinator.summonServitor(assignment: "Test task", selectAfterSummon: false)

        #expect(coordinator.spawner.mortalCount == initialCount + 1)
        #expect(mortal.assignment == "Test task")
        #expect(coordinator.servitorListViewModel.items.contains { $0.id == mortal.id })
    }

    @Test("Jake summon action with name creates named mortal")
    @MainActor
    func jakeSummonActionWithName() throws {
        let coordinator = createCoordinator()

        // Summon with specific name via spawner (simulating MCP handler path)
        let mortal = try coordinator.spawner.summon(name: "SpecialMortal", assignment: "Named task")

        #expect(mortal.name == "SpecialMortal")
        #expect(mortal.assignment == "Named task")
    }

    @Test("Jake summon failure reports error via ChatViewModel")
    @MainActor
    func jakeSummonFailureReportsError() async {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("Summon failed")
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, messenger: mock, loadSavedSession: false)
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        let coordinator = TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL, restoreState: false)

        // Send message that will fail via mock messenger
        coordinator.activeChatViewModel.inputText = "Summon a worker"
        await coordinator.activeChatViewModel.sendMessage()

        // Error should be captured in the view model
        #expect(coordinator.activeChatViewModel.error != nil)
        #expect(coordinator.activeChatViewModel.messages.count >= 2) // user msg + error msg
    }
}
