import Foundation
import Testing
@testable import TavernCore

@Suite("TodoListViewModel Tests")
@MainActor
struct TodoListViewModelTests {

    // MARK: - Initial State

    @Test("Starts with empty list")
    func startsEmpty() {
        let vm = TodoListViewModel()
        #expect(vm.items.isEmpty)
        #expect(vm.draftText == "")
        #expect(vm.pendingCount == 0)
        #expect(vm.completedCount == 0)
    }

    // MARK: - Adding Items via Draft

    @Test("Add item from draft creates uncompleted item")
    func addItemFromDraft() {
        let vm = TodoListViewModel()
        vm.draftText = "Buy milk"

        let id = vm.addItem()

        #expect(id != nil)
        #expect(vm.items.count == 1)
        #expect(vm.items[0].text == "Buy milk")
        #expect(vm.items[0].isCompleted == false)
        #expect(vm.draftText == "") // Draft cleared
        #expect(vm.pendingCount == 1)
    }

    @Test("Add item trims whitespace")
    func addItemTrimsWhitespace() {
        let vm = TodoListViewModel()
        vm.draftText = "  Walk the dog  "

        let id = vm.addItem()

        #expect(id != nil)
        #expect(vm.items[0].text == "Walk the dog")
    }

    @Test("Add empty draft returns nil")
    func addEmptyDraftReturnsNil() {
        let vm = TodoListViewModel()
        vm.draftText = ""

        let id = vm.addItem()

        #expect(id == nil)
        #expect(vm.items.isEmpty)
    }

    @Test("Add whitespace-only draft returns nil")
    func addWhitespaceOnlyDraftReturnsNil() {
        let vm = TodoListViewModel()
        vm.draftText = "   "

        let id = vm.addItem()

        #expect(id == nil)
        #expect(vm.items.isEmpty)
    }

    // MARK: - Adding Items Directly

    @Test("Add item with explicit text")
    func addItemWithText() {
        let vm = TodoListViewModel()

        let id = vm.addItem(text: "Explicit item")

        #expect(vm.items.count == 1)
        #expect(vm.items[0].id == id)
        #expect(vm.items[0].text == "Explicit item")
    }

    @Test("Items added in order")
    func itemsInOrder() {
        let vm = TodoListViewModel()
        vm.addItem(text: "First")
        vm.addItem(text: "Second")
        vm.addItem(text: "Third")

        #expect(vm.items.count == 3)
        #expect(vm.items[0].text == "First")
        #expect(vm.items[1].text == "Second")
        #expect(vm.items[2].text == "Third")
    }

    // MARK: - Toggle

    @Test("Toggle item completes it")
    func toggleItemCompletes() {
        let vm = TodoListViewModel()
        let id = vm.addItem(text: "Toggle me")

        vm.toggleItem(id)

        #expect(vm.items[0].isCompleted == true)
        #expect(vm.pendingCount == 0)
        #expect(vm.completedCount == 1)
    }

    @Test("Toggle completed item uncompletes it")
    func toggleCompletedUncompletes() {
        let vm = TodoListViewModel()
        let id = vm.addItem(text: "Toggle twice")
        vm.toggleItem(id)

        vm.toggleItem(id)

        #expect(vm.items[0].isCompleted == false)
        #expect(vm.pendingCount == 1)
        #expect(vm.completedCount == 0)
    }

    @Test("Toggle nonexistent item does not crash")
    func toggleNonexistent() {
        let vm = TodoListViewModel()
        vm.toggleItem(UUID())
        #expect(vm.items.isEmpty)
    }

    // MARK: - Remove

    @Test("Remove item")
    func removeItem() {
        let vm = TodoListViewModel()
        let id = vm.addItem(text: "Remove me")

        vm.removeItem(id)

        #expect(vm.items.isEmpty)
    }

    @Test("Remove middle item preserves others")
    func removeMiddleItem() {
        let vm = TodoListViewModel()
        vm.addItem(text: "First")
        let id2 = vm.addItem(text: "Middle")
        vm.addItem(text: "Last")

        vm.removeItem(id2)

        #expect(vm.items.count == 2)
        #expect(vm.items[0].text == "First")
        #expect(vm.items[1].text == "Last")
    }

    @Test("Remove nonexistent item does not crash")
    func removeNonexistent() {
        let vm = TodoListViewModel()
        vm.removeItem(UUID())
        #expect(vm.items.isEmpty)
    }

    // MARK: - Clear Completed

    @Test("Clear completed removes only completed items")
    func clearCompleted() {
        let vm = TodoListViewModel()
        vm.addItem(text: "Pending")
        let id2 = vm.addItem(text: "Done")
        vm.addItem(text: "Also Pending")
        vm.toggleItem(id2)

        vm.clearCompleted()

        #expect(vm.items.count == 2)
        #expect(vm.items[0].text == "Pending")
        #expect(vm.items[1].text == "Also Pending")
    }

    @Test("Clear completed with no completed items is a no-op")
    func clearCompletedNoOp() {
        let vm = TodoListViewModel()
        vm.addItem(text: "Still pending")

        vm.clearCompleted()

        #expect(vm.items.count == 1)
    }

    // MARK: - Update Text

    @Test("Update item text")
    func updateItemText() {
        let vm = TodoListViewModel()
        let id = vm.addItem(text: "Original")

        vm.updateItemText(id, text: "Updated")

        #expect(vm.items[0].text == "Updated")
    }

    @Test("Update nonexistent item does not crash")
    func updateTextNonexistent() {
        let vm = TodoListViewModel()
        vm.updateItemText(UUID(), text: "Ghost")
        #expect(vm.items.isEmpty)
    }

    // MARK: - Counts

    @Test("Counts reflect mixed states")
    func countsMixedStates() {
        let vm = TodoListViewModel()
        vm.addItem(text: "Pending 1")
        let id2 = vm.addItem(text: "Done 1")
        vm.addItem(text: "Pending 2")
        let id4 = vm.addItem(text: "Done 2")
        vm.toggleItem(id2)
        vm.toggleItem(id4)

        #expect(vm.pendingCount == 2)
        #expect(vm.completedCount == 2)
    }
}
