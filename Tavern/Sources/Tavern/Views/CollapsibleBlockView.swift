import SwiftUI
import os.log

/// A collapsible container for tool use, tool result, and thinking blocks.
/// Uses DisclosureGroup with custom styling per block type.
struct CollapsibleBlockView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    enum BlockType {
        case toolUse(name: String?)
        case toolResult
        case toolError
        case thinking
        case webSearch

        var icon: String {
            switch self {
            case .toolUse: return "hammer.fill"
            case .toolResult: return "checkmark.circle.fill"
            case .toolError: return "exclamationmark.triangle.fill"
            case .thinking: return "brain"
            case .webSearch: return "globe"
            }
        }

        var accentColor: Color {
            switch self {
            case .toolUse: return .purple
            case .toolResult: return .green
            case .toolError: return .red
            case .thinking: return .gray
            case .webSearch: return .cyan
            }
        }

        var label: String {
            switch self {
            case .toolUse(let name):
                if let name = name {
                    return "Tool: \(name)"
                }
                return "Tool Use"
            case .toolResult: return "Result"
            case .toolError: return "Error"
            case .thinking: return "Thinking"
            case .webSearch: return "Web Search"
            }
        }

        var defaultExpanded: Bool {
            switch self {
            case .toolUse: return false
            case .toolResult: return false
            case .toolError: return true
            case .thinking: return false
            case .webSearch: return true
            }
        }
    }

    let blockType: BlockType
    let content: String

    @State private var isExpanded: Bool

    init(blockType: BlockType, content: String) {
        self.blockType = blockType
        self.content = content
        self._isExpanded = State(initialValue: blockType.defaultExpanded)
    }

    var body: some View {
        let _ = Self.logger.debug("[CollapsibleBlockView] body - type: \(blockType.label), expanded: \(isExpanded)")

        DisclosureGroup(isExpanded: $isExpanded) {
            contentView
                .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: blockType.icon)
                    .font(.system(size: 12))
                    .foregroundColor(blockType.accentColor)

                Text(blockType.label)
                    .font(.caption)
                    .foregroundColor(blockType.accentColor)

                if !isExpanded {
                    Text(contentPreview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(8)
        .background(blockType.accentColor.opacity(0.06))
        .cornerRadius(8)
        .onAppear {
            Self.logger.debug("[CollapsibleBlockView] onAppear - type: \(blockType.label), expanded: \(isExpanded)")
        }
        .onChange(of: isExpanded) {
            Self.logger.debug("[CollapsibleBlockView] isExpanded changed: \(isExpanded) for type: \(blockType.label)")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch blockType {
        case .toolError:
            ErrorBlockContent(content: content)

        default:
            CodeBlockView(content: content, style: codeBlockStyle)
        }
    }

    private var codeBlockStyle: CodeBlockView.Style {
        switch blockType {
        case .thinking:
            return .plain
        default:
            return .monospaced
        }
    }

    private var contentPreview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        if firstLine.count > 80 {
            return String(firstLine.prefix(80)) + "..."
        }
        return firstLine
    }
}

// MARK: - Error Block Content

/// Styled error display with icon and prominent red treatment
private struct ErrorBlockContent: View {
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14))
                .padding(.top, 2)

            Text(content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(Color.red.opacity(0.08))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Collapsible Blocks") {
    VStack(spacing: 12) {
        CollapsibleBlockView(blockType: .toolUse(name: "bash"), content: "ls -la /tmp")
        CollapsibleBlockView(blockType: .toolResult, content: "total 0\ndrwxr-xr-x  2 user  staff  64 Feb 13 12:00 .")
        CollapsibleBlockView(blockType: .toolError, content: "Permission denied: /etc/shadow")
        CollapsibleBlockView(blockType: .thinking, content: "Let me analyze the user's request...")
        CollapsibleBlockView(blockType: .webSearch, content: "Searching for: Swift concurrency patterns")
    }
    .frame(width: 500)
    .padding()
}
