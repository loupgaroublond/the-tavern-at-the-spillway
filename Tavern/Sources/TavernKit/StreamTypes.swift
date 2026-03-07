import Foundation

// MARK: - Supporting Types

/// Information about a tool execution that has started
public struct ToolUseInfo: Sendable, Equatable {
    public let toolUseId: String
    public let toolName: String

    public init(toolUseId: String, toolName: String) {
        self.toolUseId = toolUseId
        self.toolName = toolName
    }
}

/// Result of a tool execution
public struct ToolResultInfo: Sendable, Equatable {
    public let toolUseId: String
    public let content: String
    public let isError: Bool

    public init(toolUseId: String, content: String, isError: Bool) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Progress update for a running tool
public struct ToolProgressInfo: Sendable, Equatable {
    public let toolUseId: String
    public let toolName: String
    public let elapsedSeconds: Double

    public init(toolUseId: String, toolName: String, elapsedSeconds: Double) {
        self.toolUseId = toolUseId
        self.toolName = toolName
        self.elapsedSeconds = elapsedSeconds
    }
}

// MARK: - Provenance: REQ-COST-001

/// Information from a completed stream
public struct CompletionInfo: Sendable, Equatable {
    public let sessionId: String?
    public let usage: SessionUsage?
    public let perModelUsage: [String: SessionUsage]?
    public let costUsd: Double?
    public let totalCostUsd: Double?
    public let durationMs: Int?
    public let stopReason: String?
    public let numTurns: Int?

    public init(
        sessionId: String? = nil,
        usage: SessionUsage? = nil,
        perModelUsage: [String: SessionUsage]? = nil,
        costUsd: Double? = nil,
        totalCostUsd: Double? = nil,
        durationMs: Int? = nil,
        stopReason: String? = nil,
        numTurns: Int? = nil
    ) {
        self.sessionId = sessionId
        self.usage = usage
        self.perModelUsage = perModelUsage
        self.costUsd = costUsd
        self.totalCostUsd = totalCostUsd
        self.durationMs = durationMs
        self.stopReason = stopReason
        self.numTurns = numTurns
    }
}

// MARK: - Provenance: REQ-ARCH-009

/// Information about a CLI notification surfaced through the streaming pipeline.
/// Maps from ClodKit's `NotificationInput` hook data.
public struct NotificationInfo: Sendable, Equatable {
    /// The notification message body.
    public let message: String

    /// Optional title for the notification.
    public let title: String?

    /// Severity level parsed from the CLI's `notificationType` string.
    public let level: Level

    /// The raw notification type string from the CLI (preserved for forward compatibility).
    public let rawType: String

    /// Notification severity levels.
    public enum Level: String, Sendable, Equatable {
        case info
        case warning
        case error
    }

    public init(message: String, title: String? = nil, level: Level = .info, rawType: String = "info") {
        self.message = message
        self.title = title
        self.level = level
        self.rawType = rawType
    }

    /// Parse a `NotificationInfo.Level` from the CLI's notification type string.
    /// Unrecognized types default to `.info`.
    public static func parseLevel(from notificationType: String) -> Level {
        let normalized = notificationType.lowercased()
        if normalized.contains("error") { return .error }
        if normalized.contains("warn") { return .warning }
        return .info
    }
}

/// Rate limit status information
public struct RateLimitInfo: Sendable, Equatable {
    public let status: String
    public let utilization: Double?
    public let resetsAt: Date?

    public init(status: String, utilization: Double? = nil, resetsAt: Date? = nil) {
        self.status = status
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
}

/// Token usage data from a completed response
public struct SessionUsage: Sendable, Equatable {
    /// Number of input tokens consumed
    public let inputTokens: Int

    /// Number of output tokens generated
    public let outputTokens: Int

    /// Number of cache read input tokens
    public let cacheReadInputTokens: Int

    /// Number of cache creation input tokens
    public let cacheCreationInputTokens: Int

    /// Number of web search requests made
    public let webSearchRequests: Int

    /// Cost in USD for this usage
    public let costUsd: Double

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadInputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0,
        webSearchRequests: Int = 0,
        costUsd: Double = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.webSearchRequests = webSearchRequests
        self.costUsd = costUsd
    }

    /// Total tokens (input + output)
    public var totalTokens: Int { inputTokens + outputTokens }
}

// MARK: - StreamEvent

/// Events yielded during a streaming response from Claude.
/// Each event represents a discrete update that the UI can act on.
public enum StreamEvent: Sendable, Equatable {

    // Content block events (from stream_event messages)

    /// A chunk of text content to append to the current message
    case textDelta(String)

    /// A chunk of thinking content
    case thinkingDelta(String)

    /// A tool execution has started
    case toolUseStarted(ToolUseInfo)

    /// A fragment of tool input JSON
    case toolInputDelta(toolUseId: String, json: String)

    /// A tool execution result
    case toolResult(ToolResultInfo)

    /// A content block has finished (by index)
    case blockFinished(index: Int)

    // System events (from non-stream messages)

    /// Tool progress update (elapsed time)
    case toolProgress(ToolProgressInfo)

    /// System status update (e.g. "compacting")
    case systemStatus(String)

    /// A prompt suggestion from the CLI
    case promptSuggestion(String)

    /// Rate limit warning
    case rateLimitWarning(RateLimitInfo)

    /// A CLI notification (e.g. task complete, context limit approaching)
    case notification(NotificationInfo)

    /// A session break occurred — the previous session could not be resumed
    /// and a new session was started. The stale session ID is provided.
    case sessionBreak(staleSessionId: String)

    // Terminal events

    /// The stream completed successfully
    case completed(CompletionInfo)

    /// The stream encountered an error
    case error(String)
}
