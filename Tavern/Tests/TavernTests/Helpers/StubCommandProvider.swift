import Foundation
import TavernKit

/// Stub CommandProvider that returns nil for all input (no slash commands).
final class StubCommandProvider: CommandProvider, @unchecked Sendable {
    var dispatchResult: SlashCommandResult?

    func dispatchInput(_ input: String) async -> SlashCommandResult? {
        dispatchResult
    }

    func execute(name: String, arguments: String) async -> SlashCommandResult {
        .silent
    }

    func availableCommands() async -> [(name: String, description: String, usage: String)] { [] }
    func completions(for prefix: String) async -> [(name: String, description: String)] { [] }
    func fileMentionSuggestions(for prefix: String, projectRoot: URL) async -> [FileMentionSuggestion] { [] }
}
