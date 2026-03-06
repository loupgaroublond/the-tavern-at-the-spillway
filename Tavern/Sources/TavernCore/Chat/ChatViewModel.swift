import Foundation
import Observation
import os.log

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004, REQ-ARCH-008, REQ-OPM-001, REQ-OPM-002, REQ-OPM-003, REQ-V1-003

/// View model for managing a chat conversation with an agent
@Observable @MainActor
public final class ChatViewModel {

    // ServitorActivity has moved to TavernKit as a top-level type.

    // MARK: - Published State

    /// All messages in the conversation
    public private(set) var messages: [ChatMessage] = []

    /// The agent's current activity (drives all status indicators)
    public private(set) var servitorActivity: ServitorActivity = .idle

    /// Current input text (bound to text field)
    public var inputText: String = ""

    /// Cumulative input tokens for this session
    public private(set) var totalInputTokens: Int = 0

    /// Cumulative output tokens for this session
    public private(set) var totalOutputTokens: Int = 0

    /// Any error that occurred
    public private(set) var error: Error?

    /// Whether the scroll-to-bottom button should be visible
    public var showScrollToBottom: Bool = false

    /// Whether session history is currently loading from disk
    public private(set) var isLoadingHistory: Bool = false

    /// Whether to show session recovery options (corrupt session detected)
    public private(set) var showSessionRecoveryOptions: Bool = false

    /// The corrupt session ID (if recovery options are shown)
    public private(set) var corruptSessionId: String?

    /// Current tool approval request waiting for user decision (nil when none pending)
    public private(set) var pendingApproval: ToolApprovalRequest?

    /// Current plan approval request waiting for user decision (nil when none pending)
    public private(set) var pendingPlanApproval: PlanApprovalRequest?

    /// The agent's session mode — drives CLI permission behavior.
    /// Changing this updates the agent immediately.
    public var sessionMode: PermissionMode {
        didSet {
            guard sessionMode != oldValue else { return }
            servitor.sessionMode = sessionMode
            TavernLogger.chat.info("[\(self.servitorName)] sessionMode changed: \(oldValue.rawValue) -> \(self.sessionMode.rawValue)")
        }
    }

    // MARK: - Dependencies

    private let servitor: any Servitor
    private let isJake: Bool
    private let projectPath: String?

    /// Cancellation handle for the current streaming response.
    /// Called by `cancelStreaming()` to interrupt mid-stream.
    private var streamCancelHandle: (@Sendable () -> Void)?

    /// Continuation for pending tool approval. Resumed when user responds.
    private var approvalContinuation: CheckedContinuation<ToolApprovalResponse, Never>?

    /// Continuation for pending plan approval. Resumed when user responds.
    private var planApprovalContinuation: CheckedContinuation<PlanApprovalResponse, Never>?

    /// Slash command dispatcher (injected, shared per project)
    public var commandDispatcher: SlashCommandDispatcher?

    /// The agent's ID (for identification)
    public var servitorId: UUID { servitor.id }

    /// The agent's name
    public var servitorName: String { servitor.name }

    // MARK: - Derived Activity Properties

    /// Whether the agent is currently processing (not idle)
    public var isCogitating: Bool { servitorActivity != .idle }

    /// The current cogitation verb (for UI display)
    public var cogitationVerb: String {
        if case .cogitating(let verb) = servitorActivity { return verb }
        return "Cogitating"
    }

    /// Whether the agent is currently streaming a response
    public var isStreaming: Bool {
        switch servitorActivity {
        case .streaming, .toolRunning: return true
        default: return false
        }
    }

    /// Name of the currently executing tool (nil when no tool is active)
    public var currentToolName: String? {
        if case .toolRunning(let name, _) = servitorActivity { return name }
        return nil
    }

    /// When the current tool started executing (nil when no tool is active)
    public var toolStartTime: Date? {
        if case .toolRunning(_, let startTime) = servitorActivity { return startTime }
        return nil
    }

    /// Whether there is any token usage data to display
    public var hasUsageData: Bool { totalInputTokens > 0 || totalOutputTokens > 0 }

    /// Formatted token count string (e.g. "1.2K in / 3.4K out")
    public var formattedTokens: String {
        "\(formatTokenCount(totalInputTokens)) in / \(formatTokenCount(totalOutputTokens)) out"
    }

    // MARK: - Cogitation Verbs

    /// A selection of verbs for the "thinking" indicator
    /// These come from Jake's world - the spillway vocabulary
    private static let cogitationVerbs = [
        "Cogitating",
        "Ruminating",
        "Contemplating",
        "Deliberating",
        "Pondering",
        "Mulling",
        "Musing",
        "Chewing on it",
        "Working the angles",
        "Consulting the Jukebox",
        "Checking with the Slop Squad",
        "Running the numbers",
        "Crunching",
        "Processing",
        "Scheming",
        "Plotting",
        "Calculating",
        "Figuring",
        "Sussing it out",
        "Getting to the bottom of it"
    ]

