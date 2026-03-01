import SwiftUI
import TavernKit

// MARK: - Provenance: REQ-ARCH-003, REQ-UX-002

struct SidebarSurface: View {
    let facet: SidebarFacet
    let board: WindowBoard

    var body: some View {
        switch facet {
        case .agents:
            board.servitorListView
        }
    }
}
