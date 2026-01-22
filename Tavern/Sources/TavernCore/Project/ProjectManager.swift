import Foundation
import os.log

/// Manages open projects across the application
@MainActor
public final class ProjectManager: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for the application
    public static let shared = ProjectManager()

    // MARK: - Properties

    /// All currently open projects
    @Published public private(set) var openProjects: [TavernProject] = []

    /// Recently opened project paths (for "Open Recent" menu)
    @Published public private(set) var recentProjectPaths: [URL] = []

    /// Maximum number of recent projects to remember
    private let maxRecentProjects = 10

    /// UserDefaults key for recent projects
    private let recentProjectsKey = "com.tavern.recentProjects"

    // MARK: - Initialization

    private init() {
        loadRecentProjects()
    }

    // MARK: - Open Project

    /// Open a project at the given directory
    /// - Parameter url: The directory URL
    /// - Returns: The opened project
    @discardableResult
    public func openProject(at url: URL) async -> TavernProject {
        TavernLogger.coordination.info("Opening project at: \(url.path)")

        // Check if already open
        if let existing = openProjects.first(where: { $0.rootURL == url }) {
            TavernLogger.coordination.debug("Project already open: \(url.path)")
            return existing
        }

        // Create and initialize
        let project = TavernProject(rootURL: url)
        openProjects.append(project)

        // Add to recent projects
        addToRecentProjects(url)

        // Initialize asynchronously
        await project.initialize()

        return project
    }

    /// Close a project
    /// - Parameter project: The project to close
    public func closeProject(_ project: TavernProject) {
        TavernLogger.coordination.info("Closing project: \(project.name)")
        openProjects.removeAll { $0.id == project.id }
    }

    // MARK: - Recent Projects

    /// Add a URL to recent projects
    private func addToRecentProjects(_ url: URL) {
        // Remove if already present (will re-add at front)
        recentProjectPaths.removeAll { $0 == url }

        // Add at front
        recentProjectPaths.insert(url, at: 0)

        // Trim to max
        if recentProjectPaths.count > maxRecentProjects {
            recentProjectPaths = Array(recentProjectPaths.prefix(maxRecentProjects))
        }

        saveRecentProjects()
    }

    /// Clear recent projects list
    public func clearRecentProjects() {
        recentProjectPaths.removeAll()
        saveRecentProjects()
    }

    /// Load recent projects from UserDefaults
    private func loadRecentProjects() {
        guard let data = UserDefaults.standard.data(forKey: recentProjectsKey),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }

        recentProjectPaths = paths.compactMap { URL(fileURLWithPath: $0) }
        TavernLogger.coordination.debug("Loaded \(self.recentProjectPaths.count) recent projects")
    }

    /// Save recent projects to UserDefaults
    private func saveRecentProjects() {
        let paths = recentProjectPaths.map { $0.path }
        if let data = try? JSONEncoder().encode(paths) {
            UserDefaults.standard.set(data, forKey: recentProjectsKey)
        }
    }
}