    // MARK: - Initialization

    /// Create a chat view model for Jake
    /// - Parameter jake: The Jake agent
    /// - Parameter loadHistory: Whether to load session history from disk (default true)
    public init(jake: Jake, loadHistory: Bool = true) {
        self.servitor = jake
        self.isJake = true
        self.projectPath = jake.projectPath
        self.sessionMode = jake.sessionMode

        if loadHistory {
            Task {
                await self.loadSessionHistory()
            }
        }
    }

    /// Create a chat view model for any agent
    /// - Parameters:
    ///   - servitor: The agent to chat with
    ///   - projectPath: The project path (needed for session history restoration)
    ///   - loadHistory: Whether to load session history from disk (default true)
    public init(servitor: some Servitor, projectPath: String? = nil, loadHistory: Bool = true) {
        self.servitor = servitor
        self.isJake = servitor is Jake
        self.projectPath = (servitor as? Jake)?.projectPath ?? projectPath
        self.sessionMode = servitor.sessionMode

        if loadHistory {
            Task {
                await self.loadSessionHistory()
            }
        }
    }

    // MARK: - Session History

    /// Load session history from Claude's native storage
    /// Works for both Jake and servitors.
    /// Parsing and conversion run on a background thread to keep the UI responsive.
    public func loadSessionHistory() async {
        TavernLogger.chat.info("loadSessionHistory called, isJake=\(self.isJake), servitorId=\(self.servitorId)")

        guard let projectPath = projectPath else {
            TavernLogger.chat.info("loadSessionHistory: no project path, skipping")
            return
        }

        isLoadingHistory = true

        let storedMessages: [ClaudeStoredMessage]
        if isJake {
            storedMessages = await SessionStore.loadJakeSessionHistory(projectPath: projectPath, sessionId: servitor.sessionId)
        } else {
            // Get session ID from the servitor (persisted in ProjectDirectory on disk)
            guard let sessionId = servitor.sessionId else {
                TavernLogger.chat.info("loadSessionHistory: no session ID for \(self.servitorName), skipping")
                isLoadingHistory = false
                return
            }
            let storage = ClaudeNativeSessionStorage()
            do {
                storedMessages = try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
            } catch {
                TavernLogger.chat.error("loadSessionHistory: failed to load for \(self.servitorName): \(error.localizedDescription)")
                isLoadingHistory = false
                return
            }
        }
        TavernLogger.chat.info("Got \(storedMessages.count) stored messages for agent \(self.servitorName)")

        guard !storedMessages.isEmpty else {
            isLoadingHistory = false
            return
        }

        // Convert ClaudeStoredMessage to ChatMessage(s) on a background thread.
        // This is CPU-intensive for large sessions — keep it off @MainActor.
        let loadedMessages = await Task.detached(priority: .userInitiated) {
            Self.convertStoredMessages(storedMessages)
        }.value

        TavernLogger.chat.info("Converted \(loadedMessages.count) chat messages for agent \(self.servitorName)")
        self.messages = loadedMessages
        isLoadingHistory = false
    }

    /// Convert stored messages to chat messages. Runs on any thread — pure transformation.
    private nonisolated static func convertStoredMessages(_ storedMessages: [ClaudeStoredMessage]) -> [ChatMessage] {
        var loadedMessages: [ChatMessage] = []

        for stored in storedMessages {
            let role: ChatMessage.Role = stored.role == .user ? .user : .agent

            for block in stored.contentBlocks {
                let chatMessage: ChatMessage
                switch block {
                case .text(let text):
                    guard !text.isEmpty else { continue }
                    chatMessage = ChatMessage(role: role, content: text, messageType: .text)

                case .toolUse(_, let name, let input):
                    chatMessage = ChatMessage(
                        role: .agent,
                        content: input,
                        messageType: .toolUse,
                        toolName: name
                    )

                case .toolResult(_, let content, let isError):
                    guard !content.isEmpty else { continue }
                    chatMessage = ChatMessage(
                        role: role,
                        content: content,
                        messageType: isError ? .toolError : .toolResult,
                        isError: isError
                    )
                }
                loadedMessages.append(chatMessage)
            }
        }

        return loadedMessages
    }

    // MARK: - Actions

    /// Send the current input text as a message.
    /// Uses streaming by default — tokens appear as they arrive.
    public func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        TavernLogger.chat.info("[\(self.servitorName)] sendMessage initiated, text length: \(text.count)")

