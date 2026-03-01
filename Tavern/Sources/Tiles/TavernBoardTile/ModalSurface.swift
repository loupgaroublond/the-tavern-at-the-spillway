import SwiftUI
import TavernKit
import ApprovalTile
import PermissionSettingsTile

// MARK: - Provenance: REQ-OPM-001, REQ-OPM-002, REQ-OPM-003

struct ModalSurface: View {
    let facet: ModalFacet
    let board: WindowBoard

    var body: some View {
        switch facet {
        case .toolApproval(_, let request):
            board.approvalSocket.makeToolApprovalTile(request: request).makeView()

        case .planApproval(_, let request):
            board.approvalSocket.makePlanApprovalTile(request: request).makeView()

        case .permissionSettings:
            board.permissionSettingsSocket.tile.makeView()
        }
    }
}
