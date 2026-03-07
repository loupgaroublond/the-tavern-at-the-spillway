// MARK: - Provenance: REQ-UX-007, REQ-UX-008

import Foundation
import Testing
@testable import TavernCore

// MARK: - Project-as-Document & Multi-Window Tests

@Suite("Project-as-Document & Multi-Window", .tags(.reqUX007, .reqUX008), .timeLimit(.minutes(2)))
struct MultiWindowTests {

    // MARK: - Helpers

    /// Create a temporary directory URL for test projects
    private func tempProjectURL(_ name: String = "test-project") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tavern-tests")
            .appendingPathComponent(name)
            .appendingPathComponent(UUID().uuidString)
    }

    /// Clean up projects from the shared ProjectManager after a test
    @MainActor
    private func cleanUpProjects(_ projects: [TavernProject]) {
        let manager = ProjectManager.shared
        for project in projects {
            manager.closeProject(project)
        }
    }

    // MARK: - ProjectManager Singleton

    @Test("ProjectManager.shared is the sole singleton")
    @MainActor
    func projectManagerIsSingleton() {
        let a = ProjectManager.shared
        let b = ProjectManager.shared
        #expect(a === b, "ProjectManager.shared must return the same instance")
    }

    // MARK: - Multiple Open Projects

    @Test("Can hold multiple open projects simultaneously")
    @MainActor
    func multipleOpenProjects() async {
        let manager = ProjectManager.shared
        let urlA = tempProjectURL("project-a")
        let urlB = tempProjectURL("project-b")
        let urlC = tempProjectURL("project-c")

        // Create temp directories
        for url in [urlA, urlB, urlC] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let projectA = await manager.openProject(at: urlA)
        let projectB = await manager.openProject(at: urlB)
        let projectC = await manager.openProject(at: urlC)

        #expect(manager.openProjects.count >= 3, "Manager must hold at least 3 open projects")
        #expect(manager.openProjects.contains(projectA))
        #expect(manager.openProjects.contains(projectB))
        #expect(manager.openProjects.contains(projectC))

        cleanUpProjects([projectA, projectB, projectC])

        // Clean up temp dirs
        for url in [urlA, urlB, urlC] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Project Independence

    @Test("Each project has a unique identity")
    @MainActor
    func projectsHaveUniqueIds() async {
        let manager = ProjectManager.shared
        let urlA = tempProjectURL("independent-a")
        let urlB = tempProjectURL("independent-b")

        for url in [urlA, urlB] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let projectA = await manager.openProject(at: urlA)
        let projectB = await manager.openProject(at: urlB)

        #expect(projectA.id != projectB.id, "Projects must have distinct UUIDs")
        #expect(projectA.rootURL != projectB.rootURL, "Projects must have distinct root URLs")
        #expect(projectA.name != projectB.name, "Projects must have distinct names")

        cleanUpProjects([projectA, projectB])

        for url in [urlA, urlB] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test("Projects do not share state")
    @MainActor
    func projectsDoNotShareState() {
        let urlA = tempProjectURL("isolated-a")
        let urlB = tempProjectURL("isolated-b")

        let projectA = TavernProject(rootURL: urlA)
        let projectB = TavernProject(rootURL: urlB)

        // Each project starts uninitialized independently
        #expect(projectA.isReady == false)
        #expect(projectB.isReady == false)

        // Providers are nil independently
        #expect(projectA.servitorProvider == nil)
        #expect(projectB.servitorProvider == nil)
        #expect(projectA.resourceProvider == nil)
        #expect(projectB.resourceProvider == nil)

        // Distinct identities
        #expect(projectA.id != projectB.id)
    }

    @Test("TavernProject derives name from directory")
    @MainActor
    func projectNameFromDirectory() {
        let url = URL(fileURLWithPath: "/tmp/my-cool-project")
        let project = TavernProject(rootURL: url)

        #expect(project.name == "my-cool-project")
    }

    // MARK: - Deduplication

    @Test("Opening same directory twice returns existing project")
    @MainActor
    func openSameDirectoryReturnsExisting() async {
        let manager = ProjectManager.shared
        let url = tempProjectURL("dedup-project")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let first = await manager.openProject(at: url)
        let countAfterFirst = manager.openProjects.count

        let second = await manager.openProject(at: url)

        #expect(first === second, "Opening the same URL must return the same project instance")
        #expect(manager.openProjects.count == countAfterFirst, "No duplicate entry in openProjects")

        cleanUpProjects([first])

        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Close Project

    @Test("Closing a project removes it from openProjects")
    @MainActor
    func closeProjectRemovesFromList() async {
        let manager = ProjectManager.shared
        let url = tempProjectURL("close-me")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let project = await manager.openProject(at: url)
        #expect(manager.openProjects.contains(project))

        manager.closeProject(project)
        #expect(!manager.openProjects.contains(project), "Closed project must not remain in openProjects")

        try? FileManager.default.removeItem(at: url)
    }

    @Test("Closing one project does not affect others")
    @MainActor
    func closeOneProjectKeepsOthers() async {
        let manager = ProjectManager.shared
        let urlA = tempProjectURL("keep-a")
        let urlB = tempProjectURL("remove-b")

        for url in [urlA, urlB] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let projectA = await manager.openProject(at: urlA)
        let projectB = await manager.openProject(at: urlB)

        manager.closeProject(projectB)

        #expect(manager.openProjects.contains(projectA), "Unrelated project must survive another's close")
        #expect(!manager.openProjects.contains(projectB))

        cleanUpProjects([projectA])

        for url in [urlA, urlB] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Recent Projects

    @Test("Opening a project adds it to recent projects")
    @MainActor
    func openProjectAddsToRecent() async {
        let manager = ProjectManager.shared
        let url = tempProjectURL("recent-test")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let project = await manager.openProject(at: url)

        #expect(manager.recentProjectPaths.contains(url), "Opened project URL must appear in recentProjectPaths")

        cleanUpProjects([project])

        try? FileManager.default.removeItem(at: url)
    }

    @Test("Most recently opened project appears first in recents")
    @MainActor
    func recentProjectsOrderedMostRecentFirst() async {
        let manager = ProjectManager.shared
        let urlA = tempProjectURL("older")
        let urlB = tempProjectURL("newer")

        for url in [urlA, urlB] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let projectA = await manager.openProject(at: urlA)
        let projectB = await manager.openProject(at: urlB)

        // urlB was opened last, so it should be first in recents
        if let firstRecent = manager.recentProjectPaths.first {
            #expect(firstRecent == urlB, "Most recently opened project must be first")
        } else {
            Issue.record("recentProjectPaths should not be empty")
        }

        cleanUpProjects([projectA, projectB])

        for url in [urlA, urlB] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test("Reopening a project moves it to front of recents")
    @MainActor
    func reopenProjectMovesToFrontOfRecents() async {
        let manager = ProjectManager.shared
        let urlA = tempProjectURL("first-open")
        let urlB = tempProjectURL("second-open")

        for url in [urlA, urlB] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let projectA = await manager.openProject(at: urlA)
        _ = await manager.openProject(at: urlB)

        // Close and reopen A — it should now be at front
        manager.closeProject(projectA)
        let projectA2 = await manager.openProject(at: urlA)

        if let firstRecent = manager.recentProjectPaths.first {
            #expect(firstRecent == urlA, "Reopened project must move to front of recents")
        } else {
            Issue.record("recentProjectPaths should not be empty")
        }

        cleanUpProjects([projectA2])
        // Clean projectB too — it may still be open
        let remainingB = manager.openProjects.first { $0.rootURL == urlB }
        if let b = remainingB { cleanUpProjects([b]) }

        for url in [urlA, urlB] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @Test("clearRecentProjects empties the list")
    @MainActor
    func clearRecentProjectsWorks() async {
        let manager = ProjectManager.shared
        let url = tempProjectURL("will-clear")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let project = await manager.openProject(at: url)
        #expect(!manager.recentProjectPaths.isEmpty)

        manager.clearRecentProjects()
        #expect(manager.recentProjectPaths.isEmpty, "clearRecentProjects must empty the list")

        cleanUpProjects([project])

        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - TavernProject Identity

    @Test("TavernProject equality is identity-based (UUID)")
    @MainActor
    func projectEqualityByUUID() {
        let url = URL(fileURLWithPath: "/tmp/equality-test")
        let projectA = TavernProject(rootURL: url)
        let projectB = TavernProject(rootURL: url)

        // Same URL but different instances get different UUIDs
        #expect(projectA != projectB, "Two TavernProject instances at same URL must not be equal (distinct UUIDs)")
        #expect(projectA == projectA, "Same instance must equal itself")
    }

    @Test("TavernProject conforms to Hashable via UUID")
    @MainActor
    func projectHashableViaUUID() {
        let url = URL(fileURLWithPath: "/tmp/hash-test")
        let project = TavernProject(rootURL: url)

        var set: Set<TavernProject> = []
        set.insert(project)
        set.insert(project) // duplicate insert

        #expect(set.count == 1, "Set should deduplicate same instance")

        let project2 = TavernProject(rootURL: url)
        set.insert(project2)

        #expect(set.count == 2, "Different instances (different UUIDs) must be distinct in Set")
    }

    // MARK: - Fresh Stack per Project (No Shared Providers)
    // Note: ProjectWindowConfig tests belong in TavernTests (Tavern app target),
    // since ProjectWindowConfig is defined in the Tavern target, not TavernCore.

    @Test("New TavernProject starts with nil providers")
    @MainActor
    func newProjectHasNilProviders() {
        let project = TavernProject(rootURL: URL(fileURLWithPath: "/tmp/nil-providers"))

        #expect(project.servitorProvider == nil)
        #expect(project.resourceProvider == nil)
        #expect(project.commandProvider == nil)
        #expect(project.permissionProvider == nil)
        #expect(project.isReady == false)
    }

    @Test("Two uninitialized projects share no provider instances")
    @MainActor
    func uninitializedProjectsShareNothing() {
        let projectA = TavernProject(rootURL: URL(fileURLWithPath: "/tmp/share-a"))
        let projectB = TavernProject(rootURL: URL(fileURLWithPath: "/tmp/share-b"))

        // Both nil — but importantly, when initialized they will each create
        // their own provider stack. We verify they start from the same clean slate.
        #expect(projectA.servitorProvider == nil)
        #expect(projectB.servitorProvider == nil)
        #expect(projectA.id != projectB.id, "Even uninitialized projects must have distinct IDs")
    }
}
