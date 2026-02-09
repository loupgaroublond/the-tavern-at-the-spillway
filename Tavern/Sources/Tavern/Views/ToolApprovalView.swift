import SwiftUI
import TavernCore
import os.log

/// Sheet/dialog shown when a tool needs user approval to execute.
///
/// Displays the tool name, description, allow/deny buttons, and an
/// "Always allow this tool" checkbox. Result is returned via the
/// onResponse callback.
struct ToolApprovalView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    let request: ToolApprovalRequest
    let onResponse: (ToolApprovalResponse) -> Void

    @State private var alwaysAllow: Bool = false

    var body: some View {
        let _ = Self.logger.debug("[ToolApprovalView] body - tool: \(request.toolName)")

        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Tool Approval Required")
                    .font(.headline)
            }

            Divider()

            // Tool info
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Tool") {
                    Text(request.toolName)
                        .font(.body.monospaced())
                }

                if !request.toolDescription.isEmpty {
                    LabeledContent("Action") {
                        Text(request.toolDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if !request.agentName.isEmpty {
                    LabeledContent("Agent") {
                        Text(request.agentName)
                            .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Always allow checkbox
            Toggle("Always allow \"\(request.toolName)\"", isOn: $alwaysAllow)
                .toggleStyle(.checkbox)

            // Action buttons
            HStack {
                Button("Deny") {
                    Self.logger.info("[ToolApprovalView] user denied tool: \(request.toolName)")
                    onResponse(ToolApprovalResponse(approved: false, alwaysAllow: false))
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Allow") {
                    Self.logger.info("[ToolApprovalView] user approved tool: \(request.toolName), alwaysAllow=\(alwaysAllow)")
                    onResponse(ToolApprovalResponse(approved: true, alwaysAllow: alwaysAllow))
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            Self.logger.info("[ToolApprovalView] appeared for tool: \(request.toolName)")
        }
    }
}
