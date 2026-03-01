import SwiftUI
import TavernKit
import os.log

struct FileTreeContent: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @Bindable var tile: ResourcePanelTile

    var body: some View {
        let _ = Self.logger.debug("[FileTreeContent] body - rootNodes: \(tile.rootNodes.count)")

        List {
            ForEach(tile.rootNodes) { node in
                FileTreeRow(node: node, tile: tile)
            }
        }
        .listStyle(.sidebar)
        .task {
            let taskId = UUID().uuidString.prefix(8)
            Self.logger.info("[FileTreeContent:\(taskId)] .task started - loading root directory")
            tile.loadRootDirectory()
            Self.logger.info("[FileTreeContent:\(taskId)] .task completed - rootNodes: \(tile.rootNodes.count)")
        }
        .onAppear {
            Self.logger.debug("[FileTreeContent] onAppear - rootNodes: \(tile.rootNodes.count)")
        }
    }
}

private struct FileTreeRow: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    let node: FileTreeNode
    @Bindable var tile: ResourcePanelTile

    var body: some View {
        if node.isDirectory {
            let _ = Self.logger.debug("[FileTreeRow] body - directory: \(node.name), expanded: \(node.isExpanded)")
            DisclosureGroup(
                isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { _ in tile.toggleDirectory(node) }
                )
            ) {
                if let children = node.children {
                    ForEach(children) { child in
                        FileTreeRow(node: child, tile: tile)
                    }
                }
            } label: {
                Label(node.name, systemImage: FileTypeIcon.symbolName(
                    for: node.fileExtension,
                    isDirectory: true,
                    isExpanded: node.isExpanded
                ))
            }
        } else {
            let _ = Self.logger.debug("[FileTreeRow] body - file: \(node.name), selected: \(tile.selectedFileURL == node.url)")
            Button(action: { tile.selectFile(node) }) {
                Label(node.name, systemImage: FileTypeIcon.symbolName(
                    for: node.fileExtension,
                    isDirectory: false
                ))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 1)
            .background(
                tile.selectedFileURL == node.url
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(4)
        }
    }
}
