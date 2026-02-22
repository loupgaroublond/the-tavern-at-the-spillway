import Foundation
import os.log

// MARK: - Provenance: REQ-AGT-007, REQ-ARCH-004, REQ-ARCH-006, REQ-OPM-005, REQ-SPN-001, REQ-SPN-002, REQ-SPN-003, REQ-SPN-010, REQ-V1-004

/// Factory type for creating ServitorMessenger instances.
/// Accepts the mortal name for context in permission approval requests.
/// Returns a new messenger for each spawned mortal.
public typealias MessengerFactory = @Sendable (_ servitorName: String) -> ServitorMessenger

/// Spawns and manages mortals for the Tavern
/// This is Jake's way of delegating work to the Slop Squad
public final class MortalSpawner: @unchecked Sendable {

    // MARK: - Dependencies

    private let registry: ServitorRegistry
    private let nameGenerator: NameGenerator
    private let projectURL: URL
    private let messengerFactory: MessengerFactory

    // MARK: - Initialization

    /// Create a spawner with dependencies
    /// - Parameters:
    ///   - registry: The servitor registry to add spawned mortals to
    ///   - nameGenerator: The name generator for themed names
    ///   - projectURL: The project directory URL for spawned mortals
    ///   - messengerFactory: Factory for creating messengers for spawned mortals (default: LiveMessenger)
    public init(
        registry: ServitorRegistry,
        nameGenerator: NameGenerator,
        projectURL: URL,
        messengerFactory: @escaping MessengerFactory = { _ in LiveMessenger() }
    ) {
        self.registry = registry
        self.nameGenerator = nameGenerator
        self.projectURL = projectURL
        self.messengerFactory = messengerFactory
    }

    // MARK: - Summoning

    /// Summon a new mortal without an assignment (user-spawned)
    /// The mortal waits for the user's first message
    /// - Returns: The summoned mortal
    /// - Throws: If registration fails (e.g., name collision, though unlikely with generator)
    @discardableResult
    public func summon() throws -> Mortal {
        TavernLogger.coordination.debug("MortalSpawner.summon called (no assignment)")

        let name = nameGenerator.nextNameOrFallback()
        TavernLogger.coordination.debug("Generated name: \(name)")

        let mortal = Mortal(
            name: name,
            assignment: nil,
            projectURL: projectURL,
            messenger: messengerFactory(name)
        )

        try registry.register(mortal)
        TavernLogger.coordination.info("Mortal summoned and registered: \(name) (id: \(mortal.id))")

        return mortal
    }

    /// Summon a new mortal with an assignment (Jake-summoned)
    /// - Parameter assignment: The assignment description for the mortal
    /// - Returns: The summoned mortal
    /// - Throws: If registration fails (e.g., name collision, though unlikely with generator)
    @discardableResult
    public func summon(assignment: String) throws -> Mortal {
        TavernLogger.coordination.debug("MortalSpawner.summon called, assignment: \(assignment)")

        let name = nameGenerator.nextNameOrFallback()
        TavernLogger.coordination.debug("Generated name: \(name)")

        let mortal = Mortal(
            name: name,
            assignment: assignment,
            projectURL: projectURL,
            messenger: messengerFactory(name)
        )

        try registry.register(mortal)
        TavernLogger.coordination.info("Mortal summoned and registered: \(name) (id: \(mortal.id))")

        return mortal
    }

    /// Summon a new mortal with a specific name (for testing or Jake's use)
    /// - Parameters:
    ///   - name: The desired name for the mortal
    ///   - assignment: The assignment description for the mortal (optional)
    /// - Returns: The summoned mortal
    /// - Throws: If the name is taken or registration fails
    @discardableResult
    public func summon(name: String, assignment: String?) throws -> Mortal {
        TavernLogger.coordination.debug("MortalSpawner.summon called with name: \(name), assignment: \(assignment ?? "<none>")")

        // Reserve the name first
        guard nameGenerator.reserveName(name) else {
            TavernLogger.coordination.error("Name already exists: \(name)")
            throw ServitorRegistryError.nameAlreadyExists(name)
        }

        let mortal = Mortal(
            name: name,
            assignment: assignment,
            projectURL: projectURL,
            messenger: messengerFactory(name)
        )

        do {
            try registry.register(mortal)
            TavernLogger.coordination.info("Mortal summoned and registered: \(name) (id: \(mortal.id))")
        } catch {
            // Release the name if registration fails
            TavernLogger.coordination.error("Registration failed for \(name): \(error.localizedDescription)")
            nameGenerator.releaseName(name)
            throw error
        }

        return mortal
    }

    /// Register a pre-created mortal (for restoration on app launch)
    /// - Parameter mortal: The mortal to register
    /// - Throws: If registration fails
    public func register(_ mortal: Mortal) throws {
        TavernLogger.coordination.debug("MortalSpawner.register called for: \(mortal.name) (id: \(mortal.id))")

        // Reserve the name
        guard nameGenerator.reserveName(mortal.name) else {
            TavernLogger.coordination.error("Name already exists during restore: \(mortal.name)")
            throw ServitorRegistryError.nameAlreadyExists(mortal.name)
        }

        do {
            try registry.register(mortal)
            TavernLogger.coordination.info("Mortal restored and registered: \(mortal.name) (id: \(mortal.id))")
        } catch {
            nameGenerator.releaseName(mortal.name)
            throw error
        }
    }

    /// Dismiss a mortal (remove from registry, release name)
    /// - Parameter mortal: The mortal to dismiss
    /// - Throws: If the mortal is not in the registry
    public func dismiss(_ mortal: Mortal) throws {
        TavernLogger.coordination.info("Dismissing mortal: \(mortal.name) (id: \(mortal.id))")
        try registry.remove(id: mortal.id)
        nameGenerator.releaseName(mortal.name)
        TavernLogger.coordination.debug("Mortal dismissed, name released: \(mortal.name)")
    }

    /// Dismiss a mortal by ID
    /// - Parameter id: The ID of the mortal to dismiss
    /// - Throws: If no mortal with this ID exists
    public func dismiss(id: UUID) throws {
        guard let servitor = registry.servitor(id: id) else {
            TavernLogger.coordination.error("Cannot dismiss: mortal not found with id \(id)")
            throw ServitorRegistryError.servitorNotFound(id)
        }
        TavernLogger.coordination.info("Dismissing mortal: \(servitor.name) (id: \(id))")
        try registry.remove(id: id)
        nameGenerator.releaseName(servitor.name)
        TavernLogger.coordination.debug("Mortal dismissed, name released: \(servitor.name)")
    }

    // MARK: - Queries

    /// Get all active mortals (excluding Jake)
    public var activeMortals: [any Servitor] {
        registry.allServitors()
    }

    /// Number of active mortals
    public var mortalCount: Int {
        registry.count
    }
}
