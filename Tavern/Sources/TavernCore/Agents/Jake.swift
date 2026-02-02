import Foundation
import ClaudeCodeSDK
import os.log

/// Jake - The Proprietor of the Tavern
/// The top-level coordinating agent with the voice of a used car salesman
/// and the execution of a surgical team.
public final class Jake: Agent, @unchecked Sendable {

    // MARK: - Agent Protocol

    public let id: UUID
    public let name: String = "Jake"

    /// Jake's state (mapped to AgentState for protocol conformance)
    public var state: AgentState {
        queue.sync { _isCogitating ? .working : .idle }
    }

    // MARK: - Properties

    private let projectURL: URL
    private let queue = DispatchQueue(label: "com.tavern.Jake")

    private var _sessionId: String?
    private var _isCogitating: Bool = false
    private var _toolHandler: JakeToolHandler?

    /// Tool handler for processing Jake's actions (spawn, etc.)
    /// Injected after init to break circular dependency with spawner
    public var toolHandler: JakeToolHandler? {
        get { queue.sync { _toolHandler } }
        set { queue.sync { _toolHandler = newValue } }
    }

    /// The current session ID (for conversation continuity)
    public var sessionId: String? {
        queue.sync { _sessionId }
    }

    /// The project path where sessions are stored
    public var projectPath: String {
        projectURL.path
    }

    /// Whether Jake is currently cogitating (working)
    public var isCogitating: Bool {
        queue.sync { _isCogitating }
    }

    /// Jake's system prompt - establishes his character
    public static let systemPrompt = """
        You are Jake, The Proprietor of The Tavern at the Spillway.

        VOICE: Used car salesman energy with carnival barker theatrics. You're sketchy \
        in that classic salesman way - overly enthusiastic, self-aware about the hustle, \
        and weirdly honest at the worst possible moments.

        STYLE:
        - CAPITALS for EMPHASIS on things you're EXCITED about
        - Parenthetical asides (like this one) for corrections and tangents
        - Wild claims that are obviously false, delivered with total conviction
        - Reveal critical flaws AFTER hyping everything up
        - Meme-savvy humor worked in naturally
        - Direct address - talk TO the user, not at them

        EXECUTION: Despite the patter, your actual work is flawless. Methodical. \
        Every edge case handled. Every race condition considered. The voice is \
        the costume. The work is the substance.

        You run a multi-agent orchestration system. Your worker agents are "the Slop Squad." \
        Parallel execution is "Multi-Slop Madness." Background processes are "the Jukebox."

        The spillway is always flowing, always overflowing with something different. \
        Be FRESH and SPONTANEOUS every time - different jokes, different angles.

        Remember: Perfect execution. Lingering unease. That's the Tavern experience.

        RESPONSE FORMAT:
        Always respond with valid JSON in this format:
        {"message": "your response to the user"}

        ACTIONS:
        When you need to delegate work to an agent, include a spawn action:
        {"message": "your response", "spawn": {"assignment": "task description", "name": "optional name"}}

        The "name" field is optional - omit it to auto-generate a themed name.
        Only spawn ONE agent per response. If multiple agents are needed, spawn them in sequence.
        After spawning, you'll receive confirmation and can continue the conversation.

        AGENT ORCHESTRATION MODEL:
        You operate a two-level agent system:

        Level 1 - Tavern Agents (via spawn action):
        - Full Claude Code sessions with their own context
        - Appear in sidebar, persist across sessions
        - For substantial, independent work streams
        - Use your JSON spawn action to create these

        Level 2 - Subagents (via Task tool):
        - Internal parallel workers within any agent's session
        - Lightweight, ephemeral, don't persist
        - For quick parallel tasks within a single work stream
        - Any agent (including you) can spawn these directly via Task tool

        When to use which:
        - Spawn Tavern agent: "Help me build feature X" (substantial, tracked work)
        - Use Task tool: "Search these 5 files in parallel" (quick, internal parallelism)

        You have full access to the Task tool for your own subagents. The spawn action is \
        specifically for creating new Tavern agents that the user can interact with directly.
        """

    // MARK: - Initialization

    /// Create Jake with a project URL
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - projectURL: The project directory URL
    ///   - loadSavedSession: Whether to load a saved session from SessionStore (default true)
    public init(id: UUID = UUID(), projectURL: URL, loadSavedSession: Bool = true) {
        self.id = id
        self.projectURL = projectURL

        // Restore session from previous run (per-project)
        if loadSavedSession, let savedSession = SessionStore.loadJakeSession(projectPath: projectURL.path) {
            self._sessionId = savedSession
            TavernLogger.agents.info("Jake restored session: \(savedSession) for project: \(projectURL.path)")
        }
    }

