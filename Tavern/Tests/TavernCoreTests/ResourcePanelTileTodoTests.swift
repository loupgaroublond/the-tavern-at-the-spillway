import Foundation
import Testing
import TavernKit
@testable import ResourcePanelTile

@Suite("ResourcePanelTile TODO Tests", .timeLimit(.minutes(1)))
@MainActor
struct ResourcePanelTileTodoTests {

    // MARK: - Helpers

    private static func makeTile() -> ResourcePanelTile {
        let provider = StubResourceProvider()
        let responder = ResourcePanelResponder(onFileSelected: { _ in })
        let root = URL(fileURLWithPath: "/tmp/test-\(UUID().uuidString)")
        return ResourcePanelTile(resourceProvider: provider, responder: responder, rootURL: root)
    }

    // MARK: - Initial State

    @Test("Starts with empty list")
    func startsEmpty() {
        let tile = Self.makeTile()
        #expect(tile.todoItems.isEmpty)
        #expect(tile.todoDraftText == "")
        #expect(tile.pendingCount == 0)
        #expect(tile.completedCount == 0)
    }

    // MARK: - Adding Items

    @Test("Add item from draft creates uncompleted item")
    func addItemFromDraft() {
        let tile = Self.makeTile()
        tile.todoDraftText = "Buy milk"

        tile.addTodoItem()

        #expect(tile.todoItems.count == 1)
        #expect(tile.todoItems[0].text == "Buy milk")
        #expect(tile.todoItems[0].isCompleted == false)
        #expect(tile.todoDraftText == "")
        #expect(tile.pendingCount == 1)
    }

    @Test("Add item trims whitespace")
    func addItemTrimsWhitespace() {
        let tile = Self.makeTile()
        tile.todoDraftText = "  Walk the dog  "

        tile.addTodoItem()

        #expect(tile.todoItems.count == 1)
        #expect(tile.todoItems[0].text == "Walk the dog")
    }

    @Test("Add empty draft is a no-op")
    func addEmptyDraftIsNoOp() {
        let tile = Self.makeTile()
        tile.todoDraftText = ""

        tile.addTodoItem()

        #expect(tile.todoItems.isEmpty)
    }

    @Test("Add whitespace-only draft is a no-op")
    func addWhitespaceOnlyDraftIsNoOp() {
        let tile = Self.makeTile()
        tile.todoDraftText = "   "

        tile.addTodoItem()

        #expect(tile.todoItems.isEmpty)
    }

    @Test("Items added in order")
    func itemsInOrder() {
        let tile = Self.makeTile()
        tile.todoDraftText = "First"
        tile.addTodoItem()
        tile.todoDraftText = "Second"
        tile.addTodoItem()
        tile.todoDraftText = "Third"
        tile.addTodoItem()

        #expect(tile.todoItems.count == 3)
        #expect(tile.todoItems[0].text == "First")
        #expect(tile.todoItems[1].text == "Second")
        #expect(tile.todoItems[2].text == "Third")
    }

    // MARK: - Toggle

    @Test("Toggle item completes it")
    func toggleItemCompletes() {
        let tile = Self.makeTile()
        tile.todoDraftText = "Toggle me"
        tile.addTodoItem()
        let id = tile.todoItems[0].id

        tile.toggleTodoItem(id)

        #expect(tile.todoItems[0].isCompleted == true)
        #expect(tile.pendingCount == 0)
        #expect(tile.completedCount == 1)
    }

    @Test("Toggle completed item uncompletes it")
    func toggleCompletedUncompletes() {
        let tile = Self.makeTile()
        tile.todoDraftText = "Toggle twice"
        tile.addTodoItem()
        let id = tile.todoItems[0].id
        tile.toggleTodoItem(id)

        tile.toggleTodoItem(id)

        #expect(tile.todoItems[0].isCompleted == false)
        #expect(tile.pendingCount == 1)
        #expect(tile.completedCount == 0)
    }

    @Test("Toggle nonexistent item does not crash")
    func toggleNonexistent() {
        let tile = Self.makeTile()
        tile.toggleTodoItem(UUID())
        #expect(tile.todoItems.isEmpty)
    }

    // MARK: - Remove

    @Test("Remove item")
    func removeItem() {
        let tile = Self.makeTile()
        tile.todoDraftText = "Remove me"
        tile.addTodoItem()
        let id = tile.todoItems[0].id

        tile.removeTodoItem(id)

        #expect(tile.todoItems.isEmpty)
    }

    @Test("Remove middle item preserves others")
    func removeMiddleItem() {
        let tile = Self.makeTile()
        tile.todoDraftText = "First"
        tile.addTodoItem()
        tile.todoDraftText = "Middle"
        tile.addTodoItem()
        tile.todoDraftText = "Last"
        tile.addTodoItem()
        let middleId = tile.todoItems[1].id

        tile.removeTodoItem(middleId)

        #expect(tile.todoItems.count == 2)
        #expect(tile.todoItems[0].text == "First")
        #expect(tile.todoItems[1].text == "Last")
    }

    @Test("Remove nonexistent item does not crash")
    func removeNonexistent() {
        let tile = Self.makeTile()
        tile.removeTodoItem(UUID())
        #expect(tile.todoItems.isEmpty)
    }

    // MARK: - Clear Completed

    @Test("Clear completed removes only completed items")
    func clearCompleted() {
        let tile = Self.makeTile()
        tile.todoDraftText = "Pending"
        tile.addTodoItem()
        tile.todoDraftText = "Done"
        tile.addTodoItem()
        tile.todoDraftText = "Also Pending"
        tile.addTodoItem()
        tile.toggleTodoItem(tile.todoItems[1].id)

        tile.clearCompletedTodos()

        #expect(tile.todoItems.count == 2)
        #expect(tile.todoItems[0].text == "Pending")
        #expect(tile.todoItems[1].text == "Also Pending")
    }

    @Test("Clear completed with no completed items is a no-op")
    func clearCompletedNoOp() {
        let tile = Self.makeTile()
        tile.todoDraftText = "Still pending"
        tile.addTodoItem()

        tile.clearCompletedTodos()

        #expect(tile.todoItems.count == 1)
    }

    // MARK: - Counts

    @Test("Counts reflect mixed states")
    func countsMixedStates() {
        let tile = Self.makeTile()
        tile.todoDraftText = "Pending 1"
        tile.addTodoItem()
        tile.todoDraftText = "Done 1"
        tile.addTodoItem()
        tile.todoDraftText = "Pending 2"
        tile.addTodoItem()
        tile.todoDraftText = "Done 2"
        tile.addTodoItem()
        tile.toggleTodoItem(tile.todoItems[1].id)
        tile.toggleTodoItem(tile.todoItems[3].id)

        #expect(tile.pendingCount == 2)
        #expect(tile.completedCount == 2)
    }
}
