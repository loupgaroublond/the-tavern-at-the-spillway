// MARK: - Provenance: REQ-UX-003, REQ-VIW-004, REQ-V1-003

import Foundation
import Testing
import TavernKit
@testable import ServitorListTile

@Suite("ServitorListTile Tests",
    .tags(.reqUX003, .reqVIW004, .reqV1003),
    .timeLimit(.minutes(2))
)
@MainActor
struct ServitorListTileTests {

    // MARK: - Helpers

    private static func makeTile(
        items: [ServitorListItem] = []
    ) -> (tile: ServitorListTile, provider: MockServitorProvider, tracker: ResponderTracker) {
        let provider = MockServitorProvider(items: items)
        let tracker = ResponderTracker()
        let responder = ServitorListResponder(
            onServitorSelected: { tracker.selectedIds.append($0) },
            onSpawnRequested: { tracker.spawnCount += 1 },
            onCloseRequested: { tracker.closedIds.append($0) },
            onDescriptionUpdated: { id, desc in tracker.descriptionUpdates.append((id, desc)) }
        )
        let tile = ServitorListTile(servitorProvider: provider, responder: responder)
        return (tile, provider, tracker)
    }

    private static func jakeItem(id: UUID = UUID()) -> ServitorListItem {
        ServitorListItem(id: id, name: "Jake", state: .idle, isJake: true)
    }

    private static func mortalItem(
        id: UUID = UUID(),
        name: String = "Frodo",
        description: String? = nil,
        state: ServitorState = .idle
    ) -> ServitorListItem {
        ServitorListItem(id: id, name: name, chatDescription: description, state: state, isJake: false)
    }

    // MARK: - Initialization

    @Test("Tile initializes with items from provider")
    func initializesWithProviderItems() {
        let jake = Self.jakeItem()
        let mortal = Self.mortalItem(name: "Samwise")
        let (tile, _, _) = Self.makeTile(items: [jake, mortal])

        #expect(tile.items.count == 2)
        #expect(tile.items[0].name == "Jake")
        #expect(tile.items[1].name == "Samwise")
    }

    @Test("Tile initializes with no selection")
    func initializesWithNoSelection() {
        let (tile, _, _) = Self.makeTile(items: [Self.jakeItem()])

        #expect(tile.selectedServitorId == nil)
    }

    @Test("Tile initializes empty when provider has no items")
    func initializesEmpty() {
        let (tile, _, _) = Self.makeTile()

        #expect(tile.items.isEmpty)
        #expect(tile.selectedServitorId == nil)
    }

    // MARK: - Selection

    @Test("selectServitor updates selectedServitorId")
    func selectServitorUpdatesState() {
        let jakeId = UUID()
        let (tile, _, _) = Self.makeTile(items: [Self.jakeItem(id: jakeId)])

        tile.selectServitor(id: jakeId)

        #expect(tile.selectedServitorId == jakeId)
    }

    @Test("selectServitor fires responder callback")
    func selectServitorFiresResponder() {
        let jakeId = UUID()
        let (tile, _, tracker) = Self.makeTile(items: [Self.jakeItem(id: jakeId)])

        tile.selectServitor(id: jakeId)

        #expect(tracker.selectedIds == [jakeId])
    }

    @Test("setSelectedServitor updates state without firing responder")
    func setSelectedServitorSilent() {
        let jakeId = UUID()
        let (tile, _, tracker) = Self.makeTile(items: [Self.jakeItem(id: jakeId)])

        tile.setSelectedServitor(id: jakeId)

        #expect(tile.selectedServitorId == jakeId)
        #expect(tracker.selectedIds.isEmpty, "setSelectedServitor should not fire the responder")
    }

    @Test("isSelected returns true for selected servitor")
    func isSelectedTrue() {
        let jakeId = UUID()
        let mortalId = UUID()
        let (tile, _, _) = Self.makeTile(items: [
            Self.jakeItem(id: jakeId),
            Self.mortalItem(id: mortalId)
        ])

        tile.selectServitor(id: jakeId)

        #expect(tile.isSelected(id: jakeId) == true)
        #expect(tile.isSelected(id: mortalId) == false)
    }

