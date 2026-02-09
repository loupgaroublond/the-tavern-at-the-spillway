import XCTest
@testable import TavernCore

/// Stress tests for TodoList and BackgroundTask bulk operations (Bead flwg)
///
/// Verifies:
/// - 1000 TODO items managed without crashes
/// - 100 background tasks managed without crashes
/// - Bulk operations (add/toggle/remove/clear) complete within time budget
/// - Selection state stays consistent throughout
///
/// Run with: swift test --filter TavernStressTests.SidePaneStressTests
final class SidePaneStressTests: XCTestCase {

    // MARK: - TodoListViewModel Tests

    /// Add 1000 TODO items. Verify counts and state are consistent.
    @MainActor
    func testTodoAdd1000Items() throws {
        let vm = TodoListViewModel()
        let itemCount = 1000
        let timeBudget: TimeInterval = 2.0
        var addedIds: [UUID] = []

        let startTime = Date()
        for i in 0..<itemCount {
            let id = vm.addItem(text: "Task \(i)")
            addedIds.append(id)
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(vm.items.count, itemCount,
            "Should have \(itemCount) items, got \(vm.items.count)")
        XCTAssertEqual(vm.pendingCount, itemCount,
            "All \(itemCount) should be pending")
        XCTAssertEqual(vm.completedCount, 0,
            "None should be completed yet")

        // Verify all IDs are unique
        let uniqueIds = Set(addedIds)
        XCTAssertEqual(uniqueIds.count, itemCount,
            "All \(itemCount) IDs should be unique")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Adding \(itemCount) items must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoAdd1000Items: \(itemCount) items in \(String(format: "%.3f", duration))s")
    }

    /// Toggle all 1000 items to completed, then toggle half back.
    @MainActor
    func testTodoToggle1000Items() throws {
        let vm = TodoListViewModel()
        let itemCount = 1000
        var ids: [UUID] = []

        // Add items
        for i in 0..<itemCount {
            ids.append(vm.addItem(text: "Toggle task \(i)"))
        }

        let timeBudget: TimeInterval = 2.0
        let startTime = Date()

        // Toggle all to completed
        for id in ids {
            vm.toggleItem(id)
        }
        XCTAssertEqual(vm.completedCount, itemCount,
            "All items should be completed after toggle")
        XCTAssertEqual(vm.pendingCount, 0)

        // Toggle first half back to pending
        for id in ids.prefix(itemCount / 2) {
            vm.toggleItem(id)
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(vm.completedCount, itemCount / 2,
            "Half should be completed")
        XCTAssertEqual(vm.pendingCount, itemCount / 2,
            "Half should be pending")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Toggling \(itemCount) items twice must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoToggle1000Items: \(itemCount) toggles in \(String(format: "%.3f", duration))s")
    }

    /// Clear completed items from a list of 1000 (500 completed).
    /// Must complete within 1 second.
    @MainActor
    func testTodoClearCompleted() throws {
        let vm = TodoListViewModel()
        let itemCount = 1000
        var ids: [UUID] = []

        for i in 0..<itemCount {
            ids.append(vm.addItem(text: "Clear task \(i)"))
        }

        // Mark every other item as completed
        for (i, id) in ids.enumerated() where i % 2 == 0 {
            vm.toggleItem(id)
        }
        XCTAssertEqual(vm.completedCount, itemCount / 2)

        let timeBudget: TimeInterval = 1.0
        let startTime = Date()
        vm.clearCompleted()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(vm.items.count, itemCount / 2,
            "Should have \(itemCount / 2) remaining items")
        XCTAssertEqual(vm.completedCount, 0,
            "No completed items should remain")
        XCTAssertEqual(vm.pendingCount, itemCount / 2,
            "All remaining should be pending")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Clearing \(itemCount / 2) completed items must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoClearCompleted: cleared \(itemCount / 2) items in \(String(format: "%.3f", duration))s")
    }

    /// Remove items one by one from a 1000-item list.
    @MainActor
    func testTodoRemoveOneByOne() throws {
        let vm = TodoListViewModel()
        let itemCount = 1000
        var ids: [UUID] = []

        for i in 0..<itemCount {
            ids.append(vm.addItem(text: "Remove task \(i)"))
        }

        let timeBudget: TimeInterval = 2.0
        let startTime = Date()

        for id in ids {
            vm.removeItem(id)
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(vm.items.count, 0, "All items should be removed")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Removing \(itemCount) items must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoRemoveOneByOne: \(itemCount) removals in \(String(format: "%.3f", duration))s")
    }

    /// Update text of all 1000 items.
    @MainActor
    func testTodoUpdateText1000() throws {
        let vm = TodoListViewModel()
        let itemCount = 1000
        var ids: [UUID] = []

        for i in 0..<itemCount {
            ids.append(vm.addItem(text: "Original \(i)"))
        }

        let timeBudget: TimeInterval = 2.0
        let startTime = Date()

        for (i, id) in ids.enumerated() {
            vm.updateItemText(id, text: "Updated \(i) with longer text content")
        }

        let duration = Date().timeIntervalSince(startTime)

        // Verify all texts were updated
        for (i, item) in vm.items.enumerated() {
            XCTAssertTrue(item.text.starts(with: "Updated"),
                "Item \(i) should have updated text, got '\(item.text.prefix(20))'")
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Updating \(itemCount) items must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testTodoUpdateText1000: \(itemCount) updates in \(String(format: "%.3f", duration))s")
    }

    // MARK: - BackgroundTaskViewModel Tests

    /// Add 100 background tasks and manage their lifecycle.
    @MainActor
    func testBackgroundTaskAdd100() throws {
        let vm = BackgroundTaskViewModel()
        let taskCount = 100
        let timeBudget: TimeInterval = 2.0
        var taskIds: [UUID] = []

        let startTime = Date()
        for i in 0..<taskCount {
            let id = vm.addTask(name: "Background task \(i)")
            taskIds.append(id)
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(vm.tasks.count, taskCount,
            "Should have \(taskCount) tasks, got \(vm.tasks.count)")
        XCTAssertEqual(vm.runningCount, taskCount,
            "All tasks should be running")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Adding \(taskCount) tasks must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testBackgroundTaskAdd100: \(taskCount) tasks in \(String(format: "%.3f", duration))s")
    }

    /// Run full lifecycle on 100 tasks: add, append output, update status, remove.
    @MainActor
    func testBackgroundTaskFullLifecycle() throws {
        let vm = BackgroundTaskViewModel()
        let taskCount = 100
        let timeBudget: TimeInterval = 3.0
        var taskIds: [UUID] = []

        let startTime = Date()

        // Phase 1: Add tasks
        for i in 0..<taskCount {
            taskIds.append(vm.addTask(name: "Lifecycle task \(i)"))
        }

        // Phase 2: Append output to each
        for id in taskIds {
            for j in 0..<10 {
                vm.appendOutput(id, text: "Output line \(j)\n")
            }
        }

        // Phase 3: Complete half, fail the other half
        for (i, id) in taskIds.enumerated() {
            if i % 2 == 0 {
                vm.updateStatus(id, status: .completed)
            } else {
                vm.updateStatus(id, status: .failed)
            }
        }

        XCTAssertEqual(vm.runningCount, 0, "No tasks should be running after status updates")

        // Phase 4: Verify output accumulated correctly
        for id in taskIds {
            let task = vm.tasks.first { $0.id == id }
            XCTAssertNotNil(task)
            // Each task got 10 lines of output
            let lineCount = task?.output.components(separatedBy: "\n").filter { !$0.isEmpty }.count ?? 0
            XCTAssertEqual(lineCount, 10,
                "Each task should have 10 output lines, got \(lineCount)")
        }

        // Phase 5: Clear finished
        vm.clearFinished()
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(vm.tasks.count, 0,
            "All tasks should be cleared")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Full lifecycle of \(taskCount) tasks must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testBackgroundTaskFullLifecycle: \(taskCount) tasks full lifecycle in \(String(format: "%.3f", duration))s")
    }

    /// Selection state must stay consistent during bulk operations.
    @MainActor
    func testBackgroundTaskSelectionConsistency() throws {
        let vm = BackgroundTaskViewModel()
        var taskIds: [UUID] = []

        // Add 50 tasks
        for i in 0..<50 {
            taskIds.append(vm.addTask(name: "Selection task \(i)"))
        }

        // Select a task in the middle
        let selectedId = taskIds[25]
        vm.selectTask(selectedId)
        XCTAssertEqual(vm.selectedTaskId, selectedId)
        XCTAssertNotNil(vm.selectedTask)

        // Complete and remove tasks before and after the selected one
        for id in taskIds.prefix(25) {
            vm.updateStatus(id, status: .completed)
            vm.removeTask(id)
        }
        // Selected task should still be valid
        XCTAssertEqual(vm.selectedTaskId, selectedId,
            "Selection should survive removal of other tasks")
        XCTAssertNotNil(vm.selectedTask)

        // Complete and remove the selected task
        vm.updateStatus(selectedId, status: .completed)
        vm.removeTask(selectedId)
        XCTAssertNil(vm.selectedTaskId,
            "Selection should clear when selected task is removed")
        XCTAssertNil(vm.selectedTask)

        // Remove remaining tasks
        for id in taskIds.suffix(24) {
            vm.updateStatus(id, status: .stopped)
        }
        vm.clearFinished()
        XCTAssertEqual(vm.tasks.count, 0)

        print("testBackgroundTaskSelectionConsistency: selection tracking correct through lifecycle")
    }

    /// Cannot remove a running task; verify guard works at scale.
    @MainActor
    func testBackgroundTaskCannotRemoveRunning() throws {
        let vm = BackgroundTaskViewModel()
        var taskIds: [UUID] = []

        for i in 0..<50 {
            taskIds.append(vm.addTask(name: "Running task \(i)"))
        }

        // Attempt to remove all running tasks (should all fail silently)
        for id in taskIds {
            vm.removeTask(id)
        }

        XCTAssertEqual(vm.tasks.count, 50,
            "All 50 running tasks should still be present after failed removal attempts")

        // Now stop them all and remove
        for id in taskIds {
            vm.stopTask(id)
            vm.removeTask(id)
        }
        XCTAssertEqual(vm.tasks.count, 0, "All stopped tasks should be removable")

        print("testBackgroundTaskCannotRemoveRunning: guard works correctly at scale")
    }
}
