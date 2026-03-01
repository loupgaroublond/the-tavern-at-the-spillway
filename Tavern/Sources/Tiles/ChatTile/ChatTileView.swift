import SwiftUI
import TavernKit
import os.log

// MARK: - Provenance: REQ-UX-002, REQ-UX-009

struct ChatTileView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    @Bindable var tile: ChatTile

    var body: some View {
        let _ = Self.logger.debug("[ChatTileView] body - messages: \(tile.messages.count), cogitating: \(tile.isCogitating)")

        VStack(spacing: 0) {
            ChatHeader(
                agentName: tile.servitorName,
                isEnabled: !tile.isCogitating,
                tokenDisplay: tile.hasUsageData ? tile.formattedTokens : nil,
                onNewConversation: { tile.clearConversation() }
            )

            Divider()

            if tile.showSessionRecoveryOptions {
                SessionRecoveryBanner(
                    sessionId: tile.corruptSessionId,
                    onStartFresh: { tile.startFreshSession() }
                )
            }

            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if tile.isLoadingHistory {
                                HistoryLoadingIndicator()
                            }

                            ForEach(tile.messages) { message in
                                MessageRowView(message: message, agentName: tile.servitorName)
                            }

                            if tile.isCogitating && !tile.isStreaming {
                                CogitatingIndicator(
                                    agentName: tile.servitorName,
                                    verb: tile.cogitationVerb
                                )
                                .id("cogitating")
                            }

                            if let toolName = tile.currentToolName {
                                ToolProgressIndicator(
                                    toolName: toolName,
                                    startTime: tile.toolStartTime ?? Date()
                                )
                                .id("toolProgress")
                            }

                            if tile.isStreaming && tile.currentToolName == nil {
                                StreamingIndicator()
                                    .id("streaming")
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                                .onAppear { tile.showScrollToBottom = false }
                                .onDisappear { tile.showScrollToBottom = true }
                        }
                        .padding()
                    }
                    .onChange(of: tile.messages.count) {
                        if !tile.showScrollToBottom {
                            if let lastMessage = tile.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if tile.showScrollToBottom {
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

            SessionModeStrip(
                currentMode: $tile.sessionMode,
                isEnabled: !tile.isCogitating
            )

            InputBar(
                agentName: tile.servitorName,
                text: $tile.inputText,
                isEnabled: !tile.isCogitating,
                isStreaming: tile.isStreaming,
                onSend: { Task { await tile.sendMessage() } },
                onCancel: { tile.cancelStreaming() }
            )
        }
        .task {
            await tile.loadSessionHistory()
        }
        .onChange(of: tile.sessionMode) {
            tile.syncSessionModeToProvider()
        }
        .onAppear {
            Self.logger.debug("[ChatTileView] onAppear - agent: \(tile.servitorName)")
        }
    }
}

// MARK: - Chat Header

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

                if let sessionId {
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

// MARK: - Session Mode Strip

struct SessionModeStrip: View {
    @Binding var currentMode: PermissionMode
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PermissionMode.allCases, id: \.self) { mode in
                Button(mode.displayName) {
                    currentMode = mode
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(currentMode == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(4)
                .foregroundColor(currentMode == mode ? .accentColor : .secondary)
                .font(.caption)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .disabled(!isEnabled)
    }
}

// MARK: - Input Bar

struct InputBar: View {
    let agentName: String
    @Binding var text: String
    let isEnabled: Bool
    let isStreaming: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            MultiLineTextInput(
                text: $text,
                placeholder: "Message \(agentName)...",
                isEnabled: isEnabled,
                maxHeight: 200,
                onSend: onSend,
                onTextChange: { _ in },
                onKeyEvent: nil
            )
            .frame(minHeight: 28)

            if isStreaming {
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Stop streaming")
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send message")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Indicators

private struct HistoryLoadingIndicator: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView("Loading history...")
                .font(.caption)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

private struct CogitatingIndicator: View {
    let agentName: String
    let verb: String
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("\(verb)\(String(repeating: ".", count: dotCount))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

private struct ToolProgressIndicator: View {
    let toolName: String
    let startTime: Date

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Image(systemName: "hammer.fill")
                .font(.caption)
                .foregroundColor(.purple)
            Text(toolName)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct StreamingIndicator: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(opacity)
            Text("Streaming")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
        .task {
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.6)) {
                    opacity = opacity < 0.5 ? 1.0 : 0.3
                }
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }
}

private struct ScrollToBottomButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Chat Tile") {
    VStack(spacing: 0) {
        ChatHeader(
            agentName: "Jake",
            isEnabled: true,
            tokenDisplay: "1024↑ 512↓",
            onNewConversation: {}
        )

        Divider()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                MessageRowView(
                    message: .text(role: .user, content: "Hello Jake!"),
                    agentName: "Jake"
                )
                MessageRowView(
                    message: .text(role: .agent, content: "Well HOWDY there, friend! Welcome to the FINEST establishment this side of the spillway!"),
                    agentName: "Jake"
                )
            }
            .padding()
        }

        Divider()

        SessionModeStrip(currentMode: .constant(.normal), isEnabled: true)

        InputBar(
            agentName: "Jake",
            text: .constant(""),
            isEnabled: true,
            isStreaming: false,
            onSend: {},
            onCancel: {}
        )
    }
    .frame(width: 500, height: 500)
}
