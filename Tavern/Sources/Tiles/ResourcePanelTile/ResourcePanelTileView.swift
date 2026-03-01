import SwiftUI
import TavernKit
import os.log

struct ResourcePanelTileView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @Bindable var tile: ResourcePanelTile

    var body: some View {
        let _ = Self.logger.debug("[ResourcePanelTileView] body - tab: \(tile.selectedTab.rawValue)")
        VStack(spacing: 0) {
            Picker("", selection: $tile.selectedTab) {
                ForEach(SidePaneTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            switch tile.selectedTab {
            case .files:
                FilesTabContent(tile: tile)
            case .tasks:
                BackgroundTasksContent(tile: tile)
            case .todos:
                TodoListContent(tile: tile)
            }
        }
        .onAppear {
            Self.logger.debug("[ResourcePanelTileView] onAppear - tab: \(tile.selectedTab.rawValue)")
        }
        .onChange(of: tile.selectedTab) {
            Self.logger.debug("[ResourcePanelTileView] selectedTab changed: \(tile.selectedTab.rawValue)")
        }
    }
}

private struct FilesTabContent: View {
    @Bindable var tile: ResourcePanelTile

    var body: some View {
        VSplitView {
            FileTreeContent(tile: tile)
                .frame(minHeight: 150)

            FileContentContent(tile: tile)
                .frame(minHeight: 150)
        }
    }
}
