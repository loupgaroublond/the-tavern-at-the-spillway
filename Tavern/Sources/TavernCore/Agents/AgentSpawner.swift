import Foundation
import ClaudeCodeSDK
import os.log

/// Spawns and manages mortal agents for the Tavern
/// This is Jake's way of delegating work to the Slop Squad
public final class AgentSpawner: @unchecked Sendable {

    // MARK: - Dependencies

    private let registry: AgentRegistry
    private let nameGenerator: NameGenerator
    private let claudeFactory: () -> ClaudeCode

    // MARK: - Initialization

    /// Create a spawner with dependencies
    /// - Parameters:
    ///   - registry: The agent registry to add spawned agents to
    ///   - nameGenerator: The name generator for themed names
    ///   - claudeFactory: Factory to create ClaudeCode instances for new agents
    public init(
        registry: AgentRegistry,
        nameGenerator: NameGenerator,
        claudeFactory: @escaping () -> ClaudeCode
    ) {
        self.registry = registry
        self.nameGenerator = nameGenerator
        self.claudeFactory = claudeFactory
    }

    // MARK: - Spawning

    /// Spawn a new mortal agent without an assignment (user-spawned)
    /// The agent waits for the user's first message
    /// - Returns: The spawned agent
    /// - Throws: If registration fails (e.g., name collision, though unlikely with generator)
    @discardableResult
    public func spawn() throws -> MortalAgent {
        TavernLogger.coordination.debug("AgentSpawner.spawn called (no assignment)")

        let name = nameGenerator.nextNameOrFallback()
        TavernLogger.coordination.debug("Generated name: \(name)")

        let claude = claudeFactory()

        let agent = MortalAgent(
            name: name,
            assignment: nil,
            claude: claude
        )

        try registry.register(agent)
        TavernLogger.coordination.info("Agent spawned and registered: \(name) (id: \(agent.id))")

        return agent
    }

    /// Spawn a new mortal agent with an assignment (Jake-spawned)
    /// - Parameter assignment: The task description for the agent
    /// - Returns: The spawned agent
    /// - Throws: If registration fails (e.g., name collision, though unlikely with generator)
    @discardableResult
    public func spawn(assignment: String) throws -> MortalAgent {
        TavernLogger.coordination.debug("AgentSpawner.spawn called, assignment: \(assignment)")

        let name = nameGenerator.nextNameOrFallback()
        TavernLogger.coordination.debug("Generated name: \(name)")

        let claude = claudeFactory()

        let agent = MortalAgent(
            name: name,
            assignment: assignment,
            claude: claude
        )

        try registry.register(agent)
        TavernLogger.coordination.info("Agent spawned and registered: \(name) (id: \(agent.id))")

        return agent
    }

    /// Spawn a new mortal agent with a specific name (for testing or Jake's use)
    /// - Parameters:
    ///   - name: The desired name for the agent
    ///   - assignment: The task description for the agent
    /// - Returns: The spawned agent
    /// - Throws: If the name is taken or registration fails
    @discardableResult
    public func spawn(name: String, assignment: String) throws -> MortalAgent {
        TavernLogger.coordination.debug("AgentSpawner.spawn called with name: \(name), assignment: \(assignment)")

        // Reserve the name first
        guard nameGenerator.reserveName(name) else {
            TavernLogger.coordination.error("Name already exists: \(name)")
            throw AgentRegistryError.nameAlreadyExists(name)
        }

        let claude = claudeFactory()

        let agent = MortalAgent(
            name: name,
            assignment: assignment,
            claude: claude
        )

        do {
            try registry.register(agent)
            TavernLogger.coordination.info("Agent spawned and registered: \(name) (id: \(agent.id))")
        } catch {
            // Release the name if registration fails
            TavernLogger.coordination.error("Registration failed for \(name): \(error.localizedDescription)")
            nameGenerator.releaseName(name)
            throw error
        }

        return agent
    }

    /// Register a pre-created agent (for restoration on app launch)
    /// - Parameter agent: The agent to register
    /// - Throws: If registration fails
    public func register(_ agent: MortalAgent) throws {
        TavernLogger.coordination.debug("AgentSpawner.register called for: \(agent.name) (id: \(agent.id))")

        // Reserve the name
        guard nameGenerator.reserveName(agent.name) else {
            TavernLogger.coordination.error("Name already exists during restore: \(agent.name)")
            throw AgentRegistryError.nameAlreadyExists(agent.name)
        }

        do {
            try registry.register(agent)
            TavernLogger.coordination.info("Agent restored and registered: \(agent.name) (id: \(agent.id))")
        } catch {
            nameGenerator.releaseName(agent.name)
            throw error
        }
    }

    /// Dismiss an agent (remove from registry, release name)
    /// - Parameter agent: The agent to dismiss
    /// - Throws: If the agent is not in the registry
    public func dismiss(_ agent: MortalAgent) throws {
        TavernLogger.coordination.info("Dismissing agent: \(agent.name) (id: \(agent.id))")
        try registry.remove(id: agent.id)
        nameGenerator.releaseName(agent.name)
        TavernLogger.coordination.debug("Agent dismissed, name released: \(agent.name)")
    }

    /// Dismiss an agent by ID
    /// - Parameter id: The ID of the agent to dismiss
    /// - Throws: If no agent with this ID exists
    public func dismiss(id: UUID) throws {
        guard let agent = registry.agent(id: id) else {
            TavernLogger.coordination.error("Cannot dismiss: agent not found with id \(id)")
            throw AgentRegistryError.agentNotFound(id)
        }
        TavernLogger.coordination.info("Dismissing agent: \(agent.name) (id: \(id))")
        try registry.remove(id: id)
        nameGenerator.releaseName(agent.name)
        TavernLogger.coordination.debug("Agent dismissed, name released: \(agent.name)")
    }

    // MARK: - Queries

    /// Get all active agents (excluding Jake)
    public var activeAgents: [AnyAgent] {
        registry.allAgents()
    }

    /// Number of active agents
    public var agentCount: Int {
        registry.count
    }
}
