import Foundation
import ClaudeCodeSDK

/// A mortal agent - a worker spawned by Jake to handle specific tasks
/// Unlike Jake (who is eternal), mortal agents are created for a purpose
/// and eventually complete their work.
public final class MortalAgent: Agent, @unchecked Sendable {

    // MARK: - Agent Protocol

    public let id: UUID
    public let name: String

    /// The agent's current state
    public var state: AgentState {
        queue.sync { _state }
    }

    // MARK: - Mortal Agent Properties

    /// The assignment given to this agent (their purpose)
    public let assignment: String

    // MARK: - Private State

    private let claude: ClaudeCode
    private let queue = DispatchQueue(label: "com.tavern.MortalAgent")

    private var _state: AgentState = .idle
    private var _sessionId: String?

    /// The current session ID (for conversation continuity)
    public var sessionId: String? {
        queue.sync { _sessionId }
    }

    // MARK: - System Prompt

    /// Generate the system prompt for this agent
    private var systemPrompt: String {
        """
        You are a worker agent in The Tavern at the Spillway.

        Your name is \(name).

        Your assignment: \(assignment)

        You are part of Jake's "Slop Squad" - worker agents who get things done.
        Focus on your assignment. Be efficient and thorough.

        When you complete your assignment, say "DONE" clearly.
        If you need input or clarification, ask for it.
        If you encounter an error you can't resolve, report it clearly.

        You speak professionally but with personality. You're not Jake
        (nobody is quite like Jake), but you work for him and share his
        commitment to quality execution beneath a quirky exterior.
        """
    }

    // MARK: - Initialization

    /// Create a mortal agent with a specific assignment
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - name: Display name for this agent
    ///   - assignment: The task this agent is responsible for
    ///   - claude: The ClaudeCode SDK instance to use
    public init(
        id: UUID = UUID(),
        name: String,
        assignment: String,
        claude: ClaudeCode
    ) {
        self.id = id
        self.name = name
        self.assignment = assignment
        self.claude = claude
    }

    // MARK: - Agent Protocol Implementation

    /// Send a message to this agent and get a response
    public func send(_ message: String) async throws -> String {
        queue.sync { _state = .working }
        defer { updateStateAfterResponse() }

        var options = ClaudeCodeOptions()
        options.systemPrompt = systemPrompt

        let result: ClaudeCodeResult
        let currentSessionId: String? = queue.sync { _sessionId }

        if let sessionId = currentSessionId {
            result = try await claude.resumeConversation(
                sessionId: sessionId,
                prompt: message,
                outputFormat: .json,
                options: options
            )
        } else {
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
            let response = resultMessage.result ?? ""
            checkForCompletionSignal(in: response)
            return response

        case .text(let text):
            checkForCompletionSignal(in: text)
            return text

        case .stream:
            return ""
        }
    }

    /// Reset the agent's conversation state
    public func resetConversation() {
        queue.sync {
            _sessionId = nil
            // Don't reset state to idle if done - done is terminal
            if _state != .done {
                _state = .idle
            }
        }
    }

    // MARK: - State Management

    /// Explicitly mark this agent as waiting for input
    public func markWaiting() {
        queue.sync {
            if _state != .done {
                _state = .waiting
            }
        }
    }

    /// Explicitly mark this agent as done
    public func markDone() {
        queue.sync { _state = .done }
    }

    // MARK: - Private Helpers

    private func updateStateAfterResponse() {
        queue.sync {
            // If not explicitly set to done or waiting, go back to idle
            if _state == .working {
                _state = .idle
            }
        }
    }

    private func checkForCompletionSignal(in response: String) {
        // Simple heuristic: if the response contains "DONE" prominently,
        // transition to done state
        let upperResponse = response.uppercased()
        if upperResponse.contains("DONE") || upperResponse.contains("COMPLETED") {
            queue.sync { _state = .done }
        } else if upperResponse.contains("WAITING") || upperResponse.contains("NEED INPUT") {
            queue.sync { _state = .waiting }
        }
    }
}
