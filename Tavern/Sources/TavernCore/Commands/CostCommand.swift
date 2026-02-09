import Foundation
import os.log

/// /cost — Display token usage and cost statistics
public struct CostCommand: SlashCommand {
    public let name = "cost"
    public let description = "Show token usage and cost"

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
                cacheCreate: context.totalCacheCreationTokens,
                cost: context.totalCostUSD,
                messages: context.messageCount,
                searches: context.totalWebSearchRequests
            )
        }

        var lines: [String] = []
        lines.append("Token Usage (this session)")
        lines.append(String(repeating: "\u{2500}", count: 25))
        lines.append("Input tokens:    \(formatTokens(snapshot.input))")
        lines.append("Output tokens:   \(formatTokens(snapshot.output))")

        if snapshot.cacheRead > 0 {
            lines.append("Cache reads:     \(formatTokens(snapshot.cacheRead))")
        }
        if snapshot.cacheCreate > 0 {
            lines.append("Cache writes:    \(formatTokens(snapshot.cacheCreate))")
        }

        let total = snapshot.input + snapshot.output
        lines.append("Total tokens:    \(formatTokens(total))")
        lines.append("")
        lines.append("Messages:        \(snapshot.messages)")

        if snapshot.cost > 0 {
            lines.append("Cost:            $\(String(format: "%.4f", snapshot.cost))")
        }

        if snapshot.searches > 0 {
            lines.append("Web searches:    \(snapshot.searches)")
        }

        TavernLogger.commands.info("/cost: input=\(snapshot.input) output=\(snapshot.output) cost=$\(String(format: "%.4f", snapshot.cost))")
        return .message(lines.joined(separator: "\n"))
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
