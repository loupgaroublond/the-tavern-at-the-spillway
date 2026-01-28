import Foundation
import Testing
@testable import TavernCore

@Suite("TavernCoordinator Tests")
struct TavernCoordinatorTests {

    @MainActor
    func createCoordinator() -> TavernCoordinator {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Jake response", sessionId: "jake-session")

        let jake = Jake(claude: mock, loadSavedSession: false)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let claudeFactory: () -> ClaudeCode = { MockClaudeCode() }
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            claudeFactory: claudeFactory
        )

        return TavernCoordinator(jake: jake, spawner: spawner, claudeFactory: claudeFactory)
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

    // MARK: - Chat History Preservation Tests

    @Test("Chat history preserved when switching agents")
    @MainActor
    func chatHistoryPreservedWhenSwitching() async throws {
        let coordinator = createCoordinator()

        // Send a message to Jake
        coordinator.activeChatViewModel.inputText = "Hello Jake"
        await coordinator.activeChatViewModel.sendMessage()
        let jakeMessageCount = coordinator.activeChatViewModel.messages.count

        // Spawn and switch to new agent
        let agent = try coordinator.spawnAgent(assignment: "Task", selectAfterSpawn: true)
        #expect(coordinator.activeChatViewModel.messages.isEmpty) // New agent, no messages

        // Switch back to Jake
        coordinator.selectAgent(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeMessageCount)
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
    // These tests verify end-to-end paths users actually take

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

    @Test("Mortal agent ChatViewModel can receive messages after selection")
    @MainActor
    func mortalAgentChatViewModelCanReceiveMessages() async throws {
        let coordinator = createCoordinator()

        // Spawn agent and select it
        let agent = try coordinator.spawnAgent(selectAfterSpawn: true)

        // Queue a response for this agent's mock
        // Note: The agent has its own mock from claudeFactory
        // This test verifies the ChatViewModel is properly connected

        #expect(coordinator.activeChatViewModel.agentId == agent.id)

        // Send a message
        coordinator.activeChatViewModel.inputText = "Do the task"
        await coordinator.activeChatViewModel.sendMessage()

        // Should have user message (agent response depends on mock setup)
        #expect(coordinator.activeChatViewModel.messages.count >= 1)
        #expect(coordinator.activeChatViewModel.messages[0].role == .user)
        #expect(coordinator.activeChatViewModel.messages[0].content == "Do the task")
    }

    @Test("Switching between Jake and mortal agent preserves both histories")
    @MainActor
    func switchingPreservesBothHistories() async throws {
        let coordinator = createCoordinator()

        // Send message to Jake
        coordinator.activeChatViewModel.inputText = "Hello Jake"
        await coordinator.activeChatViewModel.sendMessage()
        let jakeMessageCount = coordinator.activeChatViewModel.messages.count

        // Spawn agent and send message
        let agent = try coordinator.spawnAgent(selectAfterSpawn: true)
        coordinator.activeChatViewModel.inputText = "Hello Worker"
        await coordinator.activeChatViewModel.sendMessage()
        let agentMessageCount = coordinator.activeChatViewModel.messages.count

        // Switch to Jake
        coordinator.selectAgent(id: coordinator.jake.id)
        #expect(coordinator.activeChatViewModel.messages.count == jakeMessageCount)

        // Switch back to agent
        coordinator.selectAgent(id: agent.id)
        #expect(coordinator.activeChatViewModel.messages.count == agentMessageCount)
    }

    // MARK: - Jake Tool Handler Integration Tests (Principle #3: User Journey)
    // These test the full flow: Jake spawn action → coordinator spawns agent

    /// Helper to create an isolated coordinator for tool handler tests
    /// Clears persisted state to ensure test isolation
    @MainActor
    private func createIsolatedCoordinator(jakeMock: MockClaudeCode) -> TavernCoordinator {
        // Clear persisted agents to ensure test isolation
        SessionStore.clearAgentList()

        let jake = Jake(claude: jakeMock, loadSavedSession: false)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let claudeFactory: () -> ClaudeCode = { MockClaudeCode() }
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            claudeFactory: claudeFactory
        )

        return TavernCoordinator(jake: jake, spawner: spawner, claudeFactory: claudeFactory)
    }