        // Check for slash command before sending to agent
        let parseResult = SlashCommandParser.parse(text)
        if case .command(let name, let arguments) = parseResult, let dispatcher = commandDispatcher {
            TavernLogger.chat.info("[\(self.servitorName)] detected slash command: /\(name)")
            inputText = ""
            error = nil

            // Show the command as a user message
            let userMessage = ChatMessage(role: .user, content: text)
            messages.append(userMessage)

            let result = await dispatcher.dispatch(name: name, arguments: arguments)
            switch result {
            case .message(let output):
                let responseMessage = ChatMessage(role: .agent, content: output, messageType: .text)
                messages.append(responseMessage)
            case .silent:
                break
            case .error(let errorText):
                let errorMessage = ChatMessage(role: .agent, content: errorText, messageType: .text)
                messages.append(errorMessage)
            }
            return
        }

        // Clear input immediately
        inputText = ""
        error = nil

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        TavernLogger.chat.debug("[\(self.servitorName)] user message added to history, total: \(self.messages.count)")

        // Set cogitating state with random verb
        let verb = Self.cogitationVerbs.randomElement() ?? "Cogitating"
        servitorActivity = .cogitating(verb: verb)
        TavernLogger.chat.info("[\(self.servitorName)] cogitating state set, verb: \(verb)")

        // Yield to let UI update before starting stream
        await Task.yield()

        // Create placeholder message for streaming content
        let placeholderId = UUID()
        let streamingMessage = ChatMessage(
            id: placeholderId,
            role: .agent,
            content: "",
            isStreaming: true
        )
        messages.append(streamingMessage)
        let streamingIndex = messages.count - 1

        // Start streaming
        let (stream, cancel) = servitor.sendStreaming(text)
        streamCancelHandle = cancel
        servitorActivity = .streaming

        TavernLogger.chat.debug("[\(self.servitorName)] streaming started")

