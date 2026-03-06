import Foundation
import Observation
import TavernKit
import os.log

// MARK: - Provenance: REQ-ARCH-005

/// Represents an open project in the Tavern
/// A project is simply a directory that serves as the working context for agents
@Observable @MainActor
public final class TavernProject: Identifiable {

    // MARK: - Properties

    /// Unique identifier for this project instance
    public let id: UUID

    /// The root directory of the project
    public let rootURL: URL

    /// Human-readable name (derived from directory name)
    public var name: String {
        rootURL.lastPathComponent
    }

    /// Whether the project is fully initialized
    public private(set) var isReady: Bool = false

    /// Any error that occurred during initialization
    public private(set) var initializationError: Error?

    // MARK: - Providers (for tileboard architecture)

    /// Provider for Claude session access
    public private(set) var servitorProvider: (any ServitorProvider)?

    /// Provider for file tree browsing
    public private(set) var resourceProvider: (any ResourceProvider)?

    /// Provider for slash command execution
    public private(set) var commandProvider: (any CommandProvider)?

    /// Provider for permission management
    public private(set) var permissionProvider: (any PermissionProvider)?

    // MARK: - Initialization

    /// Create a project for the given directory
    /// - Parameter rootURL: The root directory URL
    public init(rootURL: URL) {
        self.id = UUID()
        self.rootURL = rootURL

        TavernLogger.coordination.info("TavernProject created for: \(rootURL.path)")
    }

    /// Initialize the project (creates coordinator, Jake, etc.)
    /// Call this after creation to set up the project
    public func initialize() async {
        TavernLogger.coordination.info("[\(self.name)] Initializing project at: \(self.rootURL.path)")

        let permissionManager = PermissionManager(store: PermissionStore())
        TavernLogger.coordination.debug("[\(self.name)] PermissionManager created, mode=\(permissionManager.mode.rawValue)")

        let directory = ProjectDirectory(rootURL: rootURL)

        // Load Jake's session ID from directory for resume
        let jakeSessionId = (try? directory.loadServitor(name: "jake"))?.sessionId

        TavernLogger.coordination.debug("[\(self.name)] Creating Jake...")
        let jake = Jake(projectURL: rootURL, initialSessionId: jakeSessionId, permissionManager: permissionManager)
        TavernLogger.coordination.debug("[\(self.name)] Jake created")

        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)

        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: rootURL,
            messengerFactory: { agentName in
                LiveMessenger(
                    permissionManager: permissionManager,
                    agentName: agentName
                )
            }
        )
        TavernLogger.coordination.debug("[\(self.name)] MortalSpawner created")

        // Create the session manager (ServitorProvider)
        let sessionManager = ClodSessionManager(
            jake: jake,
            spawner: spawner,
            permissionManager: permissionManager,
            projectURL: rootURL,
            directory: directory
        )

        // Setup MCP server for Jake
        let mcpServer = createTavernMCPServer(
            spawner: spawner,
            onSummon: { [directory] servitor in
                let record = ServitorRecord(
                    name: servitor.name,
                    id: servitor.id,
                    assignment: (servitor as? Mortal)?.assignment,
                    sessionId: servitor.sessionId,
                    description: servitor.chatDescription
                )
                do {
                    try directory.saveServitor(record)
                } catch {
                    TavernLogger.coordination.error("Failed to persist summoned servitor \(servitor.name): \(error.localizedDescription)")
                }
                TavernLogger.coordination.info("Jake summoned servitor: \(servitor.name)")
            },
            onDismiss: { servitorId in
                // Removal is handled by ClodSessionManager.closeServitor
                TavernLogger.coordination.info("Jake dismissed servitor: \(servitorId)")
            }
        )
        jake.mcpServer = mcpServer
        sessionManager.jakeMCPServer = mcpServer

        // Create slash command dispatcher and register commands
        let commandDispatcher = SlashCommandDispatcher()
        let commandContext = CommandContext()
        commandDispatcher.registerAll([
            HelpCommand(dispatcher: commandDispatcher),
            CompactCommand(context: commandContext),
            CostCommand(context: commandContext),
            ModelCommand(context: commandContext),
            StatusCommand(context: commandContext),
            ContextCommand(context: commandContext),
            StatsCommand(context: commandContext),
            ThinkingCommand(context: commandContext),
            ServitorsCommand(servitorListProvider: { [weak sessionManager] in
                sessionManager?.allServitors() ?? []
            }),
            HooksCommand(projectPath: rootURL.path),
            MCPCommand(projectPath: rootURL.path)
        ])
        let customCommands = CustomCommandLoader.loadCommands(projectPath: rootURL.path)
        commandDispatcher.registerAll(customCommands)
        TavernLogger.coordination.info("[\(self.name)] Registered \(commandDispatcher.commands.count) slash commands (\(customCommands.count) custom)")

        // Restore persisted servitors from file-system store
        do {
            let records = try directory.listAllServitors()
            for record in records where record.name.lowercased() != "jake" {
                let mortal = Mortal(
                    id: record.id,
                    name: record.name,
                    assignment: record.assignment,
                    chatDescription: record.description,
                    projectURL: rootURL,
                    initialSessionId: record.sessionId,
                    messenger: LiveMessenger(
                        permissionManager: permissionManager,
                        agentName: record.name
                    )
                )
                do {
                    try spawner.register(mortal)
                    TavernLogger.coordination.info("[\(self.name)] Restored mortal: \(record.name)")
                } catch {
                    TavernLogger.coordination.error("[\(self.name)] Failed to restore mortal \(record.name): \(error.localizedDescription)")
                }
            }
        } catch {
            TavernLogger.coordination.error("[\(self.name)] Failed to list persisted servitors: \(error.localizedDescription)")
        }
        if spawner.mortalCount > 0 {
            TavernLogger.coordination.info("[\(self.name)] Restored \(spawner.mortalCount) persisted servitors")
        }

        // Wire up providers
        self.servitorProvider = sessionManager
        self.resourceProvider = directory
        self.commandProvider = CommandRegistry(
            dispatcher: commandDispatcher,
            projectRoot: rootURL
        )
        self.permissionProvider = PermissionSettingsProvider(manager: permissionManager)

        self.isReady = true
        TavernLogger.coordination.info("[\(self.name)] Project initialized successfully (with providers)")
    }
}

// MARK: - Equatable

extension TavernProject: Equatable {
    nonisolated public static func == (lhs: TavernProject, rhs: TavernProject) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension TavernProject: Hashable {
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
