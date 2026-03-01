import XCTest
import TavernKit
@testable import ResourcePanelTile

// MARK: - Provenance: REQ-QA-006

/// Stress tests for ResourcePanelTile bulk TODO and task operations
///
/// Verifies:
/// - 1000 TODO items managed without crashes
/// - 100 background tasks managed without crashes
/// - Bulk operations (add/toggle/remove/clear) complete within time budget
/// - Selection state stays consistent throughout
///
/// Run with: swift test --filter TavernStressTests.SidePaneStressTests
final class SidePaneStressTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        executionTimeAllowance = 30
    }

    // MARK: - Helpers

    @MainActor
    private func makeTile() -> ResourcePanelTile {
        let provider = StubResourceProvider()
        let responder = ResourcePanelResponder(onFileSelected: { _ in })
        let root = URL(fileURLWithPath: "/tmp/stress-\(UUID().uuidString)")
        return ResourcePanelTile(resourceProvider: provider, responder: responder, rootURL: root)
    }

    // MARK: - TODO Stress Tests

    /// Add 1000 TODO items. Verify counts and state are consistent.
    @MainActor
    func testTodoAdd1000Items() throws {
        let tile = makeTile()
        let itemCount = 1000
        let timeBudget: TimeInterval = 2.0

        let startTime = Date()
        for i in 0..<itemCount {
            tile.todoDraftText = "Task \(i)"
            tile.addTodoItem()
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(tile.todoItems.count, itemCount,
            "Should have \(itemCount) items, got \(tile.todoItems.count)")
        XCTAssertEqual(tile.pendingCount, itemCount,
            "All \(itemCount) should be pending")
        XCTAssertEqual(tile.completedCount, 0,
            "None should be completed yet")

        // Verify all IDs are unique
        let uniqueIds = Set(tile.todoItems.map(\.id))
        XCTAssertEqual(uniqueIds.count, itemCount,
            "All \(itemCount) IDs should be unique")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Adding \(itemCount) items must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoAdd1000Items: \(itemCount) items in \(String(format: "%.3f", duration))s")
    }

    /// Toggle all 1000 items to completed, then toggle half back.
    @MainActor
    func testTodoToggle1000Items() throws {
        let tile = makeTile()
        let itemCount = 1000

        for i in 0..<itemCount {
            tile.todoDraftText = "Toggle task \(i)"
            tile.addTodoItem()
        }
        let ids = tile.todoItems.map(\.id)

        let timeBudget: TimeInterval = 2.0
        let startTime = Date()

        // Toggle all to completed
        for id in ids {
            tile.toggleTodoItem(id)
        }
        XCTAssertEqual(tile.completedCount, itemCount,
            "All items should be completed after toggle")
        XCTAssertEqual(tile.pendingCount, 0)

        // Toggle first half back to pending
        for id in ids.prefix(itemCount / 2) {
            tile.toggleTodoItem(id)
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(tile.completedCount, itemCount / 2,
            "Half should be completed")
        XCTAssertEqual(tile.pendingCount, itemCount / 2,
            "Half should be pending")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Toggling \(itemCount) items twice must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoToggle1000Items: \(itemCount) toggles in \(String(format: "%.3f", duration))s")
    }

    /// Clear completed items from a list of 1000 (500 completed).
    @MainActor
    func testTodoClearCompleted() throws {
        let tile = makeTile()
        let itemCount = 1000

        for i in 0..<itemCount {
            tile.todoDraftText = "Clear task \(i)"
            tile.addTodoItem()
        }

        // Mark every other item as completed
        for (i, item) in tile.todoItems.enumerated() where i % 2 == 0 {
            tile.toggleTodoItem(item.id)
        }
        XCTAssertEqual(tile.completedCount, itemCount / 2)

        let timeBudget: TimeInterval = 1.0
        let startTime = Date()
        tile.clearCompletedTodos()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(tile.todoItems.count, itemCount / 2,
            "Should have \(itemCount / 2) remaining items")
        XCTAssertEqual(tile.completedCount, 0,
            "No completed items should remain")
        XCTAssertEqual(tile.pendingCount, itemCount / 2,
            "All remaining should be pending")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Clearing \(itemCount / 2) completed items must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoClearCompleted: cleared \(itemCount / 2) items in \(String(format: "%.3f", duration))s")
    }

    /// Remove items one by one from a 1000-item list.
    @MainActor
    func testTodoRemoveOneByOne() throws {
        let tile = makeTile()
        let itemCount = 1000

        for i in 0..<itemCount {
            tile.todoDraftText = "Remove task \(i)"
            tile.addTodoItem()
        }
        let ids = tile.todoItems.map(\.id)

        let timeBudget: TimeInterval = 2.0
        let startTime = Date()

        for id in ids {
            tile.removeTodoItem(id)
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(tile.todoItems.count, 0, "All items should be removed")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Removing \(itemCount) items must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoRemoveOneByOne: \(itemCount) removals in \(String(format: "%.3f", duration))s")
    }

    // MARK: - Task Stress Tests

    /// Manage 100 tasks and their lifecycle via direct task array manipulation.
    @MainActor
    func testTaskManage100() throws {
        let tile = makeTile()
        let taskCount = 100
        let timeBudget: TimeInterval = 2.0

        let startTime = Date()

        // Phase 1: Add tasks
        var createdTasks: [TavernTask] = []
        for i in 0..<taskCount {
            createdTasks.append(TavernTask(name: "Task \(i)"))
        }
        tile.tasks = createdTasks

        XCTAssertEqual(tile.tasks.count, taskCount)
        XCTAssertEqual(tile.runningCount, taskCount)

        // Phase 2: Complete half, stop the other half
        for i in 0..<taskCount {
            if i % 2 == 0 {
                tile.tasks[i].status = .completed
                tile.tasks[i].finishedAt = Date()
            } else {
                tile.stopTask(tile.tasks[i].id)
            }
        }

        XCTAssertEqual(tile.runningCount, 0, "No tasks should be running after status updates")

        // Phase 3: Clear finished
        tile.clearFinishedTasks()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(tile.tasks.count, 0, "All tasks should be cleared")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Managing \(taskCount) tasks must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTaskManage100: \(taskCount) tasks full lifecycle in \(String(format: "%.3f", duration))s")
    }

    /// Selection state must stay consistent during bulk operations.
    @MainActor
    func testTaskSelectionConsistency() throws {
        let tile = makeTile()

        // Add 50 tasks
        var tasks: [TavernTask] = []
        for i in 0..<50 {
            tasks.append(TavernTask(name: "Selection task \(i)"))
        }
        tile.tasks = tasks

        // Select a task in the middle
        let selectedId = tile.tasks[25].id
        tile.selectedTaskId = selectedId
        XCTAssertEqual(tile.selectedTaskId, selectedId)
        XCTAssertNotNil(tile.selectedTask)

        // Complete and remove tasks before the selected one
        for i in 0..<25 {
            tile.tasks[i].status = .completed
            tile.tasks[i].finishedAt = Date()
        }
        // Selected task should still be valid
        XCTAssertEqual(tile.selectedTaskId, selectedId,
            "Selection should survive status changes of other tasks")
        XCTAssertNotNil(tile.selectedTask)

        // Clear finished — selected running task should survive
        tile.clearFinishedTasks()
        XCTAssertEqual(tile.selectedTaskId, selectedId)
        XCTAssertNotNil(tile.selectedTask)

        // Now stop and clear the selected task
        tile.stopTask(selectedId)
        tile.clearFinishedTasks()
        XCTAssertNil(tile.selectedTaskId,
            "Selection should clear when selected task is cleared")
        XCTAssertNil(tile.selectedTask)

        print("testTaskSelectionConsistency: selection tracking correct through lifecycle")
    }
}

// MARK: - Stub

@MainActor
private final class StubResourceProvider: ResourceProvider {
    func scanDirectory(at url: URL) throws -> [FileTreeNode] { [] }
    func scanChildren(of node: FileTreeNode) throws -> [FileTreeNode] { [] }
    func readFile(at url: URL) throws -> String { "" }
    func isFileTooLarge(at url: URL) -> Bool { false }
    func isBinaryFile(at url: URL) -> Bool { false }
}
