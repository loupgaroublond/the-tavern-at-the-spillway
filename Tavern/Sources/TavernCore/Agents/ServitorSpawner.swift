import Foundation
import os.log

/// Spawns and manages servitors for the Tavern
/// This is Jake's way of delegating work to the Slop Squad
public final class ServitorSpawner: @unchecked Sendable {

    // MARK: - Dependencies

    private let registry: AgentRegistry
    private let nameGenerator: NameGenerator
    private let projectURL: URL

    // MARK: - Initialization

    /// Create a spawner with dependencies
    /// - Parameters:
    ///   - registry: The agent registry to add spawned servitors to
    ///   - nameGenerator: The name generator for themed names
    ///   - projectURL: The project directory URL for spawned servitors
    public init(
        registry: AgentRegistry,
        nameGenerator: NameGenerator,
        projectURL: URL
    ) {
        self.registry = registry
        self.nameGenerator = nameGenerator
        self.projectURL = projectURL
    }

    // MARK: - Summoning

    /// Summon a new servitor without an assignment (user-spawned)
    /// The servitor waits for the user's first message
    /// - Returns: The summoned servitor
    /// - Throws: If registration fails (e.g., name collision, though unlikely with generator)
    @discardableResult
    public func summon() throws -> Servitor {
        TavernLogger.coordination.debug("ServitorSpawner.summon called (no assignment)")

        let name = nameGenerator.nextNameOrFallback()
        TavernLogger.coordination.debug("Generated name: \(name)")

        let servitor = Servitor(
            name: name,
            assignment: nil,
            projectURL: projectURL
        )

        try registry.register(servitor)
        TavernLogger.coordination.info("Servitor summoned and registered: \(name) (id: \(servitor.id))")

        return servitor
    }

    /// Summon a new servitor with an assignment (Jake-summoned)
    /// - Parameter assignment: The assignment description for the servitor
    /// - Returns: The summoned servitor
    /// - Throws: If registration fails (e.g., name collision, though unlikely with generator)
    @discardableResult
    public func summon(assignment: String) throws -> Servitor {
        TavernLogger.coordination.debug("ServitorSpawner.summon called, assignment: \(assignment)")

        let name = nameGenerator.nextNameOrFallback()
        TavernLogger.coordination.debug("Generated name: \(name)")

        let servitor = Servitor(
            name: name,
            assignment: assignment,
            projectURL: projectURL
        )

        try registry.register(servitor)
        TavernLogger.coordination.info("Servitor summoned and registered: \(name) (id: \(servitor.id))")

        return servitor
    }

    /// Summon a new servitor with a specific name (for testing or Jake's use)
    /// - Parameters:
    ///   - name: The desired name for the servitor
    ///   - assignment: The assignment description for the servitor (optional)
    /// - Returns: The summoned servitor
    /// - Throws: If the name is taken or registration fails
    @discardableResult
    public func summon(name: String, assignment: String?) throws -> Servitor {
        TavernLogger.coordination.debug("ServitorSpawner.summon called with name: \(name), assignment: \(assignment ?? "<none>")")

        // Reserve the name first
        guard nameGenerator.reserveName(name) else {
            TavernLogger.coordination.error("Name already exists: \(name)")
            throw AgentRegistryError.nameAlreadyExists(name)
        }

        let servitor = Servitor(
            name: name,
            assignment: assignment,
            projectURL: projectURL
        )

        do {
            try registry.register(servitor)
            TavernLogger.coordination.info("Servitor summoned and registered: \(name) (id: \(servitor.id))")
        } catch {
            // Release the name if registration fails
            TavernLogger.coordination.error("Registration failed for \(name): \(error.localizedDescription)")
            nameGenerator.releaseName(name)
            throw error
        }

        return servitor
    }

    /// Register a pre-created servitor (for restoration on app launch)
    /// - Parameter servitor: The servitor to register
    /// - Throws: If registration fails
    public func register(_ servitor: Servitor) throws {
        TavernLogger.coordination.debug("ServitorSpawner.register called for: \(servitor.name) (id: \(servitor.id))")

        // Reserve the name
        guard nameGenerator.reserveName(servitor.name) else {
            TavernLogger.coordination.error("Name already exists during restore: \(servitor.name)")
            throw AgentRegistryError.nameAlreadyExists(servitor.name)
        }

        do {
            try registry.register(servitor)
            TavernLogger.coordination.info("Servitor restored and registered: \(servitor.name) (id: \(servitor.id))")
        } catch {
            nameGenerator.releaseName(servitor.name)
            throw error
        }
    }

    /// Dismiss a servitor (remove from registry, release name)
    /// - Parameter servitor: The servitor to dismiss
    /// - Throws: If the servitor is not in the registry
    public func dismiss(_ servitor: Servitor) throws {
        TavernLogger.coordination.info("Dismissing servitor: \(servitor.name) (id: \(servitor.id))")
        try registry.remove(id: servitor.id)
        nameGenerator.releaseName(servitor.name)
        TavernLogger.coordination.debug("Servitor dismissed, name released: \(servitor.name)")
    }

    /// Dismiss a servitor by ID
    /// - Parameter id: The ID of the servitor to dismiss
    /// - Throws: If no servitor with this ID exists
    public func dismiss(id: UUID) throws {
        guard let agent = registry.agent(id: id) else {
            TavernLogger.coordination.error("Cannot dismiss: servitor not found with id \(id)")
            throw AgentRegistryError.agentNotFound(id)
        }
        TavernLogger.coordination.info("Dismissing servitor: \(agent.name) (id: \(id))")
        try registry.remove(id: id)
        nameGenerator.releaseName(agent.name)
        TavernLogger.coordination.debug("Servitor dismissed, name released: \(agent.name)")
    }

    // MARK: - Queries

    /// Get all active servitors (excluding Jake)
    public var activeServitors: [AnyAgent] {
        registry.allAgents()
    }

    /// Number of active servitors
    public var servitorCount: Int {
        registry.count
    }
}
