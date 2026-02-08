import Foundation
import Testing
@testable import TavernCore

@Suite("ResourcePanelViewModel Tests")
@MainActor
struct ResourcePanelViewModelTests {

    // MARK: - Helpers

    private func createTempDir() throws -> URL {
        try TestFixtures.createTempDirectory()
    }

    private func cleanup(_ url: URL) {
        TestFixtures.cleanupTempDirectory(url)
    }

    // MARK: - Initial State

    @Test("Starts with empty tree")
    func startsWithEmptyTree() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        let vm = ResourcePanelViewModel(rootURL: root)
        #expect(vm.rootNodes.isEmpty)
        #expect(vm.selectedFileURL == nil)
        #expect(vm.selectedFileContent == nil)
        #expect(vm.selectedFileName == nil)
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    // MARK: - Loading

    @Test("Loads root directory")
    func loadsRootDirectory() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        try "hello".write(to: root.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("src"), withIntermediateDirectories: false)

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.loadRootDirectory()

        #expect(vm.rootNodes.count == 2)
        #expect(vm.error == nil)
    }

    // MARK: - Directory Expansion

    @Test("Expands directory loads children")
    func expandsDirectoryLoadsChildren() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        let subdir = root.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: false)
        try "code".write(to: subdir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.loadRootDirectory()

        #expect(vm.rootNodes.count == 1)
        let dirNode = vm.rootNodes[0]
        #expect(dirNode.isDirectory)
        #expect(dirNode.children == nil) // Not loaded yet
        #expect(dirNode.isExpanded == false)

        // Expand
        vm.toggleDirectory(dirNode)

        let expandedNode = vm.rootNodes[0]
        #expect(expandedNode.isExpanded == true)
        #expect(expandedNode.children?.count == 1)
        #expect(expandedNode.children?[0].name == "main.swift")
    }

    @Test("Collapses expanded directory")
    func collapsesExpandedDirectory() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        let subdir = root.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: false)
        try "code".write(to: subdir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.loadRootDirectory()

        // Expand then collapse
        vm.toggleDirectory(vm.rootNodes[0])
        #expect(vm.rootNodes[0].isExpanded == true)

        vm.toggleDirectory(vm.rootNodes[0])
        #expect(vm.rootNodes[0].isExpanded == false)
        // Children should still be loaded (just collapsed)
        #expect(vm.rootNodes[0].children != nil)
    }

    // MARK: - File Selection

    @Test("Selects file and loads content")
    func selectsFileAndLoadsContent() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        let content = "Hello, World!"
        let fileURL = root.appendingPathComponent("hello.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.loadRootDirectory()

        let fileNode = vm.rootNodes[0]
        vm.selectFile(fileNode)

        #expect(vm.selectedFileURL == fileURL.resolvingSymlinksInPath())
        #expect(vm.selectedFileName == "hello.txt")
        #expect(vm.selectedFileContent == content)
        #expect(vm.isLoading == false)
    }

    @Test("Deselects file")
    func deselectsFile() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        try "test".write(to: root.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.loadRootDirectory()
        vm.selectFile(vm.rootNodes[0])
        #expect(vm.selectedFileURL != nil)

        vm.deselectFile()
        #expect(vm.selectedFileURL == nil)
        #expect(vm.selectedFileContent == nil)
        #expect(vm.selectedFileName == nil)
    }

    // MARK: - Edge Cases

    @Test("Binary file detection")
    func binaryFileDetection() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        // Write binary data (contains null bytes)
        let binaryURL = root.appendingPathComponent("image.bin")
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0x00])
        data.append(contentsOf: Array(repeating: UInt8(0xFF), count: 100))
        try data.write(to: binaryURL)

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.loadRootDirectory()

        let fileNode = vm.rootNodes[0]
        vm.selectFile(fileNode)

        #expect(vm.selectedFileContent == "Binary file")
    }

    @Test("File too large handling")
    func fileTooLargeHandling() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        // Write a file > 1MB
        let largeURL = root.appendingPathComponent("large.txt")
        let largeData = Data(repeating: 0x41, count: 1_048_577) // Just over 1MB
        try largeData.write(to: largeURL)

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.loadRootDirectory()

        let fileNode = vm.rootNodes[0]
        vm.selectFile(fileNode)

        #expect(vm.selectedFileContent?.contains("File too large") == true)
    }

    @Test("File read error handling")
    func fileReadErrorHandling() throws {
        let root = try createTempDir()
        defer { cleanup(root) }

        // Create a node pointing to a non-existent file
        let fakeNode = FileTreeNode(
            id: "ghost.txt",
            name: "ghost.txt",
            url: root.appendingPathComponent("ghost.txt"),
            isDirectory: false,
            fileExtension: "txt"
        )

        let vm = ResourcePanelViewModel(rootURL: root)
        vm.selectFile(fakeNode)

        #expect(vm.error != nil)
        #expect(vm.selectedFileContent == nil)
    }
}
