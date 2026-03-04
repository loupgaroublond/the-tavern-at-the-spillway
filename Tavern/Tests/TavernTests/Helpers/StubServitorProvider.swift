import Foundation
import TavernKit
@testable import ChatTile

/// Stub ServitorProvider for testing ChatTile and ChatSocketPool
/// without real Claude sessions.
@MainActor
final class StubServitorProvider: ServitorProvider {
    var streamingResponses: [UUID: [StreamEvent]] = [:]
    var historyResponses: [UUID: [ChatMessage]] = [:]
    var servitorNames: [UUID: String] = [:]
    var sessionModes: [UUID: PermissionMode] = [:]
    var setSessionModeCalls: [(mode: PermissionMode, id: UUID)] = []
    var clearConversationCalls: [UUID] = []
    var spawnedIDs: [UUID] = []
    var closedIDs: [UUID] = []

    // MARK: - ServitorProvider

    func sendStreaming(servitorID: UUID, message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let events = streamingResponses[servitorID] ?? [
            .textDelta("Hello"),
            .completed(CompletionInfo(sessionId: "test-session", usage: SessionUsage(inputTokens: 10, outputTokens: 5)))
        ]
        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
        return (stream: stream, cancel: {})
    }

    func loadHistory(servitorID: UUID) async -> [ChatMessage] {
        historyResponses[servitorID] ?? []
    }

    func clearConversation(servitorID: UUID) {
        clearConversationCalls.append(servitorID)
    }

    func servitorName(for id: UUID) -> String {
        servitorNames[id] ?? "TestServitor"
    }

    func sessionMode(for id: UUID) -> PermissionMode {
        sessionModes[id] ?? .normal
    }

    func setSessionMode(_ mode: PermissionMode, for id: UUID) {
        setSessionModeCalls.append((mode: mode, id: id))
        sessionModes[id] = mode
    }

    func allServitors() -> [ServitorListItem] { [] }

    @discardableResult
    func spawnServitor() throws -> UUID {
        let id = UUID()
        spawnedIDs.append(id)
        return id
    }

    @discardableResult
    func spawnServitor(assignment: String) throws -> UUID {
        try spawnServitor()
    }

    func closeServitor(id: UUID) throws {
        closedIDs.append(id)
    }

    func updateDescription(id: UUID, description: String?) {}
}
