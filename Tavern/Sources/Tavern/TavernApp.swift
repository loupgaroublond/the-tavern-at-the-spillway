import SwiftUI
import TavernCore

// MARK: - Provenance: REQ-UX-007, REQ-UX-008

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

// MARK: - App

@main
struct TavernApp: App {
    @NSApplicationDelegateAdaptor(TavernAppDelegate.self) var appDelegate
    @State private var projectManager = ProjectManager.shared

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
                    .environment(projectManager)
            } else {
                WelcomeView()
                    .environment(projectManager)
                    .registerWelcomeWindow()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            #if DEBUG
            // Debug menu
            CommandGroup(after: .help) {
                Button("Toggle Log Window") {
                    DebugLogPanelController.shared.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            #endif

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
                .environment(projectManager)
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
