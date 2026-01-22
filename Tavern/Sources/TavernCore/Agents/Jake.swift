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

    private let claude: ClaudeCode
    private let queue = DispatchQueue(label: "com.tavern.Jake")

    private var _sessionId: String?
    private var _isCogitating: Bool = false

    /// The current session ID (for conversation continuity)
    public var sessionId: String? {
        queue.sync { _sessionId }
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
        """

    // MARK: - Initialization

    /// Create Jake with a ClaudeCode instance
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - claude: The ClaudeCode SDK instance to use (injectable for testing)
    ///   - loadSavedSession: Whether to load a saved session from SessionStore (default true)
    public init(id: UUID = UUID(), claude: ClaudeCode, loadSavedSession: Bool = true) {
        self.id = id
        self.claude = claude

        // Restore session from previous run
        if loadSavedSession, let savedSession = SessionStore.loadJakeSession() {
            self._sessionId = savedSession
            TavernLogger.agents.info("Jake restored session: \(savedSession)")
        }
    }

    // MARK: - Communication

    /// Send a message to Jake and get a response
    /// - Parameter message: The user's message
    /// - Returns: Jake's response text
    /// - Throws: ClaudeCodeError if communication fails
    public func send(_ message: String) async throws -> String {
        TavernLogger.agents.info("Jake.send called, prompt length: \(message.count)")
        TavernLogger.agents.debug("Jake state: idle -> working")

        queue.sync { _isCogitating = true }
        defer {
            queue.sync { _isCogitating = false }
            TavernLogger.agents.debug("Jake state: working -> idle")
        }

        var options = ClaudeCodeOptions()
        options.systemPrompt = Self.systemPrompt

        let result: ClaudeCodeResult
        let currentSessionId: String? = queue.sync { _sessionId }

        // Using .json format (fixed in local SDK fork)
        // This gives us session ID tracking and full content blocks

        do {
            if let sessionId = currentSessionId {
                // Continue existing conversation
                TavernLogger.claude.info("Jake resuming session: \(sessionId)")
                result = try await claude.resumeConversation(
                    sessionId: sessionId,
                    prompt: message,
                    outputFormat: .json,
                    options: options
                )
            } else {
                // Start new conversation
                TavernLogger.claude.info("Jake starting new conversation")
                result = try await claude.runSinglePrompt(
                    prompt: message,
                    outputFormat: .json,
                    options: options
                )
            }
        } catch {
            TavernLogger.agents.error("Jake.send failed: \(error.localizedDescription)")
            throw error
        }

        // Extract response
        switch result {
        case .json(let resultMessage):
            // Primary path - JSON format gives us session ID and content blocks
            queue.sync { _sessionId = resultMessage.sessionId }

            // Persist session for next app launch
            SessionStore.saveJakeSession(resultMessage.sessionId)

            let response = resultMessage.result ?? ""
            TavernLogger.agents.info("Jake received JSON response, length: \(response.count), sessionId: \(resultMessage.sessionId)")
            return response

        case .text(let text):
            // Fallback - no session ID tracking with text format
            TavernLogger.agents.info("Jake received text response, length: \(text.count)")
            return text

        case .stream:
            // For non-streaming calls, this shouldn't happen
            TavernLogger.agents.debug("Jake received unexpected stream result")
            return ""
        }
    }

    /// Reset Jake's conversation (start fresh)
    public func resetConversation() {
        TavernLogger.agents.info("Jake conversation reset")
        queue.sync { _sessionId = nil }

        // Clear persisted session
        SessionStore.saveJakeSession(nil)
    }
}
