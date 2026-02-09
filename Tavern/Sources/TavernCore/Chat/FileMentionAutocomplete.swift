import Foundation
import Combine
import os.log

/// View model for @ file mention autocomplete behavior
///
/// Observes the chat input text and produces a filtered list of matching file paths
/// when the user types "@" followed by a partial path. Uses FileTreeScanner to
/// list files from the project directory.
@MainActor
public final class FileMentionAutocomplete: ObservableObject {

    /// Filtered file suggestions matching the current input
    @Published public private(set) var suggestions: [FileMentionSuggestion] = []

    /// Whether the autocomplete popup should be visible
    @Published public private(set) var isVisible: Bool = false

    /// Index of the currently highlighted suggestion (for keyboard navigation)
    @Published public var selectedIndex: Int = 0

    /// The project root URL for scanning files
    private let projectRoot: URL

    /// Scanner for listing files
    private let scanner: FileTreeScanner

    /// Maximum number of suggestions to show
    private let maxSuggestions = 12

    public init(projectRoot: URL) {
        self.projectRoot = projectRoot
        self.scanner = FileTreeScanner()
    }

    /// Update suggestions based on current input text.
    ///
    /// Detects "@" prefix patterns and filters file paths accordingly.
    /// The "@" can appear at the start of input or after a space.
    ///
    /// - Parameter input: The current input field text
    public func update(for input: String) {
        guard let partial = Self.extractMentionPrefix(from: input) else {
            hide()
            return
        }

        let matches = scanAndFilter(prefix: partial)
        suggestions = matches
        selectedIndex = 0
        isVisible = !matches.isEmpty

        TavernLogger.chat.debug("FileMention: prefix=\"\(partial, privacy: .public)\" matches=\(matches.count)")
    }

    /// Hide the autocomplete popup
    public func hide() {
        isVisible = false
        suggestions = []
        selectedIndex = 0
    }

    /// Move selection up in the list
    public func moveUp() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
    }

    /// Move selection down in the list
    public func moveDown() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
    }

    /// Get the full text that should replace the input when a suggestion is selected.
    ///
    /// Returns the input text with the @-mention replaced by the selected file's relative path.
    /// - Parameter currentInput: The current full input text
    /// - Returns: The updated input text, or nil if nothing selected
    public func selectedCompletion(for currentInput: String) -> String? {
        guard isVisible, suggestions.indices.contains(selectedIndex) else { return nil }

        let selectedPath = suggestions[selectedIndex].relativePath
        return Self.replaceActiveMention(in: currentInput, with: selectedPath)
    }

    /// Get the currently selected suggestion
    public func selectedSuggestion() -> FileMentionSuggestion? {
        guard isVisible, suggestions.indices.contains(selectedIndex) else { return nil }
        return suggestions[selectedIndex]
    }

    // MARK: - Mention Parsing

    /// Extract the partial path after the active @ mention.
    ///
    /// Returns the text after the last "@" that is either at position 0 or preceded by a space,
    /// and has no space after it yet (indicating the mention is still being typed).
    ///
    /// - Parameter input: The full input text
    /// - Returns: The partial path string, or nil if no active mention
    nonisolated static func extractMentionPrefix(from input: String) -> String? {
        // Find the last "@" in the string
        guard let atIndex = input.lastIndex(of: "@") else { return nil }

        // The "@" must be at the start or preceded by a space
        if atIndex != input.startIndex {
            let before = input.index(before: atIndex)
            guard input[before] == " " || input[before] == "\n" else { return nil }
        }

        // Extract everything after the "@"
        let afterAt = String(input[input.index(after: atIndex)...])

        // If there's a space in the path portion, the mention is "completed"
        // (user moved on to typing something else)
        if afterAt.contains(" ") { return nil }

        return afterAt
    }

    /// Replace the active @-mention in the input with a completed path.
    ///
    /// - Parameters:
    ///   - input: The current input text
    ///   - path: The relative file path to insert
    /// - Returns: The input with the @-mention replaced, or nil if no active mention
    nonisolated static func replaceActiveMention(in input: String, with path: String) -> String? {
        guard let atIndex = input.lastIndex(of: "@") else { return nil }

        // Verify same rules as extractMentionPrefix
        if atIndex != input.startIndex {
            let before = input.index(before: atIndex)
            guard input[before] == " " || input[before] == "\n" else { return nil }
        }

        let prefix = String(input[..<atIndex])
        return prefix + "@" + path + " "
    }

    // MARK: - File Scanning

    /// Scan the project and filter results by the partial prefix
    private func scanAndFilter(prefix: String) -> [FileMentionSuggestion] {
        // Determine which directory to scan based on the prefix
        // If prefix contains "/", scan the subdirectory
        let components = prefix.split(separator: "/", omittingEmptySubsequences: false)
        let directoryToScan: URL
        let filterName: String

        if components.count > 1 {
            // User typed something like "Sources/Tav" — scan "Sources" directory, filter by "Tav"
            let dirParts = components.dropLast()
            let subdir = dirParts.joined(separator: "/")
            directoryToScan = projectRoot.appendingPathComponent(subdir)
            filterName = String(components.last ?? "")
        } else {
            directoryToScan = projectRoot
            filterName = prefix
        }

        do {
            let nodes = try scanner.scanDirectory(at: directoryToScan, relativeTo: projectRoot)
            let filtered: [FileTreeNode]
            if filterName.isEmpty {
                filtered = Array(nodes.prefix(maxSuggestions))
            } else {
                filtered = nodes.filter { node in
                    node.name.localizedCaseInsensitiveContains(filterName)
                }.prefix(maxSuggestions).map { $0 }
            }

            return filtered.map { node in
                FileMentionSuggestion(
                    relativePath: node.id,
                    name: node.name,
                    isDirectory: node.isDirectory
                )
            }
        } catch {
            TavernLogger.chat.debugError("FileMention scan failed: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - FileMentionSuggestion

/// A single file mention autocomplete suggestion
public struct FileMentionSuggestion: Identifiable, Equatable, Sendable {
    public var id: String { relativePath }

    /// Relative path from project root
    public let relativePath: String

    /// Display name (filename only)
    public let name: String

    /// Whether this is a directory (shown with trailing /)
    public let isDirectory: Bool

    public init(relativePath: String, name: String, isDirectory: Bool) {
        self.relativePath = relativePath
        self.name = name
        self.isDirectory = isDirectory
    }
}
