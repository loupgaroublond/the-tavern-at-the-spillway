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

// MARK: - Preview

#Preview("Sidebar Surface") {
    List {
        HStack(spacing: 12) {
            Circle().fill(.orange).frame(width: 10, height: 10)
            Text("Jake").font(.headline).fontWeight(.bold)
            Spacer()
        }
        .padding(.vertical, 4)

        HStack(spacing: 12) {
            Circle().fill(.green).frame(width: 10, height: 10)
            Text("Marcos Antonio").font(.headline).fontWeight(.medium)
            Spacer()
        }
        .padding(.vertical, 4)
    }
    .listStyle(.sidebar)
    .frame(width: 250, height: 400)
}
