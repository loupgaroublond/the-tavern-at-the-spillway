import SwiftUI
import os.log

/// A code/text block with a copy-to-clipboard button that appears on hover.
/// Used inside collapsible blocks and for standalone code display.
struct CodeBlockView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    enum Style {
        case monospaced
        case plain
    }

    let content: String
    var style: Style = .monospaced

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        let _ = Self.logger.debug("[CodeBlockView] body - style: \(String(describing: style)), length: \(content.count)")

        ZStack(alignment: .topTrailing) {
            textContent
                .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                copyButton
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            Self.logger.debug("[CodeBlockView] onAppear - style: \(String(describing: style)), length: \(content.count)")
        }
        .onChange(of: isHovered) {
            Self.logger.debug("[CodeBlockView] isHovered changed: \(isHovered)")
        }
    }

    @ViewBuilder
    private var textContent: some View {
        switch style {
        case .monospaced:
            Text(content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

        case .plain:
            Text(content)
                .font(.callout)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }

    private var copyButton: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                if showCopied {
                    Text("Copied")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(4)
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .padding(4)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        Self.logger.debug("[CodeBlockView] copied \(content.count) chars to clipboard")

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}
