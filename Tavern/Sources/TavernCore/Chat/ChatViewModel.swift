import Foundation
import Combine
import os.log

/// View model for managing a chat conversation with an agent
@MainActor
public final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    /// All messages in the conversation
    @Published public private(set) var messages: [ChatMessage] = []

    /// Whether the agent is currently processing
    @Published public private(set) var isCogitating: Bool = false

    /// Current input text (bound to text field)
    @Published public var inputText: String = ""

    /// The current cogitation verb (for UI display)
    @Published public private(set) var cogitationVerb: String = "Cogitating"

    /// Any error that occurred
    @Published public private(set) var error: Error?

    /// Whether to show session recovery options (corrupt session detected)
    @Published public private(set) var showSessionRecoveryOptions: Bool = false

    /// The corrupt session ID (if recovery options are shown)
    @Published public private(set) var corruptSessionId: String?

    // MARK: - Dependencies

    private let agent: AnyAgent
    private let isJake: Bool
    private let projectPath: String?

    /// Slash command dispatcher (injected, shared per project)
    public var commandDispatcher: SlashCommandDispatcher?

    /// The agent's ID (for identification)
    public var agentId: UUID { agent.id }

    /// The agent's name
    public var agentName: String { agent.name }

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
    /// Works for both Jake and servitors
    public func loadSessionHistory() async {
        TavernLogger.chat.info("loadSessionHistory called, isJake=\(self.isJake), agentId=\(self.agentId)")

        guard let projectPath = projectPath else {
            TavernLogger.chat.info("loadSessionHistory: no project path, skipping")
            return
        }

        let storedMessages: [ClaudeStoredMessage]
        if isJake {
            storedMessages = await SessionStore.loadJakeSessionHistory(projectPath: projectPath)
        } else {
            storedMessages = await SessionStore.loadAgentSessionHistory(agentId: agentId, projectPath: projectPath)
        }
        TavernLogger.chat.info("Got \(storedMessages.count) stored messages for agent \(self.agentName)")

        guard !storedMessages.isEmpty else { return }

        // Debug logging
        let debugPath = "/tmp/tavern_chat_debug.log"
        func debugLog(_ msg: String) {
            let line = "\(msg)\n"
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: debugPath) {
                    if let handle = FileHandle(forWritingAtPath: debugPath) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    FileManager.default.createFile(atPath: debugPath, contents: data)
                }
            }
        }
        try? FileManager.default.removeItem(atPath: debugPath)
        debugLog("Loading \(storedMessages.count) stored messages")

        // Convert ClaudeStoredMessage to ChatMessage(s)
        // Each content block becomes a separate ChatMessage
        var loadedMessages: [ChatMessage] = []

        for (i, stored) in storedMessages.enumerated() {
            let role: ChatMessage.Role = stored.role == .user ? .user : .agent
            debugLog("Message \(i): role=\(stored.role), blocks=\(stored.contentBlocks.count), content=\"\(stored.content.prefix(30))...\"")

            for (j, block) in stored.contentBlocks.enumerated() {
                debugLog("  Block \(j): \(block)")
                let chatMessage: ChatMessage
                switch block {
                case .text(let text):
                    guard !text.isEmpty else {
                        debugLog("  -> Skipping empty text")
                        continue
                    }
                    chatMessage = ChatMessage(role: role, content: text, messageType: .text)

                case .toolUse(_, let name, let input):
                    chatMessage = ChatMessage(
                        role: .agent,
                        content: input,
                        messageType: .toolUse,
                        toolName: name
                    )

                case .toolResult(_, let content, let isError):
                    guard !content.isEmpty else {
                        debugLog("  -> Skipping empty tool result")
                        continue
                    }
                    chatMessage = ChatMessage(
                        role: role,
                        content: content,
                        messageType: isError ? .toolError : .toolResult,
                        isError: isError
                    )
                }
                loadedMessages.append(chatMessage)
                debugLog("  -> Created ChatMessage: \(chatMessage.messageType)")
            }
        }

        debugLog("Created \(loadedMessages.count) chat messages")
        self.messages = loadedMessages
    }

    // MARK: - Actions

    /// Send the current input text as a message
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
        isCogitating = true
        cogitationVerb = Self.cogitationVerbs.randomElement() ?? "Cogitating"
        TavernLogger.chat.info("[\(self.agentName)] cogitating state set, verb: \(self.cogitationVerb)")

        // Yield to let UI update before potentially blocking call
        await Task.yield()

        do {
            // Get response from agent
            let response = try await agent.send(text)

            // Add agent message
            let agentMessage = ChatMessage(role: .agent, content: response)
            messages.append(agentMessage)
            TavernLogger.chat.info("[\(self.agentName)] agent response received and added, total messages: \(self.messages.count)")

        } catch let error as TavernError {
            self.error = error
            switch error {
            case .sessionCorrupt(let sessionId, _):
                // Set special state for corrupt session UI
                self.corruptSessionId = sessionId
                self.showSessionRecoveryOptions = true
                TavernLogger.chat.debugError("[\(self.agentName)] session '\(sessionId)' is corrupt")
            case .internalError(let message):
                TavernLogger.chat.debugError("[\(self.agentName)] internal error: \(message)")
            }
            // Add informative error message to chat
            let errorContent = TavernErrorMessages.message(for: error)
            let errorMessage = ChatMessage(
                role: .agent,
                content: errorContent
            )
            messages.append(errorMessage)
        } catch {
            self.error = error
            TavernLogger.chat.debugError("[\(self.agentName)] sendMessage failed: \(error.localizedDescription)")
            // Add informative error message to chat
            let errorContent = TavernErrorMessages.message(for: error)
            let errorMessage = ChatMessage(
                role: .agent,
                content: errorContent
            )
            messages.append(errorMessage)
        }

        isCogitating = false
    }

    /// Clear the conversation and reset the agent's session
    public func clearConversation() {
        TavernLogger.chat.info("[\(self.agentName)] conversation cleared, was \(self.messages.count) messages")
        messages.removeAll()
        agent.resetConversation()
        error = nil
        showSessionRecoveryOptions = false
        corruptSessionId = nil
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

}
