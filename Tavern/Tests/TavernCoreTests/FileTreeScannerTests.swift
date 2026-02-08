import Foundation
import Testing
@testable import TavernCore

@Suite("FileTreeScanner Tests")
struct FileTreeScannerTests {

    let scanner = FileTreeScanner()

    // MARK: - Helpers

    private func createTempDir() throws -> URL {
        try TestFixtures.createTempDirectory()
    }

    private func cleanup(_ url: URL) {
        TestFixtures.cleanupTempDirectory(url)
    }

    // MARK: - Basic Scanning

    @Test("Scan returns files and directories")
    func scanReturnsFilesAndDirectories() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        // Create a file and a directory
        try "hello".write(to: root.appendingPathComponent("readme.md"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("src"), withIntermediateDirectories: false)

        let nodes = try scanner.scanDirectory(at: root, relativeTo: root)
        #expect(nodes.count == 2)

        let dirNode = nodes.first { $0.isDirectory }
        let fileNode = nodes.first { !$0.isDirectory }

        #expect(dirNode != nil)
        #expect(fileNode != nil)
        #expect(dirNode?.name == "src")
        #expect(fileNode?.name == "readme.md")
    }

    @Test("Directories sorted before files")
    func directoriesSortedBeforeFiles() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        try "a".write(to: root.appendingPathComponent("aaa.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("zzz"), withIntermediateDirectories: false)

        let nodes = try scanner.scanDirectory(at: root, relativeTo: root)
        #expect(nodes.count == 2)
        #expect(nodes[0].isDirectory) // Directory first even though 'z' > 'a'
        #expect(!nodes[1].isDirectory)
    }

    @Test("Alphabetical within groups")
    func alphabeticalWithinGroups() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        try FileManager.default.createDirectory(at: root.appendingPathComponent("beta"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: false)
        try "b".write(to: root.appendingPathComponent("banana.txt"), atomically: true, encoding: .utf8)
        try "a".write(to: root.appendingPathComponent("apple.txt"), atomically: true, encoding: .utf8)

        let nodes = try scanner.scanDirectory(at: root, relativeTo: root)
        #expect(nodes.count == 4)
        #expect(nodes[0].name == "alpha")
        #expect(nodes[1].name == "beta")
        #expect(nodes[2].name == "apple.txt")
        #expect(nodes[3].name == "banana.txt")
    }

    @Test("Hidden files excluded")
    func hiddenFilesExcluded() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        try "visible".write(to: root.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: root.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)

        let nodes = try scanner.scanDirectory(at: root, relativeTo: root)
        #expect(nodes.count == 1)
        #expect(nodes[0].name == "visible.txt")
    }

    @Test("Ignored directories excluded")
    func ignoredDirectoriesExcluded() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        try FileManager.default.createDirectory(at: root.appendingPathComponent("src"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".build"), withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("DerivedData"), withIntermediateDirectories: false)

        let nodes = try scanner.scanDirectory(at: root, relativeTo: root)
        #expect(nodes.count == 1)
        #expect(nodes[0].name == "src")
    }

    @Test("Empty directory handled")
    func emptyDirectoryHandled() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        let nodes = try scanner.scanDirectory(at: root, relativeTo: root)
        #expect(nodes.isEmpty)
    }

    @Test("Relative paths as IDs")
    func relativePathsAsIDs() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        let subdir = root.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: false)
        try "code".write(to: subdir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        // Scan the subdirectory
        let nodes = try scanner.scanDirectory(at: subdir, relativeTo: root)
        #expect(nodes.count == 1)
        #expect(nodes[0].id == "src/main.swift")
    }

    @Test("File extensions detected")
    func fileExtensionsDetected() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        try "swift".write(to: root.appendingPathComponent("app.swift"), atomically: true, encoding: .utf8)
        try "json".write(to: root.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "none".write(to: root.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)

        let nodes = try scanner.scanDirectory(at: root, relativeTo: root)
        let swiftNode = nodes.first { $0.name == "app.swift" }
        let jsonNode = nodes.first { $0.name == "config.json" }
        let noExtNode = nodes.first { $0.name == "Makefile" }

        #expect(swiftNode?.fileExtension == "swift")
        #expect(jsonNode?.fileExtension == "json")
        #expect(noExtNode?.fileExtension == nil)
    }

    @Test("Non-existent directory throws")
    func nonExistentDirectoryThrows() throws {
        let bogusURL = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-\(UUID().uuidString)")
        #expect(throws: (any Error).self) {
            try scanner.scanDirectory(at: bogusURL, relativeTo: bogusURL)
        }
    }
}
