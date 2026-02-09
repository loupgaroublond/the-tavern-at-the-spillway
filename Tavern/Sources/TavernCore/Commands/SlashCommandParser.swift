import Foundation
import os.log

/// Result of parsing user input for a slash command
public enum ParseResult: Equatable, Sendable {
    /// Input is a slash command with name and arguments
    case command(name: String, arguments: String)

    /// Input is not a slash command — pass through to agent
    case notACommand
}

/// Parses user input to detect and extract slash commands
///
/// A slash command is any input starting with "/" followed by a letter.
/// The command name is the first word after "/", and everything after is arguments.
///
/// Examples:
/// - "/compact" → command(name: "compact", arguments: "")
/// - "/model sonnet" → command(name: "model", arguments: "sonnet")
/// - "/cost" → command(name: "cost", arguments: "")
/// - "hello" → notACommand
/// - "/ stuff" → notACommand (space after slash)
/// - "/123" → notACommand (digit after slash)
public enum SlashCommandParser {

    /// Parse user input to detect a slash command
    /// - Parameter input: Raw user input text
    /// - Returns: Parsed result indicating command or passthrough
    public static func parse(_ input: String) -> ParseResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("/") else {
            return .notACommand
        }

        // Must have at least one character after the slash
        let afterSlash = trimmed.dropFirst()
        guard let firstChar = afterSlash.first, firstChar.isLetter else {
            return .notACommand
        }

        // Split into command name and arguments
        let parts = afterSlash.split(separator: " ", maxSplits: 1)
        let commandName = String(parts[0]).lowercased()
        let arguments = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

        TavernLogger.commands.debug("Parsed slash command: /\(commandName) args=\"\(arguments)\"")
        return .command(name: commandName, arguments: arguments)
    }

    /// Check if input starts with "/" (for autocomplete triggering)
    /// - Parameter input: Current input text
    /// - Returns: The partial command text after "/" if applicable
    public static func partialCommand(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }

        let afterSlash = String(trimmed.dropFirst())

        // Empty after slash — show all commands
        if afterSlash.isEmpty { return "" }

        // Must start with a letter for it to be a command prefix
        guard afterSlash.first?.isLetter == true else { return nil }

        // Only the first word counts as the command name (no spaces yet)
        if afterSlash.contains(" ") { return nil }

        return afterSlash.lowercased()
    }
}
