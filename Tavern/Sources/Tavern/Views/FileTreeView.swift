import SwiftUI
import TavernCore
import os.log

/// File tree browser with expand/collapse directories
struct FileTreeView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        let _ = Self.logger.debug("[FileTreeView] body - rootNodes: \(viewModel.rootNodes.count)")

        List {
            ForEach(viewModel.rootNodes) { node in
                FileTreeRow(node: node, viewModel: viewModel)
            }
        }
        .listStyle(.sidebar)
        .task {
            let taskId = UUID().uuidString.prefix(8)
            Self.logger.info("[FileTreeView:\(taskId)] .task started - loading root directory")
            viewModel.loadRootDirectory()
            Self.logger.info("[FileTreeView:\(taskId)] .task completed - rootNodes: \(viewModel.rootNodes.count)")
        }
        .onAppear {
            Self.logger.debug("[FileTreeView] onAppear - rootNodes: \(viewModel.rootNodes.count)")
        }
        .onDisappear {
            Self.logger.debug("[FileTreeView] onDisappear")
        }
    }
}

/// A single row in the file tree (recursive for directories)
private struct FileTreeRow: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    let node: FileTreeNode
    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        if node.isDirectory {
            let _ = Self.logger.debug("[FileTreeRow] body - directory: \(node.name), expanded: \(node.isExpanded)")
            DisclosureGroup(
                isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { _ in viewModel.toggleDirectory(node) }
                )
            ) {
                if let children = node.children {
                    ForEach(children) { child in
                        FileTreeRow(node: child, viewModel: viewModel)
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
            let _ = Self.logger.debug("[FileTreeRow] body - file: \(node.name), selected: \(viewModel.selectedFileURL == node.url)")
            Button(action: { viewModel.selectFile(node) }) {
                Label(node.name, systemImage: FileTypeIcon.symbolName(
                    for: node.fileExtension,
                    isDirectory: false
                ))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 1)
            .background(
                viewModel.selectedFileURL == node.url
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(4)
        }
    }
}
