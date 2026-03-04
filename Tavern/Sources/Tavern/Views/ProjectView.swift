import SwiftUI
import TavernCore
import TavernBoard
import TavernKit
import os.log

// MARK: - Provenance: REQ-UX-001, REQ-V1-001

// MARK: - Project Window View

/// View for a project window
struct ProjectWindowView: View {
    let config: ProjectWindowConfig?
    @EnvironmentObject var projectManager: ProjectManager
    @State private var project: TavernProject?

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "window")

    var body: some View {
        let _ = Self.logger.debug("[ProjectWindowView] body evaluated - config: \(config?.projectURL.path ?? "nil", privacy: .public), project: \(project?.name ?? "nil", privacy: .public)")
        Group {
            if let project = project {
                ProjectView(project: project)
            } else if let cfg = config {
                let _ = Self.logger.info("[ProjectWindowView] SHOWING SPINNER for: \(cfg.projectURL.path, privacy: .public)")
                VStack {
                    ProgressView("Loading project...")
                    Text(cfg.projectURL.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 400, minHeight: 300)
            } else {
                WelcomeView()
            }
        }
        .onAppear {
            Self.logger.debug("[ProjectWindowView] onAppear - config: \(config?.projectURL.path ?? "nil", privacy: .public), project: \(project?.name ?? "nil", privacy: .public)")
        }
        .task(id: config?.projectURL) {
            let taskId = UUID().uuidString.prefix(8)
            Self.logger.info("[ProjectWindowView:\(taskId, privacy: .public)] .task started - config: \(config?.projectURL.path ?? "nil", privacy: .public)")

            guard let url = config?.projectURL else {
                Self.logger.warning("[ProjectWindowView:\(taskId, privacy: .public)] config or projectURL is nil, falling back to WelcomeView")
                return
            }

            Self.logger.debug("[ProjectWindowView:\(taskId, privacy: .public)] Looking for existing project at: \(url.path, privacy: .public)")
            Self.logger.debug("[ProjectWindowView:\(taskId, privacy: .public)] ProjectManager openProjects count: \(self.projectManager.openProjects.count)")

            // Find or create the project
            if let existing = projectManager.openProjects.first(where: { $0.rootURL == url }) {
                Self.logger.info("[ProjectWindowView:\(taskId, privacy: .public)] Found existing project: \(existing.name, privacy: .public)")
                project = existing
            } else {
                Self.logger.info("[ProjectWindowView:\(taskId, privacy: .public)] Opening new project at: \(url.path, privacy: .public)")

                // Log before the potentially long-running operation
                Self.logger.debug("[ProjectWindowView:\(taskId, privacy: .public)] Calling projectManager.openProject...")
                let openedProject = await projectManager.openProject(at: url)
                Self.logger.info("[ProjectWindowView:\(taskId, privacy: .public)] projectManager.openProject returned - name: \(openedProject.name, privacy: .public), isReady: \(openedProject.isReady), hasError: \(openedProject.initializationError != nil)")

                project = openedProject
            }

            Self.logger.debug("[ProjectWindowView:\(taskId, privacy: .public)] .task completed - project set: \(self.project != nil)")
        }
    }
}

// MARK: - Project View

/// Shows an open project via its WindowBoard (tileboard architecture)
struct ProjectView: View {
    @ObservedObject var project: TavernProject
    @State private var windowBoard: WindowBoard?

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "window")

    var body: some View {
        let _ = Self.logger.debug("[ProjectView] body - isReady: \(project.isReady), hasBoard: \(windowBoard != nil), hasError: \(project.initializationError != nil)")
        Group {
            if let board = windowBoard {
                board.makeView()
            } else if let error = project.initializationError {
                ProjectErrorView(project: project, error: error)
            } else {
                ProjectLoadingView(project: project)
            }
        }
        .onChange(of: project.isReady) {
            createWindowBoardIfReady()
        }
        .onAppear {
            createWindowBoardIfReady()
        }
    }

    private func createWindowBoardIfReady() {
        guard windowBoard == nil,
              let servitorProvider = project.servitorProvider,
              let commandProvider = project.commandProvider,
              let resourceProvider = project.resourceProvider,
              let permissionProvider = project.permissionProvider else {
            return
        }

        Self.logger.info("[ProjectView] Creating WindowBoard for: \(project.name, privacy: .public)")
        windowBoard = WindowBoard(
            servitorProvider: servitorProvider,
            commandProvider: commandProvider,
            resourceProvider: resourceProvider,
            permissionProvider: permissionProvider,
            projectName: project.name,
            rootURL: project.rootURL
        )
    }
}

// MARK: - Loading & Error Views

/// Loading view while project initializes
struct ProjectLoadingView: View {
    let project: TavernProject

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Opening \(project.name)...")
                .font(.headline)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

/// Error view if project fails to initialize
struct ProjectErrorView: View {
    let project: TavernProject
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to open project")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Preview

#Preview("Project Loading") {
    ProjectLoadingView(project: TavernProject(rootURL: URL(fileURLWithPath: "/tmp/tavern-preview")))
}
