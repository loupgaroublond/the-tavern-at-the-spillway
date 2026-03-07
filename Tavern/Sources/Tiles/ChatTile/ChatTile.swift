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

    private(set) var totalInputTokens: Int = 0
    private(set) var totalOutputTokens: Int = 0

    // MARK: - Cost Tracking

    var totalCostUsd: Double = 0

    // MARK: - Prompt Suggestions

    var promptSuggestions: [String] = []

    // MARK: - Rate Limit

    var rateLimitStatus: RateLimitInfo?

    // MARK: - System Status

    var systemStatus: String?

    // MARK: - Streaming Cancellation

    private var cancelStreaming_: (@Sendable () -> Void)?

    // MARK: - Active Block Tracking

    private var activeThinkingMessageId: UUID?
    private var activeTextMessageId: UUID?
    private var accumulatedThinking: String = ""
    private var accumulatedText: String = ""
    private var activeToolUses: [String: ToolUseInfo] = [:]  // toolUseId → info
    private var toolUseMessageIds: [String: UUID] = [:]       // toolUseId → ChatMessage.id

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
        totalInputTokens > 0 || totalOutputTokens > 0 || totalCostUsd > 0
    }

    var formattedTokens: String {
        var parts: [String] = []
        if totalInputTokens > 0 || totalOutputTokens > 0 {
            parts.append("\(totalInputTokens)↑ \(totalOutputTokens)↓")
        }
        if totalCostUsd > 0 {
            parts.append(String(format: "$%.2f", totalCostUsd))
        }
        return parts.joined(separator: " · ")
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

        // Try slash command dispatch first
        if let commandResult = await commandProvider.dispatchInput(text) {
            Self.logger.info("[ChatTile] handled as slash command")
            switch commandResult {
            case .message(let output):
                messages.append(ChatMessage(role: .agent, content: output))
            case .error(let error):
                messages.append(ChatMessage(role: .agent, content: "Error: \(error)"))
            case .silent:
                break
            }
            return
        }

        isCogitating = true
        isStreaming = false
        currentToolName = nil
        toolStartTime = nil
        promptSuggestions = []
        rateLimitStatus = nil
        systemStatus = nil
        let verb = self.cogitationVerb
        responder.onActivityChanged(.cogitating(verb: verb))

        let (stream, cancel) = servitorProvider.sendStreaming(servitorID: servitorID, message: text)
        cancelStreaming_ = cancel

        var errorEventReceived = false

        do {
            for try await event in stream {
                switch event {

                // ── Thinking ──
                case .thinkingDelta(let chunk):
                    if activeThinkingMessageId == nil {
                        finalizeTextBlock()
                        let msg = ChatMessage(role: .agent, content: "", messageType: .thinking, isStreaming: true)
                        activeThinkingMessageId = msg.id
                        messages.append(msg)
                    }
                    accumulatedThinking += chunk
                    updateMessageContent(id: activeThinkingMessageId!, content: accumulatedThinking, isStreaming: true)

                // ── Text ──
                case .textDelta(let chunk):
                    if activeTextMessageId == nil {
                        finalizeThinkingBlock()
                        if !isStreaming {
                            isStreaming = true
                        }
                        let msg = ChatMessage(role: .agent, content: "", isStreaming: true)
                        activeTextMessageId = msg.id
                        messages.append(msg)
                    }
                    accumulatedText += chunk
                    updateMessageContent(id: activeTextMessageId!, content: accumulatedText, isStreaming: true)

                // ── Tool use started ──
                case .toolUseStarted(let info):
                    finalizeThinkingBlock()
                    finalizeTextBlock()
                    activeToolUses[info.toolUseId] = info
                    currentToolName = info.toolName
                    toolStartTime = Date()
                    let msg = ChatMessage(
                        role: .agent, content: "", messageType: .toolUse,
                        toolName: info.toolName, isStreaming: true,
                        toolUseId: info.toolUseId
                    )
                    toolUseMessageIds[info.toolUseId] = msg.id
                    messages.append(msg)

                // ── Tool input delta ──
                case .toolInputDelta(let toolUseId, let json):
                    if let msgId = toolUseMessageIds[toolUseId],
                       let idx = messages.firstIndex(where: { $0.id == msgId }) {
                        messages[idx].content += json
                    }

                // ── Tool result ──
                case .toolResult(let info):
                    if let msgId = toolUseMessageIds[info.toolUseId] {
                        finalizeMessage(id: msgId)
                    }
                    let resultMsg = ChatMessage(
                        role: .agent,
                        content: info.content,
                        messageType: info.isError ? .toolError : .toolResult,
                        isError: info.isError,
                        toolUseId: info.toolUseId
                    )
                    messages.append(resultMsg)
                    activeToolUses.removeValue(forKey: info.toolUseId)
                    if activeToolUses.isEmpty {
                        currentToolName = nil
                        toolStartTime = nil
                    }

                // ── Block finished ──
                case .blockFinished:
                    break

                // ── Tool progress ──
                case .toolProgress(let info):
                    currentToolName = info.toolName

                // ── System status ──
                case .systemStatus(let status):
                    systemStatus = status

                // ── Prompt suggestion ──
                case .promptSuggestion(let suggestion):
                    promptSuggestions.append(suggestion)

                // ── Session break ──
                case .sessionBreak(let staleSessionId):
                    Self.logger.warning("[ChatTile] session break — '\(staleSessionId)' expired")
                    finalizeThinkingBlock()
                    finalizeTextBlock()
                    messages.append(.sessionBreak(staleSessionId: staleSessionId))

                // ── Rate limit ──
                case .rateLimitWarning(let info):
                    rateLimitStatus = info
                    // Invariant #7: failures visible
                    if info.status != "ok" {
                        messages.append(ChatMessage(
                            role: .agent,
                            content: "Rate limit warning: \(info.status)" +
                                (info.utilization.map { " (\(Int($0 * 100))% utilized)" } ?? "")
                        ))
                    }

                // ── Notification ──
                case .notification(let info):
                    Self.logger.info("[ChatTile] notification: level=\(info.level.rawValue), title=\(info.title ?? "(none)"), message=\(info.message)")
                    let prefix = info.title.map { "[\($0)] " } ?? ""
                    messages.append(ChatMessage(
                        role: .system,
                        content: "\(prefix)\(info.message)",
                        messageType: .notification
                    ))

                // ── Completion ──
                case .completed(let info):
                    Self.logger.info("[ChatTile] stream completed")
                    finalizeThinkingBlock()
                    finalizeTextBlock()
                    if let usage = info.usage {
                        totalInputTokens += usage.inputTokens
                        totalOutputTokens += usage.outputTokens
                    }
                    if let cost = info.totalCostUsd {
                        totalCostUsd = cost
                    }
                    systemStatus = nil

                // ── Error ──
                case .error(let errorMessage):
                    Self.logger.error("[ChatTile] stream error: \(errorMessage)")
                    messages.append(ChatMessage(role: .agent, content: "Error: \(errorMessage)"))
                    errorEventReceived = true
                }
            }
        } catch {
            Self.logger.error("[ChatTile] streaming failed: \(error.localizedDescription)")
            if !errorEventReceived && accumulatedText.isEmpty {
                messages.append(ChatMessage(role: .agent, content: "Error: \(error.localizedDescription)"))
            }
        }

        // Reset all streaming state
        activeThinkingMessageId = nil
        activeTextMessageId = nil
        accumulatedThinking = ""
        accumulatedText = ""
        activeToolUses.removeAll()
        toolUseMessageIds.removeAll()
        isCogitating = false
        isStreaming = false
        currentToolName = nil
        toolStartTime = nil
        cancelStreaming_ = nil
        rateLimitStatus = nil
        systemStatus = nil
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
        totalCostUsd = 0
        promptSuggestions = []
        rateLimitStatus = nil
        systemStatus = nil
        servitorProvider.clearConversation(servitorID: servitorID)
    }

    func startFreshSession() {
        Self.logger.info("[ChatTile] startFreshSession")
        showSessionRecoveryOptions = false
        corruptSessionId = nil
        clearConversation()
    }

    public func loadSessionHistory() async {
        // Only load from disk on first appearance — don't overwrite in-memory messages
        guard messages.isEmpty else {
            Self.logger.info("[ChatTile] loadSessionHistory skipped — \(self.messages.count) messages already in memory")
            return
        }
        Self.logger.info("[ChatTile] loadSessionHistory")
        isLoadingHistory = true
        let history = await servitorProvider.loadHistory(servitorID: servitorID)
        messages = history
        isLoadingHistory = false
        let count = self.messages.count
        Self.logger.info("[ChatTile] loaded \(count) history messages")
    }

    // MARK: - Private Block Finalization

    private func finalizeThinkingBlock() {
        guard let id = activeThinkingMessageId else { return }
        updateMessageContent(id: id, content: accumulatedThinking, isStreaming: false)
        activeThinkingMessageId = nil
        accumulatedThinking = ""
    }

    private func finalizeTextBlock() {
        guard let id = activeTextMessageId else { return }
        updateMessageContent(id: id, content: accumulatedText, isStreaming: false)
        activeTextMessageId = nil
        accumulatedText = ""
    }

    private func finalizeMessage(id: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isStreaming = false
        }
    }

    private func updateMessageContent(id: UUID, content: String, isStreaming: Bool) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].content = content
            messages[idx].isStreaming = isStreaming
        }
    }
}
