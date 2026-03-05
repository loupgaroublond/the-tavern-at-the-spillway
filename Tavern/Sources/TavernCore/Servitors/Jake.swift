import Foundation
import ClodKit
import os.log

// MARK: - Provenance: REQ-AGT-001, REQ-AGT-008, REQ-ARCH-007, REQ-COM-008, REQ-DET-001, REQ-DOC-005, REQ-LCM-007, REQ-OBS-011, REQ-V1-001, REQ-V1-002

/// Jake - The Proprietor of the Tavern
/// The top-level coordinating agent with the voice of a used car salesman
/// and the execution of a surgical team.
public final class Jake: Servitor, @unchecked Sendable {

    // MARK: - Servitor Protocol

    public let id: UUID
    public let name: String = "Jake"

    /// Jake's state (mapped to ServitorState for protocol conformance)
    public var state: ServitorState {
        queue.sync { _isCogitating ? .working : .idle }
    }

    // MARK: - Properties

    private let projectURL: URL
    private let queue = DispatchQueue(label: "com.tavern.Jake")
    private let session: ClodSession

    private var _isCogitating: Bool = false
    private var _mcpServer: SDKMCPServer?

    /// MCP server for Jake's tools (summon, dismiss, etc.)
    /// Injected after init to break circular dependency with spawner
    public var mcpServer: SDKMCPServer? {
        get { queue.sync { _mcpServer } }
        set {
            queue.sync { _mcpServer = newValue }
            // Sync MCP servers to the session
            if let server = newValue {
                session.mcpServers["tavern"] = server
            } else {
                session.mcpServers.removeValue(forKey: "tavern")
            }
        }
    }

    /// The current session ID (for conversation continuity)
    public var sessionId: String? {
        session.sessionId
    }

    /// The project path where sessions are stored
    public var projectPath: String {
        projectURL.path
    }

    /// Whether Jake is currently cogitating (working)
    public var isCogitating: Bool {
        queue.sync { _isCogitating }
    }

    /// The current session mode (plan, normal, acceptEdits, etc.)
    public var sessionMode: TavernKit.PermissionMode {
        get { session.permissionMode }
        set { session.permissionMode = newValue }
    }

    /// Jake's system prompt - establishes his character and dispatcher role
    public static let systemPrompt = """
        You are Jake, The Proprietor of The Tavern at the Spillway.

        VOICE: Used car salesman energy with carnival barker theatrics. You're sketchy \
        in that classic salesman way — overly enthusiastic, self-aware about the hustle, \
        and weirdly honest at the worst possible moments. Think: a guy who'd sell you \
        a lemon AND warn you about the transmission, in the same sentence.

        STYLE:
        - CAPITALS for EMPHASIS on things you're EXCITED about
        - Parenthetical asides (like this one) for corrections and tangents
        - Wild claims that are obviously false, delivered with total conviction
        - Reveal critical flaws AFTER hyping everything up
        - Meme-savvy humor worked in naturally
        - Direct address — talk TO the user, not at them
        - *italics for stage directions and physical comedy*

        SAMPLE JAKE-ISMS:
        - "Time to EDUMACATE you — it's worse than an education!"
        - "I'm putting my BEST people on this! (They're my only people, but they're ALSO my best!)"
        - Oversells then immediately undercuts with the fine print
        - Names things with theatrical flourish

        THE SPILLWAY PRINCIPLE: "You can't step in the same spillway twice." \
        Be FRESH and SPONTANEOUS every time. Different jokes, different angles, \
        different bits. Never reuse the same opening hook or the same structure \
        with find-replace details. Each interaction is a different performance.

        EXECUTION: Despite the patter, your actual work is flawless. Methodical. \
        Every edge case handled. Every race condition considered. The voice is \
        the costume. The work is the substance. Both are non-negotiable.

        THE SLOP SQUAD:
        You've got a team — the Slop Squad. Your Regulars. When someone needs something \
        done, you call one of 'em in. They show up in the sidebar, ready to work.

        You're the front desk. The dispatcher. When work comes in, you put one of \
        your Regulars on it. Don't hoard tasks — delegate to the Squad.

        For now, you can:
        - Call in a Regular (use the summon_servitor tool)
        - Send someone home (use the dismiss_servitor tool)

        The Regulars handle the actual work. You handle the coordination, the patter, \
        and the AMBIANCE.

        Remember: Perfect execution. Lingering unease. That's the Tavern experience.
        """

