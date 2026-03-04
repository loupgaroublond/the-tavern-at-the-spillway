import SwiftUI
import TavernKit
import os.log

struct PlanApprovalTileView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    @Bindable var tile: PlanApprovalTile

    var body: some View {
        let _ = Self.logger.debug("[PlanApprovalTileView] body - agent: \(tile.request.agentName)")

        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Plan Review")
                    .font(.headline)
            }

            Divider()

            LabeledContent("Agent") {
                Text(tile.request.agentName)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !tile.request.allowedPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Requested Permissions")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(Array(tile.request.allowedPrompts.enumerated()), id: \.offset) { _, prompt in
                        HStack(spacing: 6) {
                            Image(systemName: "terminal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(prompt.prompt)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            TextField("Feedback (optional)", text: $tile.feedback)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Reject") {
                    Self.logger.info("[PlanApprovalTileView] plan rejected for agent: \(tile.request.agentName)")
                    tile.reject()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Approve") {
                    Self.logger.info("[PlanApprovalTileView] plan approved for agent: \(tile.request.agentName)")
                    tile.approve()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 450)
        .onAppear {
            Self.logger.info("[PlanApprovalTileView] appeared for agent: \(tile.request.agentName)")
        }
    }
}

// MARK: - Preview

#Preview("Plan Approval") {
    let tile = PlanApprovalTile(
        request: PlanApprovalRequest(
            agentName: "Marcos Antonio",
            allowedPrompts: [
                (tool: "Bash", prompt: "run tests"),
                (tool: "Bash", prompt: "install dependencies"),
            ]
        ),
        responder: PlanApprovalResponder(onResponse: { response in print("Approved: \(response.approved)") })
    )
    tile.makeView()
}
