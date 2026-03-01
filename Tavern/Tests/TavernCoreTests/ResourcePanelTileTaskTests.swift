import Foundation
import Testing
import TavernKit
@testable import ResourcePanelTile

@Suite("ResourcePanelTile Task Tests", .timeLimit(.minutes(1)))
@MainActor
struct ResourcePanelTileTaskTests {

    // MARK: - Helpers

    private static func makeTile() -> ResourcePanelTile {
        let provider = StubResourceProvider()
        let responder = ResourcePanelResponder(onFileSelected: { _ in })
        let root = URL(fileURLWithPath: "/tmp/test-\(UUID().uuidString)")
        return ResourcePanelTile(resourceProvider: provider, responder: responder, rootURL: root)
    }

    private static func makeTask(name: String = "Test", status: TavernTask.Status = .running) -> TavernTask {
        TavernTask(name: name, status: status)
    }

    // MARK: - Initial State

    @Test("Starts with empty task list")
    func startsEmpty() {
        let tile = Self.makeTile()
        #expect(tile.tasks.isEmpty)
        #expect(tile.selectedTaskId == nil)
        #expect(tile.selectedTask == nil)
        #expect(tile.runningCount == 0)
    }

    // MARK: - Running Count

    @Test("Running count reflects task statuses")
    func runningCount() {
        let tile = Self.makeTile()
        tile.tasks = [
            Self.makeTask(name: "Running 1", status: .running),
            Self.makeTask(name: "Running 2", status: .running),
            Self.makeTask(name: "Done", status: .completed),
            Self.makeTask(name: "Failed", status: .failed),
        ]

        #expect(tile.runningCount == 2)
    }

    // MARK: - Stop Task

    @Test("Stop running task marks as stopped")
    func stopRunningTask() {
        let tile = Self.makeTile()
        let task = Self.makeTask(name: "Long Task", status: .running)
        tile.tasks = [task]

        tile.stopTask(task.id)

        #expect(tile.tasks[0].status == .stopped)
        #expect(tile.tasks[0].finishedAt != nil)
    }

    // MARK: - Selection

    @Test("Selected task computed property")
    func selectedTaskComputed() {
        let tile = Self.makeTile()
        let task = Self.makeTask(name: "Pick Me")
        tile.tasks = [task]

        tile.selectedTaskId = task.id

        #expect(tile.selectedTask?.name == "Pick Me")
    }

    @Test("Deselect task clears selection")
    func deselectTask() {
        let tile = Self.makeTile()
        let task = Self.makeTask()
        tile.tasks = [task]
        tile.selectedTaskId = task.id

        tile.deselectTask()

        #expect(tile.selectedTaskId == nil)
        #expect(tile.selectedTask == nil)
    }

    @Test("Selected task is nil for unknown ID")
    func selectedTaskNilForUnknownId() {
        let tile = Self.makeTile()
        tile.selectedTaskId = UUID()
        #expect(tile.selectedTask == nil)
    }

    // MARK: - Clear Finished

    @Test("Clear finished removes non-running tasks")
    func clearFinished() {
        let tile = Self.makeTile()
        let running = Self.makeTask(name: "Running", status: .running)
        tile.tasks = [
            running,
            Self.makeTask(name: "Done", status: .completed),
            Self.makeTask(name: "Failed", status: .failed),
            Self.makeTask(name: "Stopped", status: .stopped),
        ]

        tile.clearFinishedTasks()

        #expect(tile.tasks.count == 1)
        #expect(tile.tasks[0].id == running.id)
        #expect(tile.tasks[0].status == .running)
    }

    @Test("Clear finished clears selection if selected was finished")
    func clearFinishedClearsSelection() {
        let tile = Self.makeTile()
        let done = Self.makeTask(name: "Done", status: .completed)
        tile.tasks = [done]
        tile.selectedTaskId = done.id

        tile.clearFinishedTasks()

        #expect(tile.selectedTaskId == nil)
    }

    @Test("Clear finished preserves selection if selected is running")
    func clearFinishedPreservesSelection() {
        let tile = Self.makeTile()
        let running = Self.makeTask(name: "Running", status: .running)
        let done = Self.makeTask(name: "Done", status: .completed)
        tile.tasks = [running, done]
        tile.selectedTaskId = running.id

        tile.clearFinishedTasks()

        #expect(tile.selectedTaskId == running.id)
        #expect(tile.selectedTask?.name == "Running")
    }
}
