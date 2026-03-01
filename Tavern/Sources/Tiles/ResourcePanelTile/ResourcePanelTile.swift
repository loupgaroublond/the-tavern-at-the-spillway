import Foundation
import TavernKit
import SwiftUI
import os.log

// MARK: - Provenance: REQ-ARCH-003

@Observable @MainActor
public final class ResourcePanelTile {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    // MARK: - Tab State

    var selectedTab: SidePaneTab = .files

    // MARK: - File Tree State

    var rootNodes: [FileTreeNode] = []
    var selectedFileURL: URL?
    var selectedFileContent: String?
    var selectedFileName: String?
    var isLoading: Bool = false
    var error: String?

    // MARK: - Tasks State

    var tasks: [TavernTask] = []
    var selectedTaskId: UUID?

    // MARK: - TODO State

    var todoItems: [TodoItem] = []
    var todoDraftText: String = ""

    // MARK: - Dependencies

    private let resourceProvider: any ResourceProvider
    let responder: ResourcePanelResponder
    private let rootURL: URL

    // MARK: - Computed Properties

    var selectedTask: TavernTask? {
        guard let id = selectedTaskId else { return nil }
        return tasks.first { $0.id == id }
    }

    var runningCount: Int {
        tasks.filter { $0.status == .running }.count
    }

    var pendingCount: Int {
        todoItems.filter { !$0.isCompleted }.count
    }

    var completedCount: Int {
        todoItems.filter { $0.isCompleted }.count
    }

    // MARK: - Initialization

    public init(resourceProvider: any ResourceProvider, responder: ResourcePanelResponder, rootURL: URL) {
        self.resourceProvider = resourceProvider
        self.responder = responder
        self.rootURL = rootURL
        Self.logger.info("[ResourcePanelTile] initialized - rootURL: \(rootURL.path)")
    }

    public func makeView() -> some View {
        ResourcePanelTileView(tile: self)
    }

    // MARK: - File Tree Actions

    func loadRootDirectory() {
        Self.logger.info("[ResourcePanelTile] loadRootDirectory")
        do {
            rootNodes = try resourceProvider.scanDirectory(at: rootURL)
        } catch {
            Self.logger.error("[ResourcePanelTile] loadRootDirectory failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func toggleDirectory(_ node: FileTreeNode) {
        Self.logger.debug("[ResourcePanelTile] toggleDirectory: \(node.name)")
        guard node.isDirectory else { return }

        toggleNodeInTree(id: node.id, in: &rootNodes)
    }

    func selectFile(_ node: FileTreeNode) {
        guard !node.isDirectory else { return }
        Self.logger.info("[ResourcePanelTile] selectFile: \(node.name)")
        selectedFileURL = node.url
        selectedFileName = node.name
        error = nil

        if resourceProvider.isBinaryFile(at: node.url) {
            selectedFileContent = nil
            error = "Binary file — cannot display"
            return
        }

        if resourceProvider.isFileTooLarge(at: node.url) {
            selectedFileContent = nil
            error = "File is too large to display"
            return
        }

        isLoading = true
        do {
            selectedFileContent = try resourceProvider.readFile(at: node.url)
            isLoading = false
        } catch {
            Self.logger.error("[ResourcePanelTile] readFile failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            selectedFileContent = nil
            isLoading = false
        }

        responder.onFileSelected(node.url)
    }

    func deselectFile() {
        Self.logger.debug("[ResourcePanelTile] deselectFile")
        selectedFileURL = nil
        selectedFileName = nil
        selectedFileContent = nil
        error = nil
    }

    // MARK: - Task Actions

    func stopTask(_ id: UUID) {
        Self.logger.info("[ResourcePanelTile] stopTask: \(id)")
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = .stopped
            tasks[index].finishedAt = Date()
        }
    }

    func deselectTask() {
        Self.logger.debug("[ResourcePanelTile] deselectTask")
        selectedTaskId = nil
    }

    func clearFinishedTasks() {
        Self.logger.info("[ResourcePanelTile] clearFinishedTasks")
        tasks.removeAll { $0.status != .running }
        if let selectedId = selectedTaskId, !tasks.contains(where: { $0.id == selectedId }) {
            selectedTaskId = nil
        }
    }

    // MARK: - TODO Actions

    func addTodoItem() {
        let text = todoDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Self.logger.info("[ResourcePanelTile] addTodoItem: \(text)")
        todoItems.append(TodoItem(text: text))
        todoDraftText = ""
    }

    func toggleTodoItem(_ id: UUID) {
        Self.logger.debug("[ResourcePanelTile] toggleTodoItem: \(id)")
        if let index = todoItems.firstIndex(where: { $0.id == id }) {
            todoItems[index].isCompleted.toggle()
        }
    }

    func removeTodoItem(_ id: UUID) {
        Self.logger.debug("[ResourcePanelTile] removeTodoItem: \(id)")
        todoItems.removeAll { $0.id == id }
    }

    func clearCompletedTodos() {
        Self.logger.info("[ResourcePanelTile] clearCompletedTodos")
        todoItems.removeAll { $0.isCompleted }
    }

    // MARK: - Private Helpers

    private func toggleNodeInTree(id: String, in nodes: inout [FileTreeNode]) {
        for i in nodes.indices {
            if nodes[i].id == id {
                nodes[i].isExpanded.toggle()
                if nodes[i].isExpanded && nodes[i].children == nil {
                    do {
                        nodes[i].children = try resourceProvider.scanChildren(of: nodes[i])
                    } catch {
                        Self.logger.error("[ResourcePanelTile] scanChildren failed: \(error.localizedDescription)")
                        nodes[i].children = []
                    }
                }
                return
            }
            if var children = nodes[i].children {
                toggleNodeInTree(id: id, in: &children)
                nodes[i].children = children
            }
        }
    }
}
