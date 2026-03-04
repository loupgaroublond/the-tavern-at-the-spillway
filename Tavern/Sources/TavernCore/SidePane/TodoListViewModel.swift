import Foundation
import os.log

/// ViewModel for managing a simple TODO checklist in the side pane
@MainActor
public final class TodoListViewModel: ObservableObject {

    // MARK: - Published State

    /// All TODO items in display order
    @Published public private(set) var items: [TodoItem] = []

    /// Text for a new item being composed
    @Published public var draftText: String = ""

    // MARK: - Init

    public init() {
        TavernLogger.resources.debug("[TodoListViewModel] Created")
    }

    // MARK: - Computed

    /// Count of incomplete items
    public var pendingCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    /// Count of completed items
    public var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    // MARK: - Actions

    /// Add a new TODO item from the draft text. Returns the item ID, or nil if draft was empty.
    @discardableResult
    public func addItem() -> UUID? {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            TavernLogger.resources.debug("[TodoListViewModel] Ignoring empty draft")
            return nil
        }
        let item = TodoItem(text: trimmed)
        items.append(item)
        draftText = ""
        TavernLogger.resources.info("[TodoListViewModel] Added item: \(trimmed, privacy: .public)")
        return item.id
    }

    /// Add a TODO item with explicit text (bypasses draft). Returns the item ID.
    @discardableResult
    public func addItem(text: String) -> UUID {
        let item = TodoItem(text: text)
        items.append(item)
        TavernLogger.resources.info("[TodoListViewModel] Added item: \(text, privacy: .public)")
        return item.id
    }

    /// Toggle the completion state of an item
    public func toggleItem(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            TavernLogger.resources.error("[TodoListViewModel] Item not found for toggle: \(id.uuidString, privacy: .public)")
            return
        }
        items[index].isCompleted.toggle()
        let state = items[index].isCompleted ? "completed" : "uncompleted"
        TavernLogger.resources.info("[TodoListViewModel] Toggled item \(id.uuidString, privacy: .public): \(state, privacy: .public)")
    }

    /// Remove a specific item
    public func removeItem(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            TavernLogger.resources.error("[TodoListViewModel] Item not found for removal: \(id.uuidString, privacy: .public)")
            return
        }
        let text = items[index].text
        items.remove(at: index)
        TavernLogger.resources.info("[TodoListViewModel] Removed item: \(text, privacy: .public)")
    }

    /// Remove all completed items
    public func clearCompleted() {
        let beforeCount = items.count
        items.removeAll { $0.isCompleted }
        let removed = beforeCount - items.count
        TavernLogger.resources.info("[TodoListViewModel] Cleared \(removed) completed items")
    }

    /// Update the text of an existing item
    public func updateItemText(_ id: UUID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            TavernLogger.resources.error("[TodoListViewModel] Item not found for text update: \(id.uuidString, privacy: .public)")
            return
        }
        items[index].text = text
        TavernLogger.resources.debug("[TodoListViewModel] Updated item text: \(id.uuidString, privacy: .public)")
    }
}