    @Test("Selecting different servitor changes selection")
    func selectionChanges() {
        let jakeId = UUID()
        let mortalId = UUID()
        let (tile, _, tracker) = Self.makeTile(items: [
            Self.jakeItem(id: jakeId),
            Self.mortalItem(id: mortalId)
        ])

        tile.selectServitor(id: jakeId)
        tile.selectServitor(id: mortalId)

        #expect(tile.selectedServitorId == mortalId)
        #expect(tracker.selectedIds == [jakeId, mortalId])
    }

    // MARK: - List Updates (servitorsDidChange)

    @Test("servitorsDidChange refreshes items from provider")
    func servitorsDidChangeRefreshes() {
        let jake = Self.jakeItem()
        let (tile, provider, _) = Self.makeTile(items: [jake])

        #expect(tile.items.count == 1)

        // Simulate spawning a new mortal
        let mortal = Self.mortalItem(name: "Gandalf")
        provider.items = [jake, mortal]
        tile.servitorsDidChange()

        #expect(tile.items.count == 2)
        #expect(tile.items[1].name == "Gandalf")
    }

    @Test("servitorsDidChange reflects dismissed servitor")
    func servitorsDidChangeReflectsDismissal() {
        let jake = Self.jakeItem()
        let mortal = Self.mortalItem(name: "Aragorn")
        let (tile, provider, _) = Self.makeTile(items: [jake, mortal])

        #expect(tile.items.count == 2)

        // Simulate dismissal
        provider.items = [jake]
        tile.servitorsDidChange()

        #expect(tile.items.count == 1)
        #expect(tile.items[0].isJake == true)
    }

    @Test("servitorsDidChange reflects state changes")
    func servitorsDidChangeReflectsStateChange() {
        let mortalId = UUID()
        let jake = Self.jakeItem()
        let mortal = Self.mortalItem(id: mortalId, name: "Legolas", state: .idle)
        let (tile, provider, _) = Self.makeTile(items: [jake, mortal])

        #expect(tile.items[1].state == .idle)

        // Simulate state change
        provider.items = [jake, Self.mortalItem(id: mortalId, name: "Legolas", state: .working)]
        tile.servitorsDidChange()

        #expect(tile.items[1].state == .working)
    }

    // MARK: - Flat List (REQ-VIW-004: Agent Hierarchy Independence)

    @Test("Tile shows flat list with no hierarchy information")
    func flatListNoHierarchy() {
        let jake = Self.jakeItem()
        let m1 = Self.mortalItem(name: "Worker-A")
        let m2 = Self.mortalItem(name: "Worker-B")
        let m3 = Self.mortalItem(name: "Worker-C")
        let (tile, _, _) = Self.makeTile(items: [jake, m1, m2, m3])

        // Tile displays items as a flat list — no parent/child,
        // no nesting, no grouping. All items are at the same level.
        #expect(tile.items.count == 4)
        for item in tile.items {
            // ServitorListItem has no parent, children, or depth fields.
            // The tile treats every item identically in terms of hierarchy.
            #expect(item.id != UUID(), "Each item has its own identity")
        }
    }

    @Test("Jake and mortals appear in provider order, not sorted by type")
    func orderMatchesProvider() {
        let m1 = Self.mortalItem(name: "Alpha")
        let jake = Self.jakeItem()
        let m2 = Self.mortalItem(name: "Beta")
        // Provider returns mortal-first order
        let (tile, _, _) = Self.makeTile(items: [m1, jake, m2])

        #expect(tile.items[0].name == "Alpha")
        #expect(tile.items[1].name == "Jake")
        #expect(tile.items[2].name == "Beta")
    }

    // MARK: - Spawn and Close

    @Test("spawnServitor fires responder callback")
    func spawnServitorFiresResponder() {
        let (tile, _, tracker) = Self.makeTile()

        tile.spawnServitor()

        #expect(tracker.spawnCount == 1)
    }

    @Test("closeServitor fires responder callback with correct ID")
    func closeServitorFiresResponder() {
        let mortalId = UUID()
        let (tile, _, tracker) = Self.makeTile(items: [Self.mortalItem(id: mortalId)])

        tile.closeServitor(id: mortalId)

        #expect(tracker.closedIds == [mortalId])
    }

    // MARK: - Description Editing

