import Foundation

/// Error thrown when agent registry operations fail
public enum AgentRegistryError: Error, Equatable {
    case agentNotFound(UUID)
    case nameAlreadyExists(String)
}

/// Registry that tracks all active agents in the Tavern
/// Thread-safe via serial dispatch queue
public final class AgentRegistry: @unchecked Sendable {

    // MARK: - Thread Safety

    private let queue = DispatchQueue(label: "com.tavern.AgentRegistry")

    // MARK: - State

    private var _agents: [UUID: any Agent] = [:]
    private var _nameToId: [String: UUID] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Registration

    /// Register an agent with the registry
    /// - Parameter agent: The agent to register
    /// - Throws: `AgentRegistryError.nameAlreadyExists` if an agent with this name exists
    public func register(_ agent: some Agent) throws {
        try queue.sync {
            // Check for name uniqueness
            if _nameToId[agent.name] != nil {
                throw AgentRegistryError.nameAlreadyExists(agent.name)
            }

            _agents[agent.id] = agent
            _nameToId[agent.name] = agent.id
        }
    }

    /// Remove an agent from the registry
    /// - Parameter id: The ID of the agent to remove
    /// - Throws: `AgentRegistryError.agentNotFound` if no agent with this ID exists
    public func remove(id: UUID) throws {
        try queue.sync {
            guard let agent = _agents[id] else {
                throw AgentRegistryError.agentNotFound(id)
            }

            _nameToId.removeValue(forKey: agent.name)
            _agents.removeValue(forKey: id)
        }
    }

    // MARK: - Queries

    /// Get an agent by ID
    /// - Parameter id: The agent's unique ID
    /// - Returns: The agent if found, nil otherwise
    public func agent(id: UUID) -> (any Agent)? {
        queue.sync { _agents[id] }
    }

    /// Get an agent by name
    /// - Parameter name: The agent's display name
    /// - Returns: The agent if found, nil otherwise
    public func agent(named name: String) -> (any Agent)? {
        queue.sync {
            guard let id = _nameToId[name] else { return nil }
            return _agents[id]
        }
    }

    /// List all registered agents
    /// - Returns: Array of all agents in the registry
    public func allAgents() -> [any Agent] {
        queue.sync { Array(_agents.values) }
    }

    /// Number of registered agents
    public var count: Int {
        queue.sync { _agents.count }
    }

    /// Check if a name is already taken
    /// - Parameter name: The name to check
    /// - Returns: true if an agent with this name exists
    public func isNameTaken(_ name: String) -> Bool {
        queue.sync { _nameToId[name] != nil }
    }

    /// Remove all agents from the registry
    public func removeAll() {
        queue.sync {
            _agents.removeAll()
            _nameToId.removeAll()
        }
    }
}
