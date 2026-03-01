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
