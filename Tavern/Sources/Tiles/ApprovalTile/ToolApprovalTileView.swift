import SwiftUI
import TavernKit
import os.log

struct ToolApprovalTileView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    @Bindable var tile: ToolApprovalTile

    var body: some View {
        let _ = Self.logger.debug("[ToolApprovalTileView] body - tool: \(tile.request.toolName)")

        VStack(spacing: 16) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Tool Approval Required")
                    .font(.headline)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Tool") {
                    Text(tile.request.toolName)
                        .font(.body.monospaced())
                }

                if !tile.request.toolDescription.isEmpty {
                    LabeledContent("Action") {
                        Text(tile.request.toolDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if !tile.request.agentName.isEmpty {
                    LabeledContent("Agent") {
                        Text(tile.request.agentName)
                            .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Toggle("Always allow \"\(tile.request.toolName)\"", isOn: $tile.alwaysAllow)
                .toggleStyle(.checkbox)

            HStack {
                Button("Deny") {
                    Self.logger.info("[ToolApprovalTileView] user denied tool: \(tile.request.toolName)")
                    tile.deny()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Allow") {
                    Self.logger.info("[ToolApprovalTileView] user approved tool: \(tile.request.toolName), alwaysAllow=\(tile.alwaysAllow)")
                    tile.approve()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            Self.logger.info("[ToolApprovalTileView] appeared for tool: \(tile.request.toolName)")
        }
    }
}

// MARK: - Preview

#Preview("Tool Approval") {
    let tile = ToolApprovalTile(
        request: ToolApprovalRequest(
            toolName: "bash",
            toolDescription: "Execute: rm -rf /tmp/test",
            agentName: "Marcos Antonio"
        ),
        responder: ToolApprovalResponder(onResponse: { response in print("Response: \(response.approved)") })
    )
    tile.makeView()
}
