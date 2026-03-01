import Foundation

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
