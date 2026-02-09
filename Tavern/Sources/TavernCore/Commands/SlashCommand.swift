import Foundation

/// Result of executing a slash command
public enum SlashCommandResult: Equatable, Sendable {
    /// Command produced output to display in the chat
    case message(String)

    /// Command completed silently (no visible output needed)
    case silent

    /// Command encountered an error
    case error(String)
}

/// Protocol for all slash commands in the Tavern
///
/// Commands are local-only operations that don't go through the Claude SDK.
/// They execute immediately when the user types `/commandName` in the input field.
public protocol SlashCommand: Sendable {
    /// The command name without the leading slash (e.g., "compact")
    var name: String { get }

    /// Short description shown in autocomplete
    var description: String { get }

    /// Usage string (e.g., "/model [model-name]")
    var usage: String { get }

    /// Execute the command with the given arguments
    /// - Parameter arguments: Everything after the command name, trimmed
    /// - Returns: The result of execution
    func execute(arguments: String) async -> SlashCommandResult
}

/// Default implementation for usage — just the command name with slash prefix
extension SlashCommand {
    public var usage: String { "/\(name)" }
}
