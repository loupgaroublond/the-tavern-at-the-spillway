import Foundation

/// Maps file types to SF Symbol names for the file tree
public enum FileTypeIcon {

    /// Returns the appropriate SF Symbol name for a given file extension and type
    ///
    /// - Parameters:
    ///   - extension: The file extension (e.g., "swift", "json"), or nil
    ///   - isDirectory: Whether the item is a directory
    ///   - isExpanded: Whether the directory is expanded (only relevant for directories)
    /// - Returns: An SF Symbol name string
    public static func symbolName(for fileExtension: String?, isDirectory: Bool, isExpanded: Bool = false) -> String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }

        guard let ext = fileExtension?.lowercased() else {
            return "doc"
        }

        switch ext {
        case "swift":
            return "swift"
        case "json":
            return "curlybraces"
        case "md", "markdown":
            return "doc.text"
        case "yml", "yaml":
            return "list.bullet.rectangle"
        case "txt":
            return "doc.plaintext"
        case "html", "htm":
            return "globe"
        case "css":
            return "paintbrush"
        case "js", "ts", "jsx", "tsx":
            return "chevron.left.forwardslash.chevron.right"
        case "py":
            return "terminal"
        case "sh", "bash", "zsh":
            return "terminal"
        case "png", "jpg", "jpeg", "gif", "svg", "ico", "webp":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "zip", "tar", "gz", "bz2":
            return "doc.zipper"
        case "xcodeproj", "xcworkspace":
            return "hammer"
        case "plist":
            return "list.bullet"
        case "entitlements":
            return "lock.shield"
        case "gitignore":
            return "eye.slash"
        case "resolved":
            return "pin"
        default:
            return "doc"
        }
    }
}
