import Foundation
import ClaudeCodeSDK

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

    /// Spawn a new mortal agent with an assignment
    /// - Parameter assignment: The task description for the agent
    /// - Returns: The spawned agent
    /// - Throws: If registration fails (e.g., name collision, though unlikely with generator)
    @discardableResult
    public func spawn(assignment: String) throws -> MortalAgent {
        let name = nameGenerator.nextNameOrFallback()
        let claude = claudeFactory()

        let agent = MortalAgent(
            name: name,
            assignment: assignment,
            claude: claude
        )

        try registry.register(agent)

        return agent
    }

    /// Spawn a new mortal agent with a specific name
    /// - Parameters:
    ///   - name: The desired name for the agent
    ///   - assignment: The task description for the agent
    /// - Returns: The spawned agent
    /// - Throws: If the name is taken or registration fails
    @discardableResult
    public func spawn(name: String, assignment: String) throws -> MortalAgent {
        // Reserve the name first
        guard nameGenerator.reserveName(name) else {
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
        } catch {
            // Release the name if registration fails
            nameGenerator.releaseName(name)
            throw error
        }

        return agent
    }

    /// Dismiss an agent (remove from registry, release name)
    /// - Parameter agent: The agent to dismiss
    /// - Throws: If the agent is not in the registry
    public func dismiss(_ agent: MortalAgent) throws {
        try registry.remove(id: agent.id)
        nameGenerator.releaseName(agent.name)
    }

    /// Dismiss an agent by ID
    /// - Parameter id: The ID of the agent to dismiss
    /// - Throws: If no agent with this ID exists
    public func dismiss(id: UUID) throws {
        guard let agent = registry.agent(id: id) else {
            throw AgentRegistryError.agentNotFound(id)
        }
        try registry.remove(id: id)
        nameGenerator.releaseName(agent.name)
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
