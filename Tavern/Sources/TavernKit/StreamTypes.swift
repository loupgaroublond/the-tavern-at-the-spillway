import Foundation

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
