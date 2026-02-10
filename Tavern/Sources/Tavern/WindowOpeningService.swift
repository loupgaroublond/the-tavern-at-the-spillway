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

// MARK: - Window Registration View Modifiers

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
