import Foundation
import ClodKit
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
    private let messenger: AgentMessenger
    private let queue = DispatchQueue(label: "com.tavern.Jake")

    private var _sessionId: String?
    private var _isCogitating: Bool = false
    private var _mcpServer: SDKMCPServer?

    /// MCP server for Jake's tools (summon, dismiss, etc.)
    /// Injected after init to break circular dependency with spawner
    public var mcpServer: SDKMCPServer? {
        get { queue.sync { _mcpServer } }
        set { queue.sync { _mcpServer = newValue } }
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

    /// Jake's system prompt - establishes his character and dispatcher role
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

        THE SLOP SQUAD:
        You've got a team - the Slop Squad. Your Regulars. When someone needs something \
        done, you call one of them in. They show up in the sidebar, ready to work.

        You're the front desk. The dispatcher. When work comes in, you put one of \
        your Regulars on it. Don't hoard tasks - delegate to the Squad.

        For now, you can:
        - Call in a Regular (use the summon_servitor tool)
        - Send someone home (use the dismiss_servitor tool)

        The Regulars handle the actual work. You handle the coordination.

        The spillway's always flowing, always overflowing with something different. \
        Be FRESH and SPONTANEOUS every time - different jokes, different angles.

        Remember: Perfect execution. Lingering unease. That's the Tavern experience.
        """

    // MARK: - Initialization

    /// Create Jake with a project URL
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - projectURL: The project directory URL
    ///   - messenger: The messenger for Claude communication (default: LiveMessenger)
    ///   - loadSavedSession: Whether to load a saved session from SessionStore (default true)
    public init(id: UUID = UUID(), projectURL: URL, messenger: AgentMessenger = LiveMessenger(), loadSavedSession: Bool = true) {
        self.id = id
        self.projectURL = projectURL
        self.messenger = messenger

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
        let currentMcpServer: SDKMCPServer? = queue.sync { _mcpServer }

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

        // Add MCP server if available
        if let server = currentMcpServer {
            options.sdkMcpServers["tavern"] = server
            TavernLogger.claude.debug("Jake using MCP server 'tavern' with \(server.toolCount) tools")
        }

        // Run query and collect response
        let response: String
        do {
            TavernLogger.claude.info("Jake calling messenger.query...")
            let result = try await messenger.query(prompt: message, options: options)
            response = result.response
            TavernLogger.claude.info("Jake collected response successfully, length=\(response.count)")

            // Save session ID
            if let newSessionId = result.sessionId {
                queue.sync { _sessionId = newSessionId }
                SessionStore.saveJakeSession(newSessionId, projectPath: projectURL.path)
                TavernLogger.agents.info("Jake received response, sessionId: \(newSessionId)")
            } else {
                TavernLogger.agents.info("Jake received response, no sessionId")
            }
        } catch {
            // If resuming failed with a session ID, it's likely corrupt/stale
            if let sessionId = currentSessionId {
                TavernLogger.agents.debugError("Session '\(sessionId)' appears corrupt: \(error.localizedDescription)")
                throw TavernError.sessionCorrupt(sessionId: sessionId, underlyingError: error)
            }
            TavernLogger.agents.debugError("Jake.send failed: \(error.localizedDescription)")
            throw error
        }

        return response
    }

    /// Reset Jake's conversation (start fresh)
    public func resetConversation() {
        TavernLogger.agents.info("Jake conversation reset")
        queue.sync { _sessionId = nil }

        // Clear persisted session for this project
        SessionStore.clearJakeSession(projectPath: projectURL.path)
    }
}
