import Foundation
import Observation

/// Shared context passed to slash commands that need access to session state
///
/// Commands that need session info, model settings, or coordinator access
/// receive this through their initializer. Commands that are purely local
/// (like /help) don't need it.
@Observable @MainActor
public final class CommandContext {

    /// Current model name (user-configurable, nil = SDK default)
    public var currentModel: String?

    /// Max thinking tokens (user-configurable, nil = SDK default)
    public var maxThinkingTokens: Int?

    /// Cumulative token usage for this session
    public private(set) var totalInputTokens: Int = 0
    public private(set) var totalOutputTokens: Int = 0
    public private(set) var totalCacheReadTokens: Int = 0
    public private(set) var totalCacheCreationTokens: Int = 0
    public private(set) var totalCostUSD: Double = 0.0
    public private(set) var totalWebSearchRequests: Int = 0

    /// Context window info (from last usage report)
    public private(set) var contextWindowSize: Int = 0
    public private(set) var maxOutputTokens: Int = 0

    /// Number of messages sent in this session
    public private(set) var messageCount: Int = 0

    /// Session start time
    public let sessionStartTime: Date

    public init() {
        self.sessionStartTime = Date()
    }

    /// Record usage from a model response
    public func recordUsage(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int = 0,
        cacheCreationTokens: Int = 0,
        costUSD: Double = 0.0,
        webSearchRequests: Int = 0,
        contextWindow: Int = 0,
        maxOutput: Int = 0
    ) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        totalCacheReadTokens += cacheReadTokens
        totalCacheCreationTokens += cacheCreationTokens
        totalCostUSD += costUSD
        totalWebSearchRequests += webSearchRequests
        messageCount += 1

        if contextWindow > 0 { contextWindowSize = contextWindow }
        if maxOutput > 0 { maxOutputTokens = maxOutput }
    }
}
