import SwiftUI
import TavernCore

/// File tree browser with expand/collapse directories
struct FileTreeView: View {
    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        List {
            ForEach(viewModel.rootNodes) { node in
                FileTreeRow(node: node, viewModel: viewModel)
            }
        }
        .listStyle(.sidebar)
        .task {
            viewModel.loadRootDirectory()
        }
    }
}

/// A single row in the file tree (recursive for directories)
private struct FileTreeRow: View {
    let node: FileTreeNode
    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        if node.isDirectory {
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
