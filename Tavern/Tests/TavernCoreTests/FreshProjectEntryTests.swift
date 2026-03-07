// MARK: - Provenance: REQ-UX-001

import Foundation
import Testing
@testable import TavernCore

@Suite("Fresh Project Entry", .tags(.reqUX001), .timeLimit(.minutes(2)))
struct FreshProjectEntryTests {

    // MARK: - Test Helpers

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    private static func createFreshSessionManager() -> ClodSessionManager {
        let projectURL = testProjectURL()
        let jake = Jake(projectURL: projectURL)
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        let permissionManager = PermissionManager(store: PermissionStore())
        let directory = ProjectDirectory(rootURL: projectURL)

        return ClodSessionManager(
            jake: jake,
            spawner: spawner,
            permissionManager: permissionManager,
            projectURL: projectURL,
            directory: directory
        )
    }

    // MARK: - Jake Present and Ready

    @Test("Fresh project has Jake as the only servitor")
    func freshProjectHasOnlyJake() {
        let manager = Self.createFreshSessionManager()

        let servitors = manager.allServitors()

        #expect(servitors.count == 1)
        #expect(servitors[0].isJake == true)
        #expect(servitors[0].name == "Jake")
    }

    @Test("Jake is idle on fresh project entry")
    func jakeIsIdleOnFreshEntry() {
        let manager = Self.createFreshSessionManager()

        let servitors = manager.allServitors()

        #expect(servitors[0].state == .idle)
    }

    @Test("Jake has no prior session on fresh project")
    func jakeHasNoPriorSession() {
        let manager = Self.createFreshSessionManager()

        #expect(manager.jake.sessionId == nil)
    }

    @Test("Jake state is idle (not working) before any interaction")
    func jakeStateIsIdleBeforeInteraction() {
        let manager = Self.createFreshSessionManager()

        #expect(manager.jake.state == .idle)
        #expect(manager.jake.isCogitating == false)
    }

    // MARK: - Chat Area Empty

    @Test("Fresh project chat history is empty for Jake")
    func freshProjectChatHistoryIsEmpty() async {
        let manager = Self.createFreshSessionManager()

        let history = await manager.loadHistory(servitorID: manager.jake.id)

        #expect(history.isEmpty)
    }

    @Test("No stale messages from previous sessions")
    func noStaleMessagesFromPreviousSessions() async {
        let manager = Self.createFreshSessionManager()

        // Load history twice to ensure no phantom messages appear
        let firstLoad = await manager.loadHistory(servitorID: manager.jake.id)
        let secondLoad = await manager.loadHistory(servitorID: manager.jake.id)

        #expect(firstLoad.isEmpty)
        #expect(secondLoad.isEmpty)
    }

    // MARK: - Servitor List Shows Only Jake

    @Test("No mortals exist on fresh project entry")
    func noMortalsOnFreshEntry() {
        let manager = Self.createFreshSessionManager()

        let servitors = manager.allServitors()
        let mortals = servitors.filter { !$0.isJake }

        #expect(mortals.isEmpty)
    }

    @Test("Servitor name lookup works for Jake on fresh project")
    func servitorNameLookupWorksForJake() {
        let manager = Self.createFreshSessionManager()

        let name = manager.servitorName(for: manager.jake.id)

        #expect(name == "Jake")
    }

    @Test("Servitor name lookup returns Unknown for non-existent IDs")
    func servitorNameLookupReturnsUnknownForBogusId() {
        let manager = Self.createFreshSessionManager()

        let name = manager.servitorName(for: UUID())

        #expect(name == "Unknown")
    }

    // MARK: - Jake as Single Entry Point

    @Test("Jake is the single entry point — first item in servitor list")
    func jakeIsFirstItemInServitorList() {
        let manager = Self.createFreshSessionManager()

        let servitors = manager.allServitors()

        #expect(!servitors.isEmpty)
        #expect(servitors.first?.isJake == true)
        #expect(servitors.first?.name == "Jake")
    }

    @Test("Fresh project Jake defaults to plan mode")
    func freshProjectJakeDefaultsToPlanMode() {
        let manager = Self.createFreshSessionManager()

        let mode = manager.sessionMode(for: manager.jake.id)

        #expect(mode == .plan)
    }

    @Test("Clear conversation on fresh project is a no-op")
    func clearConversationOnFreshProjectIsNoOp() {
        let manager = Self.createFreshSessionManager()

        // Should not crash or produce side effects
        manager.clearConversation(servitorID: manager.jake.id)

        #expect(manager.jake.sessionId == nil)
        #expect(manager.jake.state == .idle)
    }
}
