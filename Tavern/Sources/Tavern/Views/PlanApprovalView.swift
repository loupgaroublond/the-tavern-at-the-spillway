import SwiftUI
import TavernCore
import os.log

/// Sheet shown when an agent in plan mode calls ExitPlanMode.
/// Displays the allowed prompts the agent requested and lets the user
/// approve (switching to normal mode) or reject (with optional feedback).
struct PlanApprovalView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    let request: PlanApprovalRequest
    let onResponse: (PlanApprovalResponse) -> Void

    @State private var feedback: String = ""

    var body: some View {
        let _ = Self.logger.debug("[PlanApprovalView] body - agent: \(request.agentName)")

        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Plan Review")
                    .font(.headline)
            }

            Divider()

            // Agent info
            LabeledContent("Agent") {
                Text(request.agentName)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Allowed prompts (if any)
            if !request.allowedPrompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Requested Permissions")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(Array(request.allowedPrompts.enumerated()), id: \.offset) { _, prompt in
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

            // Feedback field for rejection
            TextField("Feedback (optional)", text: $feedback)
                .textFieldStyle(.roundedBorder)

            // Action buttons
            HStack {
                Button("Reject") {
                    Self.logger.info("[PlanApprovalView] plan rejected for agent: \(request.agentName)")
                    onResponse(PlanApprovalResponse(
                        approved: false,
                        feedback: feedback.isEmpty ? nil : feedback
                    ))
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Approve") {
                    Self.logger.info("[PlanApprovalView] plan approved for agent: \(request.agentName)")
                    onResponse(PlanApprovalResponse(approved: true))
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 450)
        .onAppear {
            Self.logger.info("[PlanApprovalView] appeared for agent: \(request.agentName)")
        }
    }
}

// MARK: - Preview

#Preview("Plan Approval") {
    PlanApprovalView(
        request: PlanApprovalRequest(
            agentName: "Marcos Antonio",
            allowedPrompts: [
                (tool: "Bash", prompt: "run tests"),
                (tool: "Bash", prompt: "install dependencies"),
            ]
        ),
        onResponse: { response in print("Approved: \(response.approved)") }
    )
}
