import Foundation
import os.log

/// /context — Show context window usage with visual bar
public struct ContextCommand: SlashCommand {
    public let name = "context"
    public let description = "Show context window usage"

    private let context: CommandContext

    public init(context: CommandContext) {
        self.context = context
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let snapshot = await MainActor.run {
            (
                input: context.totalInputTokens,
                output: context.totalOutputTokens,
                cacheRead: context.totalCacheReadTokens,
                window: context.contextWindowSize,
                maxOutput: context.maxOutputTokens
            )
        }

        let totalUsed = snapshot.input + snapshot.output

        var lines: [String] = []
        lines.append("Context Window Usage")
        lines.append(String(repeating: "\u{2500}", count: 20))

        if snapshot.window > 0 {
            let pct = Double(totalUsed) / Double(snapshot.window) * 100
            let bar = CommandFormatting.makeBar(filled: pct, width: 30)
            lines.append("\(bar) \(String(format: "%.1f", pct))%")
            lines.append("")
            lines.append("Used:         \(CommandFormatting.formatTokens(totalUsed)) / \(CommandFormatting.formatTokens(snapshot.window))")
            lines.append("Remaining:    \(CommandFormatting.formatTokens(snapshot.window - totalUsed))")
        } else {
            lines.append("Used:         \(CommandFormatting.formatTokens(totalUsed))")
            lines.append("Window size:  (not yet reported)")
        }

        lines.append("")
        lines.append("Breakdown:")
        lines.append("  Input:      \(CommandFormatting.formatTokens(snapshot.input))")
        lines.append("  Output:     \(CommandFormatting.formatTokens(snapshot.output))")

        if snapshot.cacheRead > 0 {
            lines.append("  Cache:      \(CommandFormatting.formatTokens(snapshot.cacheRead)) (read)")
        }

        if snapshot.maxOutput > 0 {
            lines.append("  Max output: \(CommandFormatting.formatTokens(snapshot.maxOutput))")
        }

        TavernLogger.commands.info("/context: used=\(totalUsed)/\(snapshot.window)")
        return .message(lines.joined(separator: "\n"))
    }

}
