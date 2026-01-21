import Foundation

/// State of an agent in the Tavern
public enum AgentState: String, Equatable, Sendable {
    /// Agent is idle, waiting for work
    case idle

    /// Agent is actively working on a task
    case working

    /// Agent is waiting for input or decision
    case waiting

    /// Agent is verifying its commitments before completing
    case verifying

    /// Agent has completed their assignment
    case done
}

/// Protocol defining the common interface for all agents in the Tavern
public protocol Agent: AnyObject, Identifiable, Sendable {

    /// Unique identifier for this agent
    var id: UUID { get }

    /// Display name for this agent
    var name: String { get }

    /// Current state of the agent
    var state: AgentState { get }

    /// Send a message to this agent and get a response
    /// - Parameter message: The message to send
    /// - Returns: The agent's response
    func send(_ message: String) async throws -> String

    /// Reset the agent's conversation state
    func resetConversation()
}

/// Type-erased wrapper for agents to enable heterogeneous collections
public final class AnyAgent: Agent, @unchecked Sendable {
    private let _id: UUID
    private let _name: String
    private let _getState: () -> AgentState
    private let _send: (String) async throws -> String
    private let _resetConversation: () -> Void

    public var id: UUID { _id }
    public var name: String { _name }
    public var state: AgentState { _getState() }

    public init<A: Agent>(_ agent: A) {
        self._id = agent.id
        self._name = agent.name
        self._getState = { agent.state }
        self._send = { try await agent.send($0) }
        self._resetConversation = { agent.resetConversation() }
    }

    public func send(_ message: String) async throws -> String {
        try await _send(message)
    }

    public func resetConversation() {
        _resetConversation()
    }
}
