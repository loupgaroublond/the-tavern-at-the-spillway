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
            // Avatar
            Circle()
                .fill(message.role == .user ? Color.blue : Color.orange)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(message.role == .user ? "U" : agentInitial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : agentName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(message.content)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
