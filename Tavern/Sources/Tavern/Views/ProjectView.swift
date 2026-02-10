import SwiftUI
import TavernCore
import os.log

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

/// Shows an open project with its coordinator
struct ProjectView: View {
    @ObservedObject var project: TavernProject

    var body: some View {
        Group {
            if let coordinator = project.coordinator {
                ProjectContentView(project: project, coordinator: coordinator)
            } else if let error = project.initializationError {
                ProjectErrorView(project: project, error: error)
            } else {
                ProjectLoadingView(project: project)
            }
        }
    }
}

// MARK: - Project Content View

/// Content view for an initialized project
struct ProjectContentView: View {
    @ObservedObject var project: TavernProject
    @ObservedObject var coordinator: TavernCoordinator
    @SceneStorage("resourcePanelVisible") private var isResourcePanelVisible: Bool = false
    @SceneStorage("sidePaneTab") private var selectedTabRaw: String = SidePaneTab.files.rawValue
    @StateObject private var resourcePanelViewModel: ResourcePanelViewModel
    @StateObject private var backgroundTaskViewModel = BackgroundTaskViewModel()
    @StateObject private var todoListViewModel = TodoListViewModel()
    @StateObject private var autocomplete: SlashCommandAutocomplete
    @StateObject private var fileMention: FileMentionAutocomplete

    private var selectedTab: Binding<SidePaneTab> {
        Binding(
            get: { SidePaneTab(rawValue: selectedTabRaw) ?? .files },
            set: { selectedTabRaw = $0.rawValue }
        )
    }

    init(project: TavernProject, coordinator: TavernCoordinator) {
        self.project = project
        self.coordinator = coordinator
        self._resourcePanelViewModel = StateObject(wrappedValue: ResourcePanelViewModel(rootURL: project.rootURL))
        self._autocomplete = StateObject(wrappedValue: SlashCommandAutocomplete(dispatcher: coordinator.commandDispatcher))
        self._fileMention = StateObject(wrappedValue: FileMentionAutocomplete(projectRoot: project.rootURL))
    }

    var body: some View {
        let coord = coordinator  // Capture for closures
        NavigationSplitView {
            // Sidebar with agent list
            VStack(spacing: 0) {
                TavernHeader(projectName: project.name, projectURL: project.rootURL)
                Divider()
                AgentListView(
                    viewModel: coordinator.agentListViewModel,
                    onSpawnAgent: {
                        do {
                            try coord.spawnAgent()
                        } catch {
                            print("Failed to spawn agent: \(error)")
                        }
                    },
                    onCloseAgent: { id in
                        do {
                            try coord.closeAgent(id: id)
                        } catch {
                            print("Failed to close agent: \(error)")
                        }
                    },
                    onUpdateDescription: { id, description in
                        SessionStore.updateAgent(id: id, chatDescription: description)
                        coord.agentListViewModel.refreshItems()
                    },
                    onSelectAgent: { id in
                        coord.selectAgent(id: id)
                    }
                )
            }
            .frame(minWidth: 200)
        } detail: {
            // Detail: Chat + optional Side Pane
            HSplitView {
                ChatView(viewModel: coordinator.activeChatViewModel, autocomplete: autocomplete, fileMention: fileMention)

                if isResourcePanelVisible {
                    ResourcePanelView(
                        resourceViewModel: resourcePanelViewModel,
                        taskViewModel: backgroundTaskViewModel,
                        todoViewModel: todoListViewModel,
                        selectedTab: selectedTab
                    )
                    .frame(minWidth: 250, idealWidth: 350, maxWidth: 600)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isResourcePanelVisible.toggle() }) {
                    Image(systemName: "sidebar.right")
                }
                .help(isResourcePanelVisible ? "Hide Side Pane" : "Show Side Pane")
            }
        }
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

// MARK: - Tavern Header

private struct TavernHeader: View {
    let projectName: String
    let projectURL: URL

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("The Tavern at the Spillway")
                    .font(.headline)
                Text(projectName)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            // Raise all windows for this project
            Button(action: {
                WindowOpeningService.shared.raiseAllWindowsForProject(url: projectURL)
            }) {
                Image(systemName: "rectangle.stack")
                    .help("Bring all windows for this project to front")
            }
            .buttonStyle(.borderless)

            // Status indicator
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("Open")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Project") {
    let projectURL = URL(fileURLWithPath: "/tmp/tavern-preview")

    let jake = Jake(projectURL: projectURL, loadSavedSession: false)
    let registry = AgentRegistry()
    let nameGenerator = NameGenerator(theme: .lotr)
    let spawner = ServitorSpawner(
        registry: registry,
        nameGenerator: nameGenerator,
        projectURL: projectURL
    )

    let coordinator = TavernCoordinator(jake: jake, spawner: spawner, projectURL: projectURL)
    let project = TavernProject(rootURL: projectURL)

    ProjectContentView(project: project, coordinator: coordinator)
}