        do {
            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    // Append delta to the streaming message in place
                    messages[streamingIndex].content += delta

                case .toolUseStarted(let info):
                    servitorActivity = .toolRunning(name: info.toolName, startTime: Date())
                    TavernLogger.chat.debug("[\(self.servitorName)] tool started: \(info.toolName)")

                case .toolResult:
                    servitorActivity = .streaming

                case .completed(let info):
                    // Mark streaming complete
                    messages[streamingIndex].isStreaming = false
                    if let usage = info.usage {
                        totalInputTokens += usage.inputTokens
                        totalOutputTokens += usage.outputTokens
                        TavernLogger.chat.info("[\(self.servitorName)] usage: +\(usage.inputTokens)in/+\(usage.outputTokens)out (total: \(self.totalInputTokens)in/\(self.totalOutputTokens)out)")
                    }
                    TavernLogger.chat.info("[\(self.servitorName)] streaming completed, total messages: \(self.messages.count)")

                case .error(let errorDescription):
                    TavernLogger.chat.debugError("[\(self.servitorName)] stream error event: \(errorDescription)")

                default:
                    break
                }
            }

            // If the message ended up empty (unusual), remove the placeholder
            if messages[streamingIndex].content.isEmpty {
                messages.remove(at: streamingIndex)
            }

        } catch let error as TavernError {
            self.error = error
            // Remove empty streaming placeholder and add error message
            if messages[streamingIndex].content.isEmpty {
                messages.remove(at: streamingIndex)
            } else {
                messages[streamingIndex].isStreaming = false
            }

            switch error {
            case .sessionCorrupt(let sessionId, _):
                self.corruptSessionId = sessionId
                self.showSessionRecoveryOptions = true
                TavernLogger.chat.debugError("[\(self.servitorName)] session '\(sessionId)' is corrupt")
            case .servitorNameConflict(let name):
                TavernLogger.chat.debugError("[\(self.servitorName)] name conflict: '\(name)'")
            case .commitmentTimeout(let id):
                TavernLogger.chat.debugError("[\(self.servitorName)] commitment timeout: \(id)")
            case .mcpServerFailed(let reason):
                TavernLogger.chat.debugError("[\(self.servitorName)] MCP server failed: \(reason)")
            case .permissionDenied(let tool):
                TavernLogger.chat.debugError("[\(self.servitorName)] permission denied: \(tool)")
            case .commandNotFound(let name):
                TavernLogger.chat.debugError("[\(self.servitorName)] command not found: /\(name)")
            case .internalError(let message):
                TavernLogger.chat.debugError("[\(self.servitorName)] internal error: \(message)")
            }
            let errorContent = TavernErrorMessages.message(for: error)
            let errorMessage = ChatMessage(role: .agent, content: errorContent)
            messages.append(errorMessage)

        } catch {
            self.error = error
            if messages[streamingIndex].content.isEmpty {
                messages.remove(at: streamingIndex)
            } else {
                messages[streamingIndex].isStreaming = false
            }

            TavernLogger.chat.debugError("[\(self.servitorName)] sendMessage streaming failed: \(error.localizedDescription)")
            let errorContent = TavernErrorMessages.message(for: error)
            let errorMessage = ChatMessage(role: .agent, content: errorContent)
            messages.append(errorMessage)
        }

        servitorActivity = .idle
        streamCancelHandle = nil
    }

    /// Cancel the current streaming response.
    /// The partial message is kept in the chat as-is.
    public func cancelStreaming() {
        guard isStreaming else { return }
        TavernLogger.chat.info("[\(self.servitorName)] streaming cancelled by user")

        streamCancelHandle?()
        streamCancelHandle = nil
        servitorActivity = .idle

        // Mark the last message as no longer streaming
        if let lastIndex = messages.indices.last, messages[lastIndex].isStreaming {
            messages[lastIndex].isStreaming = false
        }
    }

    /// Clear the conversation and reset the agent's session
    public func clearConversation() {
        TavernLogger.chat.info("[\(self.servitorName)] conversation cleared, was \(self.messages.count) messages")
        messages.removeAll()
        servitor.resetConversation()
        error = nil
        showSessionRecoveryOptions = false
        corruptSessionId = nil
        totalInputTokens = 0
        totalOutputTokens = 0
    }

    /// Respond to a pending tool approval request.
    /// Resumes the suspended canUseTool callback with the user's decision.
    /// - Parameter response: The user's approval or denial
    public func respondToApproval(_ response: ToolApprovalResponse) {
        TavernLogger.permissions.info("[\(self.servitorName)] tool approval response: approved=\(response.approved), alwaysAllow=\(response.alwaysAllow)")

        guard let continuation = approvalContinuation else {
            TavernLogger.permissions.error("[\(self.servitorName)] respondToApproval called with no pending continuation")
            return
        }

        approvalContinuation = nil
        pendingApproval = nil
        continuation.resume(returning: response)
    }

    /// Create a ToolApprovalHandler that surfaces requests through this view model.
    /// The handler suspends until the user responds via `respondToApproval`.
    public func makeApprovalHandler() -> ToolApprovalHandler {
        // Capture self weakly. The handler runs on arbitrary threads
        // but publishes UI state on MainActor via the continuation bridge.
        return { [weak self] request in
            guard let self else {
                TavernLogger.permissions.error("ChatViewModel deallocated, denying tool '\(request.toolName)'")
                return ToolApprovalResponse(approved: false)
            }

            return await withCheckedContinuation { continuation in
                Task { @MainActor in
                    self.approvalContinuation = continuation
                    self.pendingApproval = request
                    TavernLogger.permissions.info("[\(self.servitorName)] showing approval for tool '\(request.toolName)'")
                }
            }
        }
    }

    /// Respond to a pending plan approval request.
    /// Resumes the suspended ExitPlanMode callback with the user's decision.
    /// On approval, switches the agent out of plan mode.
    /// - Parameter response: The user's approval or rejection
    public func respondToPlanApproval(_ response: PlanApprovalResponse) {
        TavernLogger.permissions.info("[\(self.servitorName)] plan approval response: approved=\(response.approved)")

        guard let continuation = planApprovalContinuation else {
            TavernLogger.permissions.error("[\(self.servitorName)] respondToPlanApproval called with no pending continuation")
            return
        }

        planApprovalContinuation = nil
        pendingPlanApproval = nil

        if response.approved {
            // Switch agent out of plan mode on approval
            sessionMode = .normal
        }

        continuation.resume(returning: response)
    }

    /// Create a PlanApprovalHandler that surfaces requests through this view model.
    /// The handler suspends until the user responds via `respondToPlanApproval`.
    public func makePlanApprovalHandler() -> PlanApprovalHandler {
        return { [weak self] request in
            guard let self else {
                TavernLogger.permissions.error("ChatViewModel deallocated, rejecting plan")
                return PlanApprovalResponse(approved: false, feedback: "View model no longer available")
            }

            return await withCheckedContinuation { continuation in
                Task { @MainActor in
                    self.planApprovalContinuation = continuation
                    self.pendingPlanApproval = request
                    TavernLogger.permissions.info("[\(self.servitorName)] showing plan approval")
                }
            }
        }
    }

    /// Start fresh after a corrupt session
    /// Clears the old session and removes the recovery UI
    public func startFreshSession() {
        TavernLogger.chat.info("[\(self.servitorName)] starting fresh session (was corrupt: \(self.corruptSessionId ?? "none"))")
        servitor.resetConversation()
        error = nil
        showSessionRecoveryOptions = false
        corruptSessionId = nil
        // Keep messages so user can see what they tried to send
    }

    // MARK: - Private Helpers

    /// Format token count for display (e.g. 1234 -> "1.2K", 999 -> "999")
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
