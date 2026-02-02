import Foundation
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

        TavernLogger.coordination.debug("[\(self.name)] Creating Jake...")
        let jake = Jake(projectURL: rootURL)
        TavernLogger.coordination.debug("[\(self.name)] Jake created")

        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)

        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: rootURL
        )
        TavernLogger.coordination.debug("[\(self.name)] AgentSpawner created")

        TavernLogger.coordination.debug("[\(self.name)] Creating TavernCoordinator...")
        self.coordinator = TavernCoordinator(jake: jake, spawner: spawner, projectURL: rootURL)
        self.isReady = true

        TavernLogger.coordination.info("[\(self.name)] Project initialized successfully")
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
