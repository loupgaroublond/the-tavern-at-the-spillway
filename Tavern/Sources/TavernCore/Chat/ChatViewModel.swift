import Foundation
import Combine
import os.log

/// View model for managing a chat conversation with an agent
@MainActor
public final class ChatViewModel: ObservableObject {

    // MARK: - Agent Activity

    /// The agent's current activity state — single source of truth for UI indicators.
    /// Eliminates impossible state combinations (e.g. cogitating + tool running).
    public enum AgentActivity: Equatable {
        case idle
        case cogitating(verb: String)
        case streaming
        case toolRunning(name: String, startTime: Date)
    }

    // MARK: - Published State

    /// All messages in the conversation
    @Published public private(set) var messages: [ChatMessage] = []

    /// The agent's current activity (drives all status indicators)
    @Published public private(set) var agentActivity: AgentActivity = .idle

    /// Current input text (bound to text field)
    @Published public var inputText: String = ""

    /// Cumulative input tokens for this session
    @Published public private(set) var totalInputTokens: Int = 0

    /// Cumulative output tokens for this session
    @Published public private(set) var totalOutputTokens: Int = 0

    /// Any error that occurred
    @Published public private(set) var error: Error?

    /// Whether the scroll-to-bottom button should be visible
    @Published public var showScrollToBottom: Bool = false

    /// Whether session history is currently loading from disk
    @Published public private(set) var isLoadingHistory: Bool = false

    /// Whether to show session recovery options (corrupt session detected)
    @Published public private(set) var showSessionRecoveryOptions: Bool = false

    /// The corrupt session ID (if recovery options are shown)
    @Published public private(set) var corruptSessionId: String?

    // MARK: - Dependencies

    private let agent: AnyAgent
    private let isJake: Bool
    private let projectPath: String?

    /// Cancellation handle for the current streaming response.
    /// Called by `cancelStreaming()` to interrupt mid-stream.
    private var streamCancelHandle: (@Sendable () -> Void)?

    /// Slash command dispatcher (injected, shared per project)
    public var commandDispatcher: SlashCommandDispatcher?

    /// The agent's ID (for identification)
    public var agentId: UUID { agent.id }

    /// The agent's name
    public var agentName: String { agent.name }

    // MARK: - Derived Activity Properties

    /// Whether the agent is currently processing (not idle)
    public var isCogitating: Bool { agentActivity != .idle }

    /// The current cogitation verb (for UI display)
    public var cogitationVerb: String {
        if case .cogitating(let verb) = agentActivity { return verb }
        return "Cogitating"
    }

    /// Whether the agent is currently streaming a response
    public var isStreaming: Bool {
        switch agentActivity {
        case .streaming, .toolRunning: return true
        default: return false
        }
    }

    /// Name of the currently executing tool (nil when no tool is active)
    public var currentToolName: String? {
        if case .toolRunning(let name, _) = agentActivity { return name }
        return nil
    }

    /// When the current tool started executing (nil when no tool is active)
    public var toolStartTime: Date? {
        if case .toolRunning(_, let startTime) = agentActivity { return startTime }
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
        self.agent = AnyAgent(jake)
        self.isJake = true
        self.projectPath = jake.projectPath

        if loadHistory {
            Task {
                await self.loadSessionHistory()
            }
        }
    }

