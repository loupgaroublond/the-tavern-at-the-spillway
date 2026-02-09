import Foundation
import os.log

/// /status — Show app version, model, and session info
public struct StatusCommand: SlashCommand {
    public let name = "status"
    public let description = "Show version, model, and session info"

    private let context: CommandContext

    public init(context: CommandContext) {
        self.context = context
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let snapshot = await MainActor.run {
            (
                model: context.currentModel ?? "(SDK default)",
                thinking: context.maxThinkingTokens,
                startTime: context.sessionStartTime,
                messages: context.messageCount,
                cost: context.totalCostUSD
            )
        }

        let version = TavernCore.version
        let thinkingStr = snapshot.thinking.map { "\($0)" } ?? "(default)"
        let elapsed = formatElapsed(since: snapshot.startTime)

        var lines: [String] = []
        lines.append("The Tavern at the Spillway")
        lines.append(String(repeating: "\u{2500}", count: 25))
        lines.append("Version:      v\(version)")
        lines.append("Model:        \(snapshot.model)")
        lines.append("Thinking:     \(thinkingStr) tokens")
        lines.append("Session:      \(elapsed), \(snapshot.messages) messages")

        if snapshot.cost > 0 {
            lines.append("Cost:         $\(String(format: "%.4f", snapshot.cost))")
        }

        return .message(lines.joined(separator: "\n"))
    }

    private func formatElapsed(since start: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(start))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }
}
