import Foundation
import os.log

/// Discovers and loads custom commands from .claude/commands/ directories
///
/// Scans two locations for `.md` files:
/// 1. **Project-level:** `<projectPath>/.claude/commands/`
/// 2. **User-level:** `~/.claude/commands/`
///
/// Files are converted to `CustomCommand` instances where:
/// - Filename (without `.md`) becomes the command name
/// - Subdirectories create colon-separated namespaces (e.g., `git/amend.md` → `git:amend`)
/// - First line of the file becomes the description (if it starts with `#` or is plain text)
/// - Full file content becomes the template body
///
/// Project commands take precedence over user commands with the same name.
public enum CustomCommandLoader {

    /// Load all custom commands for a project
    /// - Parameters:
    ///   - projectPath: Path to the project root directory
    ///   - userHome: Path to the user's home directory (defaults to `~`)
    /// - Returns: Array of discovered custom commands (project commands first)
    public static func loadCommands(
        projectPath: String,
        userHome: String = NSHomeDirectory()
    ) -> [CustomCommand] {
        let projectDir = (projectPath as NSString).appendingPathComponent(".claude/commands")
        let userDir = (userHome as NSString).appendingPathComponent(".claude/commands")

        let projectCommands = discoverCommands(in: projectDir, source: .project)
        let userCommands = discoverCommands(in: userDir, source: .user)

        // Project commands override user commands with the same name
        let projectNames = Set(projectCommands.map(\.name))
        let deduplicated = projectCommands + userCommands.filter { !projectNames.contains($0.name) }

        TavernLogger.commands.info("Loaded \(deduplicated.count) custom commands (\(projectCommands.count) project, \(userCommands.count - (userCommands.count - (deduplicated.count - projectCommands.count))) user)")

        return deduplicated
    }

    /// Discover commands in a single directory
    /// - Parameters:
    ///   - directoryPath: Path to the commands directory
    ///   - source: Whether this is a project or user directory
    /// - Returns: Array of discovered commands
    static func discoverCommands(in directoryPath: String, source: CustomCommand.Source) -> [CustomCommand] {
        let fileManager = FileManager.default
        let baseURL = URL(fileURLWithPath: directoryPath)

        guard fileManager.fileExists(atPath: directoryPath) else {
            TavernLogger.commands.debug("Commands directory does not exist: \(directoryPath)")
            return []
        }

        guard let enumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            TavernLogger.commands.debugError("Failed to enumerate commands directory: \(directoryPath)")
            return []
        }

        var commands: [CustomCommand] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                TavernLogger.commands.debugError("Failed to read command file: \(fileURL.path)")
                continue
            }

            let commandName = deriveCommandName(fileURL: fileURL, baseURL: baseURL)
            let description = deriveDescription(from: content, commandName: commandName)

            let command = CustomCommand(
                name: commandName,
                description: description,
                template: content,
                source: source
            )
            commands.append(command)
            TavernLogger.commands.debug("Discovered custom command: /\(commandName) from \(fileURL.path)")
        }

        return commands.sorted { $0.name < $1.name }
    }

    /// Derive a command name from a file path relative to the commands base directory
    ///
    /// - `review.md` → `review`
    /// - `git/amend.md` → `git:amend`
    /// - `project/deploy/staging.md` → `project:deploy:staging`
    static func deriveCommandName(fileURL: URL, baseURL: URL) -> String {
        // Get relative path from base directory
        let basePath = baseURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path

        var relativePath = filePath
        if relativePath.hasPrefix(basePath) {
            relativePath = String(relativePath.dropFirst(basePath.count))
            // Remove leading slash if present
            if relativePath.hasPrefix("/") {
                relativePath = String(relativePath.dropFirst())
            }
        }

        // Remove .md extension
        if relativePath.lowercased().hasSuffix(".md") {
            relativePath = String(relativePath.dropLast(3))
        }

        // Replace path separators with colon for namespace
        let commandName = relativePath.replacingOccurrences(of: "/", with: ":").lowercased()

        return commandName
    }

    /// Extract a description from the command file content
    ///
    /// Uses the first line if it's a markdown heading or short enough.
    /// Falls back to "Custom command" if the content isn't suitable.
    static func deriveDescription(from content: String, commandName: String) -> String {
        let firstLine = content.prefix(while: { $0 != "\n" }).trimmingCharacters(in: .whitespaces)

        // If first line is a markdown heading, use the heading text
        if firstLine.hasPrefix("#") {
            let headingText = firstLine.drop(while: { $0 == "#" || $0 == " " })
            if !headingText.isEmpty {
                return String(headingText)
            }
        }

        // If first line is short enough and not template content, use it
        if !firstLine.isEmpty && firstLine.count <= 80 && !firstLine.contains("$ARGUMENTS") {
            return firstLine
        }

        return "Custom command: /\(commandName)"
    }
}
