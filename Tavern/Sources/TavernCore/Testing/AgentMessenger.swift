import Foundation
import ClodKit

// MARK: - Stream Event

/// Token usage data from a completed response
public struct SessionUsage: Sendable, Equatable {
    /// Number of input tokens consumed
    public let inputTokens: Int

    /// Number of output tokens generated
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    /// Total tokens (input + output)
    public var totalTokens: Int { inputTokens + outputTokens }
}

/// Events yielded during a streaming response from Claude.
/// Each event represents a discrete update that the UI can act on.
public enum StreamEvent: Sendable, Equatable {
    /// A chunk of text content to append to the current message
    case textDelta(String)

    /// A tool execution has started (name of tool)
    case toolUseStarted(String)

    /// A tool execution has finished (name of tool)
    case toolUseFinished(String)

    /// The stream completed successfully with the final session ID and optional usage
    case completed(sessionId: String?, usage: SessionUsage?)

    /// The stream encountered an error
    case error(String)
}

// MARK: - AgentMessenger Protocol

/// Protocol abstracting the Claude SDK communication layer.
/// Jake and Servitor use this to send messages — `LiveMessenger` calls real Claude,
/// `MockMessenger` returns canned responses for testing.
public protocol AgentMessenger: Sendable {
    /// Send a prompt to Claude and get a response (batch mode)
    /// - Parameters:
    ///   - prompt: The user's message
    ///   - options: Query options (system prompt, session ID, etc.)
    /// - Returns: Tuple of (response text, session ID if available)
    func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?)

    /// Send a prompt to Claude and receive a stream of events (streaming mode)
    /// - Parameters:
    ///   - prompt: The user's message
    ///   - options: Query options (system prompt, session ID, etc.)
    /// - Returns: A stream of StreamEvent values and a cancellation handle
    func queryStreaming(prompt: String, options: QueryOptions) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void)
}
