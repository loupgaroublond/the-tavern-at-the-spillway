import Foundation
import ClaudeCodeSDK
import os.log

/// Coordinates the Tavern's agents and their chat sessions
/// This is the central hub that ties together Jake, the Slop Squad, and the UI
@MainActor
public final class TavernCoordinator: ObservableObject {

    // MARK: - Published State

    /// The agent list view model (manages selection)
    @Published public private(set) var agentListViewModel: AgentListViewModel

    /// Currently active chat view model
    @Published public private(set) var activeChatViewModel: ChatViewModel

    // MARK: - Core Components

    /// Jake - The Proprietor (eternal, always present)
    public let jake: Jake

    /// Spawner for mortal agents
    public let spawner: AgentSpawner

    // MARK: - Private State

    /// Chat view models keyed by agent ID
    private var chatViewModels: [UUID: ChatViewModel] = [:]

    /// Jake's chat view model (always exists)
    private let jakeChatViewModel: ChatViewModel

    /// Factory for creating ClaudeCode instances (for agent restoration)
    private let claudeFactory: () -> ClaudeCode

    // MARK: - Initialization

    /// Create the coordinator with dependencies
    /// - Parameters:
    ///   - jake: The Proprietor
    ///   - spawner: Agent spawner for the Slop Squad
    ///   - claudeFactory: Factory for creating ClaudeCode instances (for restored agents)
    public init(jake: Jake, spawner: AgentSpawner, claudeFactory: @escaping () -> ClaudeCode) {
        self.jake = jake
        self.spawner = spawner
        self.claudeFactory = claudeFactory

        // Create Jake's chat view model
        self.jakeChatViewModel = ChatViewModel(jake: jake)
        self.chatViewModels[jake.id] = jakeChatViewModel

        // Start with Jake's chat as active
        self.activeChatViewModel = jakeChatViewModel

        // Create the agent list view model
        self.agentListViewModel = AgentListViewModel(jake: jake, spawner: spawner)

        // Restore persisted agents
        restoreAgents()
    }

    // MARK: - Agent Restoration

    /// Restore agents from UserDefaults on app launch
    private func restoreAgents() {
        let persistedAgents = SessionStore.loadAgentList()
        TavernLogger.coordination.info("Restoring \(persistedAgents.count) persisted agents")

        for persisted in persistedAgents {
            let claude = claudeFactory()
            let agent = MortalAgent(
                id: persisted.id,
                name: persisted.name,
                assignment: nil,  // Restored agents don't have original assignment
                chatDescription: persisted.chatDescription,
                claude: claude,
                loadSavedSession: true  // Will load session from SessionStore
            )

            do {
                try spawner.register(agent)
                TavernLogger.coordination.info("Restored agent: \(persisted.name) (id: \(persisted.id))")
            } catch {
                TavernLogger.coordination.error("Failed to restore agent \(persisted.name): \(error.localizedDescription)")
            }
        }

        // Refresh UI
        agentListViewModel.agentsDidChange()
    }

    // MARK: - Agent Selection

    /// Select an agent to chat with
    /// - Parameter agentId: The ID of the agent to select
    public func selectAgent(id agentId: UUID) {
        TavernLogger.coordination.info("Agent selection changed to: \(agentId)")
        agentListViewModel.selectAgent(id: agentId)
        updateActiveChatViewModel()
    }

