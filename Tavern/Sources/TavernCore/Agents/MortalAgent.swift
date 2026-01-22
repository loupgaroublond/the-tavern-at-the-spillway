import Foundation
import ClaudeCodeSDK
import os.log

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

    /// Commitments this agent must verify before completing
    public let commitments: CommitmentList

    /// Verifier used to check commitments (injected for testability)
    public let verifier: CommitmentVerifier

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
    ///   - commitments: List of commitments to verify before completion (defaults to empty)
    ///   - verifier: Verifier for checking commitments (defaults to shell-based)
    public init(
        id: UUID = UUID(),
        name: String,
        assignment: String,
        claude: ClaudeCode,
        commitments: CommitmentList = CommitmentList(),
        verifier: CommitmentVerifier = CommitmentVerifier()
    ) {
        self.id = id
        self.name = name
        self.assignment = assignment
        self.claude = claude
        self.commitments = commitments
        self.verifier = verifier
    }

    // MARK: - Agent Protocol Implementation

    /// Send a message to this agent and get a response
    public func send(_ message: String) async throws -> String {
        TavernLogger.agents.info("[\(self.name)] send called, prompt length: \(message.count)")
        TavernLogger.agents.debug("[\(self.name)] state: \(self._state.rawValue) -> working")

        queue.sync { _state = .working }
        defer { updateStateAfterResponse() }

        var options = ClaudeCodeOptions()
        options.systemPrompt = systemPrompt

        let result: ClaudeCodeResult
        let currentSessionId: String? = queue.sync { _sessionId }

        // NOTE: Using .text format because ClaudeCodeSDK has a bug parsing
        // the .json format (Claude CLI returns an array, SDK expects an object).
        // This means we lose session ID tracking for now.
        // FIX: Fork ClaudeCodeSDK and fix HeadlessBackend.swift to parse arrays

        do {
            if let sessionId = currentSessionId {
                TavernLogger.claude.info("[\(self.name)] resuming session: \(sessionId)")
                result = try await claude.resumeConversation(
                    sessionId: sessionId,
                    prompt: message,
                    outputFormat: .text,
                    options: options
                )
            } else {
                TavernLogger.claude.info("[\(self.name)] starting new conversation")
                result = try await claude.runSinglePrompt(
                    prompt: message,
                    outputFormat: .text,
                    options: options
                )
            }
        } catch {
            TavernLogger.agents.error("[\(self.name)] send failed: \(error.localizedDescription)")
            throw error
        }

        // Extract response
        switch result {
        case .json(let resultMessage):
            // Won't happen with .text format, but handle it anyway
            queue.sync { _sessionId = resultMessage.sessionId }
            let response = resultMessage.result ?? ""
            TavernLogger.agents.info("[\(self.name)] received JSON response, length: \(response.count)")
            await checkForCompletionSignal(in: response)
            return response

        case .text(let text):
            TavernLogger.agents.info("[\(self.name)] received text response, length: \(text.count)")
            await checkForCompletionSignal(in: text)
            return text

        case .stream:
            TavernLogger.agents.debug("[\(self.name)] received unexpected stream result")
            return ""
        }
    }

    /// Reset the agent's conversation state
    public func resetConversation() {
        TavernLogger.agents.info("[\(self.name)] conversation reset")
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

    private func checkForCompletionSignal(in response: String) async {
        // Simple heuristic: if the response contains "DONE" prominently,
        // trigger the completion flow
        let upperResponse = response.uppercased()
        if upperResponse.contains("DONE") || upperResponse.contains("COMPLETED") {
            TavernLogger.agents.info("[\(self.name)] detected DONE signal in response")
            await handleCompletionAttempt()
        } else if upperResponse.contains("WAITING") || upperResponse.contains("NEED INPUT") {
            TavernLogger.agents.info("[\(self.name)] detected waiting signal, state -> waiting")
            queue.sync { _state = .waiting }
        }
    }

    /// Handle when the agent signals completion
    /// Verifies all commitments before actually marking done
    private func handleCompletionAttempt() async {
        // If no commitments or all already passed, mark done immediately
        if commitments.count == 0 || commitments.allPassed {
            TavernLogger.agents.info("[\(self.name)] no commitments to verify, state -> done")
            queue.sync { _state = .done }
            return
        }

        // Enter verifying state
        TavernLogger.agents.info("[\(self.name)] starting commitment verification, state -> verifying")
        queue.sync { _state = .verifying }

        do {
            let allPassed = try await verifier.verifyAll(in: commitments)

            if allPassed {
                TavernLogger.agents.info("[\(self.name)] all commitments passed, state -> done")
                queue.sync { _state = .done }
            } else {
                // Verification failed - agent needs to continue working
                TavernLogger.agents.info("[\(self.name)] commitment verification failed, state -> idle")
                queue.sync { _state = .idle }
            }
        } catch {
            // Verification error - stay idle so agent can retry
            TavernLogger.agents.error("[\(self.name)] commitment verification error: \(error.localizedDescription)")
            queue.sync { _state = .idle }
        }
    }

    /// Add a commitment that must be verified before completion
    /// - Parameters:
    ///   - description: What is being committed
    ///   - assertion: Command to verify the commitment
    /// - Returns: The created commitment
    @discardableResult
    public func addCommitment(description: String, assertion: String) -> Commitment {
        commitments.add(description: description, assertion: assertion)
    }

    /// Whether all commitments have been verified and passed
    public var allCommitmentsPassed: Bool {
        commitments.count == 0 || commitments.allPassed
    }

    /// Whether there are any failed commitments
    public var hasFailedCommitments: Bool {
        commitments.hasFailed
    }
}
