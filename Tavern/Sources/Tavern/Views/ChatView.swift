import SwiftUI
import TavernCore

/// A chat interface for conversing with an agent
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var autocomplete: SlashCommandAutocomplete

    var body: some View {
        VStack(spacing: 0) {
            // Header with agent name and new conversation button
            ChatHeader(
                agentName: viewModel.agentName,
                isEnabled: !viewModel.isCogitating,
                onNewConversation: {
                    viewModel.clearConversation()
                }
            )

            Divider()

            // Session recovery banner (corrupt session detected)
            if viewModel.showSessionRecoveryOptions {
                SessionRecoveryBanner(
                    sessionId: viewModel.corruptSessionId,
                    onStartFresh: {
                        viewModel.startFreshSession()
                    }
                )
                .accessibilityIdentifier("sessionRecoveryBanner")
            }

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageRowView(message: message, agentName: viewModel.agentName)
                        }

                        // Cogitating indicator (shown before streaming starts)
                        if viewModel.isCogitating && !viewModel.isStreaming {
                            CogitatingIndicator(
                                agentName: viewModel.agentName,
                                verb: viewModel.cogitationVerb
                            )
                            .id("cogitating")
                            .accessibilityIdentifier("cogitatingIndicator")
                        }

                        // Streaming indicator (shown while tokens are arriving)
                        if viewModel.isStreaming {
                            StreamingIndicator()
                                .id("streaming")
                                .accessibilityIdentifier("streamingIndicator")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    // Scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isCogitating) {
                    if viewModel.isCogitating {
                        withAnimation {
                            proxy.scrollTo("cogitating", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isStreaming) {
                    if viewModel.isStreaming {
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Autocomplete popup (appears above input bar)
            if autocomplete.isVisible {
                SlashCommandAutocompletePopup(
                    autocomplete: autocomplete,
                    onSelect: { commandText in
                        viewModel.inputText = commandText
                        autocomplete.hide()
                    }
                )
                .accessibilityIdentifier("autocompletePopup")
            }

            // Input area
            InputBar(
                agentName: viewModel.agentName,
                text: $viewModel.inputText,
                isEnabled: !viewModel.isCogitating,
                isStreaming: viewModel.isStreaming,
                autocomplete: autocomplete,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                },
                onCancel: {
                    viewModel.cancelStreaming()
                }
            )
        }
        .onChange(of: viewModel.inputText) {
            autocomplete.update(for: viewModel.inputText)
        }
    }
}

// MARK: - Chat Header

/// Header bar with agent name and new conversation button
private struct ChatHeader: View {
    let agentName: String
    let isEnabled: Bool
    let onNewConversation: () -> Void

    var body: some View {
        HStack {
            Text(agentName)
                .font(.headline)

            Spacer()

            Button(action: onNewConversation) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
            .disabled(!isEnabled)
            .help("New Conversation")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Session Recovery Banner

/// Banner shown when a corrupt/expired session is detected
/// Allows user to start fresh or (future) resume a different session
private struct SessionRecoveryBanner: View {
    let sessionId: String?
    let onStartFresh: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Session Recovery")
                    .font(.headline)

                if let sessionId = sessionId {
                    Text("Session '\(sessionId)' couldn't be resumed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Start Fresh") {
                onStartFresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
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

// MARK: - Streaming Indicator

/// A pulsing dot indicator shown while tokens are arriving
private struct StreamingIndicator: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .opacity(opacity)

            Text("Generating...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 44) // Align with message content (past avatar)
        .padding(.vertical, 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Slash Command Autocomplete Popup

private struct SlashCommandAutocompletePopup: View {
    @ObservedObject var autocomplete: SlashCommandAutocomplete
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(autocomplete.suggestions.enumerated()), id: \.offset) { index, command in
                HStack(spacing: 8) {
                    Text("/\(command.name)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)

                    Text(command.description)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(index == autocomplete.selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect("/\(command.name) ")
                }
            }
        }
        .background(.regularMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 4, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Input Bar

private struct InputBar: View {
    let agentName: String
    @Binding var text: String
    let isEnabled: Bool
    let isStreaming: Bool
    @ObservedObject var autocomplete: SlashCommandAutocomplete
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message \(agentName)...", text: $text)
                .textFieldStyle(.plain)
                .disabled(!isEnabled)
                .accessibilityIdentifier("chatInputField")
                .onSubmit {
                    // If autocomplete is showing, Enter selects the completion
                    if autocomplete.isVisible, let completion = autocomplete.selectedCompletion() {
                        text = completion
                        autocomplete.hide()
                        return
                    }
                    if isEnabled && !text.isEmpty {
                        onSend()
                    }
                }
                .onKeyPress(.upArrow) {
                    guard autocomplete.isVisible else { return .ignored }
                    autocomplete.moveUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    guard autocomplete.isVisible else { return .ignored }
                    autocomplete.moveDown()
                    return .handled
                }
                .onKeyPress(.tab) {
                    guard autocomplete.isVisible, let completion = autocomplete.selectedCompletion() else {
                        return .ignored
                    }
                    text = completion
                    autocomplete.hide()
                    return .handled
                }
                .onKeyPress(.escape) {
                    if isStreaming {
                        onCancel()
                        return .handled
                    }
                    guard autocomplete.isVisible else { return .ignored }
                    autocomplete.hide()
                    return .handled
                }

            if isStreaming {
                // Stop button while streaming
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stopStreamingButton")
                .help("Stop generating")
            } else {
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(text.isEmpty || !isEnabled ? .gray : .blue)
                }
                .disabled(text.isEmpty || !isEnabled)
                .buttonStyle(.plain)
                .accessibilityIdentifier("sendButton")
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    // Create Jake for preview (no saved session for preview)
    let projectURL = URL(fileURLWithPath: "/tmp/tavern-preview")
    let jake = Jake(projectURL: projectURL, loadSavedSession: false)
    let viewModel = ChatViewModel(jake: jake, loadHistory: false)
    let dispatcher = SlashCommandDispatcher()
    let autocomplete = SlashCommandAutocomplete(dispatcher: dispatcher)

    ChatView(viewModel: viewModel, autocomplete: autocomplete)
        .frame(width: 400, height: 600)
}
