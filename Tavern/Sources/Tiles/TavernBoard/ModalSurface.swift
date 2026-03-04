import SwiftUI
import TavernKit
import ToolApprovalTile
import PlanApprovalTile
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

// MARK: - Preview

#Preview("Modal Surface - Permission Settings") {
    VStack(alignment: .leading, spacing: 16) {
        Section {
            Picker("Permission Mode", selection: .constant(PermissionMode.normal)) {
                ForEach(PermissionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Tools require approval unless an always-allow rule matches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Mode").font(.headline)
        }

        Divider()

        Text("No permission rules configured.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    .padding()
    .frame(width: 500, height: 300)
}
