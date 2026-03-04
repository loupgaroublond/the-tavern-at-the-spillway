import Testing
import Foundation
import TavernKit
@testable import TavernBoardTile
@testable import ChatTile

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004

@Suite("ChatSocketPool Tests", .timeLimit(.minutes(1)))
@MainActor
struct ChatSocketPoolTests {

    // MARK: - Factory

    private static func makePool(
        provider: StubServitorProvider = StubServitorProvider(),
        commandProvider: StubCommandProvider = StubCommandProvider()
    ) -> ChatSocketPool {
        let navigator = StubNavigator()
        return ChatSocketPool(
            servitorProvider: provider,
            commandProvider: commandProvider,
            navigator: navigator
        )
    }

    // MARK: - Caching

    @Test("Pool returns same tile instance for same servitor ID")
    func cacheHit() {
        let pool = Self.makePool()
        let id = UUID()

        let tile1 = pool.tile(for: id)
        let tile2 = pool.tile(for: id)

        #expect(tile1 === tile2)
    }

    @Test("Pool returns different tiles for different servitor IDs")
    func cacheMiss() {
        let pool = Self.makePool()
        let idA = UUID()
        let idB = UUID()

        let tileA = pool.tile(for: idA)
        let tileB = pool.tile(for: idB)

        #expect(tileA !== tileB)
    }

    @Test("Tile state survives across multiple retrievals from pool")
    func statePersistsAcrossRetrieval() async {
        let pool = Self.makePool()
        let id = UUID()

        // First retrieval — send a message
        let tile = pool.tile(for: id)
        tile.inputText = "hello"
        await tile.sendMessage()
        let messageCount = tile.messages.count
        #expect(messageCount >= 1)

        // Second retrieval — same tile, same messages
        let sameTile = pool.tile(for: id)
        #expect(sameTile.messages.count == messageCount)
        #expect(sameTile.messages[0].content == "hello")
    }

    @Test("Messages survive switch-away and switch-back pattern")
    func switchAwayAndBack() async {
        let pool = Self.makePool()
        let idA = UUID()
        let idB = UUID()

        // Send message to A
        let tileA = pool.tile(for: idA)
        tileA.inputText = "message for A"
        await tileA.sendMessage()

        // Switch to B (simulates user clicking another servitor)
        let tileB = pool.tile(for: idB)
        tileB.inputText = "message for B"
        await tileB.sendMessage()

        // Switch back to A — must get same tile with messages intact
        let tileAAgain = pool.tile(for: idA)
        #expect(tileAAgain === tileA)
        #expect(tileAAgain.messages[0].content == "message for A")

        // B also intact
        let tileBAgain = pool.tile(for: idB)
        #expect(tileBAgain === tileB)
        #expect(tileBAgain.messages[0].content == "message for B")
    }

    // MARK: - Removal

    @Test("removeTile evicts from cache")
    func removeTile() {
        let pool = Self.makePool()
        let id = UUID()

        let original = pool.tile(for: id)
        pool.removeTile(for: id)
        let replacement = pool.tile(for: id)

        #expect(original !== replacement)
    }

    // MARK: - History Loading at Creation

    @Test("Pool triggers history load when creating a new tile")
    func historyLoadedAtCreation() async throws {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.historyResponses[id] = [
            ChatMessage(role: .user, content: "old message"),
            ChatMessage(role: .agent, content: "old reply")
        ]

        let pool = Self.makePool(provider: provider)
        let tile = pool.tile(for: id)

        // History load is kicked off via Task in pool.tile(for:)
        // Give it a moment to complete
        try await Task.sleep(for: .milliseconds(50))

        #expect(tile.messages.count == 2)
        #expect(tile.messages[0].content == "old message")
    }

    @Test("History load does not overwrite messages sent before load completes")
    func historyDoesNotOverwriteNewMessages() async throws {
        let id = UUID()
        let provider = StubServitorProvider()
        // Provider will return old history
        provider.historyResponses[id] = [
            ChatMessage(role: .agent, content: "stale history")
        ]

        let pool = Self.makePool(provider: provider)
        let tile = pool.tile(for: id)

        // Immediately send a message before history load Task runs
        tile.inputText = "new message"
        await tile.sendMessage()

        // Let the history load Task run
        try await Task.sleep(for: .milliseconds(50))

        // New message must not be overwritten by stale history
        #expect(tile.messages[0].content == "new message")
        #expect(!tile.messages.contains(where: { $0.content == "stale history" }))
    }
}

// MARK: - Stub Navigator

@MainActor
private final class StubNavigator: TavernNavigator {
    func selectServitor(id: UUID) {}
    func spawnServitor() {}
    func closeServitor(id: UUID) {}
    func updateServitorDescription(id: UUID, description: String?) {}
    func presentToolApproval(for servitorID: UUID, request: ToolApprovalRequest) async -> ToolApprovalResponse {
        ToolApprovalResponse(approved: false, alwaysAllow: false)
    }
    func presentPlanApproval(for servitorID: UUID, request: PlanApprovalRequest) async -> PlanApprovalResponse {
        PlanApprovalResponse(approved: false, feedback: nil)
    }
    func respondToToolApproval(_ response: ToolApprovalResponse) {}
    func respondToPlanApproval(_ response: PlanApprovalResponse) {}
    func dismissModal() {}
    func toggleSidePane() {}
    func selectSidePaneTab(_ tab: SidePaneTab) {}
    func servitorActivityChanged(id: UUID, activity: ServitorActivity) {}
    func presentPermissionSettings() {}
}
