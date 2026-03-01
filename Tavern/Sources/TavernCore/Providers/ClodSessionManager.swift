import Foundation
import TavernKit
import ClodKit
import os.log

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004, REQ-ARCH-008

@MainActor
public final class ClodSessionManager: ServitorProvider {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sessionmgr")

    let jake: Jake
    let spawner: MortalSpawner
    private let permissionManager: PermissionManager
    private let commandDispatcher: SlashCommandDispatcher
    private let projectURL: URL

    var jakeMCPServer: SDKMCPServer? {
        get { jake.mcpServer }
        set { jake.mcpServer = newValue }
    }

    // MARK: - Initialization

    public init(
        jake: Jake,
        spawner: MortalSpawner,
        permissionManager: PermissionManager,
        commandDispatcher: SlashCommandDispatcher,
        projectURL: URL
    ) {
        self.jake = jake
        self.spawner = spawner
        self.permissionManager = permissionManager
        self.commandDispatcher = commandDispatcher
        self.projectURL = projectURL

        Self.logger.info("[ClodSessionManager] initialized for project: \(projectURL.lastPathComponent)")
    }

    // MARK: - ServitorProvider

    public func sendStreaming(servitorID: UUID, message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        if servitorID == jake.id {
            return jake.sendStreaming(message)
        }
        if let mortal = spawner.activeMortals.first(where: { $0.id == servitorID }) {
            return mortal.sendStreaming(message)
        }
        // Unknown servitor — return an error stream
        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            continuation.finish(throwing: TavernError.internalError("Servitor not found: \(servitorID)"))
        }
        return (stream: stream, cancel: {})
    }

    public func loadHistory(servitorID: UUID) async -> [ChatMessage] {
        let projectPath = projectURL.path

        if servitorID == jake.id {
            let stored = await SessionStore.loadJakeSessionHistory(projectPath: projectPath)
            return stored.compactMap { Self.convertStoredMessage($0) }
        }

        let stored = await SessionStore.loadServitorSessionHistory(
            servitorId: servitorID,
            projectPath: projectPath
        )
        return stored.compactMap { Self.convertStoredMessage($0) }
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
        persistServitor(mortal)
        Self.logger.info("[ClodSessionManager] spawned servitor: \(mortal.name) (\(mortal.id))")
        return mortal.id
    }

    @discardableResult
    public func spawnServitor(assignment: String) throws -> UUID {
        let mortal = try spawner.summon(assignment: assignment)
        persistServitor(mortal)
        Self.logger.info("[ClodSessionManager] spawned servitor with assignment: \(mortal.name) (\(mortal.id))")
        return mortal.id
    }

    public func closeServitor(id: UUID) throws {
        SessionStore.removeServitor(id: id)
        try spawner.dismiss(id: id)
        Self.logger.info("[ClodSessionManager] closed servitor: \(id)")
    }

    public func updateDescription(id: UUID, description: String?) {
        SessionStore.updateServitor(id: id, chatDescription: description)
        if let mortal = spawner.activeMortals.first(where: { $0.id == id }) as? Mortal {
            mortal.chatDescription = description
        }
    }

    // MARK: - Private Helpers

    private func persistServitor(_ mortal: Mortal) {
        let persisted = SessionStore.PersistedServitor(
            id: mortal.id,
            name: mortal.name,
            sessionId: mortal.sessionId,
            chatDescription: mortal.chatDescription
        )
        SessionStore.addServitor(persisted)
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
