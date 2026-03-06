import Foundation
import TavernKit
import ClodKit
import os.log

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004, REQ-ARCH-008

public final class ClodSessionManager: @unchecked Sendable, ServitorProvider {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sessionmgr")

    let jake: Jake
    let spawner: MortalSpawner
    private let permissionManager: PermissionManager
    private let projectURL: URL
    private let directory: ProjectDirectory

    var jakeMCPServer: SDKMCPServer? {
        get { jake.mcpServer }
        set { jake.mcpServer = newValue }
    }

    // MARK: - Initialization

    public init(
        jake: Jake,
        spawner: MortalSpawner,
        permissionManager: PermissionManager,
        projectURL: URL,
        directory: ProjectDirectory
    ) {
        self.jake = jake
        self.spawner = spawner
        self.permissionManager = permissionManager
        self.projectURL = projectURL
        self.directory = directory

        Self.logger.info("[ClodSessionManager] initialized for project: \(projectURL.lastPathComponent)")
    }

    // MARK: - ServitorProvider

    public func sendStreaming(servitorID: UUID, message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let servitor: (any Servitor)?
        if servitorID == jake.id {
            servitor = jake
        } else {
            servitor = spawner.activeMortals.first(where: { $0.id == servitorID })
        }

        guard let servitor else {
            let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
                continuation.finish(throwing: TavernError.internalError("Servitor not found: \(servitorID)"))
            }
            return (stream: stream, cancel: {})
        }

        let (innerStream, innerCancel) = servitor.sendStreaming(message)

        // Wrap to persist session IDs after completion (policy layer)
        let wrappedStream = wrapStreamWithPersistence(innerStream, servitor: servitor)

