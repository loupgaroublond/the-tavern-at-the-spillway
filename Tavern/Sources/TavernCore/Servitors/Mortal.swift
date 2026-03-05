import Foundation
import ClodKit
import os.log

// MARK: - Provenance: REQ-AGT-002, REQ-AGT-005, REQ-AGT-009, REQ-DET-001, REQ-DET-004, REQ-LCM-007, REQ-OBS-011, REQ-OPM-005, REQ-SPN-009, REQ-V1-005

/// A mortal - a worker spawned by Jake to handle specific assignments
/// Unlike Jake (who is eternal), mortals are created for a purpose
/// and eventually complete their work.
///
/// Terminology:
/// - Jake calls them "Regulars" (individuals)
/// - The whole team is the "Slop Squad"
public final class Mortal: Servitor, @unchecked Sendable {

    // MARK: - Servitor Protocol

    public let id: UUID
    public let name: String

    /// The servitor's current state
    public var state: ServitorState {
        queue.sync { _state }
    }

    // MARK: - Mortal Properties

    /// The assignment given to this mortal (their purpose)
    /// nil for user-spawned mortals that wait for user's first message
    public let assignment: String?

    /// User-editable description shown in the sidebar
    public var chatDescription: String?

    /// Commitments this mortal must verify before completing
    public let commitments: CommitmentList

    /// Verifier used to check commitments (injected for testability)
    public let verifier: CommitmentVerifier

    // MARK: - Private State

    private let projectURL: URL
    private let session: ClodSession
    private let queue = DispatchQueue(label: "com.tavern.Mortal")

    private var _state: ServitorState = .idle

    /// The current session ID (for conversation continuity)
    public var sessionId: String? {
        session.sessionId
    }

    /// The current session mode (plan, normal, acceptEdits, etc.)
    public var sessionMode: TavernKit.PermissionMode {
        get { session.permissionMode }
        set { session.permissionMode = newValue }
    }

    // MARK: - System Prompt

