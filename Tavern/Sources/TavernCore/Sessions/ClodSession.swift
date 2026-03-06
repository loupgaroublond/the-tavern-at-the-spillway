import Foundation
import ClodKit
import os.log
import TavernKit

// MARK: - Provenance: REQ-ARCH-009, REQ-QA-002, REQ-QA-005

/// Pure in-memory session mechanism layer. Owns all Claude session plumbing:
/// build options, resume-with-fallback, permission mapping.
///
/// ClodSession is *mechanism*, not *policy*. It holds ephemeral session state
/// in memory and returns it to callers. Persistence is the caller's responsibility
/// (see ClodSessionManager).
///
/// Servitors (Jake, Mortal) delegate to a ClodSession instance, keeping only their
/// unique business logic (state machines, MCP injection, completion detection).
// @unchecked Sendable: ClodSession has mutable state (_sessionId, config) but is
// single-owner (one servitor) and called sequentially. The queue was removed because
// no cross-isolation access occurs. This @unchecked remains until Jake/Mortal threading
// cleanup converts servitors to actors or @MainActor (Step 7 follow-up).
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
    private var _sessionId: String?
    private let messenger: ServitorMessenger

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "session")

    // MARK: - Public Properties

    var sessionId: String? { _sessionId }

    var systemPrompt: String {
        get { config.systemPrompt }
        set { config.systemPrompt = newValue }
    }

    var permissionMode: TavernKit.PermissionMode {
        get { config.permissionMode }
        set { config.permissionMode = newValue }
    }

    var mcpServers: [String: SDKMCPServer] {
        get { config.mcpServers }
        set { config.mcpServers = newValue }
    }

    // MARK: - Initialization

    init(config: Config, initialSessionId: String? = nil, messenger: ServitorMessenger? = nil) {
        self.config = config
        self._sessionId = initialSessionId
        self.messenger = messenger ?? LiveMessenger(
            approvalHandler: config.approvalHandler,
            planApprovalHandler: config.planApprovalHandler
        )

        Self.logger.info("[ClodSession] initialized for '\(config.servitorName)', hasSession: \(initialSessionId != nil)")
    }

    // MARK: - Communication

    /// Send a message with resume-with-fallback.
    /// Returns the response text, new session ID, whether a fallback occurred,
    /// and the expired session ID if one was discarded.
    func send(_ message: String) async throws -> (response: String, sessionId: String?, didFallback: Bool, expiredSessionId: String?) {
        let options = buildOptions()

        do {
            let result = try await messenger.query(prompt: message, options: options)
            if let newSessionId = result.sessionId {
                _sessionId = newSessionId
            }
            return (response: result.response, sessionId: result.sessionId, didFallback: false, expiredSessionId: nil)
        } catch {
            let hadSessionId = _sessionId
            if hadSessionId != nil && isStaleSessionError(error) {
                Self.logger.warning("[ClodSession] stale session detected, falling back to fresh session")
                _sessionId = nil

                let freshOptions = buildOptions()
                let result = try await messenger.query(prompt: message, options: freshOptions)
                if let newSessionId = result.sessionId {
                    _sessionId = newSessionId
                }
                return (response: result.response, sessionId: result.sessionId, didFallback: true, expiredSessionId: hadSessionId)
            }

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
        let currentSessionId = _sessionId

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
                                self._sessionId = sessionId
                            }
                            continuation.yield(event)
                        default:
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    if currentSessionId != nil && self.isStaleSessionError(error) {
                        Self.logger.warning("[ClodSession] streaming stale session, falling back")
                        self._sessionId = nil

                        // Yield session break marker
                        continuation.yield(.sessionBreak(staleSessionId: currentSessionId!))

                        // Retry with fresh session
                        let freshOptions = self.buildOptions()
                        let (retryStream, retryCancel) = self.messenger.queryStreaming(prompt: message, options: freshOptions)
                        cancelBox.value = retryCancel

                        do {
                            for try await event in retryStream {
                                if case .completed(let info) = event, let sessionId = info.sessionId {
                                    self._sessionId = sessionId
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

    /// Reset conversation: clear in-memory session ID.
    /// Caller is responsible for persisting the break and logging events.
    func resetConversation() {
        _sessionId = nil
        Self.logger.info("[ClodSession] conversation reset for '\(self.config.servitorName)'")
    }

    // MARK: - Private — Options

    private func buildOptions() -> QueryOptions {
        var options = QueryOptions()
        options.systemPrompt = config.systemPrompt
        options.permissionMode = Self.mapPermissionMode(config.permissionMode)
        options.workingDirectory = config.workingDirectory

        if let sessionId = _sessionId {
            options.resume = sessionId
        }

        for (key, server) in config.mcpServers {
            options.sdkMcpServers[key] = server
        }

        return options
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