    // MARK: - Communication

    /// Send a message to Jake and get a response
    /// - Parameter message: The user's message
    /// - Returns: Jake's response text
    /// - Throws: QueryError if communication fails
    public func send(_ message: String) async throws -> String {
        TavernLogger.agents.info("Jake.send called, prompt length: \(message.count)")
        TavernLogger.agents.debug("Jake state: idle -> working")

        queue.sync { _isCogitating = true }
        defer {
            queue.sync { _isCogitating = false }
            TavernLogger.agents.debug("Jake state: working -> idle")
        }

        let currentSessionId: String? = queue.sync { _sessionId }

        // Build query options
        var options = QueryOptions()
        options.systemPrompt = Self.systemPrompt
        options.workingDirectory = projectURL
        if let sessionId = currentSessionId {
            options.resume = sessionId
            TavernLogger.claude.info("Jake resuming session: \(sessionId)")
        } else {
            TavernLogger.claude.info("Jake starting new conversation")
        }

        // Run query and collect response
        let rawResponse: String
        do {
            let query = try await ClaudeCode.query(prompt: message, options: options)
            rawResponse = try await collectResponse(from: query)
        } catch {
            // If resuming failed with a session ID, it's likely corrupt/stale
            if let sessionId = currentSessionId {
                TavernLogger.agents.debugError("Session '\(sessionId)' appears corrupt: \(error.localizedDescription)")
                throw TavernError.sessionCorrupt(sessionId: sessionId, underlyingError: error)
            }
            TavernLogger.agents.debugError("Jake.send failed: \(error.localizedDescription)")
            throw error
        }

        // Process through tool handler if available
        guard let handler = queue.sync(execute: { _toolHandler }) else {
            return rawResponse
        }

        // Tool execution loop: process response, execute actions, continue if needed
        var toolResult = try await handler.processResponse(rawResponse)

        while let feedback = toolResult.toolFeedback {
            TavernLogger.agents.info("Jake tool feedback: \(feedback)")

            // Send feedback to Jake and get continuation
            let continuationResponse = try await sendContinuation(feedback)

            // Process the continuation for more actions
            toolResult = try await handler.processResponse(continuationResponse)
        }

        return toolResult.displayMessage
    }

    // MARK: - Private Helpers

    /// Collect the response from a ClaudeQuery stream
    private func collectResponse(from query: ClaudeQuery) async throws -> String {
        var responseText: String = ""

        for try await message in query {
            switch message {
            case .regular(let sdkMessage):
                // Look for result message with the final response
                if sdkMessage.type == "result" {
                    // The result content is typically a string
                    if let content = sdkMessage.content?.stringValue {
                        responseText = content
                    }
                }
            case .controlRequest, .controlResponse, .controlCancelRequest, .keepAlive:
                // Control messages handled internally by SDK
                break
            }
        }

        // Get session ID from the query
        if let newSessionId = await query.sessionId {
            queue.sync { _sessionId = newSessionId }
            SessionStore.saveJakeSession(newSessionId, projectPath: projectURL.path)
            TavernLogger.agents.info("Jake received response, length: \(responseText.count), sessionId: \(newSessionId)")
        } else {
            TavernLogger.agents.info("Jake received response, length: \(responseText.count), no sessionId")
        }

        return responseText
    }

    /// Send a continuation message to Jake (used for tool feedback)
    private func sendContinuation(_ message: String) async throws -> String {
        guard let sessionId = queue.sync(execute: { _sessionId }) else {
            TavernLogger.agents.error("Jake.sendContinuation called without session ID")
            throw TavernError.sessionCorrupt(sessionId: "nil", underlyingError: nil)
        }

        TavernLogger.claude.info("Jake sending continuation to session: \(sessionId)")

        var options = QueryOptions()
        options.systemPrompt = Self.systemPrompt
        options.workingDirectory = projectURL
        options.resume = sessionId

        let query = try await ClaudeCode.query(prompt: message, options: options)
        return try await collectResponse(from: query)
    }

    /// Reset Jake's conversation (start fresh)
    public func resetConversation() {
        TavernLogger.agents.info("Jake conversation reset")
        queue.sync { _sessionId = nil }

        // Clear persisted session for this project
        SessionStore.clearJakeSession(projectPath: projectURL.path)
    }
}
