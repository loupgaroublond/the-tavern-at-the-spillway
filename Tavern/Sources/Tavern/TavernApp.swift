import SwiftUI
import TavernCore
import AppKit
import os.log

// MARK: - Window Opening Service

/// Shared service that bridges AppKit → SwiftUI window opening
/// Views register their openWindow environment action here
@MainActor
final class WindowOpeningService: ObservableObject {
    static let shared = WindowOpeningService()
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "window")

    /// The openWindow action from SwiftUI, registered by active views
    var openWindow: ((ProjectWindowConfig) -> Void)?
    var openWelcomeWindow: (() -> Void)?
    var dismissWelcomeWindow: (() -> Void)?

    /// Track which project URLs have open windows
    @Published private(set) var openProjectURLs: Set<URL> = []

    /// Open a project window
    /// - Parameters:
    ///   - url: The project URL to open
    ///   - reuseExisting: If true, bring existing window to front instead of opening new one
    ///   - closeWelcome: Whether to close the welcome window after opening
    func openProjectWindow(url: URL, reuseExisting: Bool = false, closeWelcome: Bool = true) {
        Self.logger.info("[WindowOpeningService] openProjectWindow called - url: \(url.path, privacy: .public), reuseExisting: \(reuseExisting), closeWelcome: \(closeWelcome)")

        // Optionally reuse existing window
        if reuseExisting, let existingWindow = findWindowForProject(url: url) {
            Self.logger.debug("[WindowOpeningService] Reusing existing window for: \(url.path, privacy: .public)")
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if closeWelcome {
                dismissWelcomeWindow?()
            }
            return
        }

        // Open new window
        let config = ProjectWindowConfig(projectURL: url)
        if let openWindow = openWindow {
            Self.logger.info("[WindowOpeningService] Calling openWindow handler for: \(url.path, privacy: .public)")
            openWindow(config)
            openProjectURLs.insert(url)
            if closeWelcome {
                dismissWelcomeWindow?()
            }
        } else {
            Self.logger.error("[WindowOpeningService] No openWindow handler registered!")
            TavernLogger.coordination.error("No openWindow handler registered")
        }
    }

    /// Show the welcome window
    func showWelcomeWindow() {
        if let welcomeWindow = findWelcomeWindowNS() {
            welcomeWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openWelcomeWindow?()
        }
    }

    /// Bring all windows for a project to the front
    func raiseAllWindowsForProject(url: URL) {
        let projectName = url.lastPathComponent
        var foundWindows: [NSWindow] = []

        for window in NSApp.windows {
            // Skip welcome windows
            guard !isWelcomeWindow(window) else { continue }

            // Check if window title contains the project name
            if window.title.contains(projectName) {
                foundWindows.append(window)
            }
        }

        // If we found windows for this project, bring them forward
        // Otherwise bring all non-welcome windows forward as fallback
        let windowsToRaise = foundWindows.isEmpty
            ? NSApp.windows.filter { !isWelcomeWindow($0) }
            : foundWindows

        for window in windowsToRaise {
            window.orderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Mark a project URL as closed (called when window closes)
    func projectWindowClosed(url: URL) {
        openProjectURLs.remove(url)
    }

    /// Find the welcome window (for closing it)
    func findWelcomeWindowNS() -> NSWindow? {
        for window in NSApp.windows {
            if isWelcomeWindow(window) {
                return window
            }
        }
        return nil
    }

    private func findWindowForProject(url: URL) -> NSWindow? {
        // Find window by checking if it's showing this project
        // This is approximate - we check window title contains project name
        for window in NSApp.windows {
            if window.title.contains(url.lastPathComponent) && !isWelcomeWindow(window) {
                return window
            }
        }
        return nil
    }

    private func isWelcomeWindow(_ window: NSWindow) -> Bool {
        // Welcome window has "Tavern at the Spillway" in title but no project indicator
        // or we can check the window group ID
        return window.title.isEmpty || window.title == "The Tavern at the Spillway"
    }

    private init() {}
}

/// View modifier that registers the openWindow environment action
struct WindowOpenerRegistration: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "window")

    func body(content: Content) -> some View {
        content
            .onAppear {
                Self.logger.debug("[WindowOpenerRegistration] Registering openWindow handler")
                WindowOpeningService.shared.openWindow = { config in
                    Self.logger.info("[WindowOpenerRegistration] Opening window for: \(config.projectURL.path, privacy: .public)")
                    openWindow(value: config)
                }
            }
    }
}