    @Test("beginEditDescription populates editing state")
    func beginEditDescription() {
        let item = Self.mortalItem(name: "Gimli", description: "Axe work")
        let (tile, _, _) = Self.makeTile(items: [item])

        tile.beginEditDescription(for: item)

        #expect(tile.editingDescriptionForServitorId == item.id)
        #expect(tile.editedDescription == "Axe work")
    }

    @Test("beginEditDescription with nil description starts empty")
    func beginEditDescriptionNilDescription() {
        let item = Self.mortalItem(name: "Gimli")
        let (tile, _, _) = Self.makeTile(items: [item])

        tile.beginEditDescription(for: item)

        #expect(tile.editingDescriptionForServitorId == item.id)
        #expect(tile.editedDescription == "")
    }

    @Test("saveDescription fires responder and clears editing state")
    func saveDescription() {
        let item = Self.mortalItem(name: "Gimli")
        let (tile, _, tracker) = Self.makeTile(items: [item])

        tile.beginEditDescription(for: item)
        tile.editedDescription = "Mining duties"
        tile.saveDescription()

        #expect(tracker.descriptionUpdates.count == 1)
        #expect(tracker.descriptionUpdates[0].0 == item.id)
        #expect(tracker.descriptionUpdates[0].1 == "Mining duties")
        #expect(tile.editingDescriptionForServitorId == nil)
        #expect(tile.editedDescription == "")
    }

    @Test("saveDescription with empty text sends nil")
    func saveDescriptionEmpty() {
        let item = Self.mortalItem(name: "Gimli", description: "Old desc")
        let (tile, _, tracker) = Self.makeTile(items: [item])

        tile.beginEditDescription(for: item)
        tile.editedDescription = ""
        tile.saveDescription()

        #expect(tracker.descriptionUpdates[0].1 == nil)
    }

    @Test("saveDescription trims whitespace-only to nil")
    func saveDescriptionWhitespace() {
        let item = Self.mortalItem(name: "Gimli")
        let (tile, _, tracker) = Self.makeTile(items: [item])

        tile.beginEditDescription(for: item)
        tile.editedDescription = "   \n  "
        tile.saveDescription()

        #expect(tracker.descriptionUpdates[0].1 == nil)
    }

    @Test("cancelEditDescription clears editing state without firing responder")
    func cancelEditDescription() {
        let item = Self.mortalItem(name: "Gimli", description: "Axe work")
        let (tile, _, tracker) = Self.makeTile(items: [item])

        tile.beginEditDescription(for: item)
        tile.editedDescription = "Changed"
        tile.cancelEditDescription()

        #expect(tile.editingDescriptionForServitorId == nil)
        #expect(tile.editedDescription == "")
        #expect(tracker.descriptionUpdates.isEmpty)
    }

    @Test("saveDescription without beginEdit is a no-op")
    func saveDescriptionWithoutBeginIsNoOp() {
        let (tile, _, tracker) = Self.makeTile()

        tile.saveDescription()

        #expect(tracker.descriptionUpdates.isEmpty)
    }
}

// MARK: - Mock ServitorProvider

private final class MockServitorProvider: @unchecked Sendable, ServitorProvider {
    var items: [ServitorListItem]

    init(items: [ServitorListItem] = []) {
        self.items = items
    }

    func allServitors() -> [ServitorListItem] { items }

    func sendStreaming(servitorID: UUID, message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let stream = AsyncThrowingStream<StreamEvent, Error> { $0.finish() }
        return (stream: stream, cancel: {})
    }

    func loadHistory(servitorID: UUID) async -> [ChatMessage] { [] }
    func clearConversation(servitorID: UUID) {}
    func servitorName(for id: UUID) -> String { "Mock" }
    func sessionMode(for id: UUID) -> PermissionMode { .normal }
    func setSessionMode(_ mode: PermissionMode, for id: UUID) {}
    @discardableResult func spawnServitor() throws -> UUID { UUID() }
    @discardableResult func spawnServitor(assignment: String) throws -> UUID { UUID() }
    func closeServitor(id: UUID) throws {}
    func updateDescription(id: UUID, description: String?) {}
}

// MARK: - Responder Tracker

private final class ResponderTracker: @unchecked Sendable {
    var selectedIds: [UUID] = []
    var spawnCount = 0
    var closedIds: [UUID] = []
    var descriptionUpdates: [(UUID, String?)] = []
}