        return (stream: wrappedStream, cancel: innerCancel)
    }

    public func loadHistory(servitorID: UUID) async -> [ChatMessage] {
        let projectPath = projectURL.path

        if servitorID == jake.id {
            let stored = await SessionStore.loadJakeSessionHistory(projectPath: projectPath, sessionId: jake.sessionId)
            return stored.compactMap { Self.convertStoredMessage($0) }
        }

        // Look up the session ID from our file-system store
        let servitorName = servitorName(for: servitorID)
        guard servitorName != "Unknown",
              let record = try? directory.loadServitor(name: servitorName),
              let sessionId = record.sessionId else {
            Self.logger.info("[ClodSessionManager] no session ID for servitor \(servitorID), skipping history load")
            return []
        }

        let storage = ClaudeNativeSessionStorage()
        do {
            let messages = try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
            return messages.compactMap { Self.convertStoredMessage($0) }
        } catch {
            Self.logger.error("[ClodSessionManager] failed to load history for \(servitorName): \(error.localizedDescription)")
            return []
        }
    }

    public func clearConversation(servitorID: UUID) {
        if servitorID == jake.id {
            jake.resetConversation()
        } else if let mortal = spawner.activeMortals.first(where: { $0.id == servitorID }) as? Mortal {
            mortal.resetConversation()
        }
    }

    public func servitorName(for id: UUID) -> String {
        if id == jake.id { return jake.name }
        if let servitor = spawner.activeMortals.first(where: { $0.id == id }) {
            return servitor.name
        }
        return "Unknown"
    }

    public func sessionMode(for id: UUID) -> TavernKit.PermissionMode {
        if id == jake.id { return jake.sessionMode }
        if let servitor = spawner.activeMortals.first(where: { $0.id == id }) {
            return servitor.sessionMode
        }
        return .plan
    }

    public func setSessionMode(_ mode: TavernKit.PermissionMode, for id: UUID) {
        if id == jake.id {
            jake.sessionMode = mode
        } else if let servitor = spawner.activeMortals.first(where: { $0.id == id }) {
            servitor.sessionMode = mode
        }
    }

    public func allServitors() -> [ServitorListItem] {
        var items: [ServitorListItem] = [ServitorListItem.from(jake: jake)]
        for mortal in spawner.activeMortals {
            if let m = mortal as? Mortal {
                items.append(ServitorListItem.from(mortal: m))
            }
        }
        return items
    }

    @discardableResult
    public func spawnServitor() throws -> UUID {
        let mortal = try spawner.summon()
        persistServitorRecord(mortal)
        Self.logger.info("[ClodSessionManager] spawned servitor: \(mortal.name) (\(mortal.id))")
        return mortal.id
    }

    @discardableResult
    public func spawnServitor(assignment: String) throws -> UUID {
        let mortal = try spawner.summon(assignment: assignment)
        persistServitorRecord(mortal)
        Self.logger.info("[ClodSessionManager] spawned servitor with assignment: \(mortal.name) (\(mortal.id))")
        return mortal.id
    }

    public func closeServitor(id: UUID) throws {
        // Find the servitor name before removing
        let servitorName = spawner.activeMortals.first(where: { $0.id == id })?.name
        try spawner.dismiss(id: id)

        // Remove from file-system store
        if let name = servitorName {
            do {
                try directory.removeServitor(name: name)
            } catch {
                Self.logger.error("[ClodSessionManager] failed to remove store for \(name): \(error.localizedDescription)")
            }
        }

        Self.logger.info("[ClodSessionManager] closed servitor: \(servitorName ?? id.uuidString)")
    }

    public func updateDescription(id: UUID, description: String?) {
        if let mortal = spawner.activeMortals.first(where: { $0.id == id }) as? Mortal {
            mortal.chatDescription = description

            // Update in file-system store
            do {
                if var record = try directory.loadServitor(name: mortal.name) {
                    record.description = description
                    record.updatedAt = Date()
                    try directory.saveServitor(record)
                }
            } catch {
                Self.logger.error("[ClodSessionManager] failed to update description for \(mortal.name): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    private func persistServitorRecord(_ mortal: Mortal) {
        let record = ServitorRecord(
            name: mortal.name,
            id: mortal.id,
            assignment: mortal.assignment,
            sessionId: mortal.sessionId,
            description: mortal.chatDescription
        )
        do {
            try directory.saveServitor(record)
        } catch {
            Self.logger.error("[ClodSessionManager] failed to persist record for \(mortal.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Stream Wrapping

    private func wrapStreamWithPersistence(
        _ innerStream: AsyncThrowingStream<StreamEvent, Error>,
        servitor: any Servitor
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<StreamEvent, Error>.makeStream()
        let task = Task { [weak self] in
            do {
                for try await event in innerStream {
                    if case .completed = event {
                        self?.persistSessionId(for: servitor)
                    } else if case .sessionBreak(let staleId) = event {
                        self?.logSessionExpired(servitorName: servitor.name, staleSessionId: staleId)
                    }
                    continuation.yield(event)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { @Sendable _ in task.cancel() }
        return stream
    }

    // MARK: - Session Persistence (policy layer — moved from ClodSession)

    private func persistSessionId(for servitor: any Servitor) {
        guard let sessionId = servitor.sessionId else { return }
        let servitorName = servitor.name.lowercased() == "jake" ? "jake" : servitor.name
        do {
            if var record = try directory.loadServitor(name: servitorName) {
                record.sessionId = sessionId
                record.updatedAt = Date()
                try directory.saveServitor(record)
            }
        } catch {
            Self.logger.error("[ClodSessionManager] failed to persist session for \(servitorName): \(error.localizedDescription)")
        }
    }

    private func logSessionExpired(servitorName: String, staleSessionId: String) {
        let event = SessionEvent(event: .sessionExpired, sessionId: staleSessionId, timestamp: Date(), reason: "timeout")
        do {
            try directory.appendSessionEvent(event, name: servitorName)
        } catch {
            Self.logger.error("[ClodSessionManager] failed to log session expired for \(servitorName): \(error.localizedDescription)")
        }
    }

    private static func convertStoredMessage(_ stored: ClaudeStoredMessage) -> ChatMessage? {
        let role: ChatMessage.Role
        switch stored.role {
        case .user:
            role = .user
        case .assistant:
            role = .agent
        case .system:
            return nil
        }

        return ChatMessage(role: role, content: stored.content, messageType: .text)
    }
}
