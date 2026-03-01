import Foundation

@MainActor
public protocol CommandProvider: Sendable {
    /// Parse raw input and execute if it's a slash command.
    /// Returns the command result, or `nil` if the input is not a command.
    func dispatchInput(_ input: String) async -> SlashCommandResult?

    func execute(name: String, arguments: String) async -> SlashCommandResult
    func availableCommands() -> [(name: String, description: String, usage: String)]
    func completions(for prefix: String) -> [(name: String, description: String)]
    func fileMentionSuggestions(for prefix: String, projectRoot: URL) -> [FileMentionSuggestion]
}
