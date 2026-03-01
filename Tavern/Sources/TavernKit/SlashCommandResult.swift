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
