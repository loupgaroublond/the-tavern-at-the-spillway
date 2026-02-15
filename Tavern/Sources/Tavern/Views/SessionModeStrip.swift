import SwiftUI
import TavernCore
import os.log

/// Compact mode picker strip that sits above the input bar.
/// Shows the four main session modes as pill buttons.
struct SessionModeStrip: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    @Binding var currentMode: PermissionMode
    let isEnabled: Bool

    /// The modes exposed in the strip (omits dontAsk for simplicity)
    private static let modes: [(mode: PermissionMode, label: String, icon: String)] = [
        (.plan, "Plan", "doc.text.magnifyingglass"),
        (.normal, "Normal", "checkmark.shield"),
        (.acceptEdits, "Auto-Edit", "pencil.circle"),
        (.bypassPermissions, "YOLO", "bolt.circle"),
    ]

    var body: some View {
        let _ = Self.logger.debug("[SessionModeStrip] body - mode: \(currentMode.rawValue), enabled: \(isEnabled)")

        HStack(spacing: 4) {
            ForEach(Self.modes, id: \.mode) { item in
                Button {
                    currentMode = item.mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10))
                        Text(item.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        currentMode == item.mode
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .foregroundColor(
                        currentMode == item.mode
                            ? .accentColor
                            : .secondary
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .help(item.mode.modeDescription)
                .accessibilityIdentifier("sessionMode_\(item.mode.rawValue)")
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var mode: PermissionMode = .plan

    VStack {
        Spacer()
        Divider()
        SessionModeStrip(currentMode: $mode, isEnabled: true)
        Divider()
    }
    .frame(width: 500, height: 200)
}
