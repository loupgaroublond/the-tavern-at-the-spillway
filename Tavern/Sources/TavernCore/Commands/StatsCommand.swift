import Foundation
import os.log

/// /stats — Show session usage statistics and visualization
public struct StatsCommand: SlashCommand {
    public let name = "stats"
    public let description = "Show session usage statistics"

    private let context: CommandContext

    public init(context: CommandContext) {
        self.context = context
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let snapshot = await MainActor.run {
            (
                input: context.totalInputTokens,
                output: context.totalOutputTokens,
                messages: context.messageCount,
                cost: context.totalCostUSD,
                startTime: context.sessionStartTime,
                searches: context.totalWebSearchRequests
            )
        }

        let elapsed = Date().timeIntervalSince(snapshot.startTime)

        var lines: [String] = []
        lines.append("Session Statistics")
        lines.append(String(repeating: "\u{2500}", count: 18))
        lines.append("Duration:        \(formatDuration(elapsed))")
        lines.append("Messages:        \(snapshot.messages)")
        lines.append("")

        // Token breakdown with visual bars
        let total = max(snapshot.input + snapshot.output, 1)
        let inputPct = Double(snapshot.input) / Double(total) * 100
        let outputPct = Double(snapshot.output) / Double(total) * 100

        lines.append("Token Distribution:")
        lines.append("  Input  \(CommandFormatting.makeBar(filled: inputPct, width: 20)) \(CommandFormatting.formatTokens(snapshot.input))")
        lines.append("  Output \(CommandFormatting.makeBar(filled: outputPct, width: 20)) \(CommandFormatting.formatTokens(snapshot.output))")
        lines.append("  Total:  \(CommandFormatting.formatTokens(total))")

        if snapshot.cost > 0 {
            lines.append("")
            lines.append("Cost:            $\(String(format: "%.4f", snapshot.cost))")
            if snapshot.messages > 0 {
                lines.append("Avg per message: $\(String(format: "%.4f", snapshot.cost / Double(snapshot.messages)))")
            }
        }

        if snapshot.searches > 0 {
            lines.append("")
            lines.append("Web searches:    \(snapshot.searches)")
        }

        if snapshot.messages > 0 && elapsed > 0 {
            lines.append("")
            let rate = Double(snapshot.messages) / (elapsed / 60)
            lines.append("Rate: \(String(format: "%.1f", rate)) messages/min")
        }

        return .message(lines.joined(separator: "\n"))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m \(s % 60)s" }
        let h = m / 60
        return "\(h)h \(m % 60)m"
    }
}
