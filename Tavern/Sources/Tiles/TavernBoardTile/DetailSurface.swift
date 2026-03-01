import SwiftUI
import TavernKit

// MARK: - Provenance: REQ-ARCH-003, REQ-UX-002

struct DetailSurface: View {
    let facet: DetailFacet
    let board: WindowBoard

    var body: some View {
        switch facet {
        case .empty:
            EmptyDetailView()

        case .chat(let servitorID):
            board.chatView(for: servitorID)
                .id(servitorID)
        }
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an agent to start chatting")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Detail Surface - Empty") {
    EmptyDetailView()
        .frame(width: 500, height: 400)
}
