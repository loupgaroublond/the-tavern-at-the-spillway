import Foundation
import os.log

/// /model — View or change the active model
///
/// Usage:
/// - `/model` — Show current model
/// - `/model <name>` — Switch to a different model
public struct ModelCommand: SlashCommand {
    public let name = "model"
    public let description = "View or change the AI model"
    public let usage = "/model [model-name]"

    /// Known model identifiers for display
    private static let knownModels = [
        "claude-opus-4-6",
        "claude-sonnet-4-5-20250929",
        "claude-haiku-4-5-20251001"
    ]

    private let context: CommandContext

    public init(context: CommandContext) {
        self.context = context
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let arg = arguments.trimmingCharacters(in: .whitespacesAndNewlines)

        if arg.isEmpty {
            return await showCurrentModel()
        } else {
            return await switchModel(to: arg)
        }
    }

    private func showCurrentModel() async -> SlashCommandResult {
        let current = await MainActor.run { context.currentModel }

        var lines: [String] = []
        lines.append("Current model: \(current ?? "(SDK default)")")
        lines.append("")
        lines.append("Available models:")
        for model in Self.knownModels {
            let marker = (current == model) ? " (active)" : ""
            lines.append("  \(model)\(marker)")
        }
        lines.append("")
        lines.append("Usage: /model <model-name>")

        return .message(lines.joined(separator: "\n"))
    }

    private func switchModel(to modelName: String) async -> SlashCommandResult {
        let previous = await MainActor.run {
            let prev = context.currentModel ?? "(SDK default)"
            context.currentModel = modelName
            return prev
        }
        TavernLogger.commands.info("/model: switched from \(previous) to \(modelName)")
        return .message("Model changed to: \(modelName)\nTakes effect on your next message.")
    }
}