    /// Generate the system prompt for this mortal
    private var systemPrompt: String {
        if let assignment = assignment {
            // Jake-summoned: has an assignment, start working immediately
            return """
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
        } else {
            // User-spawned: no assignment, wait for user's first message
            return """
            You are a worker agent in The Tavern at the Spillway.

            Your name is \(name).

            You are part of Jake's "Slop Squad" - worker agents who get things done.
            Wait for the user to give you an assignment. Once they do, be efficient and thorough.

            When you complete an assignment, say "DONE" clearly.
            If you need input or clarification, ask for it.
            If you encounter an error you can't resolve, report it clearly.

            You speak professionally but with personality. You're not Jake
            (nobody is quite like Jake), but you work for him and share his
            commitment to quality execution beneath a quirky exterior.
            """
        }
    }

    // MARK: - Initialization

    /// Create a mortal, optionally with an assignment
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - name: Display name for this mortal
    ///   - assignment: The assignment this mortal is responsible for (nil for user-spawned mortals)
    ///   - chatDescription: User-editable description shown in sidebar
    ///   - projectURL: The project directory URL
    ///   - store: File-system persistence store for servitor state
    ///   - commitments: List of commitments to verify before completion (defaults to empty)
    ///   - verifier: Verifier for checking commitments (defaults to shell-based)
    ///   - messenger: The messenger for Claude communication (default: LiveMessenger)
    public init(
        id: UUID = UUID(),
        name: String,
        assignment: String? = nil,
        chatDescription: String? = nil,
        projectURL: URL,
        store: ServitorStore,
        commitments: CommitmentList = CommitmentList(),
        verifier: CommitmentVerifier = CommitmentVerifier(),
        messenger: ServitorMessenger? = nil
    ) {
        self.id = id
        self.name = name
        self.assignment = assignment
        self.chatDescription = chatDescription
        self.projectURL = projectURL
        self.commitments = commitments
        self.verifier = verifier

        let config = ClodSession.Config(
            systemPrompt: "", // Will be set below via session.systemPrompt
            permissionMode: .plan,
            workingDirectory: projectURL,
            servitorName: name.lowercased()
        )

        self.session = ClodSession(config: config, store: store, messenger: messenger)
        // Set the actual system prompt (depends on self.name and self.assignment)
        self.session.systemPrompt = systemPrompt
    }

    // MARK: - Agent Protocol Implementation

    /// Send a message to this servitor and get a response
    public func send(_ message: String) async throws -> String {
        TavernLogger.agents.info("[\(self.name)] send called, prompt length: \(message.count)")
        TavernLogger.agents.debug("[\(self.name)] state: \(self._state.rawValue) -> working")

        queue.sync { _state = .working }
        defer { updateStateAfterResponse() }

        let result = try await session.send(message)

        if result.didFallback {
            TavernLogger.agents.warning("[\(self.name)] session fell back to fresh (stale session)")
        }

        TavernLogger.agents.info("[\(self.name)] received response, length: \(result.response.count)")

        await checkForCompletionSignal(in: result.response)
        return result.response
    }

    /// Send a message and receive a stream of events (streaming mode)
    public func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        TavernLogger.agents.info("[\(self.name)] sendStreaming called, prompt length: \(message.count)")
        TavernLogger.agents.debug("[\(self.name)] state: \(self._state.rawValue) -> working")

        queue.sync { _state = .working }

        let (innerStream, innerCancel) = session.sendStreaming(message)

        // Accumulate full response text for completion signal detection
        let responseAccumulator = UnsafeSendableBox("")

        // Wrap the stream to manage Mortal-specific state
        let wrappedStream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task { [weak self] in
                do {
                    for try await event in innerStream {
                        switch event {
                        case .textDelta(let delta):
                            responseAccumulator.value += delta
                            continuation.yield(event)

                        case .completed:
                            self?.updateStateAfterResponse()
                            // Check for done/waiting signals in accumulated response
                            if let self {
                                await self.checkForCompletionSignal(in: responseAccumulator.value)
                            }
                            continuation.yield(event)

                        case .error:
                            self?.updateStateAfterResponse()
                            continuation.yield(event)

                        default:
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    self?.updateStateAfterResponse()
                    TavernLogger.agents.error("[\(self?.name ?? "??")] streaming error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        let cancel: @Sendable () -> Void = { [weak self] in
            self?.updateStateAfterResponse()
            innerCancel()
            TavernLogger.agents.debug("[\(self?.name ?? "??")] streaming cancelled by user")
        }

        return (stream: wrappedStream, cancel: cancel)
    }

    /// Reset the mortal's conversation state
    public func resetConversation() {
        TavernLogger.agents.info("[\(self.name)] conversation reset")
        queue.sync {
            // Don't reset state to idle if done - done is terminal
            if _state != .done {
                _state = .idle
            }
        }

        session.resetConversation()
    }

    /// Update the chat description
    /// - Parameter description: The new description (nil to clear)
    /// Note: Persistence is handled by ClodSessionManager.updateDescription()
    public func updateChatDescription(_ description: String?) {
        self.chatDescription = description
        TavernLogger.agents.debug("[\(self.name)] chat description updated: \(description ?? "nil")")
    }

    // MARK: - State Management

    /// Explicitly mark this mortal as waiting for input
    public func markWaiting() {
        queue.sync {
            if _state != .done {
                _state = .waiting
            }
        }
    }

    /// Explicitly mark this mortal as done
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

    /// Handle when the mortal signals completion
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
                // Verification failed - servitor needs to continue working
                TavernLogger.agents.info("[\(self.name)] commitment verification failed, state -> idle")
                queue.sync { _state = .idle }
            }
        } catch {
            // Verification error - stay idle so servitor can retry
            TavernLogger.agents.error("[\(self.name)] commitment verification error: \(error.localizedDescription)")
            queue.sync { _state = .idle }
        }
    }

    /// Add a commitment that must be verified before completion
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
