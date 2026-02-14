import SwiftUI
import TavernCore
import os.log

/// A single message row in the chat view.
/// Provides visual distinction between message types via color-coded avatars,
/// styled content blocks, and timestamps.
struct MessageRowView: View {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    let message: ChatMessage
    let agentName: String

    var body: some View {
        let _ = Self.logger.debug("[MessageRowView] body - type: \(message.messageType.rawValue), role: \(message.role.rawValue)")

        Group {
            switch message.messageType {
            case .text:
                textMessageRow

            case .toolUse:
                collapsibleRow(blockType: .toolUse(name: message.toolName))

            case .toolResult:
                collapsibleRow(blockType: .toolResult)

            case .toolError:
                collapsibleRow(blockType: .toolError)

            case .thinking:
                collapsibleRow(blockType: .thinking)

            case .webSearch:
                webSearchRow
            }
        }
        .onAppear {
            Self.logger.debug("[MessageRowView] onAppear - type: \(message.messageType.rawValue), id: \(message.id)")
        }
    }

    // MARK: - Text Message

    private var textMessageRow: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                headerWithTimestamp

                Text(message.content)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Collapsible Block Row (Tool Use, Tool Result, Thinking, Error)

    private func collapsibleRow(blockType: CollapsibleBlockView.BlockType) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Timestamp right-aligned above the block
            HStack {
                Spacer()
                timestampView
            }

            // Detect diff content in tool results
            if case .toolResult = blockType, isDiffContent(message.content) {
                diffCollapsibleBlock(blockType: blockType)
            } else {
                CollapsibleBlockView(blockType: blockType, content: message.content)
            }
        }
        .padding(.leading, 44) // Align with text content (avatar width + spacing)
    }

    /// A collapsible block that renders a diff view instead of plain code
    private func diffCollapsibleBlock(blockType: CollapsibleBlockView.BlockType) -> some View {
        DiffCollapsibleBlock(blockType: blockType, content: message.content)
    }

    // MARK: - Web Search Row

    private var webSearchRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                timestampView
            }

            CollapsibleBlockView(blockType: .webSearch, content: message.content)
        }
        .padding(.leading, 44)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: avatarIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
    }

    private var avatarColor: Color {
        switch message.messageType {
        case .text:
            return message.role == .user ? .blue : .orange
        case .toolUse: return .purple
        case .toolResult: return .green
        case .toolError: return .red
        case .thinking: return .gray
        case .webSearch: return .cyan
        }
    }

    private var avatarIcon: String {
        switch message.messageType {
        case .text:
            return message.role == .user ? "person.fill" : "star.fill"
        case .toolUse: return "hammer.fill"
        case .toolResult: return "checkmark"
        case .toolError: return "exclamationmark.triangle.fill"
        case .thinking: return "brain"
        case .webSearch: return "globe"
        }
    }

    // MARK: - Header + Timestamp

    private var headerWithTimestamp: some View {
        HStack {
            headerLabel
            Spacer()
            timestampView
        }
    }

    @ViewBuilder
    private var headerLabel: some View {
        switch message.messageType {
        case .text:
            Text(message.role == .user ? "You" : agentName)
                .font(.caption)
                .foregroundColor(.secondary)

        default:
            EmptyView()
        }
    }

    private var timestampView: some View {
        Text(formattedTimestamp)
            .font(.caption2)
            .foregroundColor(.secondary.opacity(0.7))
    }

    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(message.timestamp) {
            // Today: show just time
            return Self.timeFormatter.string(from: message.timestamp)
        } else if calendar.isDateInYesterday(message.timestamp) {
            return "Yesterday " + Self.timeFormatter.string(from: message.timestamp)
        } else if let daysAgo = calendar.dateComponents([.day], from: message.timestamp, to: now).day, daysAgo < 7 {
            // Within a week: show day name + time
            return Self.dayTimeFormatter.string(from: message.timestamp)
        } else {
            // Older: show full date + time
            return Self.dateTimeFormatter.string(from: message.timestamp)
        }
    }

    // MARK: - Diff Detection

    /// Detect if tool result content looks like a unified diff
    private func isDiffContent(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let diffIndicators = lines.filter { line in
            line.hasPrefix("+") || line.hasPrefix("-") || line.hasPrefix("@@") || line.hasPrefix("---") || line.hasPrefix("+++")
        }
        return diffIndicators.count >= 2
    }

    // MARK: - Formatters

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()
}

// MARK: - Diff Collapsible Block

/// A collapsible block that renders diff content with colored lines
private struct DiffCollapsibleBlock: View {

    let blockType: CollapsibleBlockView.BlockType
    let content: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            DiffView(content: content)
                .padding(.top, 4)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill.viewfinder")
                    .font(.system(size: 12))
                    .foregroundColor(.green)

                Text("File Edit")
                    .font(.caption)
                    .foregroundColor(.green)

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
        .background(Color.green.opacity(0.06))
        .cornerRadius(8)
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

// MARK: - Preview

#Preview("Message Types") {
    VStack(spacing: 8) {
        MessageRowView(message: .text(role: .user, content: "Hello Jake!"), agentName: "Jake")
        MessageRowView(message: .text(role: .agent, content: "Well HOWDY there, friend!"), agentName: "Jake")
        MessageRowView(message: .toolUse(name: "bash", input: "ls -la"), agentName: "Jake")
        MessageRowView(message: .toolResult(content: "file1.txt\nfile2.txt"), agentName: "Jake")
        MessageRowView(message: .toolResult(content: "No such file", isError: true), agentName: "Jake")
        MessageRowView(message: .thinking(content: "Let me think about this..."), agentName: "Jake")
    }
    .frame(width: 500)
    .padding()
}