    @Test("Jake tool handler is configured on coordinator init")
    @MainActor
    func jakeToolHandlerConfigured() {
        let coordinator = createCoordinator()

        // Jake should have a tool handler after coordinator init
        #expect(coordinator.jake.toolHandler != nil)
    }

    @Test("Jake spawn action creates agent in coordinator")
    @MainActor
    func jakeSpawnActionCreatesAgent() async throws {
        let jakeMock = MockClaudeCode()
        // First: Jake's response with spawn action
        jakeMock.queueJSONResponse(
            result: #"{"message": "I'll delegate!", "spawn": {"assignment": "Test task"}}"#,
            sessionId: "jake-session"
        )
        // Second: Jake's continuation after spawn feedback
        jakeMock.queueJSONResponse(
            result: #"{"message": "Agent is working on it!"}"#,
            sessionId: "jake-session"
        )

        let coordinator = createIsolatedCoordinator(jakeMock: jakeMock)

        // Initial state: only Jake
        let initialAgentCount = coordinator.spawner.agentCount
        #expect(initialAgentCount == 0)

        // Send message that triggers spawn
        coordinator.activeChatViewModel.inputText = "Please help with testing"
        await coordinator.activeChatViewModel.sendMessage()

        // Agent should have been spawned
        #expect(coordinator.spawner.agentCount == initialAgentCount + 1)
        #expect(coordinator.agentListViewModel.items.count == 2) // Jake + new agent
    }

    @Test("Jake spawn action with name uses specified name")
    @MainActor
    func jakeSpawnActionWithName() async throws {
        let jakeMock = MockClaudeCode()
        jakeMock.queueJSONResponse(
            result: #"{"message": "Spawning Gandalf!", "spawn": {"assignment": "Wizardry", "name": "Gandalf"}}"#,
            sessionId: "jake-session"
        )
        jakeMock.queueJSONResponse(
            result: #"{"message": "Gandalf is ready!"}"#,
            sessionId: "jake-session"
        )

        let coordinator = createIsolatedCoordinator(jakeMock: jakeMock)

        coordinator.activeChatViewModel.inputText = "Spawn Gandalf"
        await coordinator.activeChatViewModel.sendMessage()

        // Find the spawned agent
        let spawnedAgents = coordinator.spawner.activeAgents
        #expect(spawnedAgents.count == 1)
        #expect(spawnedAgents.first?.name == "Gandalf")
    }

    @Test("Jake spawn failure reports error in feedback")
    @MainActor
    func jakeSpawnFailureReportsError() async throws {
        let jakeMock = MockClaudeCode()
        // First: spawn request with duplicate name
        jakeMock.queueJSONResponse(
            result: #"{"message": "Spawning!", "spawn": {"assignment": "Task", "name": "Duplicate"}}"#,
            sessionId: "jake-session"
        )
        // Second: another spawn with same name (will fail)
        jakeMock.queueJSONResponse(
            result: #"{"message": "Got it, trying again!", "spawn": {"assignment": "Task 2", "name": "Duplicate"}}"#,
            sessionId: "jake-session"
        )
        // Third: continuation after failure
        jakeMock.queueJSONResponse(
            result: #"{"message": "Oh no, that name is taken!"}"#,
            sessionId: "jake-session"
        )

        let coordinator = createIsolatedCoordinator(jakeMock: jakeMock)

        // First spawn should succeed
        coordinator.activeChatViewModel.inputText = "Spawn Duplicate"
        await coordinator.activeChatViewModel.sendMessage()

        #expect(coordinator.spawner.agentCount == 1)

        // Second spawn attempt with same name - should fail but conversation continues
        // The error is reported in the feedback to Jake
        let sentPrompts = jakeMock.sentPrompts
        let failureFeedback = sentPrompts.first { $0.contains("Failed to spawn") }
        #expect(failureFeedback != nil)
    }
}
