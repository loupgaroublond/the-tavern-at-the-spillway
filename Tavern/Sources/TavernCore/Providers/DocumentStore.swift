import Foundation
import TavernKit
import os.log

// MARK: - Provenance: REQ-DOC-001, REQ-DOC-002

@MainActor
public final class DocumentStore: ResourceProvider {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "docstore")

    private let scanner: FileTreeScanner
    private let rootURL: URL
    private let fileManager = FileManager.default

    private let maxFileSize: UInt64 = 1_000_000

    private static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "ico", "icns", "icon",
        "pdf", "zip", "tar", "gz", "bz2", "xz", "rar", "7z",
        "exe", "dll", "dylib", "so", "a", "o",
        "mp3", "mp4", "m4a", "wav", "avi", "mov", "mkv",
        "sqlite", "db", "realm",
        "xcassets", "car", "nib", "storyboardc",
        "pbxproj"
    ]

    public init(rootURL: URL) {
        self.scanner = FileTreeScanner()
        self.rootURL = rootURL
    }

    public func scanDirectory(at url: URL) throws -> [FileTreeNode] {
        try scanner.scanDirectory(at: url, relativeTo: rootURL)
    }

    public func scanChildren(of node: FileTreeNode) throws -> [FileTreeNode] {
        try scanner.scanDirectory(at: node.url, relativeTo: rootURL)
    }

    public func readFile(at url: URL) throws -> String {
        guard !isBinaryFile(at: url) else {
            throw TavernError.internalError("Binary file: \(url.path)")
        }
        guard !isFileTooLarge(at: url) else {
            throw TavernError.internalError("File too large (>1MB): \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func isFileTooLarge(at url: URL) -> Bool {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64 else {
            return false
        }
        return size > maxFileSize
    }

    public func isBinaryFile(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.binaryExtensions.contains(ext)
    }
}
