import Foundation
import Observation
import os.log

/// ViewModel for managing background tasks displayed in the side pane
@Observable @MainActor
public final class BackgroundTaskViewModel {

    // MARK: - Published State

    /// All background tasks, most recent first
    public private(set) var tasks: [TavernTask] = []

    /// ID of the task whose output is currently being viewed
    public var selectedTaskId: UUID?

    // MARK: - Init

    public init() {
        TavernLogger.resources.debug("[BackgroundTaskViewModel] Created")
    }

    // MARK: - Computed

    /// The currently selected task, if any
    public var selectedTask: TavernTask? {
        guard let id = selectedTaskId else { return nil }
        return tasks.first { $0.id == id }
    }

    /// Count of currently running tasks
    public var runningCount: Int {
        tasks.filter { $0.status == .running }.count
    }

    // MARK: - Actions

    /// Add a new background task
    @discardableResult
    public func addTask(name: String, id: UUID = UUID()) -> UUID {
        let task = TavernTask(id: id, name: name)
        tasks.insert(task, at: 0)
        TavernLogger.resources.info("[BackgroundTaskViewModel] Added task: \(name) (\(id.uuidString))")
        return task.id
    }

    /// Update a task's status
    public func updateStatus(_ id: UUID, status: TavernTask.Status) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            TavernLogger.resources.error("[BackgroundTaskViewModel] Task not found for status update: \(id.uuidString)")
            return
        }
        tasks[index].status = status
        if status != .running {
            tasks[index].finishedAt = Date()
        }
        TavernLogger.resources.info("[BackgroundTaskViewModel] Task \(id.uuidString) status: \(status.rawValue)")
    }

    /// Append output text to a task
    public func appendOutput(_ id: UUID, text: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            TavernLogger.resources.error("[BackgroundTaskViewModel] Task not found for output append: \(id.uuidString)")
            return
        }
        tasks[index].output += text
    }

    /// Stop a running task (marks it as stopped)
    public func stopTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            TavernLogger.resources.error("[BackgroundTaskViewModel] Task not found for stop: \(id.uuidString)")
            return
        }
        guard tasks[index].status == .running else {
            TavernLogger.resources.debug("[BackgroundTaskViewModel] Task \(id.uuidString) not running, cannot stop")
            return
        }
        tasks[index].status = .stopped
        tasks[index].finishedAt = Date()
        TavernLogger.resources.info("[BackgroundTaskViewModel] Stopped task: \(id.uuidString)")
    }

    /// Remove a finished task from the list
    public func removeTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            TavernLogger.resources.error("[BackgroundTaskViewModel] Task not found for removal: \(id.uuidString)")
            return
        }
        guard tasks[index].status != .running else {
            TavernLogger.resources.debug("[BackgroundTaskViewModel] Cannot remove running task: \(id.uuidString)")
            return
        }
        let name = tasks[index].name
        tasks.remove(at: index)
        if selectedTaskId == id {
            selectedTaskId = nil
        }
        TavernLogger.resources.info("[BackgroundTaskViewModel] Removed task: \(name)")
    }

    /// Clear all finished tasks
    public func clearFinished() {
        let beforeCount = tasks.count
        tasks.removeAll { $0.status != .running }
        if let selectedId = selectedTaskId, !tasks.contains(where: { $0.id == selectedId }) {
            selectedTaskId = nil
        }
        let removed = beforeCount - tasks.count
        TavernLogger.resources.info("[BackgroundTaskViewModel] Cleared \(removed) finished tasks")
    }

    /// Select a task to view its output
    public func selectTask(_ id: UUID) {
        selectedTaskId = id
        TavernLogger.resources.debug("[BackgroundTaskViewModel] Selected task: \(id.uuidString)")
    }

    /// Deselect the currently selected task
    public func deselectTask() {
        selectedTaskId = nil
        TavernLogger.resources.debug("[BackgroundTaskViewModel] Deselected task")
    }
}