/// View modifier for welcome window that registers dismiss action
struct WelcomeWindowRegistration: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "window")

    func body(content: Content) -> some View {
        content
            .onAppear {
                Self.logger.debug("[WelcomeWindowRegistration] Registering all handlers")
                WindowOpeningService.shared.openWindow = { config in
                    Self.logger.info("[WelcomeWindowRegistration] Opening window for: \(config.projectURL.path, privacy: .public)")
                    openWindow(value: config)
                }
                WindowOpeningService.shared.openWelcomeWindow = {
                    Self.logger.debug("[WelcomeWindowRegistration] Opening welcome window")
                    openWindow(id: "welcome")
                }
                WindowOpeningService.shared.dismissWelcomeWindow = {
                    Self.logger.debug("[WelcomeWindowRegistration] Dismissing welcome window")
                    // Use NSApplication to close welcome window (works on macOS 13+)
                    if let window = WindowOpeningService.shared.findWelcomeWindowNS() {
                        window.close()
                    }
                }
            }
    }
}

extension View {
    func registerWindowOpener() -> some View {
        modifier(WindowOpenerRegistration())
    }

    func registerWelcomeWindow() -> some View {
        modifier(WelcomeWindowRegistration())
    }
}

// MARK: - App Delegate

/// AppKit delegate for Dock menu and other OS-level integration
class TavernAppDelegate: NSObject, NSApplicationDelegate {

    /// Provides the Dock icon right-click menu
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        // Recent projects
        let recentPaths = ProjectManager.shared.recentProjectPaths
        if !recentPaths.isEmpty {
            for url in recentPaths.prefix(10) {
                let item = NSMenuItem(
                    title: url.lastPathComponent,
                    action: #selector(openRecentProject(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = url
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Open Project...
        let openItem = NSMenuItem(
            title: "Open Project...",
            action: #selector(openProjectFromDock(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        return menu
    }

    @objc private func openRecentProject(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        Task { @MainActor in
            WindowOpeningService.shared.openProjectWindow(url: url)
        }
    }

    @objc private func openProjectFromDock(_ sender: NSMenuItem) {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.title = "Open Project"
            panel.message = "Select a project directory"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false

            let response = await panel.begin()
            if response == .OK, let url = panel.url {
                WindowOpeningService.shared.openProjectWindow(url: url)
            }
        }
    }
}

// MARK: - App

// MARK: - UI Testing Support

/// Check if the app was launched with --ui-testing flag
private let isUITesting = CommandLine.arguments.contains("--ui-testing")

/// Get the project path from --project-path launch argument
private var uiTestProjectPath: String? {
    guard let index = CommandLine.arguments.firstIndex(of: "--project-path"),
          index + 1 < CommandLine.arguments.count else {
        return nil
    }
    return CommandLine.arguments[index + 1]
}

@main
struct TavernApp: App {
    @NSApplicationDelegateAdaptor(TavernAppDelegate.self) var appDelegate
    @StateObject private var projectManager = ProjectManager.shared

    var body: some Scene {
        // Welcome window (no project) — skipped in UI testing mode
        WindowGroup(id: "welcome") {
            if isUITesting, let path = uiTestProjectPath {
                // In UI testing mode, bypass welcome and open project directly
                Color.clear
                    .onAppear {
                        let url = URL(fileURLWithPath: path)
                        // Ensure the sandbox directory exists
                        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        WindowOpeningService.shared.openProjectWindow(url: url)
                    }
                    .registerWelcomeWindow()
                    .environmentObject(projectManager)
            } else {
                WelcomeView()
                    .environmentObject(projectManager)
                    .registerWelcomeWindow()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Open Project...") {
                    WindowOpeningService.shared.showWelcomeWindow()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                // Open Recent submenu
                Menu("Open Recent") {
                    ForEach(projectManager.recentProjectPaths, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            WindowOpeningService.shared.openProjectWindow(url: url)
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

        // Project windows
        WindowGroup(for: ProjectWindowConfig.self) { $config in
            ProjectWindowView(config: config)
                .environmentObject(projectManager)
                .registerWindowOpener()
        }
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - Project Window Configuration

/// Configuration for a project window
/// Using a struct allows us to add more fields later (window type, view state, etc.)
/// without changing the WindowGroup signature
struct ProjectWindowConfig: Hashable, Codable {
    let projectURL: URL
    // Future: windowType, splitState, etc.
}

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
                                WindowOpeningService.shared.openProjectWindow(url: url)
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
            WindowOpeningService.shared.openProjectWindow(url: url)
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
    @SceneStorage("resourcePanelVisible") private var isResourcePanelVisible: Bool = false
    @StateObject private var resourcePanelViewModel: ResourcePanelViewModel
    @StateObject private var autocomplete: SlashCommandAutocomplete
    @StateObject private var fileMention: FileMentionAutocomplete

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
            // Detail: Chat + optional Resource Panel
            HSplitView {
                ChatView(viewModel: coordinator.activeChatViewModel, autocomplete: autocomplete, fileMention: fileMention)

                if isResourcePanelVisible {
                    ResourcePanelView(viewModel: resourcePanelViewModel)
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
                .help(isResourcePanelVisible ? "Hide Resources" : "Show Resources")
            }
        }
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

#Preview("Welcome") {
    WelcomeView()
        .environmentObject(ProjectManager.shared)
}

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
