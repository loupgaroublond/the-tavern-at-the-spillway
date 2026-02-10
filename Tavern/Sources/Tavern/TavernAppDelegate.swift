import AppKit
import TavernCore

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
