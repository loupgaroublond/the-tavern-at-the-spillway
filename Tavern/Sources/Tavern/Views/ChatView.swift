import SwiftUI
import TavernCore
import os.log

/// A chat interface for conversing with an agent
struct ChatView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var autocomplete: SlashCommandAutocomplete
    @ObservedObject var fileMention: FileMentionAutocomplete

    var body: some View {
        let _ = Self.logger.debug("[ChatView] body - messages: \(viewModel.messages.count), cogitating: \(viewModel.isCogitating), streaming: \(viewModel.isStreaming)")
        VStack(spacing: 0) {
            // Header with agent name, token display, and new conversation button
            ChatHeader(
                agentName: viewModel.agentName,
                isEnabled: !viewModel.isCogitating,
                tokenDisplay: viewModel.hasUsageData ? viewModel.formattedTokens : nil,
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

            // Message list with scroll-to-bottom support
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Loading indicator while session history restores
                            if viewModel.isLoadingHistory {
                                HistoryLoadingIndicator()
                                    .accessibilityIdentifier("historyLoadingIndicator")
                            }

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

                            // Tool progress indicator (shown when a tool is executing)
                            if let toolName = viewModel.currentToolName {
                                ToolProgressIndicator(
                                    toolName: toolName,
                                    startTime: viewModel.toolStartTime ?? Date()
                                )
                                .id("toolProgress")
                                .accessibilityIdentifier("toolProgressIndicator")
                            }

                            // Streaming indicator (shown while tokens are arriving)
                            if viewModel.isStreaming && viewModel.currentToolName == nil {
                                StreamingIndicator()
                                    .id("streaming")
                                    .accessibilityIdentifier("streamingIndicator")
                            }

                            // Bottom anchor for scroll detection
                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                                .onAppear {
                                    viewModel.showScrollToBottom = false
                                }
                                .onDisappear {
                                    viewModel.showScrollToBottom = true
                                }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        // Auto-scroll only if already at bottom
                        if !viewModel.showScrollToBottom {
                            if let lastMessage = viewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onChange(of: viewModel.isCogitating) {
                        if viewModel.isCogitating && !viewModel.showScrollToBottom {
                            withAnimation {
                                proxy.scrollTo("cogitating", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isStreaming) {
                        if viewModel.isStreaming && !viewModel.showScrollToBottom {
                            withAnimation {
                                proxy.scrollTo("streaming", anchor: .bottom)
                            }
                        }
                    }
                    // Expose proxy for the scroll-to-bottom button
                    .overlay(alignment: .bottom) {
                        if viewModel.showScrollToBottom {
                            ScrollToBottomButton {
                                withAnimation {
                                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                                }
                            }
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
            }

            Divider()

            // Session mode picker
            SessionModeStrip(
                currentMode: $viewModel.sessionMode,
                isEnabled: !viewModel.isCogitating
            )

            // Autocomplete popups (appears above input bar) — only one visible at a time
            if autocomplete.isVisible {
                SlashCommandAutocompletePopup(
                    autocomplete: autocomplete,
                    onSelect: { commandText in
                        viewModel.inputText = commandText
                        autocomplete.hide()
                    }
                )
                .accessibilityIdentifier("autocompletePopup")
            } else if fileMention.isVisible {
                FileMentionAutocompletePopup(
                    fileMention: fileMention,
                    onSelect: { suggestion in
                        if let replacement = fileMention.selectedCompletion(for: viewModel.inputText) {
                            viewModel.inputText = replacement
                        }
                        fileMention.hide()
                    }
                )
                .accessibilityIdentifier("fileMentionPopup")
            }

            // Input area
            InputBar(
                agentName: viewModel.agentName,
                text: $viewModel.inputText,
                isEnabled: !viewModel.isCogitating,
                isStreaming: viewModel.isStreaming,
                autocomplete: autocomplete,
                fileMention: fileMention,
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
        .onAppear {
            Self.logger.debug("[ChatView] onAppear - agent: \(viewModel.agentName), messages: \(viewModel.messages.count)")
        }
        .onDisappear {
            Self.logger.debug("[ChatView] onDisappear - agent: \(viewModel.agentName)")
        }
        .onChange(of: viewModel.inputText) {
            autocomplete.update(for: viewModel.inputText)
            // Only update file mentions if slash command autocomplete isn't showing
            if !autocomplete.isVisible {
                fileMention.update(for: viewModel.inputText)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.pendingApproval != nil },
            set: { show in
                if !show {
                    viewModel.respondToApproval(ToolApprovalResponse(approved: false))
                }
            }
        )) {
            if let request = viewModel.pendingApproval {
                ToolApprovalView(
                    request: request,
                    onResponse: { response in
                        viewModel.respondToApproval(response)
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.pendingPlanApproval != nil },
            set: { show in
                if !show {
                    viewModel.respondToPlanApproval(PlanApprovalResponse(approved: false, feedback: "Dismissed"))
                }
            }
        )) {
            if let request = viewModel.pendingPlanApproval {
                PlanApprovalView(
                    request: request,
                    onResponse: { response in
                        viewModel.respondToPlanApproval(response)
                    }
                )
            }
        }
    }
}

// MARK: - Chat Header

/// Header bar with agent name, token display, and new conversation button
private struct ChatHeader: View {
    let agentName: String
    let isEnabled: Bool
    let tokenDisplay: String?
    let onNewConversation: () -> Void

    var body: some View {
        HStack {
            Text(agentName)
                .font(.headline)

            Spacer()

            if let tokenDisplay {
                Text(tokenDisplay)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("tokenDisplay")
            }

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

// MARK: - History Loading Indicator

/// Placeholder shown while session history loads from disk
private struct HistoryLoadingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text("Restoring session history...")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
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

// MARK: - Scroll to Bottom Button

/// Floating button that scrolls the chat to the latest message
private struct ScrollToBottomButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white, .blue)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scrollToBottomButton")
        .help("Scroll to bottom")
    }
}

// MARK: - Tool Progress Indicator

/// Shows which tool is currently executing with elapsed time
private struct ToolProgressIndicator: View {
    let toolName: String
    let startTime: Date

    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text(toolName)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text(formattedElapsed)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .monospacedDigit()
        }
        .padding(.leading, 44) // Align with message content (past avatar)
        .padding(.vertical, 4)
        .onAppear {
            elapsed = Date().timeIntervalSince(startTime)
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    elapsed = Date().timeIntervalSince(startTime)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var formattedElapsed: String {
        let seconds = Int(elapsed)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m \(seconds % 60)s"
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

// MARK: - File Mention Autocomplete Popup

private struct FileMentionAutocompletePopup: View {
    @ObservedObject var fileMention: FileMentionAutocomplete
    let onSelect: (FileMentionSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(fileMention.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                HStack(spacing: 8) {
                    Image(systemName: suggestion.isDirectory ? "folder" : "doc")
                        .foregroundColor(suggestion.isDirectory ? .blue : .secondary)
                        .frame(width: 16)

                    Text(suggestion.relativePath)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(index == fileMention.selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(suggestion)
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
    @ObservedObject var fileMention: FileMentionAutocomplete
    let onSend: () -> Void
    let onCancel: () -> Void

    /// Maximum height the input area can grow to (roughly 8 lines)
    private let maxInputHeight: CGFloat = 200

    /// Whether any autocomplete popup is currently visible
    private var isAnyAutocompleteVisible: Bool {
        autocomplete.isVisible || fileMention.isVisible
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            MultiLineTextInput(
                text: $text,
                placeholder: "Message \(agentName)...",
                isEnabled: isEnabled,
                maxHeight: maxInputHeight,
                onSend: {
                    // If slash command autocomplete is showing, Enter selects the completion
                    if autocomplete.isVisible, let completion = autocomplete.selectedCompletion() {
                        text = completion
                        autocomplete.hide()
                        return
                    }
                    // If file mention autocomplete is showing, Enter selects the completion
                    if fileMention.isVisible, let completion = fileMention.selectedCompletion(for: text) {
                        text = completion
                        fileMention.hide()
                        return
                    }
                    if isEnabled && !text.isEmpty {
                        onSend()
                    }
                },
                onTextChange: { _ in },
                onKeyEvent: { event in
                    handleKeyEvent(event)
                }
            )
            .frame(minHeight: 28, maxHeight: maxInputHeight)

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

    /// Handle special key events forwarded from the NSTextView
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode

        // Up arrow (keyCode 126)
        if keyCode == 126 {
            if autocomplete.isVisible {
                autocomplete.moveUp()
                return true
            }
            if fileMention.isVisible {
                fileMention.moveUp()
                return true
            }
            return false
        }

        // Down arrow (keyCode 125)
        if keyCode == 125 {
            if autocomplete.isVisible {
                autocomplete.moveDown()
                return true
            }
            if fileMention.isVisible {
                fileMention.moveDown()
                return true
            }
            return false
        }

        // Tab (keyCode 48)
        if keyCode == 48 {
            if autocomplete.isVisible, let completion = autocomplete.selectedCompletion() {
                text = completion
                autocomplete.hide()
                return true
            }
            if fileMention.isVisible, let completion = fileMention.selectedCompletion(for: text) {
                text = completion
                fileMention.hide()
                return true
            }
            return false
        }

        // Escape (keyCode 53)
        if keyCode == 53 {
            if isStreaming {
                onCancel()
                return true
            }
            if autocomplete.isVisible {
                autocomplete.hide()
                return true
            }
            if fileMention.isVisible {
                fileMention.hide()
                return true
            }
            return false
        }

        return false
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
    let fileMention = FileMentionAutocomplete(projectRoot: projectURL)

    ChatView(viewModel: viewModel, autocomplete: autocomplete, fileMention: fileMention)
        .frame(width: 400, height: 600)
}
