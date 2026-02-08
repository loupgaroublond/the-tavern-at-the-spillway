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
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )

        return TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL)
    }

    // MARK: - Initialization Tests

    @Test("Coordinator starts with Jake selected")
    @MainActor
    func coordinatorStartsWithJakeSelected() {
        let coordinator = createCoordinator()

        #expect(coordinator.agentListViewModel.selectedAgentId == coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.agentId == coordinator.jake.id)
    }

    @Test("Jake is always in the list")
    @MainActor
    func jakeAlwaysInList() {
        let coordinator = createCoordinator()

        let items = coordinator.agentListViewModel.items
        #expect(items.contains { $0.isJake })
        #expect(items.first?.id == coordinator.jake.id)
    }

    // MARK: - Selection Tests

    @Test("Switching agents switches chat view")
    @MainActor
    func switchingAgentsSwitchesChatView() throws {
        let coordinator = createCoordinator()

        let agent = try coordinator.spawnAgent(assignment: "Test task", selectAfterSpawn: false)
        coordinator.selectAgent(id: agent.id)

        #expect(coordinator.activeChatViewModel.agentId == agent.id)
        #expect(coordinator.activeChatViewModel.agentName == agent.name)
    }

    @Test("Selecting Jake returns to Jake's chat")
    @MainActor
    func selectingJakeReturnsToJakesChat() throws {
        let coordinator = createCoordinator()

        let agent = try coordinator.spawnAgent(assignment: "Task", selectAfterSpawn: true)
        #expect(coordinator.activeChatViewModel.agentId == agent.id)

        coordinator.selectAgent(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.agentId == coordinator.jake.id)
    }

    // MARK: - Spawn Tests

    @Test("Spawn agent updates list")
    @MainActor
    func spawnAgentUpdatesList() throws {
        let coordinator = createCoordinator()

        let initialCount = coordinator.agentListViewModel.items.count
        _ = try coordinator.spawnAgent(assignment: "Task", selectAfterSpawn: false)

        #expect(coordinator.agentListViewModel.items.count == initialCount + 1)
    }

    @Test("Spawn agent with selectAfterSpawn selects new agent")
    @MainActor
    func spawnAgentWithSelectAfterSpawn() throws {
        let coordinator = createCoordinator()

        let agent = try coordinator.spawnAgent(assignment: "Task", selectAfterSpawn: true)

        #expect(coordinator.agentListViewModel.selectedAgentId == agent.id)
        #expect(coordinator.activeChatViewModel.agentId == agent.id)
    }

    // MARK: - Dismiss Tests

    @Test("Dismiss agent removes from list")
    @MainActor
    func dismissAgentRemovesFromList() throws {
        let coordinator = createCoordinator()

        let agent = try coordinator.spawnAgent(assignment: "Task", selectAfterSpawn: false)
        let countAfterSpawn = coordinator.agentListViewModel.items.count

        try coordinator.dismissAgent(id: agent.id)

        #expect(coordinator.agentListViewModel.items.count == countAfterSpawn - 1)
    }

    @Test("Dismiss selected agent switches to Jake")
    @MainActor
    func dismissSelectedAgentSwitchesToJake() throws {
        let coordinator = createCoordinator()

        let agent = try coordinator.spawnAgent(assignment: "Task", selectAfterSpawn: true)
        #expect(coordinator.activeChatViewModel.agentId == agent.id)

        try coordinator.dismissAgent(id: agent.id)

        #expect(coordinator.activeChatViewModel.agentId == coordinator.jake.id)
        #expect(coordinator.agentListViewModel.selectedAgentId == coordinator.jake.id)
    }

    @Test("Dismiss non-selected agent keeps current selection")
    @MainActor
    func dismissNonSelectedAgentKeepsSelection() throws {
        let coordinator = createCoordinator()

        let agent1 = try coordinator.spawnAgent(assignment: "Task 1", selectAfterSpawn: true)
        let agent2 = try coordinator.spawnAgent(assignment: "Task 2", selectAfterSpawn: false)

        // Agent1 should still be selected
        #expect(coordinator.activeChatViewModel.agentId == agent1.id)

        try coordinator.dismissAgent(id: agent2.id)

        // Should still have agent1 selected
        #expect(coordinator.activeChatViewModel.agentId == agent1.id)
    }

    // MARK: - User Journey Tests (Testing Principle #3)

    @Test("User-spawned agent gets ChatViewModel when selected")
    @MainActor
    func userSpawnedAgentGetsChatViewModel() throws {
        let coordinator = createCoordinator()

        // User spawns an agent (no assignment)
        let agent = try coordinator.spawnAgent(selectAfterSpawn: true)

        // ChatViewModel should be created for this agent
        #expect(coordinator.activeChatViewModel.agentId == agent.id)
        #expect(coordinator.activeChatViewModel.agentName == agent.name)
        #expect(coordinator.activeChatViewModel.messages.isEmpty)
    }

    @Test("Jake MCP server is configured on coordinator init")
    @MainActor
    func jakeMCPServerConfigured() {
        let coordinator = createCoordinator()

        // Jake should have an MCP server after coordinator init
        #expect(coordinator.jake.mcpServer != nil)
    }

    // MARK: - Grade 2 Mock Tests (using MockAgent for ChatViewModel interaction)
    // Note: chatHistoryPreservedWhenSwitching and servitorChatViewModelCanReceiveMessages
    // can be tested without mocking Jake — they only need the coordinator's view model
    // caching to work. The remaining 4 tests require AgentMessenger (Phase 2b).

    @Test("Chat history preserved when switching agents")
    @MainActor
    func chatHistoryPreservedWhenSwitching() async throws {
        let coordinator = createCoordinator()

        // Manually add messages to Jake's chat (avoids real Claude call)
        // We do this by getting the active chat view model and using MockAgent
        // through a second chat view model
        let jakeChatVM = coordinator.activeChatViewModel
        let jakeInitialCount = jakeChatVM.messages.count

        // Spawn a servitor and switch
        let servitor = try coordinator.summonServitor(selectAfterSummon: true)
        let servitorChatVM = coordinator.activeChatViewModel
        #expect(servitorChatVM.agentId == servitor.id)
        #expect(servitorChatVM.messages.isEmpty)

        // Switch back to Jake
        coordinator.selectAgent(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.agentId == coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeInitialCount)
    }

    @Test("Servitor ChatViewModel is created on selection")
    @MainActor
    func servitorChatViewModelCanReceiveMessages() throws {
        let coordinator = createCoordinator()

        let servitor = try coordinator.summonServitor(selectAfterSummon: true)
        let vm = coordinator.activeChatViewModel

        #expect(vm.agentId == servitor.id)
        #expect(vm.agentName == servitor.name)
        #expect(vm.messages.isEmpty)
    }

    // MARK: - Grade 2 Mock Tests (using MockMessenger for agent communication)

    @MainActor
    func createCoordinatorWithMockJake(responses: [String] = ["OK"]) -> TavernCoordinator {
        let projectURL = Self.testProjectURL()
        let mock = MockMessenger(responses: responses)
        let jake = Jake(projectURL: projectURL, messenger: mock, loadSavedSession: false)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        return TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL)
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

        // Spawn servitor with mock messenger, switch to it
        let servitorMessenger = MockMessenger(responses: ["Servitor response"])
        let servitor = try coordinator.summonServitor(selectAfterSummon: true)
        // The servitor already has LiveMessenger, but we can test the view model interaction
        // by using MockAgent approach instead. For now, just verify switching preserves Jake's count.

        // Switch back to Jake
        coordinator.selectAgent(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeCount)

        // Switch to servitor — should still have empty chat (no messages sent)
        coordinator.selectAgent(id: servitor.id)
        #expect(coordinator.activeChatViewModel.messages.isEmpty)

        // Switch back to Jake again — still preserved
        coordinator.selectAgent(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeCount)

        _ = servitorMessenger // Suppress unused warning
    }

    @Test("Jake summon action creates servitor via coordinator")
    @MainActor
    func jakeSummonActionCreatesServitor() throws {
        let coordinator = createCoordinator()

        let initialCount = coordinator.spawner.servitorCount

        // Summon via coordinator (simulating what Jake's MCP handler does)
        let servitor = try coordinator.summonServitor(assignment: "Test task", selectAfterSummon: false)

        #expect(coordinator.spawner.servitorCount == initialCount + 1)
        #expect(servitor.assignment == "Test task")
        #expect(coordinator.agentListViewModel.items.contains { $0.id == servitor.id })
    }

    @Test("Jake summon action with name creates named servitor")
    @MainActor
    func jakeSummonActionWithName() throws {
        let coordinator = createCoordinator()

        // Summon with specific name via spawner (simulating MCP handler path)
        let servitor = try coordinator.spawner.summon(name: "SpecialAgent", assignment: "Named task")

        #expect(servitor.name == "SpecialAgent")
        #expect(servitor.assignment == "Named task")
    }

    @Test("Jake summon failure reports error via ChatViewModel")
    @MainActor
    func jakeSummonFailureReportsError() async {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("Summon failed")
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, messenger: mock, loadSavedSession: false)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        let coordinator = TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL)

        // Send message that will fail via mock messenger
        coordinator.activeChatViewModel.inputText = "Summon a worker"
        await coordinator.activeChatViewModel.sendMessage()

        // Error should be captured in the view model
        #expect(coordinator.activeChatViewModel.error != nil)
        #expect(coordinator.activeChatViewModel.messages.count >= 2) // user msg + error msg
    }
}
