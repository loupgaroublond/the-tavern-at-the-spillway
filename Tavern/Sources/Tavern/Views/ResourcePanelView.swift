import SwiftUI
import TavernCore

/// Container view for the resource panel (file tree + file content)
struct ResourcePanelView: View {
    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        VSplitView {
            // Top: File tree browser
            VStack(spacing: 0) {
                // Header
                HStack {
                    Label("Resources", systemImage: "folder")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                FileTreeView(viewModel: viewModel)
            }
            .frame(minHeight: 150)

            // Bottom: File content viewer
            FileContentView(viewModel: viewModel)
                .frame(minHeight: 150)
        }
    }
}
