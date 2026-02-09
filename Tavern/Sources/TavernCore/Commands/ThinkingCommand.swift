import Foundation
import os.log

/// /thinking — View or set max thinking tokens
///
/// Usage:
/// - `/thinking` — Show current thinking token limit
/// - `/thinking <number>` — Set max thinking tokens
/// - `/thinking off` — Disable extended thinking
/// - `/thinking default` — Reset to SDK default
public struct ThinkingCommand: SlashCommand {
    public let name = "thinking"
    public let description = "Set max thinking tokens"
    public let usage = "/thinking [tokens|off|default]"

    private let context: CommandContext

    public init(context: CommandContext) {
        self.context = context
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let arg = arguments.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if arg.isEmpty {
            return await showCurrent()
        }

        switch arg {
        case "off", "none", "0":
            await MainActor.run { context.maxThinkingTokens = 0 }
            TavernLogger.commands.info("/thinking: disabled")
            return .message("Extended thinking disabled.\nTakes effect on your next message.")

        case "default", "reset":
            await MainActor.run { context.maxThinkingTokens = nil }
            TavernLogger.commands.info("/thinking: reset to default")
            return .message("Thinking tokens reset to SDK default.\nTakes effect on your next message.")

        default:
            guard let tokens = Int(arg), tokens > 0 else {
                return .error("Invalid value: \(arg)\nUsage: /thinking <number> or /thinking off|default")
            }
            await MainActor.run { context.maxThinkingTokens = tokens }
            TavernLogger.commands.info("/thinking: set to \(tokens)")
            return .message("Max thinking tokens set to \(formatTokens(tokens)).\nTakes effect on your next message.")
        }
    }

    private func showCurrent() async -> SlashCommandResult {
        let current = await MainActor.run { context.maxThinkingTokens }
        let display: String
        if let tokens = current {
            display = tokens == 0 ? "disabled" : formatTokens(tokens)
        } else {
            display = "(SDK default)"
        }

        var lines: [String] = []
        lines.append("Thinking tokens: \(display)")
        lines.append("")
        lines.append("Usage:")
        lines.append("  /thinking <number>  Set max thinking tokens")
        lines.append("  /thinking off       Disable extended thinking")
        lines.append("  /thinking default   Reset to SDK default")

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
