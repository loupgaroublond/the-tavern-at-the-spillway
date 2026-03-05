import Foundation
import ClodKit
import os.log
import TavernKit

// MARK: - Provenance: REQ-ARCH-009, REQ-QA-002, REQ-QA-005

/// Consolidated session mechanism layer. Owns all Claude session plumbing:
/// build options, resume-with-fallback, session persistence, permission mapping.
///
/// Servitors (Jake, Mortal) delegate to a ClodSession instance, keeping only their
/// unique business logic (state machines, MCP injection, completion detection).
final class ClodSession: @unchecked Sendable {

    // MARK: - Configuration

    struct Config: Sendable {
        var systemPrompt: String
        var permissionMode: TavernKit.PermissionMode
        var workingDirectory: URL
        var mcpServers: [String: SDKMCPServer] = [:]
        var approvalHandler: ToolApprovalHandler?
        var planApprovalHandler: PlanApprovalHandler?
        let servitorName: String
    }

    // MARK: - State

    private var config: Config
    private let queue = DispatchQueue(label: "com.tavern.ClodSession")
    private var _sessionId: String?
    private let messenger: ServitorMessenger
    private let store: ServitorStore

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "session")

    // MARK: - Public Properties

    var sessionId: String? {
        queue.sync { _sessionId }
    }

    var systemPrompt: String {
        get { queue.sync { config.systemPrompt } }
        set { queue.sync { config.systemPrompt = newValue } }
    }

    var permissionMode: TavernKit.PermissionMode {
        get { queue.sync { config.permissionMode } }
        set { queue.sync { config.permissionMode = newValue } }
    }

    var mcpServers: [String: SDKMCPServer] {
        get { queue.sync { config.mcpServers } }
        set { queue.sync { config.mcpServers = newValue } }
    }

    // MARK: - Initialization

    init(config: Config, store: ServitorStore, messenger: ServitorMessenger? = nil) {
        self.config = config
        self.store = store
        self.messenger = messenger ?? LiveMessenger(
            approvalHandler: config.approvalHandler,
            planApprovalHandler: config.planApprovalHandler
        )

        // Load saved session from file-system store
        if let record = try? store.load(name: config.servitorName) {
            _sessionId = record.sessionId
        }

        Self.logger.info("[ClodSession] initialized for '\(config.servitorName)', hasSession: \(self._sessionId != nil)")
    }

    // MARK: - Communication

    /// Send a message with resume-with-fallback.
    /// Returns the response text, new session ID (if any), and whether a fallback occurred.
    func send(_ message: String) async throws -> (response: String, sessionId: String?, didFallback: Bool) {
        let options = buildOptions()

        do {
            let result = try await messenger.query(prompt: message, options: options)
            if let newSessionId = result.sessionId {
                persistSession(newSessionId)
            }
            return (response: result.response, sessionId: result.sessionId, didFallback: false)
        } catch {
            // If we had a session and it's a stale-session error, retry without resume
            let hadSessionId = queue.sync { _sessionId }
            if hadSessionId != nil && isStaleSessionError(error) {
                Self.logger.warning("[ClodSession] stale session detected, falling back to fresh session")
                logSessionExpired(staleSessionId: hadSessionId!, reason: "timeout")
                clearSession()

                let freshOptions = buildOptions()
                let result = try await messenger.query(prompt: message, options: freshOptions)
                if let newSessionId = result.sessionId {
                    persistSession(newSessionId)
                    logSessionStarted(sessionId: newSessionId)
                }
                return (response: result.response, sessionId: result.sessionId, didFallback: true)
            }

            // Non-session error or no session to fall back from
            if let sessionId = hadSessionId {
                throw TavernError.sessionCorrupt(sessionId: sessionId, underlyingError: error)
            }
            throw error
        }
    }

    /// Send a streaming message with resume-with-fallback.
    /// If the session is stale, yields `.sessionBreak` and retries with a fresh session.
    func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let options = buildOptions()
        let (innerStream, innerCancel) = messenger.queryStreaming(prompt: message, options: options)
        let currentSessionId: String? = queue.sync { _sessionId }

        // Sendable box for cancel closure — updated if fallback creates a new stream
        let cancelBox = UnsafeSendableBox<@Sendable () -> Void>(innerCancel)

        let wrappedStream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                do {
                    for try await event in innerStream {
                        switch event {
                        case .completed(let info):
                            if let sessionId = info.sessionId {
                                self.persistSession(sessionId)
                            }
                            continuation.yield(event)
                        default:
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    // If stale session error, fall back to fresh session
                    if currentSessionId != nil && self.isStaleSessionError(error) {
                        Self.logger.warning("[ClodSession] streaming stale session, falling back")
                        self.logSessionExpired(staleSessionId: currentSessionId!, reason: "timeout")
                        self.clearSession()

                        // Yield session break marker
                        continuation.yield(.sessionBreak(staleSessionId: currentSessionId!))

                        // Retry with fresh session
                        let freshOptions = self.buildOptions()
                        let (retryStream, retryCancel) = self.messenger.queryStreaming(prompt: message, options: freshOptions)
                        cancelBox.value = retryCancel

                        do {
                            for try await event in retryStream {
                                if case .completed(let info) = event, let sessionId = info.sessionId {
                                    self.persistSession(sessionId)
                                    self.logSessionStarted(sessionId: sessionId)
                                }
                                continuation.yield(event)
                            }
                            continuation.finish()
                        } catch {
                            let userMessage = TavernErrorMessages.message(for: error)
                            continuation.yield(.error(userMessage))
                            continuation.finish(throwing: error)
                        }
                    } else {
                        let userMessage = TavernErrorMessages.message(for: error)
                        if let sessionId = currentSessionId {
                            Self.logger.error("[ClodSession] stream error on session '\(sessionId)': \(error.localizedDescription)")
                            continuation.yield(.error(userMessage))
                            continuation.finish(throwing: TavernError.sessionCorrupt(sessionId: sessionId, underlyingError: error))
                        } else {
                            Self.logger.error("[ClodSession] stream error (no session): \(error.localizedDescription)")
                            continuation.yield(.error(userMessage))
                            continuation.finish(throwing: error)
                        }
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        return (stream: wrappedStream, cancel: { cancelBox.value() })
    }

    /// Reset conversation: clear session, log break event.
    func resetConversation(reason: String = "user_cleared") {
        let oldSessionId = queue.sync { _sessionId }
        clearSession()

        // Log the break event
        let breakEvent = SessionEvent(event: .break, timestamp: Date(), reason: reason)
        do {
            try store.appendSessionEvent(breakEvent, name: config.servitorName)
        } catch {
            Self.logger.error("[ClodSession] failed to log break event: \(error.localizedDescription)")
        }

        // If there was an active session, log it as ended
        if let oldSessionId {
            let endEvent = SessionEvent(event: .sessionEnded, sessionId: oldSessionId, timestamp: Date(), reason: reason)
            do {
                try store.appendSessionEvent(endEvent, name: config.servitorName)
            } catch {
                Self.logger.error("[ClodSession] failed to log session ended: \(error.localizedDescription)")
            }
        }

        Self.logger.info("[ClodSession] conversation reset for '\(self.config.servitorName)'")
    }

    // MARK: - Private — Options

    private func buildOptions() -> QueryOptions {
        let (sessionId, mode, mcpServers, systemPrompt) = queue.sync {
            (_sessionId, config.permissionMode, config.mcpServers, config.systemPrompt)
        }

        var options = QueryOptions()
        options.systemPrompt = systemPrompt
        options.permissionMode = Self.mapPermissionMode(mode)
        options.workingDirectory = config.workingDirectory

        // Resume with session ID if available — fallback logic handles stale sessions
        if let sessionId {
            options.resume = sessionId
        }

        for (key, server) in mcpServers {
            options.sdkMcpServers[key] = server
        }

        return options
    }

    // MARK: - Private — Session Persistence

    private func persistSession(_ sessionId: String) {
        queue.sync { _sessionId = sessionId }

        // Update the servitor record with the new session ID
        do {
            if var record = try store.load(name: config.servitorName) {
                record.sessionId = sessionId
                record.updatedAt = Date()
                try store.save(record)
            } else {
                // Record doesn't exist yet — this is unusual but handle gracefully
                Self.logger.warning("[ClodSession] no record found for '\(self.config.servitorName)' during persistSession")
            }
        } catch {
            Self.logger.error("[ClodSession] failed to persist session for '\(self.config.servitorName)': \(error.localizedDescription)")
        }
    }

    private func clearSession() {
        queue.sync { _sessionId = nil }

        do {
            if var record = try store.load(name: config.servitorName) {
                record.sessionId = nil
                record.updatedAt = Date()
                try store.save(record)
            }
        } catch {
            Self.logger.error("[ClodSession] failed to clear session for '\(self.config.servitorName)': \(error.localizedDescription)")
        }
    }

    // MARK: - Private — Session Event Logging

    private func logSessionExpired(staleSessionId: String, reason: String) {
        let event = SessionEvent(event: .sessionExpired, sessionId: staleSessionId, timestamp: Date(), reason: reason)
        do {
            try store.appendSessionEvent(event, name: config.servitorName)
        } catch {
            Self.logger.error("[ClodSession] failed to log session expired: \(error.localizedDescription)")
        }
    }

    private func logSessionStarted(sessionId: String) {
        let event = SessionEvent(event: .sessionStarted, sessionId: sessionId, timestamp: Date())
        do {
            try store.appendSessionEvent(event, name: config.servitorName)
        } catch {
            Self.logger.error("[ClodSession] failed to log session started: \(error.localizedDescription)")
        }
    }

    // MARK: - Private — Error Detection

    /// Detect stale session errors that warrant a fallback to a fresh session.
    private func isStaleSessionError(_ error: any Error) -> Bool {
        guard let controlError = error as? ControlProtocolError else { return false }
        if case .timeout = controlError { return true }
        return false
    }

    // MARK: - Permission Mapping

    /// Map Tavern's PermissionMode to ClodKit's PermissionMode — one place, not six.
    static func mapPermissionMode(_ mode: TavernKit.PermissionMode) -> ClodKit.PermissionMode {
        switch mode {
        case .normal: return .default
        case .acceptEdits: return .acceptEdits
        case .plan: return .plan
        case .bypassPermissions: return .bypassPermissions
        case .dontAsk: return .dontAsk
        }
    }
}
