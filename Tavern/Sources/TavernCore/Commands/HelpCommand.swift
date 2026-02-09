import Foundation

/// /help — List all available slash commands
public struct HelpCommand: SlashCommand {
    public let name = "help"
    public let description = "List available commands"

    private let dispatcher: SlashCommandDispatcher

    public init(dispatcher: SlashCommandDispatcher) {
        self.dispatcher = dispatcher
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let lines = await MainActor.run {
            dispatcher.commands.map { cmd in
                "/\(cmd.name) — \(cmd.description)"
            }
        }

        let output = """
            Available commands:

            \(lines.joined(separator: "\n"))

            Type /command to execute, or start typing / for autocomplete.
            """
        return .message(output)
    }
}
