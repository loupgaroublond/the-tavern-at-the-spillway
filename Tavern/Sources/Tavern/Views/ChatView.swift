import SwiftUI
import TavernCore

/// A chat interface for conversing with an agent
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageRow(message: message, agentName: viewModel.agentName)
                        }

                        // Cogitating indicator
                        if viewModel.isCogitating {
                            CogitatingIndicator(
                                agentName: viewModel.agentName,
                                verb: viewModel.cogitationVerb
                            )
                            .id("cogitating")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    // Scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isCogitating) { isCogitating in
                    if isCogitating {
                        withAnimation {
                            proxy.scrollTo("cogitating", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            InputBar(
                agentName: viewModel.agentName,
                text: $viewModel.inputText,
                isEnabled: !viewModel.isCogitating,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
        }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: ChatMessage
    let agentName: String

    /// First letter of agent name for avatar
    private var agentInitial: String {
        String(agentName.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar - varies by message type
            avatarView

            // Content - varies by message type
            contentView

            Spacer()
        }
        .padding(.vertical, 4)
    }

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
        case .toolUse:
            return .purple
        case .toolResult:
            return .green
        case .toolError:
            return .red
        case .thinking:
            return .gray
        case .webSearch:
            return .cyan
        }
    }

    private var avatarIcon: String {
        switch message.messageType {
        case .text:
            return message.role == .user ? "person.fill" : "star.fill"
        case .toolUse:
            return "hammer.fill"
        case .toolResult:
            return "checkmark"
        case .toolError:
            return "exclamationmark.triangle.fill"
        case .thinking:
            return "brain"
        case .webSearch:
            return "globe"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header label
            headerLabel

            // Content based on type
            contentBody
        }
    }

    @ViewBuilder
    private var headerLabel: some View {
        switch message.messageType {
        case .text:
            Text(message.role == .user ? "You" : agentName)
                .font(.caption)
                .foregroundColor(.secondary)

        case .toolUse:
            HStack(spacing: 4) {
                Text("Tool")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let toolName = message.toolName {
                    Text(toolName)
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                }
            }

        case .toolResult:
            Text("Result")
                .font(.caption)
                .foregroundColor(.green)

        case .toolError:
            Text("Error")
                .font(.caption)
                .foregroundColor(.red)

        case .thinking:
            Text("Thinking...")
                .font(.caption)
                .foregroundColor(.gray)
                .italic()

        case .webSearch:
            Text("Web Search")
                .font(.caption)
                .foregroundColor(.cyan)
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch message.messageType {
        case .text:
            Text(message.content)
                .textSelection(.enabled)

        case .toolUse:
            // Tool use shows input in a code-style block
            Text(message.content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)

        case .toolResult:
            // Tool result in a success-styled block
            Text(message.content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)

        case .toolError:
            // Error in a warning-styled block
            Text(message.content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)

        case .thinking:
            // Thinking in a subtle gray block
            Text(message.content)
                .font(.callout)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

        case .webSearch:
            Text(message.content)
                .textSelection(.enabled)
                .padding(8)
                .background(Color.cyan.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

// MARK: - Cogitating Indicator

private struct CogitatingIndicator: View {
    let agentName: String
    let verb: String
    @State private var dotCount = 0
    @State private var timer: Timer?

    /// First letter of agent name for avatar
    private var agentInitial: String {
        String(agentName.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar with animation
            Circle()
                .fill(Color.orange.opacity(0.7))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(agentInitial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

            // Animated status
            VStack(alignment: .leading, spacing: 4) {
                Text(agentName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text(verb)
                        .foregroundColor(.secondary)
                        .italic()

                    Text(String(repeating: ".", count: dotCount + 1))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

// MARK: - Input Bar

private struct InputBar: View {
    let agentName: String
    @Binding var text: String
    let isEnabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message \(agentName)...", text: $text)
                .textFieldStyle(.plain)
                .disabled(!isEnabled)
                .onSubmit {
                    if isEnabled && !text.isEmpty {
                        onSend()
                    }
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(text.isEmpty || !isEnabled ? .gray : .blue)
            }
            .disabled(text.isEmpty || !isEnabled)
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    // Create a mock Jake for preview
    let mock = MockClaudeCode()
    mock.queueJSONResponse(result: "Well well WELL!", sessionId: "preview-session")

    let jake = Jake(claude: mock)
    let viewModel = ChatViewModel(jake: jake)

    return ChatView(viewModel: viewModel)
        .frame(width: 400, height: 600)
}
