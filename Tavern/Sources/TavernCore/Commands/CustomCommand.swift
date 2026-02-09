import Foundation

/// A slash command loaded from a .md file in .claude/commands/
///
/// Custom commands are discovered from two locations:
/// 1. Project-level: `<projectPath>/.claude/commands/`
/// 2. User-level: `~/.claude/commands/`
///
/// The filename becomes the command name (e.g., `review.md` → `/review`).
/// Subdirectories create namespaces (e.g., `git/amend.md` → `/git:amend`).
/// The file contents become the command body, with `$ARGUMENTS`, `$1`, `$2` etc.
/// substituted at execution time.
public struct CustomCommand: SlashCommand {

    public let name: String
    public let description: String

    /// Whether this command came from the project or user directory
    public let source: Source

    /// Raw template content from the .md file
    let template: String

    public var usage: String {
        if template.contains("$ARGUMENTS") || template.range(of: #"\$\d+"#, options: .regularExpression) != nil {
            return "/\(name) [arguments]"
        }
        return "/\(name)"
    }

    /// Where a custom command was loaded from
    public enum Source: Equatable, Sendable {
        case project
        case user
    }

    public init(name: String, description: String, template: String, source: Source) {
        self.name = name
        self.description = description
        self.template = template
        self.source = source
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let substituted = CustomCommand.substitute(template: template, arguments: arguments)
        return .message(substituted)
    }

    // MARK: - Argument Substitution

    /// Substitute argument placeholders in a template string
    ///
    /// Supports:
    /// - `$ARGUMENTS` — replaced with the full argument string
    /// - `$1`, `$2`, etc. — replaced with positional arguments (split by whitespace)
    /// - Missing positional args are replaced with empty string
    static func substitute(template: String, arguments: String) -> String {
        var result = template

        // Replace $ARGUMENTS with the full argument string
        result = result.replacingOccurrences(of: "$ARGUMENTS", with: arguments)

        // Split arguments for positional substitution
        let positional = arguments.isEmpty ? [String]() : arguments.split(separator: " ").map(String.init)

        // Replace $1, $2, ... $N with positional arguments
        // Process higher numbers first to avoid $1 matching in $10
        let placeholderPattern = #"\$(\d+)"#
        if let regex = try? NSRegularExpression(pattern: placeholderPattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange)

            // Process matches in reverse order to preserve indices
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let numberRange = Range(match.range(at: 1), in: result) else { continue }

                let numberStr = String(result[numberRange])
                guard let index = Int(numberStr), index >= 1 else { continue }

                let replacement = (index <= positional.count) ? positional[index - 1] : ""
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }
}
