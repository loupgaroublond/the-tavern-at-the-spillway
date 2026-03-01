import Foundation
import TavernKit
import SwiftUI
import os.log

// MARK: - Provenance: REQ-UX-002, REQ-UX-009

@Observable @MainActor
public final class ChatTile {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    // MARK: - State

    var messages: [ChatMessage] = []
    var isCogitating: Bool = false
    var isStreaming: Bool = false
    var inputText: String = ""
    var showScrollToBottom: Bool = false
    var isLoadingHistory: Bool = false
    var showSessionRecoveryOptions: Bool = false
    var corruptSessionId: String?
    var sessionMode: PermissionMode

    // MARK: - Streaming Progress State

    var currentToolName: String?
    var toolStartTime: Date?

    // MARK: - Token Tracking

    private var totalInputTokens: Int = 0
    private var totalOutputTokens: Int = 0

    // MARK: - Streaming Cancellation

    private var cancelStreaming_: (@Sendable () -> Void)?

    // MARK: - Dependencies

    private let servitorID: UUID
    private let servitorProvider: any ServitorProvider
    private let commandProvider: any CommandProvider
    let responder: ChatResponder

    // MARK: - Computed Properties

    var servitorName: String {
        servitorProvider.servitorName(for: servitorID)
    }

    var hasUsageData: Bool {
        totalInputTokens > 0 || totalOutputTokens > 0
    }

    var formattedTokens: String {
        "\(totalInputTokens)↑ \(totalOutputTokens)↓"
    }

    var cogitationVerb: String {
        servitorName == "Jake" ? "Jake is cogitating" : "\(servitorName) is thinking"
    }

    // MARK: - Initialization

    public init(
        servitorID: UUID,
        servitorProvider: any ServitorProvider,
        commandProvider: any CommandProvider,
        responder: ChatResponder
    ) {
        self.servitorID = servitorID
        self.servitorProvider = servitorProvider
        self.commandProvider = commandProvider
        self.responder = responder
        self.sessionMode = servitorProvider.sessionMode(for: servitorID)
        Self.logger.info("[ChatTile] initialized for servitor: \(servitorID)")
    }

    public func makeView() -> some View {
        ChatTileView(tile: self)
    }

    // MARK: - Actions

    /// Syncs the session mode to the provider. Called from the view's onChange.
    func syncSessionModeToProvider() {
        let mode = self.sessionMode
        Self.logger.info("[ChatTile] sessionMode changed: \(mode.rawValue)")
        servitorProvider.setSessionMode(mode, for: servitorID)
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Self.logger.info("[ChatTile] sendMessage: \(text.prefix(50))...")
        inputText = ""

        messages.append(ChatMessage(role: .user, content: text))

        isCogitating = true
        isStreaming = false
        currentToolName = nil
        toolStartTime = nil
        let verb = self.cogitationVerb
        responder.onActivityChanged(.cogitating(verb: verb))

        let (stream, cancel) = servitorProvider.sendStreaming(servitorID: servitorID, message: text)
        cancelStreaming_ = cancel

        var accumulatedText = ""
        var streamingMessageId: UUID?

        do {
            for try await event in stream {
                switch event {
                case .textDelta(let chunk):
                    if !isStreaming {
                        isStreaming = true
                        let msg = ChatMessage(role: .agent, content: "", isStreaming: true)
                        streamingMessageId = msg.id
                        messages.append(msg)
                    }
                    accumulatedText += chunk
                    if let msgId = streamingMessageId,
                       let idx = messages.firstIndex(where: { $0.id == msgId }) {
                        messages[idx] = ChatMessage(
                            id: msgId,
                            role: .agent,
                            content: accumulatedText,
                            isStreaming: true
                        )
                    }

                case .toolUseStarted(let name):
                    currentToolName = name
                    toolStartTime = Date()

                case .toolUseFinished:
                    currentToolName = nil
                    toolStartTime = nil

                case .completed(_, let usage):
                    Self.logger.info("[ChatTile] stream completed")
                    if let usage {
                        totalInputTokens += usage.inputTokens
                        totalOutputTokens += usage.outputTokens
                    }
                    if let msgId = streamingMessageId,
                       let idx = messages.firstIndex(where: { $0.id == msgId }) {
                        messages[idx] = ChatMessage(
                            id: msgId,
                            role: .agent,
                            content: accumulatedText
                        )
                    }

                case .error(let errorMessage):
                    Self.logger.error("[ChatTile] stream error: \(errorMessage)")
                    messages.append(ChatMessage(role: .agent, content: "Error: \(errorMessage)"))
                }
            }
        } catch {
            Self.logger.error("[ChatTile] streaming failed: \(error.localizedDescription)")
            if accumulatedText.isEmpty {
                messages.append(ChatMessage(role: .agent, content: "Error: \(error.localizedDescription)"))
            }
        }

        isCogitating = false
        isStreaming = false
        currentToolName = nil
        toolStartTime = nil
        cancelStreaming_ = nil
        responder.onActivityChanged(.idle)
    }

    func cancelStreaming() {
        Self.logger.info("[ChatTile] cancelStreaming")
        cancelStreaming_?()
        cancelStreaming_ = nil
        isCogitating = false
        isStreaming = false
        currentToolName = nil
        toolStartTime = nil
        responder.onActivityChanged(.idle)
    }

    func clearConversation() {
        Self.logger.info("[ChatTile] clearConversation")
        messages.removeAll()
        totalInputTokens = 0
        totalOutputTokens = 0
        servitorProvider.clearConversation(servitorID: servitorID)
    }

    func startFreshSession() {
        Self.logger.info("[ChatTile] startFreshSession")
        showSessionRecoveryOptions = false
        corruptSessionId = nil
        clearConversation()
    }

    func loadSessionHistory() async {
        Self.logger.info("[ChatTile] loadSessionHistory")
        isLoadingHistory = true
        let history = await servitorProvider.loadHistory(servitorID: servitorID)
        messages = history
        isLoadingHistory = false
        let count = self.messages.count
        Self.logger.info("[ChatTile] loaded \(count) history messages")
    }
}
