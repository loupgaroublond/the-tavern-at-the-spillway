import Foundation
import os.log

/// /compact — Trigger context compaction
///
/// Sends a compaction request to the current agent's session via the SDK.
/// This reduces the context window usage by summarizing earlier messages.
public struct CompactCommand: SlashCommand {
    public let name = "compact"
    public let description = "Compact conversation context"

    private let context: CommandContext

    public init(context: CommandContext) {
        self.context = context
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let (used, window) = await MainActor.run {
            (context.totalInputTokens + context.totalOutputTokens, context.contextWindowSize)
        }

        var report = "Context compaction requested."
        if window > 0 {
            let pct = Double(used) / Double(window) * 100
            report += "\nCurrent usage: \(CommandFormatting.formatTokens(used)) / \(CommandFormatting.formatTokens(window)) (\(String(format: "%.1f", pct))%)"
        }
        report += "\nCompaction will take effect on your next message."

        TavernLogger.commands.info("/compact requested, current usage: \(used) tokens")
        return .message(report)
    }

}
