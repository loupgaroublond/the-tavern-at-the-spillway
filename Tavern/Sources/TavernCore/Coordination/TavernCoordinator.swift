import Foundation
import ClodKit
import os.log

// MARK: - Provenance: REQ-AGT-007, REQ-ARCH-002, REQ-ARCH-005, REQ-COM-008

/// Coordinates the Tavern's agents and their chat sessions
/// This is the central hub that ties together Jake, the Slop Squad, and the UI
@MainActor
public final class TavernCoordinator: ObservableObject {

    // MARK: - Published State

    /// The agent list view model (manages selection)
    @Published public private(set) var servitorListViewModel: ServitorListViewModel

    /// Currently active chat view model
    @Published public private(set) var activeChatViewModel: ChatViewModel

    // MARK: - Core Components

    /// Jake - The Proprietor (eternal, always present)
    public let jake: Jake

    /// Spawner for servitors
    public let spawner: MortalSpawner

    /// Permission manager shared across all agents in this project
    public let permissionManager: PermissionManager

    /// Slash command dispatcher (shared across all chats in this project)
    public let commandDispatcher: SlashCommandDispatcher

    /// Shared command context (model settings, usage tracking)
    public let commandContext: CommandContext

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
    ///   - permissionManager: Permission manager for tool checks (default: new instance with standard store)
    ///   - restoreState: Whether to restore persisted state (session history, custom commands, saved servitors). Pass false in tests.
    public init(jake: Jake, spawner: MortalSpawner, projectURL: URL, permissionManager: PermissionManager = PermissionManager(store: PermissionStore()), restoreState: Bool = true) {
        self.jake = jake
        self.spawner = spawner
        self.projectURL = projectURL
        self.permissionManager = permissionManager
        self.commandDispatcher = SlashCommandDispatcher()
        self.commandContext = CommandContext()

        // Create Jake's chat view model
        self.jakeChatViewModel = ChatViewModel(jake: jake, loadHistory: restoreState)
        self.chatViewModels[jake.id] = jakeChatViewModel

        // Start with Jake's chat as active
        self.activeChatViewModel = jakeChatViewModel

        // Wire up command dispatcher to Jake's chat
        self.jakeChatViewModel.commandDispatcher = commandDispatcher

        // Create the agent list view model
        self.servitorListViewModel = ServitorListViewModel(jake: jake, spawner: spawner)

        // Post-init setup (all stored properties must be initialized above)
        registerCoreCommands()
        setupMCPServer()
        if restoreState {
            loadCustomCommands()
            restoreServitors()
        }
    }

