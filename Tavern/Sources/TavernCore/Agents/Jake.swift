import Foundation
import ClaudeCodeSDK

/// Jake - The Proprietor of the Tavern
/// The top-level coordinating agent with the voice of a used car salesman
/// and the execution of a surgical team.
public final class Jake: @unchecked Sendable {

    // MARK: - Types

    /// Jake's current state
    public enum State: Equatable, Sendable {
        case idle
        case cogitating
    }

    // MARK: - Properties

    private let claude: ClaudeCode
    private let queue = DispatchQueue(label: "com.tavern.Jake")

    private var _sessionId: String?
    private var _state: State = .idle

    /// The current session ID (for conversation continuity)
    public var sessionId: String? {
        queue.sync { _sessionId }
    }

    /// Jake's current state
    public var state: State {
        queue.sync { _state }
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
    /// - Parameter claude: The ClaudeCode SDK instance to use (injectable for testing)
    public init(claude: ClaudeCode) {
        self.claude = claude
    }

    // MARK: - Communication

    /// Send a message to Jake and get a response
    /// - Parameter message: The user's message
    /// - Returns: Jake's response text
    /// - Throws: ClaudeCodeError if communication fails
    public func send(_ message: String) async throws -> String {
        queue.sync { _state = .cogitating }
        defer { queue.sync { _state = .idle } }

        var options = ClaudeCodeOptions()
        options.systemPrompt = Self.systemPrompt

        let result: ClaudeCodeResult
        let currentSessionId: String? = queue.sync { _sessionId }

        if let sessionId = currentSessionId {
            // Continue existing conversation
            result = try await claude.resumeConversation(
                sessionId: sessionId,
                prompt: message,
                outputFormat: .json,
                options: options
            )
        } else {
            // Start new conversation
            result = try await claude.runSinglePrompt(
                prompt: message,
                outputFormat: .json,
                options: options
            )
        }

        // Extract session ID and response
        switch result {
        case .json(let resultMessage):
            queue.sync { _sessionId = resultMessage.sessionId }
            return resultMessage.result ?? ""

        case .text(let text):
            return text

        case .stream:
            // For non-streaming calls, this shouldn't happen
            return ""
        }
    }

    /// Reset Jake's conversation (start fresh)
    public func resetConversation() {
        queue.sync { _sessionId = nil }
    }
}
