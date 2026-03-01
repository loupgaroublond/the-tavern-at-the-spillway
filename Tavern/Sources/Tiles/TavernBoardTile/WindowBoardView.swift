import SwiftUI
import TavernKit
import os.log

// MARK: - Provenance: REQ-UX-001, REQ-ARCH-003

struct WindowBoardView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "board")

    @Bindable var board: WindowBoard

    var body: some View {
        let _ = Self.logger.debug("[WindowBoardView] body - detail: \(String(describing: board.detailFacet)), sidebar: \(String(describing: board.sidebarFacet)), modal: \(board.activeModal?.id ?? "none")")

        NavigationSplitView {
            VStack(spacing: 0) {
                BoardHeader(
                    projectName: board.projectName,
                    rootURL: board.rootURL
                )

                Divider()

                SidebarSurface(
                    facet: board.sidebarFacet,
                    board: board
                )
            }
            .frame(minWidth: 200)
        } detail: {
            HSplitView {
                DetailSurface(
                    facet: board.detailFacet,
                    board: board
                )

                SidePaneSurface(
                    facet: board.sidePaneFacet,
                    board: board
                )
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { board.toggleSidePane() }) {
                    Image(systemName: "sidebar.right")
                }
                .help(board.sidePaneFacet == .hidden ? "Show Side Pane" : "Hide Side Pane")
            }
        }
        .sheet(item: $board.activeModal) { modal in
            ModalSurface(facet: modal, board: board)
        }
        .onAppear {
            Self.logger.info("[WindowBoardView] onAppear - project: \(board.projectName)")
        }
    }
}

// MARK: - Board Header

private struct BoardHeader: View {
    let projectName: String
    let rootURL: URL

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("The Tavern at the Spillway")
                    .font(.headline)
                Text(projectName)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("Open")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
