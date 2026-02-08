import Foundation
import os.log

/// Scans directories lazily, one level at a time
public final class FileTreeScanner: Sendable {

    /// Directories to skip when scanning
    private static let ignoredDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "node_modules",
        "DerivedData", ".DS_Store", "xcuserdata"
    ]

    public init() {}

    /// Scan a single directory level and return its children as FileTreeNodes
    ///
    /// - Parameters:
    ///   - url: The directory URL to scan
    ///   - relativeTo: The project root URL, used to compute relative path IDs
    /// - Returns: Sorted array of FileTreeNodes (directories first, then alphabetical)
    /// - Throws: If the directory cannot be read
    public func scanDirectory(at url: URL, relativeTo root: URL) throws -> [FileTreeNode] {
        // Resolve symlinks so /var and /private/var match on macOS
        let resolvedURL = url.resolvingSymlinksInPath()
        let resolvedRoot = root.resolvingSymlinksInPath()

        TavernLogger.resources.debug("[FileTreeScanner] Scanning: \(resolvedURL.path, privacy: .public)")

        let contents = try FileManager.default.contentsOfDirectory(
            at: resolvedURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: []
        )

        var nodes: [FileTreeNode] = []

        for itemURL in contents {
            let resolvedItemURL = itemURL.resolvingSymlinksInPath()
            let resourceValues = try resolvedItemURL.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            let isHidden = resourceValues.isHidden ?? false
            let isDirectory = resourceValues.isDirectory ?? false
            let name = resolvedItemURL.lastPathComponent

            // Skip hidden files and ignored directories
            if isHidden { continue }
            if Self.ignoredDirectories.contains(name) { continue }

            let relativePath = resolvedItemURL.path.replacingOccurrences(of: resolvedRoot.path + "/", with: "")
            let ext = isDirectory ? nil : (resolvedItemURL.pathExtension.isEmpty ? nil : resolvedItemURL.pathExtension)

            let node = FileTreeNode(
                id: relativePath,
                name: name,
                url: resolvedItemURL,
                isDirectory: isDirectory,
                fileExtension: ext,
                children: isDirectory ? nil : nil // nil = not yet loaded for directories
            )
            nodes.append(node)
        }

        // Sort: directories first, then alphabetical within each group
        nodes.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        TavernLogger.resources.debug("[FileTreeScanner] Found \(nodes.count) items in: \(url.lastPathComponent, privacy: .public)")
        return nodes
    }
}
