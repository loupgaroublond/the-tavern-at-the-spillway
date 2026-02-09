import SwiftUI
import os.log

/// Renders inline diffs for file edit operations.
/// Detects unified diff format and renders with green/red line coloring.
/// Falls back to plain code display if the content is not a diff.
struct DiffView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    let content: String

    var body: some View {
        let lines = parseDiffLines(content)
        let _ = Self.logger.debug("[DiffView] body - \(lines.count) lines, isDiff: \(isDiffContent(content))")

        Group {
            if isDiffContent(content) {
                let _ = Self.logger.debug("[DiffView] SHOWING DIFF")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        DiffLineView(line: line)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            } else {
                let _ = Self.logger.debug("[DiffView] SHOWING CODE BLOCK (not a diff)")
                CodeBlockView(content: content, style: .monospaced)
            }
        }
        .onAppear {
            Self.logger.debug("[DiffView] onAppear - lines: \(lines.count), isDiff: \(isDiffContent(content))")
        }
    }

    /// Check if the content appears to be a unified diff
    private func isDiffContent(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let diffIndicators = lines.filter { line in
            line.hasPrefix("+") || line.hasPrefix("-") || line.hasPrefix("@@") || line.hasPrefix("---") || line.hasPrefix("+++")
        }
        return diffIndicators.count >= 2
    }

    /// Parse content into colored diff lines
    private func parseDiffLines(_ text: String) -> [DiffLine] {
        text.components(separatedBy: .newlines).map { line in
            if line.hasPrefix("+++") || line.hasPrefix("---") {
                return DiffLine(text: line, type: .header)
            } else if line.hasPrefix("@@") {
                return DiffLine(text: line, type: .hunk)
            } else if line.hasPrefix("+") {
                return DiffLine(text: line, type: .added)
            } else if line.hasPrefix("-") {
                return DiffLine(text: line, type: .removed)
            } else {
                return DiffLine(text: line, type: .context)
            }
        }
    }
}

// MARK: - Diff Line Model

struct DiffLine {
    let text: String
    let type: DiffLineType

    enum DiffLineType {
        case header
        case hunk
        case added
        case removed
        case context
    }
}

// MARK: - Diff Line View

private struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        Text(line.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
    }

    private var backgroundColor: Color {
        switch line.type {
        case .added: return Color.green.opacity(0.15)
        case .removed: return Color.red.opacity(0.15)
        case .hunk: return Color.blue.opacity(0.08)
        case .header: return Color.gray.opacity(0.08)
        case .context: return .clear
        }
    }

    private var foregroundColor: Color {
        switch line.type {
        case .added: return Color.green
        case .removed: return Color.red
        case .hunk: return Color.blue
        case .header: return .secondary
        case .context: return .primary
        }
    }
}