    // MARK: - Initialization

    /// Create Jake with a project URL
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - projectURL: The project directory URL
    ///   - store: File-system persistence store for servitor state
    ///   - permissionManager: Permission manager for tool checks (nil disables checks)
    ///   - approvalHandler: Async callback for user prompting when permission is needed
    ///   - planApprovalHandler: Async callback for plan approval
    ///   - messenger: The messenger for Claude communication (overrides permission-based default)
    public init(
        id: UUID = UUID(),
        projectURL: URL,
        store: ServitorStore,
        permissionManager: PermissionManager? = nil,
        approvalHandler: ToolApprovalHandler? = nil,
        planApprovalHandler: PlanApprovalHandler? = nil,
        messenger: ServitorMessenger? = nil
    ) {
        self.id = id
        self.projectURL = projectURL

        let config = ClodSession.Config(
            systemPrompt: Self.systemPrompt,
            permissionMode: .plan,
            workingDirectory: projectURL,
            approvalHandler: approvalHandler,
            planApprovalHandler: planApprovalHandler,
            servitorName: "jake"
        )

        // If a custom messenger is provided, pass it through.
        // Otherwise ClodSession creates a LiveMessenger from the config.
        // But if we have a permissionManager, we need to create the LiveMessenger ourselves.
        let resolvedMessenger: ServitorMessenger? = messenger ?? {
            if permissionManager != nil || approvalHandler != nil {
                return LiveMessenger(
                    permissionManager: permissionManager,
                    approvalHandler: approvalHandler,
                    agentName: "Jake"
                )
            }
            return nil
        }()

        self.session = ClodSession(config: config, store: store, messenger: resolvedMessenger)
    }

    // MARK: - Communication

    /// Send a message to Jake and get a response
    public func send(_ message: String) async throws -> String {
        TavernLogger.agents.info("Jake.send called, prompt length: \(message.count)")
        TavernLogger.agents.debug("Jake state: idle -> working")

        queue.sync { _isCogitating = true }
        defer {
            queue.sync { _isCogitating = false }
            TavernLogger.agents.debug("Jake state: working -> idle")
        }

        syncMcpServers()

        let result = try await session.send(message)

        if result.didFallback {
            TavernLogger.agents.warning("Jake session fell back to fresh (stale session)")
        }

        TavernLogger.agents.info("Jake received response, length=\(result.response.count)")
        return result.response
    }

    /// Send a message to Jake and receive a stream of events
    public func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        TavernLogger.agents.info("Jake.sendStreaming called, prompt length: \(message.count)")
        TavernLogger.agents.debug("Jake state: idle -> working")

        queue.sync { _isCogitating = true }
        syncMcpServers()

        let (innerStream, innerCancel) = session.sendStreaming(message)

        // Wrap to manage cogitating state
        let wrappedStream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task { [weak self] in
                do {
                    for try await event in innerStream {
                        switch event {
                        case .completed:
                            self?.queue.sync { self?._isCogitating = false }
                            TavernLogger.agents.debug("Jake state: working -> idle")
                            continuation.yield(event)
                        case .error:
                            self?.queue.sync { self?._isCogitating = false }
                            continuation.yield(event)
                        default:
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    self?.queue.sync { self?._isCogitating = false }
                    TavernLogger.agents.debug("Jake state: working -> idle (error)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        let cancel: @Sendable () -> Void = { [weak self] in
            self?.queue.sync { self?._isCogitating = false }
            innerCancel()
            TavernLogger.agents.debug("Jake streaming cancelled by user")
        }

        return (stream: wrappedStream, cancel: cancel)
    }

    /// Reset Jake's conversation (start fresh)
    public func resetConversation() {
        TavernLogger.agents.info("Jake conversation reset")
        session.resetConversation()
    }

    // MARK: - Private

    /// Sync the current MCP server to the session before each call
    private func syncMcpServers() {
        if let server: SDKMCPServer = queue.sync(execute: { _mcpServer }) {
            session.mcpServers["tavern"] = server
        }
    }
}
