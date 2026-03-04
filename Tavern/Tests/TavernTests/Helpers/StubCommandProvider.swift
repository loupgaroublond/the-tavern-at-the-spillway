import Foundation
import TavernKit

/// Stub CommandProvider that returns nil for all input (no slash commands).
@MainActor
final class StubCommandProvider: CommandProvider {
    var dispatchResult: SlashCommandResult?

    func dispatchInput(_ input: String) async -> SlashCommandResult? {
        dispatchResult
    }

    func execute(name: String, arguments: String) async -> SlashCommandResult {
        .silent
    }

    func availableCommands() -> [(name: String, description: String, usage: String)] { [] }
    func completions(for prefix: String) -> [(name: String, description: String)] { [] }
    func fileMentionSuggestions(for prefix: String, projectRoot: URL) -> [FileMentionSuggestion] { [] }
}
