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

    // MARK: - Tests requiring SDK mocking (skipped for now)
    // TODO: These tests need dependency injection or SDK mocking to work
    // - chatHistoryPreservedWhenSwitching
    // - servitorChatViewModelCanReceiveMessages
    // - switchingPreservesBothHistories
    // - jakeSummonActionCreatesServitor
    // - jakeSummonActionWithName
    // - jakeSummonFailureReportsError
}
