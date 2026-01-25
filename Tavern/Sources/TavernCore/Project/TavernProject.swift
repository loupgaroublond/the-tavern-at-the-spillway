import Foundation
import ClaudeCodeSDK
import os.log

/// Represents an open project in the Tavern
/// A project is simply a directory that serves as the working context for agents
@MainActor
public final class TavernProject: ObservableObject, Identifiable {

    // MARK: - Properties

    /// Unique identifier for this project instance
    public let id: UUID

    /// The root directory of the project
    public let rootURL: URL

    /// Human-readable name (derived from directory name)
    public var name: String {
        rootURL.lastPathComponent
    }

    /// The coordinator for this project (owns Jake and agents)
    @Published public private(set) var coordinator: TavernCoordinator?

    /// Whether the project is fully initialized
    @Published public private(set) var isReady: Bool = false

    /// Any error that occurred during initialization
    @Published public private(set) var initializationError: Error?

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

        do {
            TavernLogger.coordination.debug("[\(self.name)] Creating ClaudeCode client...")
            let claude = try Self.createClaudeCode(for: rootURL)
            TavernLogger.coordination.debug("[\(self.name)] ClaudeCode client created")

            TavernLogger.coordination.debug("[\(self.name)] Creating Jake...")
            let jake = Jake(claude: claude)
            TavernLogger.coordination.debug("[\(self.name)] Jake created")

            let registry = AgentRegistry()
            let nameGenerator = NameGenerator(theme: .lotr)
            let spawner = AgentSpawner(
                registry: registry,
                nameGenerator: nameGenerator,
                claudeFactory: { [rootURL] in
                    // Each spawned agent gets its own ClaudeCode instance
                    // scoped to the same project
                    do {
                        return try Self.createClaudeCode(for: rootURL)
                    } catch {
                        TavernLogger.coordination.error("Failed to create ClaudeCode for spawned agent: \(error.localizedDescription)")
                        // Fall back to mock if real client fails
                        let mock = MockClaudeCode()
                        mock.errorToThrow = error
                        return mock
                    }
                }
            )
            TavernLogger.coordination.debug("[\(self.name)] AgentSpawner created")

            TavernLogger.coordination.debug("[\(self.name)] Creating TavernCoordinator...")
            self.coordinator = TavernCoordinator(jake: jake, spawner: spawner)
            self.isReady = true

            TavernLogger.coordination.info("[\(self.name)] Project initialized successfully")

        } catch {
            self.initializationError = error
            TavernLogger.coordination.error("[\(self.name)] Project initialization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - ClaudeCode Factory

    /// Create a ClaudeCode instance configured for this project
    private static func createClaudeCode(for rootURL: URL) throws -> ClaudeCode {
        var config = ClaudeCodeConfiguration.default
        config.workingDirectory = rootURL.path
        config.enableDebugLogging = true

        TavernLogger.claude.debug("Creating ClaudeCode with workingDirectory: \(rootURL.path)")

        return try ClaudeCodeClient(configuration: config)
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