    /// Update the active chat view model based on selection
    private func updateActiveChatViewModel() {
        guard let selectedId = agentListViewModel.selectedAgentId else {
            // Fallback to Jake
            TavernLogger.coordination.info("updateActiveChatViewModel: no selection, using Jake")
            activeChatViewModel = jakeChatViewModel
            return
        }

        if selectedId == jake.id {
            TavernLogger.coordination.info("updateActiveChatViewModel: selected Jake")
            activeChatViewModel = jakeChatViewModel
        } else if let existingViewModel = chatViewModels[selectedId] {
            TavernLogger.coordination.info("updateActiveChatViewModel: using cached viewModel for \(selectedId)")
            activeChatViewModel = existingViewModel
        } else {
            // Create a new chat view model for this agent
            // We need to get the agent from spawner
            if let anyAgent = spawner.activeAgents.first(where: { $0.id == selectedId }) {
                TavernLogger.coordination.info("updateActiveChatViewModel: creating new viewModel for \(anyAgent.name)")
                // Pass project path so mortal agents can load their session history
                let viewModel = ChatViewModel(agent: anyAgent, projectPath: jake.projectPath)
                chatViewModels[selectedId] = viewModel
                activeChatViewModel = viewModel
            } else {
                // Agent not found, fallback to Jake
                TavernLogger.coordination.error("updateActiveChatViewModel: agent \(selectedId) not found, using Jake")
                activeChatViewModel = jakeChatViewModel
            }
        }
        TavernLogger.coordination.info("Active chat now: \(self.activeChatViewModel.agentName)")
    }

    // MARK: - Agent Lifecycle

    /// Spawn a new agent for user interaction (no assignment)
    /// The agent waits for the user's first message
    /// - Parameter selectAfterSpawn: Whether to switch to the new agent's chat
    /// - Returns: The spawned agent
    @discardableResult
    public func spawnAgent(selectAfterSpawn: Bool = true) throws -> MortalAgent {
        TavernLogger.coordination.info("Spawning new agent (user-spawned, no assignment)")

        let agent = try spawner.spawn()
        TavernLogger.coordination.info("Agent spawned: \(agent.name) (id: \(agent.id))")

        // Persist the agent
        persistAgent(agent)

        // Refresh the list
        agentListViewModel.agentsDidChange()

        // Optionally select the new agent
        if selectAfterSpawn {
            selectAgent(id: agent.id)
        }

        return agent
    }

    /// Spawn a new agent with an assignment (Jake-spawned)
    /// - Parameters:
    ///   - assignment: The task for the agent
    ///   - selectAfterSpawn: Whether to switch to the new agent's chat
    /// - Returns: The spawned agent
    @discardableResult
    public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
        TavernLogger.coordination.info("Spawning new agent with assignment: \(assignment)")

        let agent = try spawner.spawn(assignment: assignment)
        TavernLogger.coordination.info("Agent spawned: \(agent.name) (id: \(agent.id))")

        // Persist the agent
        persistAgent(agent)

        // Refresh the list
        agentListViewModel.agentsDidChange()

        // Optionally select the new agent
        if selectAfterSpawn {
            selectAgent(id: agent.id)
        }

        return agent
    }

    /// Close an agent (remove from UI and persistence, keep Claude session orphaned)
    /// - Parameter agentId: The ID of the agent to close
    public func closeAgent(id agentId: UUID) throws {
        TavernLogger.coordination.info("Closing agent: \(agentId)")

        // Remove the chat view model
        chatViewModels.removeValue(forKey: agentId)

        // Remove from persistence (doesn't delete Claude session)
        SessionStore.removeAgent(id: agentId)

        // Dismiss from spawner
        try spawner.dismiss(id: agentId)
        TavernLogger.coordination.info("Agent closed successfully: \(agentId)")

        // Update the list (will select Jake if closed agent was selected)
        agentListViewModel.agentsDidChange()

        // Update active view model
        updateActiveChatViewModel()
    }

    /// Dismiss an agent (alias for closeAgent for backward compatibility)
    /// - Parameter agentId: The ID of the agent to dismiss
    public func dismissAgent(id agentId: UUID) throws {
        try closeAgent(id: agentId)
    }

    // MARK: - Agent Persistence

    /// Persist an agent to UserDefaults
    private func persistAgent(_ agent: MortalAgent) {
        let persisted = SessionStore.PersistedAgent(
            id: agent.id,
            name: agent.name,
            sessionId: agent.sessionId,
            chatDescription: agent.chatDescription
        )
        SessionStore.addAgent(persisted)
        TavernLogger.coordination.debug("Persisted agent: \(agent.name) (id: \(agent.id))")
    }

    // MARK: - Refresh

    /// Refresh all state
    public func refresh() {
        agentListViewModel.refreshItems()
        updateActiveChatViewModel()
    }
}