    /// Setup the MCP server for Jake - called after init completes
    private func setupMCPServer() {
        let server = createTavernMCPServer(
            spawner: spawner,
            onSummon: { [weak self] servitor in
                guard let coordinator = self else { return }
                await MainActor.run {
                    coordinator.persistServitor(servitor)
                    coordinator.servitorListViewModel.servitorsDidChange()
                }
                TavernLogger.coordination.info("Jake summoned servitor: \(servitor.name)")
            },
            onDismiss: { [weak self] servitorId in
                guard let coordinator = self else { return }
                await MainActor.run {
                    coordinator.chatViewModels.removeValue(forKey: servitorId)
                    SessionStore.removeServitor(id: servitorId)
                    coordinator.servitorListViewModel.servitorsDidChange()
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
        let persistedServitors = SessionStore.loadServitorList()
        TavernLogger.coordination.info("Restoring \(persistedServitors.count) persisted servitors")

        for persisted in persistedServitors {
            let mortal = Mortal(
                id: persisted.id,
                name: persisted.name,
                assignment: nil,  // Restored mortals don't have original assignment
                chatDescription: persisted.chatDescription,
                projectURL: projectURL,
                messenger: LiveMessenger(
                    permissionManager: permissionManager,
                    agentName: persisted.name
                ),
                loadSavedSession: true  // Will load session from SessionStore
            )

            do {
                try spawner.register(mortal)
                TavernLogger.coordination.info("Restored mortal: \(persisted.name) (id: \(persisted.id))")
            } catch {
                TavernLogger.coordination.error("Failed to restore mortal \(persisted.name): \(error.localizedDescription)")
            }
        }

        // Refresh UI
        servitorListViewModel.servitorsDidChange()
    }

    // MARK: - Servitor Selection

    /// Select a servitor to chat with
    /// - Parameter servitorId: The ID of the servitor to select
    public func selectServitor(id servitorId: UUID) {
        TavernLogger.coordination.info("Servitor selection changed to: \(servitorId)")
        servitorListViewModel.selectServitor(id: servitorId)
        updateActiveChatViewModel()
    }

    /// Update the active chat view model based on selection
    private func updateActiveChatViewModel() {
        guard let selectedId = servitorListViewModel.selectedServitorId else {
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
            if let anyServitor = spawner.activeMortals.first(where: { $0.id == selectedId }) {
                TavernLogger.coordination.info("updateActiveChatViewModel: creating new viewModel for \(anyServitor.name)")
                // Pass project path so mortals can load their session history
                let viewModel = ChatViewModel(servitor: anyServitor, projectPath: jake.projectPath)
                viewModel.commandDispatcher = commandDispatcher
                chatViewModels[selectedId] = viewModel
                activeChatViewModel = viewModel
            } else {
                // Servitor not found, fallback to Jake
                TavernLogger.coordination.error("updateActiveChatViewModel: servitor \(selectedId) not found, using Jake")
                activeChatViewModel = jakeChatViewModel
            }
        }
        TavernLogger.coordination.info("Active chat now: \(self.activeChatViewModel.servitorName)")
    }

    // MARK: - Servitor Lifecycle

    /// Summon a new servitor for user interaction (no assignment)
    /// The servitor waits for the user's first message
    /// - Parameter selectAfterSummon: Whether to switch to the new servitor's chat
    /// - Returns: The summoned servitor
    @discardableResult
    public func summonServitor(selectAfterSummon: Bool = true) throws -> Mortal {
        TavernLogger.coordination.info("Summoning new servitor (user-spawned, no assignment)")

        let servitor = try spawner.summon()
        TavernLogger.coordination.info("Servitor summoned: \(servitor.name) (id: \(servitor.id))")

        // Persist the servitor
        persistServitor(servitor)

        // Refresh the list
        servitorListViewModel.servitorsDidChange()

        // Optionally select the new servitor
        if selectAfterSummon {
            selectServitor(id: servitor.id)
        }

        return servitor
    }

    /// Summon a new servitor with an assignment (Jake-summoned)
    /// - Parameters:
    ///   - assignment: The assignment for the servitor
    ///   - selectAfterSummon: Whether to switch to the new servitor's chat
    /// - Returns: The summoned servitor
    @discardableResult
    public func summonServitor(assignment: String, selectAfterSummon: Bool = true) throws -> Mortal {
        TavernLogger.coordination.info("Summoning new servitor with assignment: \(assignment)")

        let servitor = try spawner.summon(assignment: assignment)
        TavernLogger.coordination.info("Servitor summoned: \(servitor.name) (id: \(servitor.id))")

        // Persist the servitor
        persistServitor(servitor)

        // Refresh the list
        servitorListViewModel.servitorsDidChange()

        // Optionally select the new servitor
        if selectAfterSummon {
            selectServitor(id: servitor.id)
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
        SessionStore.removeServitor(id: servitorId)

        // Dismiss from spawner
        try spawner.dismiss(id: servitorId)
        TavernLogger.coordination.info("Servitor closed successfully: \(servitorId)")

        // Update the list (will select Jake if closed servitor was selected)
        servitorListViewModel.servitorsDidChange()

        // Update active view model
        updateActiveChatViewModel()
    }

    /// Dismiss a servitor (alias for closeServitor for backward compatibility)
    /// - Parameter servitorId: The ID of the servitor to dismiss
    public func dismissServitor(id servitorId: UUID) throws {
        try closeServitor(id: servitorId)
    }

    // MARK: - Servitor Persistence

    /// Persist a servitor to UserDefaults
    private func persistServitor(_ mortal: Mortal) {
        let persisted = SessionStore.PersistedServitor(
            id: mortal.id,
            name: mortal.name,
            sessionId: mortal.sessionId,
            chatDescription: mortal.chatDescription
        )
        SessionStore.addServitor(persisted)
        TavernLogger.coordination.debug("Persisted mortal: \(mortal.name) (id: \(mortal.id))")
    }

    // MARK: - Commands

    /// Register the core slash commands with the dispatcher
    private func registerCoreCommands() {
        commandDispatcher.registerAll([
            HelpCommand(dispatcher: commandDispatcher),
            CompactCommand(context: commandContext),
            CostCommand(context: commandContext),
            ModelCommand(context: commandContext),
            StatusCommand(context: commandContext),
            ContextCommand(context: commandContext),
            StatsCommand(context: commandContext),
            ThinkingCommand(context: commandContext),
            ServitorsCommand(servitorListProvider: { [weak self] in
                self?.servitorListViewModel.items ?? []
            }),
            HooksCommand(projectPath: projectURL.path),
            MCPCommand(projectPath: projectURL.path)
        ])
        TavernLogger.coordination.info("Registered \(self.commandDispatcher.commands.count) core slash commands")
    }

    /// Load custom commands from .claude/commands/ directories
    private func loadCustomCommands() {
        let customCommands = CustomCommandLoader.loadCommands(projectPath: projectURL.path)
        commandDispatcher.registerAll(customCommands)
        if !customCommands.isEmpty {
            TavernLogger.coordination.info("Loaded \(customCommands.count) custom commands for project")
        }
    }

    /// Reload custom commands (e.g., after file changes)
    public func reloadCustomCommands() {
        // Remove existing custom commands (keep built-in ones)
        commandDispatcher.removeAll { $0 is CustomCommand }
        loadCustomCommands()
        TavernLogger.coordination.info("Reloaded custom commands")
    }

    // MARK: - Refresh

    /// Refresh all state
    public func refresh() {
        servitorListViewModel.refreshItems()
        updateActiveChatViewModel()
    }
}
