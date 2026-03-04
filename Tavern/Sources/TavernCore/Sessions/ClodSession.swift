import Foundation
import ClodKit
import os.log

// MARK: - Provenance: REQ-ARCH-009, REQ-QA-002, REQ-QA-005

// TODO: ClodSession consolidates session logic currently duplicated in Jake and Mortal
// (send, streaming, session persistence, resetConversation). Wire as the backing type
// for both servitor types to eliminate the duplication. Requires extracting the shared
// session logic from Jake.swift and Mortal.swift into ClodSession, then having each
// servitor delegate to a ClodSession instance.

final class ClodSession: @unchecked Sendable {

    // MARK: - Configuration

    struct Config: Sendable {
        var systemPrompt: String
        var permissionMode: TavernKit.PermissionMode
        var workingDirectory: URL
        var mcpServers: [String: SDKMCPServer] = [:]
        var approvalHandler: ToolApprovalHandler?
        var planApprovalHandler: PlanApprovalHandler?
        var sessionKeyScheme: SessionKeyScheme
    }

    enum SessionKeyScheme: Sendable {
        case perProject(projectPath: String)   // Jake
        case perServitor(id: UUID)             // Mortal
    }

    // MARK: - State

    private var config: Config
    private let queue = DispatchQueue(label: "com.tavern.ClodSession")
    private var _sessionId: String?
    private let messenger: ServitorMessenger

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "session")

    // MARK: - Public Properties

    var sessionId: String? {
        queue.sync { _sessionId }
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

    init(config: Config, messenger: ServitorMessenger? = nil) {
        self.config = config
        self.messenger = messenger ?? LiveMessenger(
            approvalHandler: config.approvalHandler,
            planApprovalHandler: config.planApprovalHandler
        )

        // Load saved session based on key scheme
        switch config.sessionKeyScheme {
        case .perProject(let path):
            _sessionId = SessionStore.loadJakeSession(projectPath: path)
        case .perServitor(let id):
            _sessionId = SessionStore.loadServitorSession(servitorId: id)
        }

        Self.logger.info("[ClodSession] initialized, scheme: \(String(describing: config.sessionKeyScheme)), hasSession: \(self._sessionId != nil)")
    }

    // MARK: - Communication

    func send(_ message: String) async throws -> (response: String, sessionId: String?) {
        let options = buildOptions()

        let result = try await messenger.query(prompt: message, options: options)

        if let newSessionId = result.sessionId {
            persistSession(newSessionId)
        }

        return result
    }

    func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let options = buildOptions()
        let (innerStream, innerCancel) = messenger.queryStreaming(prompt: message, options: options)
        let currentSessionId: String? = queue.sync { _sessionId }

        let wrappedStream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task { [weak self] in
                do {
                    for try await event in innerStream {
                        switch event {
                        case .completed(let info):
                            if let sessionId = info.sessionId, let self {
                                self.persistSession(sessionId)
                            }
                            continuation.yield(event)
                        default:
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
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

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        return (stream: wrappedStream, cancel: innerCancel)
    }

    func resetConversation() {
        queue.sync { _sessionId = nil }

        switch config.sessionKeyScheme {
        case .perProject(let path):
            SessionStore.clearJakeSession(projectPath: path)
        case .perServitor(let id):
            SessionStore.clearServitorSession(servitorId: id)
        }

        Self.logger.info("[ClodSession] conversation reset")
    }

    // MARK: - Private

    private func buildOptions() -> QueryOptions {
        let (sessionId, mode, mcpServers) = queue.sync {
            (_sessionId, config.permissionMode, config.mcpServers)
        }

        var options = QueryOptions()
        options.systemPrompt = config.systemPrompt
        options.permissionMode = Self.mapPermissionMode(mode)
        options.workingDirectory = config.workingDirectory

        // Session resume disabled — stale sessions cause ControlProtocolError.timeout
        // TODO: Re-enable with fallback logic (try resume, catch timeout, start fresh)
        // if let sessionId {
        //     options.resume = sessionId
        // }

        for (key, server) in mcpServers {
            options.sdkMcpServers[key] = server
        }

        return options
    }

    private func persistSession(_ sessionId: String) {
        queue.sync { _sessionId = sessionId }

        switch config.sessionKeyScheme {
        case .perProject(let path):
            SessionStore.saveJakeSession(sessionId, projectPath: path)
        case .perServitor(let id):
            SessionStore.saveServitorSession(servitorId: id, sessionId: sessionId)
        }
    }

    /// Map Tavern's PermissionMode to ClodKit's PermissionMode — one place, not two.
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
