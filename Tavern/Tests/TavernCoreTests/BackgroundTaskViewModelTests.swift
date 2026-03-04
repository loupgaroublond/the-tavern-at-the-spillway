import Foundation
import Testing
@testable import TavernCore

@Suite("BackgroundTaskViewModel Tests")
@MainActor
struct BackgroundTaskViewModelTests {

    // MARK: - Initial State

    @Test("Starts with empty task list")
    func startsEmpty() {
        let vm = BackgroundTaskViewModel()
        #expect(vm.tasks.isEmpty)
        #expect(vm.selectedTaskId == nil)
        #expect(vm.selectedTask == nil)
        #expect(vm.runningCount == 0)
    }

    // MARK: - Adding Tasks

    @Test("Add task creates running task at front of list")
    func addTaskCreatesRunning() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Build project")

        #expect(vm.tasks.count == 1)
        #expect(vm.tasks[0].id == id)
        #expect(vm.tasks[0].name == "Build project")
        #expect(vm.tasks[0].status == .running)
        #expect(vm.tasks[0].output == "")
        #expect(vm.runningCount == 1)
    }

    @Test("Multiple tasks added in reverse chronological order")
    func multipleTasksOrder() {
        let vm = BackgroundTaskViewModel()
        let id1 = vm.addTask(name: "First")
        let id2 = vm.addTask(name: "Second")

        #expect(vm.tasks.count == 2)
        #expect(vm.tasks[0].id == id2) // Most recent first
        #expect(vm.tasks[1].id == id1)
    }

    @Test("Add task with explicit ID")
    func addTaskWithExplicitId() {
        let vm = BackgroundTaskViewModel()
        let customId = UUID()
        let returnedId = vm.addTask(name: "Custom", id: customId)

        #expect(returnedId == customId)
        #expect(vm.tasks[0].id == customId)
    }

    // MARK: - Status Updates

    @Test("Update status to completed sets finishedAt")
    func updateStatusCompleted() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Test")

        vm.updateStatus(id, status: .completed)

        #expect(vm.tasks[0].status == .completed)
        #expect(vm.tasks[0].finishedAt != nil)
        #expect(vm.runningCount == 0)
    }

    @Test("Update status to failed sets finishedAt")
    func updateStatusFailed() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Test")

        vm.updateStatus(id, status: .failed)

        #expect(vm.tasks[0].status == .failed)
        #expect(vm.tasks[0].finishedAt != nil)
    }

    @Test("Update status for nonexistent task does not crash")
    func updateStatusNonexistent() {
        let vm = BackgroundTaskViewModel()
        vm.updateStatus(UUID(), status: .completed)
        #expect(vm.tasks.isEmpty)
    }

    // MARK: - Output

    @Test("Append output accumulates text")
    func appendOutput() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Build")

        vm.appendOutput(id, text: "Line 1\n")
        vm.appendOutput(id, text: "Line 2\n")

        #expect(vm.tasks[0].output == "Line 1\nLine 2\n")
    }

    @Test("Append output for nonexistent task does not crash")
    func appendOutputNonexistent() {
        let vm = BackgroundTaskViewModel()
        vm.appendOutput(UUID(), text: "ghost")
        #expect(vm.tasks.isEmpty)
    }

    // MARK: - Stop

    @Test("Stop running task marks as stopped")
    func stopRunningTask() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Long Task")

        vm.stopTask(id)

        #expect(vm.tasks[0].status == .stopped)
        #expect(vm.tasks[0].finishedAt != nil)
    }

    @Test("Stop non-running task is a no-op")
    func stopNonRunningTask() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Done Task")
        vm.updateStatus(id, status: .completed)

        vm.stopTask(id)

        #expect(vm.tasks[0].status == .completed) // Unchanged
    }

    // MARK: - Remove

    @Test("Remove finished task")
    func removeFinishedTask() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Done")
        vm.updateStatus(id, status: .completed)

        vm.removeTask(id)

        #expect(vm.tasks.isEmpty)
    }

    @Test("Cannot remove running task")
    func cannotRemoveRunningTask() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Still Running")

        vm.removeTask(id)

        #expect(vm.tasks.count == 1) // Still there
    }

    @Test("Remove selected task clears selection")
    func removeSelectedTaskClearsSelection() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Selected")
        vm.updateStatus(id, status: .completed)
        vm.selectTask(id)

        vm.removeTask(id)

        #expect(vm.selectedTaskId == nil)
        #expect(vm.selectedTask == nil)
    }

    // MARK: - Clear Finished

    @Test("Clear finished removes non-running tasks")
    func clearFinished() {
        let vm = BackgroundTaskViewModel()
        let id1 = vm.addTask(name: "Running")
        let _ = vm.addTask(name: "Done")
        let _ = vm.addTask(name: "Failed")

        vm.updateStatus(vm.tasks[0].id, status: .failed)
        vm.updateStatus(vm.tasks[1].id, status: .completed)

        vm.clearFinished()

        #expect(vm.tasks.count == 1)
        #expect(vm.tasks[0].id == id1)
        #expect(vm.tasks[0].status == .running)
    }

    @Test("Clear finished clears selection if selected was finished")
    func clearFinishedClearsSelection() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Done")
        vm.updateStatus(id, status: .completed)
        vm.selectTask(id)

        vm.clearFinished()

        #expect(vm.selectedTaskId == nil)
    }

    // MARK: - Selection

    @Test("Select task updates selectedTask")
    func selectTask() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Pick Me")

        vm.selectTask(id)

        #expect(vm.selectedTaskId == id)
        #expect(vm.selectedTask?.name == "Pick Me")
    }

    @Test("Deselect task clears selection")
    func deselectTask() {
        let vm = BackgroundTaskViewModel()
        let id = vm.addTask(name: "Deselect Me")
        vm.selectTask(id)

        vm.deselectTask()

        #expect(vm.selectedTaskId == nil)
        #expect(vm.selectedTask == nil)
    }
}
