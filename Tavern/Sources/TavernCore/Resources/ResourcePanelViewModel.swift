import Foundation
import os.log

/// ViewModel for the resource panel: file tree + file content viewer
@MainActor
public final class ResourcePanelViewModel: ObservableObject {

    /// The file tree scanner
    private let scanner = FileTreeScanner()

    /// The project root URL
    private let rootURL: URL

    /// Maximum file size to display (1 MB)
    private static let maxFileSize = 1_048_576

    /// Number of bytes to check for binary detection
    private static let binaryCheckSize = 8_192

    // MARK: - Published State

    /// Root-level nodes in the file tree
    @Published public var rootNodes: [FileTreeNode] = []

    /// URL of the currently selected file
    @Published public var selectedFileURL: URL?

    /// Content of the currently selected file
    @Published public var selectedFileContent: String?

    /// Name of the currently selected file
    @Published public var selectedFileName: String?

    /// Whether a file is currently loading
    @Published public var isLoading: Bool = false

    /// Error message to display
    @Published public var error: String?

    // MARK: - Init

    public init(rootURL: URL) {
        self.rootURL = rootURL
        TavernLogger.resources.info("[ResourcePanelViewModel] Created for: \(rootURL.path, privacy: .public)")
    }

    // MARK: - Actions

    /// Load the root directory contents
    public func loadRootDirectory() {
        TavernLogger.resources.debug("[ResourcePanelViewModel] Loading root directory")
        do {
            rootNodes = try scanner.scanDirectory(at: rootURL, relativeTo: rootURL)
            error = nil
        } catch {
            TavernLogger.resources.error("[ResourcePanelViewModel] Failed to load root: \(error.localizedDescription, privacy: .public)")
            self.error = "Failed to load directory: \(error.localizedDescription)"
        }
    }

    /// Toggle a directory's expanded state (load children on first expand)
    public func toggleDirectory(_ node: FileTreeNode) {
        guard node.isDirectory else { return }

        TavernLogger.resources.debug("[ResourcePanelViewModel] Toggling directory: \(node.name, privacy: .public)")

        if node.isExpanded {
            // Collapse: just toggle the flag
            updateNode(id: node.id, in: &rootNodes) { n in
                n.isExpanded = false
            }
        } else {
            // Expand: load children if not yet loaded, then toggle
            if node.children == nil {
                do {
                    let children = try scanner.scanDirectory(at: node.url, relativeTo: rootURL)
                    updateNode(id: node.id, in: &rootNodes) { n in
                        n.children = children
                        n.isExpanded = true
                    }
                } catch {
                    TavernLogger.resources.error("[ResourcePanelViewModel] Failed to expand \(node.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    self.error = "Failed to read directory: \(error.localizedDescription)"
                }
            } else {
                updateNode(id: node.id, in: &rootNodes) { n in
                    n.isExpanded = true
                }
            }
        }
    }

    /// Select a file and load its content
    public func selectFile(_ node: FileTreeNode) {
        guard !node.isDirectory else { return }

        TavernLogger.resources.info("[ResourcePanelViewModel] Selected file: \(node.name, privacy: .public)")
        selectedFileURL = node.url
        selectedFileName = node.name
        isLoading = true
        error = nil

        do {
            // Check file size
            let attributes = try FileManager.default.attributesOfItem(atPath: node.url.path)
            let fileSize = attributes[.size] as? Int ?? 0

            if fileSize > Self.maxFileSize {
                selectedFileContent = "File too large to display (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)))"
                isLoading = false
                return
            }

            // Check for binary content
            let handle = try FileHandle(forReadingFrom: node.url)
            let headerData = handle.readData(ofLength: Self.binaryCheckSize)
            handle.closeFile()

            if headerData.contains(0) {
                selectedFileContent = "Binary file"
                isLoading = false
                return
            }

            // Read full content as text
            let content = try String(contentsOf: node.url, encoding: .utf8)
            selectedFileContent = content
            isLoading = false
        } catch {
            TavernLogger.resources.error("[ResourcePanelViewModel] Failed to read file \(node.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            selectedFileContent = nil
            self.error = "Failed to read file: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Deselect the current file
    public func deselectFile() {
        selectedFileURL = nil
        selectedFileContent = nil
        selectedFileName = nil
        error = nil
    }

    // MARK: - Private Helpers

    /// Recursively find and update a node by ID in the tree
    private func updateNode(id: String, in nodes: inout [FileTreeNode], transform: (inout FileTreeNode) -> Void) {
        for i in nodes.indices {
            if nodes[i].id == id {
                transform(&nodes[i])
                return
            }
            if nodes[i].children != nil {
                updateNode(id: id, in: &nodes[i].children!, transform: transform)
            }
        }
    }
}
