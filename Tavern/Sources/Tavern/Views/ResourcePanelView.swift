import SwiftUI
import TavernCore
import os.log

/// Container view for the side pane with tab-based navigation (Files, Tasks, TODOs)
struct ResourcePanelView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @ObservedObject var resourceViewModel: ResourcePanelViewModel
    @ObservedObject var taskViewModel: BackgroundTaskViewModel
    @ObservedObject var todoViewModel: TodoListViewModel
    @Binding var selectedTab: SidePaneTab

    var body: some View {
        let _ = Self.logger.debug("[ResourcePanelView] body - tab: \(selectedTab.rawValue, privacy: .public)")
        VStack(spacing: 0) {
            // Tab picker at the top
            Picker("", selection: $selectedTab) {
                ForEach(SidePaneTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // Tab content
            switch selectedTab {
            case .files:
                FilesTabContent(viewModel: resourceViewModel)
            case .tasks:
                BackgroundTasksView(viewModel: taskViewModel)
            case .todos:
                TodoListView(viewModel: todoViewModel)
            }
        }
    }
}

/// The Files tab content (preserves existing file tree + content layout)
private struct FilesTabContent: View {
    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        VSplitView {
            FileTreeView(viewModel: viewModel)
                .frame(minHeight: 150)

            FileContentView(viewModel: viewModel)
                .frame(minHeight: 150)
        }
    }
}
