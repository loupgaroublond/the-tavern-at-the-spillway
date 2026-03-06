import Foundation

public protocol ServitorProvider: Sendable {
    func sendStreaming(servitorID: UUID, message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void)
    func loadHistory(servitorID: UUID) async -> [ChatMessage]
    func clearConversation(servitorID: UUID)
    func servitorName(for id: UUID) -> String
    func sessionMode(for id: UUID) -> PermissionMode
    func setSessionMode(_ mode: PermissionMode, for id: UUID)
    func allServitors() -> [ServitorListItem]

    @discardableResult
    func spawnServitor() throws -> UUID

    @discardableResult
    func spawnServitor(assignment: String) throws -> UUID

    func closeServitor(id: UUID) throws
    func updateDescription(id: UUID, description: String?)
}
