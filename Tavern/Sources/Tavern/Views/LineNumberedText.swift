import SwiftUI
import os.log

/// Displays text content with line numbers in a scrollable monospace view
struct LineNumberedText: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    let content: String

    private var lines: [String] {
        content.components(separatedBy: "\n")
    }

    /// Width needed for the line number gutter based on total line count
    private var gutterWidth: CGFloat {
        let digits = String(lines.count).count
        return CGFloat(max(digits, 2)) * 10 + 12
    }

    var body: some View {
        let _ = Self.logger.debug("[LineNumberedText] body - lines: \(lines.count), gutterWidth: \(gutterWidth)")

        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 0) {
                        // Line number gutter
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                        // Line content
                        Text(line.isEmpty ? " " : line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
