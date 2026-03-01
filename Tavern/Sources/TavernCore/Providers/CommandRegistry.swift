import Foundation
import TavernKit
import os.log

// MARK: - Provenance: REQ-COM-008

@MainActor
public final class CommandRegistry: CommandProvider {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "commands")

    let dispatcher: SlashCommandDispatcher
    private let projectRoot: URL

    public init(dispatcher: SlashCommandDispatcher, projectRoot: URL) {
        self.dispatcher = dispatcher
        self.projectRoot = projectRoot
    }

    public func dispatchInput(_ input: String) async -> SlashCommandResult? {
        await dispatcher.dispatchInput(input)
    }

    public func execute(name: String, arguments: String) async -> SlashCommandResult {
        Self.logger.info("[CommandRegistry] executing /\(name) with args: \(arguments.prefix(50))")
        return await dispatcher.dispatch(name: name, arguments: arguments)
    }

    public func availableCommands() -> [(name: String, description: String, usage: String)] {
        dispatcher.commands.map { cmd in
            (name: cmd.name, description: cmd.description, usage: cmd.usage)
        }
    }

    public func completions(for prefix: String) -> [(name: String, description: String)] {
        dispatcher.matchingCommands(prefix: prefix).map { cmd in
            (name: cmd.name, description: cmd.description)
        }
    }

    public func fileMentionSuggestions(for prefix: String, projectRoot: URL) -> [FileMentionSuggestion] {
        // Tracked in jake-3eu8: wire to FileTreeScanner when ChatTile absorbs FileMentionAutocomplete
        []
    }
}
