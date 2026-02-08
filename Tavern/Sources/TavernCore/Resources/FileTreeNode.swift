import Foundation

/// A node in the file tree representing a file or directory
public struct FileTreeNode: Identifiable, Equatable, Sendable {

    /// Relative path from the project root, used as a stable identifier
    public let id: String

    /// Display name (file or directory name)
    public let name: String

    /// Absolute URL on disk
    public let url: URL

    /// Whether this node represents a directory
    public let isDirectory: Bool

    /// File extension (nil for directories or extensionless files)
    public let fileExtension: String?

    /// Children of this node (nil = not yet loaded, empty = loaded but empty)
    public var children: [FileTreeNode]?

    /// Whether this directory is expanded in the tree
    public var isExpanded: Bool

    public init(
        id: String,
        name: String,
        url: URL,
        isDirectory: Bool,
        fileExtension: String? = nil,
        children: [FileTreeNode]? = nil,
        isExpanded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.fileExtension = fileExtension
        self.children = children
        self.isExpanded = isExpanded
    }
}
