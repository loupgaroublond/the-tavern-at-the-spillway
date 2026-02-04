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

    /// Spawner for servitors
    public let spawner: ServitorSpawner

    // MARK: - Private State

    /// Chat view models keyed by agent ID
    private var chatViewModels: [UUID: ChatViewModel] = [:]

    /// Jake's chat view model (always exists)
    private let jakeChatViewModel: ChatViewModel

    /// Project URL for creating restored servitors
    private let projectURL: URL

    /// The MCP server for Jake's tools (optional to allow delayed init)
    private var mcpServer: SDKMCPServer?

    // MARK: - Initialization

    /// Create the coordinator with dependencies
    /// - Parameters:
    ///   - jake: The Proprietor
    ///   - spawner: Servitor spawner for the Slop Squad
    ///   - projectURL: The project directory URL
    public init(jake: Jake, spawner: ServitorSpawner, projectURL: URL) {
        self.jake = jake
        self.spawner = spawner
        self.projectURL = projectURL

        // Create Jake's chat view model
        self.jakeChatViewModel = ChatViewModel(jake: jake)
        self.chatViewModels[jake.id] = jakeChatViewModel

        // Start with Jake's chat as active
        self.activeChatViewModel = jakeChatViewModel

        // Create the agent list view model
        self.agentListViewModel = AgentListViewModel(jake: jake, spawner: spawner)

        // Setup MCP server for Jake's tools (must be after all stored properties initialized)
        setupMCPServer()

        // Restore persisted servitors
        restoreServitors()
    }

    /// Setup the MCP server for Jake - called after init completes
    private func setupMCPServer() {
        let server = createTavernMCPServer(
            spawner: spawner,
            onSummon: { [weak self] servitor in
                guard let coordinator = self else { return }
                await MainActor.run {
                    coordinator.persistServitor(servitor)
                    coordinator.agentListViewModel.agentsDidChange()
                }
                TavernLogger.coordination.info("Jake summoned servitor: \(servitor.name)")
            },
            onDismiss: { [weak self] servitorId in
                guard let coordinator = self else { return }
                await MainActor.run {
                    coordinator.chatViewModels.removeValue(forKey: servitorId)
                    SessionStore.removeAgent(id: servitorId)
                    coordinator.agentListViewModel.agentsDidChange()
                    coordinator.updateActiveChatViewModel()
                }
                TavernLogger.coordination.info("Jake dismissed servitor: \(servitorId)")
            }
        )
        self.mcpServer = server
        jake.mcpServer = server
        TavernLogger.coordination.info("TavernMCPServer configured for Jake")
    }

    // MARK: - Servitor Restoration

    /// Restore servitors from UserDefaults on app launch
    private func restoreServitors() {
        let persistedAgents = SessionStore.loadAgentList()
        TavernLogger.coordination.info("Restoring \(persistedAgents.count) persisted servitors")

        for persisted in persistedAgents {
            let servitor = Servitor(
                id: persisted.id,
                name: persisted.name,
                assignment: nil,  // Restored servitors don't have original assignment
                chatDescription: persisted.chatDescription,
                projectURL: projectURL,
                loadSavedSession: true  // Will load session from SessionStore
            )

            do {
                try spawner.register(servitor)
                TavernLogger.coordination.info("Restored servitor: \(persisted.name) (id: \(persisted.id))")
            } catch {
                TavernLogger.coordination.error("Failed to restore servitor \(persisted.name): \(error.localizedDescription)")
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
            // Create a new chat view model for this servitor
            // We need to get the servitor from spawner
            if let anyAgent = spawner.activeServitors.first(where: { $0.id == selectedId }) {
                TavernLogger.coordination.info("updateActiveChatViewModel: creating new viewModel for \(anyAgent.name)")
                // Pass project path so servitors can load their session history
                let viewModel = ChatViewModel(agent: anyAgent, projectPath: jake.projectPath)
                chatViewModels[selectedId] = viewModel
                activeChatViewModel = viewModel
            } else {
                // Servitor not found, fallback to Jake
                TavernLogger.coordination.error("updateActiveChatViewModel: servitor \(selectedId) not found, using Jake")
                activeChatViewModel = jakeChatViewModel
            }
        }
        TavernLogger.coordination.info("Active chat now: \(self.activeChatViewModel.agentName)")
    }

    // MARK: - Agent Lifecycle

    /// Summon a new servitor for user interaction (no assignment)
    /// The servitor waits for the user's first message
    /// - Parameter selectAfterSummon: Whether to switch to the new servitor's chat
    /// - Returns: The summoned servitor
    @discardableResult
    public func summonServitor(selectAfterSummon: Bool = true) throws -> Servitor {
        TavernLogger.coordination.info("Summoning new servitor (user-spawned, no assignment)")

        let servitor = try spawner.summon()
        TavernLogger.coordination.info("Servitor summoned: \(servitor.name) (id: \(servitor.id))")

        // Persist the servitor
        persistServitor(servitor)

        // Refresh the list
        agentListViewModel.agentsDidChange()

        // Optionally select the new servitor
        if selectAfterSummon {
            selectAgent(id: servitor.id)
        }

        return servitor
    }

    /// Summon a new servitor with an assignment (Jake-summoned)
    /// - Parameters:
    ///   - assignment: The assignment for the servitor
    ///   - selectAfterSummon: Whether to switch to the new servitor's chat
    /// - Returns: The summoned servitor
    @discardableResult
    public func summonServitor(assignment: String, selectAfterSummon: Bool = true) throws -> Servitor {
        TavernLogger.coordination.info("Summoning new servitor with assignment: \(assignment)")

        let servitor = try spawner.summon(assignment: assignment)
        TavernLogger.coordination.info("Servitor summoned: \(servitor.name) (id: \(servitor.id))")

        // Persist the servitor
        persistServitor(servitor)

        // Refresh the list
        agentListViewModel.agentsDidChange()

        // Optionally select the new servitor
        if selectAfterSummon {
            selectAgent(id: servitor.id)
        }

        return servitor
    }

    /// Close a servitor (remove from UI and persistence, keep Claude session orphaned)
    /// - Parameter servitorId: The ID of the servitor to close
    public func closeServitor(id servitorId: UUID) throws {
        TavernLogger.coordination.info("Closing servitor: \(servitorId)")

        // Remove the chat view model
        chatViewModels.removeValue(forKey: servitorId)

        // Remove from persistence (doesn't delete Claude session)
        SessionStore.removeAgent(id: servitorId)

        // Dismiss from spawner
        try spawner.dismiss(id: servitorId)
        TavernLogger.coordination.info("Servitor closed successfully: \(servitorId)")

        // Update the list (will select Jake if closed servitor was selected)
        agentListViewModel.agentsDidChange()

        // Update active view model
        updateActiveChatViewModel()
    }

    /// Dismiss a servitor (alias for closeServitor for backward compatibility)
    /// - Parameter servitorId: The ID of the servitor to dismiss
    public func dismissServitor(id servitorId: UUID) throws {
        try closeServitor(id: servitorId)
    }

    // MARK: - Legacy compatibility methods

    /// Spawn a new agent (legacy - calls summonServitor)
    @available(*, deprecated, renamed: "summonServitor(selectAfterSummon:)")
    @discardableResult
    public func spawnAgent(selectAfterSpawn: Bool = true) throws -> Servitor {
        try summonServitor(selectAfterSummon: selectAfterSpawn)
    }

    /// Spawn a new agent with assignment (legacy - calls summonServitor)
    @available(*, deprecated, renamed: "summonServitor(assignment:selectAfterSummon:)")
    @discardableResult
    public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> Servitor {
        try summonServitor(assignment: assignment, selectAfterSummon: selectAfterSpawn)
    }

    /// Close an agent (legacy - calls closeServitor)
    @available(*, deprecated, renamed: "closeServitor(id:)")
    public func closeAgent(id agentId: UUID) throws {
        try closeServitor(id: agentId)
    }

    /// Dismiss an agent (legacy - calls dismissServitor)
    @available(*, deprecated, renamed: "dismissServitor(id:)")
    public func dismissAgent(id agentId: UUID) throws {
        try dismissServitor(id: agentId)
    }

    // MARK: - Servitor Persistence

    /// Persist a servitor to UserDefaults
    private func persistServitor(_ servitor: Servitor) {
        let persisted = SessionStore.PersistedAgent(
            id: servitor.id,
            name: servitor.name,
            sessionId: servitor.sessionId,
            chatDescription: servitor.chatDescription
        )
        SessionStore.addAgent(persisted)
        TavernLogger.coordination.debug("Persisted servitor: \(servitor.name) (id: \(servitor.id))")
    }

    // MARK: - Refresh

    /// Refresh all state
    public func refresh() {
        agentListViewModel.refreshItems()
        updateActiveChatViewModel()
    }
}
