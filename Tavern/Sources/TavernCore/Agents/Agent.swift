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

    /// Agent encountered an error
    case error
}

/// Protocol defining the common interface for all agents in the Tavern
public protocol Agent: AnyObject, Identifiable, Sendable {

    /// Unique identifier for this agent
    var id: UUID { get }

    /// Display name for this agent
    var name: String { get }

    /// Current state of the agent
    var state: AgentState { get }

    /// The agent's current session mode (plan, normal, acceptEdits, etc.)
    var sessionMode: PermissionMode { get set }

    /// Send a message to this agent and get a response (batch mode)
    /// - Parameter message: The message to send
    /// - Returns: The agent's response
    func send(_ message: String) async throws -> String

    /// Send a message and receive a stream of events (streaming mode)
    /// - Parameter message: The message to send
    /// - Returns: Tuple of (event stream, cancel closure)
    func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void)

    /// Reset the agent's conversation state
    func resetConversation()
}

