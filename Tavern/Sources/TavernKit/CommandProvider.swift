import Foundation

@MainActor
public protocol CommandProvider: Sendable {
    func execute(name: String, arguments: String) async -> SlashCommandResult
    func availableCommands() -> [(name: String, description: String, usage: String)]
    func completions(for prefix: String) -> [(name: String, description: String)]
    func fileMentionSuggestions(for prefix: String, projectRoot: URL) -> [FileMentionSuggestion]
}
