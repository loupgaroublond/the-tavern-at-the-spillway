import Foundation
import Testing
@testable import TavernCore

@Suite("SidePaneTab Tests")
struct SidePaneTabTests {

    @Test("All cases have distinct symbol names")
    func allCasesHaveSymbols() {
        let symbols = SidePaneTab.allCases.map(\.symbolName)
        #expect(symbols.count == 3)
        #expect(Set(symbols).count == 3) // All distinct
    }

    @Test("Raw values match display names")
    func rawValues() {
        #expect(SidePaneTab.files.rawValue == "Files")
        #expect(SidePaneTab.tasks.rawValue == "Tasks")
        #expect(SidePaneTab.todos.rawValue == "TODOs")
    }

    @Test("All cases are iterable")
    func allCases() {
        #expect(SidePaneTab.allCases.count == 3)
        #expect(SidePaneTab.allCases.contains(.files))
        #expect(SidePaneTab.allCases.contains(.tasks))
        #expect(SidePaneTab.allCases.contains(.todos))
    }
}

@Suite("TavernTask Tests")
struct TavernTaskTests {

    @Test("Default init creates running task with empty output")
    func defaultInit() {
        let task = TavernTask(name: "Build")
        #expect(task.name == "Build")
        #expect(task.status == .running)
        #expect(task.output == "")
        #expect(task.finishedAt == nil)
    }

    @Test("Elapsed time for running task is positive")
    func elapsedRunning() {
        let task = TavernTask(name: "Running", startedAt: Date().addingTimeInterval(-5))
        #expect(task.elapsed >= 4.5)
    }

    @Test("Elapsed time for finished task uses finishedAt")
    func elapsedFinished() {
        let start = Date().addingTimeInterval(-10)
        let finish = Date().addingTimeInterval(-5)
        let task = TavernTask(
            name: "Done",
            startedAt: start,
            finishedAt: finish,
            status: .completed
        )
        let elapsed = task.elapsed
        #expect(elapsed >= 4.5 && elapsed <= 5.5)
    }

    @Test("Custom init with all fields")
    func customInit() {
        let id = UUID()
        let start = Date()
        let task = TavernTask(
            id: id,
            name: "Custom",
            startedAt: start,
            finishedAt: nil,
            status: .failed,
            output: "error output"
        )
        #expect(task.id == id)
        #expect(task.name == "Custom")
        #expect(task.startedAt == start)
        #expect(task.status == .failed)
        #expect(task.output == "error output")
    }

    @Test("All status cases are distinct")
    func statusCases() {
        let statuses: [TavernTask.Status] = [.running, .completed, .failed, .stopped]
        #expect(Set(statuses.map(\.rawValue)).count == 4)
    }
}

@Suite("TodoItem Tests")
struct TodoItemTests {

    @Test("Default init creates uncompleted item")
    func defaultInit() {
        let item = TodoItem(text: "Buy groceries")
        #expect(item.text == "Buy groceries")
        #expect(item.isCompleted == false)
    }

    @Test("Custom init with completion state")
    func customInit() {
        let id = UUID()
        let date = Date()
        let item = TodoItem(id: id, text: "Done", isCompleted: true, createdAt: date)
        #expect(item.id == id)
        #expect(item.text == "Done")
        #expect(item.isCompleted == true)
        #expect(item.createdAt == date)
    }
}
