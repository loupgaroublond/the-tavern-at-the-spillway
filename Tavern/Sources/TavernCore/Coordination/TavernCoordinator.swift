import Foundation
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

    // MARK: - Initialization

    /// Create the coordinator with dependencies
    /// - Parameters:
    ///   - jake: The Proprietor
    ///   - spawner: Agent spawner for the Slop Squad
    public init(jake: Jake, spawner: AgentSpawner) {
        self.jake = jake
        self.spawner = spawner

        // Create Jake's chat view model
        self.jakeChatViewModel = ChatViewModel(jake: jake)
        self.chatViewModels[jake.id] = jakeChatViewModel

        // Start with Jake's chat as active
        self.activeChatViewModel = jakeChatViewModel

        // Create the agent list view model
        self.agentListViewModel = AgentListViewModel(jake: jake, spawner: spawner)
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
            activeChatViewModel = jakeChatViewModel
            return
        }

        if selectedId == jake.id {
            activeChatViewModel = jakeChatViewModel
        } else if let existingViewModel = chatViewModels[selectedId] {
            activeChatViewModel = existingViewModel
        } else {
            // Create a new chat view model for this agent
            // We need to get the agent from spawner
            if let anyAgent = spawner.activeAgents.first(where: { $0.id == selectedId }) {
                let viewModel = ChatViewModel(agent: anyAgent)
                chatViewModels[selectedId] = viewModel
                activeChatViewModel = viewModel
            } else {
                // Agent not found, fallback to Jake
                activeChatViewModel = jakeChatViewModel
            }
        }
    }

    // MARK: - Agent Lifecycle

    /// Spawn a new agent and optionally select it
    /// - Parameters:
    ///   - assignment: The task for the agent
    ///   - selectAfterSpawn: Whether to switch to the new agent's chat
    /// - Returns: The spawned agent
    @discardableResult
    public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
        TavernLogger.coordination.info("Spawning new agent with assignment: \(assignment)")

        let agent = try spawner.spawn(assignment: assignment)
        TavernLogger.coordination.info("Agent spawned: \(agent.name) (id: \(agent.id))")

        // Cache the assignment for display
        agentListViewModel.cacheAssignment(agentId: agent.id, assignment: assignment)

        // Refresh the list
        agentListViewModel.agentsDidChange()

        // Optionally select the new agent
        if selectAfterSpawn {
            selectAgent(id: agent.id)
        }

        return agent
    }

    /// Dismiss an agent
    /// - Parameter agentId: The ID of the agent to dismiss
    public func dismissAgent(id agentId: UUID) throws {
        TavernLogger.coordination.info("Dismissing agent: \(agentId)")

        // Remove the chat view model
        chatViewModels.removeValue(forKey: agentId)

        // Dismiss from spawner
        try spawner.dismiss(id: agentId)
        TavernLogger.coordination.info("Agent dismissed successfully: \(agentId)")

        // Update the list (will select Jake if dismissed agent was selected)
        agentListViewModel.agentsDidChange()

        // Update active view model
        updateActiveChatViewModel()
    }

    // MARK: - Refresh

    /// Refresh all state
    public func refresh() {
        agentListViewModel.refreshItems()
        updateActiveChatViewModel()
    }
}
