import SwiftUI
import TavernKit

// MARK: - Provenance: REQ-ARCH-003

struct SidePaneSurface: View {
    let facet: SidePaneFacet
    let board: WindowBoard

    var body: some View {
        switch facet {
        case .hidden:
            EmptyView()

        case .visible:
            board.resourcePanelSocket.tile.makeView()
                .frame(minWidth: 250, idealWidth: 350, maxWidth: 600)
        }
    }
}

// MARK: - Preview

#Preview("Side Pane Surface") {
    VStack(spacing: 0) {
        Picker("", selection: .constant("Files")) {
            Text("Files").tag("Files")
            Text("Tasks").tag("Tasks")
            Text("TODOs").tag("TODOs")
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)

        Divider()

        List {
            Label("Sources", systemImage: "folder.fill")
            Label("Tests", systemImage: "folder.fill")
            Label("Package.swift", systemImage: "swift")
        }
        .listStyle(.sidebar)
    }
    .frame(width: 300, height: 400)
}