    /// Create a chat view model for any agent
    /// - Parameters:
    ///   - agent: The agent to chat with
    ///   - projectPath: The project path (needed for session history restoration)
    ///   - loadHistory: Whether to load session history from disk (default true)
    public init(agent: some Agent, projectPath: String? = nil, loadHistory: Bool = true) {
        self.agent = AnyAgent(agent)
        self.isJake = agent is Jake
        self.projectPath = (agent as? Jake)?.projectPath ?? projectPath

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
        TavernLogger.chat.info("loadSessionHistory called, isJake=\(self.isJake), agentId=\(self.agentId)")

        guard let projectPath = projectPath else {
            TavernLogger.chat.info("loadSessionHistory: no project path, skipping")
            return
        }

        isLoadingHistory = true

        let storedMessages: [ClaudeStoredMessage]
        if isJake {
            storedMessages = await SessionStore.loadJakeSessionHistory(projectPath: projectPath)
        } else {
            storedMessages = await SessionStore.loadAgentSessionHistory(agentId: agentId, projectPath: projectPath)
        }
        TavernLogger.chat.info("Got \(storedMessages.count) stored messages for agent \(self.agentName)")

        guard !storedMessages.isEmpty else {
            isLoadingHistory = false
            return
        }

        // Convert ClaudeStoredMessage to ChatMessage(s) on a background thread.
        // This is CPU-intensive for large sessions — keep it off @MainActor.
        let loadedMessages = await Task.detached(priority: .userInitiated) {
            Self.convertStoredMessages(storedMessages)
        }.value

        TavernLogger.chat.info("Converted \(loadedMessages.count) chat messages for agent \(self.agentName)")
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

        TavernLogger.chat.info("[\(self.agentName)] sendMessage initiated, text length: \(text.count)")

        // Check for slash command before sending to agent
        let parseResult = SlashCommandParser.parse(text)
        if case .command(let name, let arguments) = parseResult, let dispatcher = commandDispatcher {
            TavernLogger.chat.info("[\(self.agentName)] detected slash command: /\(name)")
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
        TavernLogger.chat.debug("[\(self.agentName)] user message added to history, total: \(self.messages.count)")

        // Set cogitating state with random verb
        let verb = Self.cogitationVerbs.randomElement() ?? "Cogitating"
        agentActivity = .cogitating(verb: verb)
        TavernLogger.chat.info("[\(self.agentName)] cogitating state set, verb: \(verb)")

        // Yield to let UI update before starting stream
        await Task.yield()

        // Create placeholder message for streaming content
        let placeholderId = UUID()
        var streamingMessage = ChatMessage(
            id: placeholderId,
            role: .agent,
            content: "",
            isStreaming: true
        )
        messages.append(streamingMessage)
        let streamingIndex = messages.count - 1

        // Start streaming
        let (stream, cancel) = agent.sendStreaming(text)
        streamCancelHandle = cancel
        agentActivity = .streaming

        TavernLogger.chat.debug("[\(self.agentName)] streaming started")

        do {
            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    // Append delta to the streaming message in place
                    messages[streamingIndex].content += delta

                case .toolUseStarted(let toolName):
                    agentActivity = .toolRunning(name: toolName, startTime: Date())
                    TavernLogger.chat.debug("[\(self.agentName)] tool started: \(toolName)")

                case .toolUseFinished(let toolName):
                    TavernLogger.chat.debug("[\(self.agentName)] tool finished: \(toolName)")
                    agentActivity = .streaming

                case .completed(_, let usage):
                    // Mark streaming complete
                    messages[streamingIndex].isStreaming = false
                    if let usage {
                        totalInputTokens += usage.inputTokens
                        totalOutputTokens += usage.outputTokens
                        TavernLogger.chat.info("[\(self.agentName)] usage: +\(usage.inputTokens)in/+\(usage.outputTokens)out (total: \(self.totalInputTokens)in/\(self.totalOutputTokens)out)")
                    }
                    TavernLogger.chat.info("[\(self.agentName)] streaming completed, total messages: \(self.messages.count)")

                case .error(let errorDescription):
                    TavernLogger.chat.debugError("[\(self.agentName)] stream error event: \(errorDescription)")
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
                TavernLogger.chat.debugError("[\(self.agentName)] session '\(sessionId)' is corrupt")
            case .agentNameConflict(let name):
                TavernLogger.chat.debugError("[\(self.agentName)] name conflict: '\(name)'")
            case .commitmentTimeout(let id):
                TavernLogger.chat.debugError("[\(self.agentName)] commitment timeout: \(id)")
            case .mcpServerFailed(let reason):
                TavernLogger.chat.debugError("[\(self.agentName)] MCP server failed: \(reason)")
            case .permissionDenied(let tool):
                TavernLogger.chat.debugError("[\(self.agentName)] permission denied: \(tool)")
            case .commandNotFound(let name):
                TavernLogger.chat.debugError("[\(self.agentName)] command not found: /\(name)")
            case .internalError(let message):
                TavernLogger.chat.debugError("[\(self.agentName)] internal error: \(message)")
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

            TavernLogger.chat.debugError("[\(self.agentName)] sendMessage streaming failed: \(error.localizedDescription)")
            let errorContent = TavernErrorMessages.message(for: error)
            let errorMessage = ChatMessage(role: .agent, content: errorContent)
            messages.append(errorMessage)
        }

        agentActivity = .idle
        streamCancelHandle = nil
    }

    /// Cancel the current streaming response.
    /// The partial message is kept in the chat as-is.
    public func cancelStreaming() {
        guard isStreaming else { return }
        TavernLogger.chat.info("[\(self.agentName)] streaming cancelled by user")

        streamCancelHandle?()
        streamCancelHandle = nil
        agentActivity = .idle

        // Mark the last message as no longer streaming
        if let lastIndex = messages.indices.last, messages[lastIndex].isStreaming {
            messages[lastIndex].isStreaming = false
        }
    }

    /// Clear the conversation and reset the agent's session
    public func clearConversation() {
        TavernLogger.chat.info("[\(self.agentName)] conversation cleared, was \(self.messages.count) messages")
        messages.removeAll()
        agent.resetConversation()
        error = nil
        showSessionRecoveryOptions = false
        corruptSessionId = nil
        totalInputTokens = 0
        totalOutputTokens = 0
    }

    /// Start fresh after a corrupt session
    /// Clears the old session and removes the recovery UI
    public func startFreshSession() {
        TavernLogger.chat.info("[\(self.agentName)] starting fresh session (was corrupt: \(self.corruptSessionId ?? "none"))")
        agent.resetConversation()
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
