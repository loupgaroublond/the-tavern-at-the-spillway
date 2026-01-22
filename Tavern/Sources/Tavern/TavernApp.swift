import SwiftUI
import TavernCore
import AppKit

@main
struct TavernApp: App {
    @StateObject private var projectManager = ProjectManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(projectManager)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open Project...") {
                    Task { @MainActor in
                        await openProjectDialog()
                    }
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                // Open Recent submenu
                Menu("Open Recent") {
                    ForEach(projectManager.recentProjectPaths, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            Task { @MainActor in
                                await projectManager.openProject(at: url)
                            }
                        }
                    }

                    if !projectManager.recentProjectPaths.isEmpty {
                        Divider()
                        Button("Clear Menu") {
                            projectManager.clearRecentProjects()
                        }
                    }
                }
                .disabled(projectManager.recentProjectPaths.isEmpty)
            }
        }
    }

    /// Show the open folder dialog
    @MainActor
    private func openProjectDialog() async {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.message = "Select a project directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        let response = await panel.begin()

        if response == .OK, let url = panel.url {
            await projectManager.openProject(at: url)
        }
    }
}

// MARK: - Root View

/// Root view that shows either welcome screen or open project
struct RootView: View {
    @EnvironmentObject var projectManager: ProjectManager

    var body: some View {
        if let project = projectManager.openProjects.first {
            ProjectView(project: project)
        } else {
            WelcomeView()
        }
    }
}

// MARK: - Welcome View

/// Shown when no project is open
struct WelcomeView: View {
    @EnvironmentObject var projectManager: ProjectManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo/Title
            VStack(spacing: 8) {
                Text("The Tavern at the Spillway")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pull up a stool. Stay a while.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            VStack(spacing: 16) {
                Button(action: {
                    Task { @MainActor in
                        await openProjectDialog()
                    }
                }) {
                    Label("Open Project", systemImage: "folder")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Recent projects
                if !projectManager.recentProjectPaths.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Projects")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        ForEach(projectManager.recentProjectPaths.prefix(5), id: \.self) { url in
                            Button(action: {
                                Task { @MainActor in
                                    await projectManager.openProject(at: url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.secondary)
                                    VStack(alignment: .leading) {
                                        Text(url.lastPathComponent)
                                            .fontWeight(.medium)
                                        Text(url.deletingLastPathComponent().path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding(40)
    }

    @MainActor
    private func openProjectDialog() async {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.message = "Select a project directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        let response = await panel.begin()

        if response == .OK, let url = panel.url {
            await projectManager.openProject(at: url)
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

/// Content view for an initialized project
struct ProjectContentView: View {
    @ObservedObject var project: TavernProject
    @ObservedObject var coordinator: TavernCoordinator

    var body: some View {
        NavigationSplitView {
            // Sidebar with agent list
            VStack(spacing: 0) {
                TavernHeader(projectName: project.name)
                Divider()
                AgentListView(viewModel: coordinator.agentListViewModel)
            }
            .frame(minWidth: 200)
        } detail: {
            // Detail view with selected agent's chat
            ChatView(viewModel: coordinator.activeChatViewModel)
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

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

            // Status indicator placeholder
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

#Preview("Welcome") {
    WelcomeView()
        .environmentObject(ProjectManager.shared)
}

#Preview("Project") {
    let mock = MockClaudeCode()
    mock.queueJSONResponse(result: "Well well WELL, look who just walked in!", sessionId: "preview")

    let jake = Jake(claude: mock)
    let registry = AgentRegistry()
    let nameGenerator = NameGenerator(theme: .lotr)
    let spawner = AgentSpawner(
        registry: registry,
        nameGenerator: nameGenerator,
        claudeFactory: { MockClaudeCode() }
    )

    let coordinator = TavernCoordinator(jake: jake, spawner: spawner)
    let project = TavernProject(rootURL: URL(fileURLWithPath: "/tmp/test-project"))

    return ProjectContentView(project: project, coordinator: coordinator)
}
