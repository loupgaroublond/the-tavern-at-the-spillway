import Foundation
import Testing
import TavernKit
@testable import ResourcePanelTile

@Suite("ResourcePanelTile File Tree Tests", .timeLimit(.minutes(1)))
@MainActor
struct ResourcePanelTileFileTests {

    // MARK: - Helpers

    private static func makeTile(
        provider: StubResourceProvider = StubResourceProvider(),
        rootURL: URL = URL(fileURLWithPath: "/tmp/test-\(UUID().uuidString)")
    ) -> ResourcePanelTile {
        let responder = ResourcePanelResponder(onFileSelected: { _ in })
        return ResourcePanelTile(resourceProvider: provider, responder: responder, rootURL: rootURL)
    }

    // MARK: - Initial State

    @Test("Starts with empty tree")
    func startsWithEmptyTree() {
        let tile = Self.makeTile()
        #expect(tile.rootNodes.isEmpty)
        #expect(tile.selectedFileURL == nil)
        #expect(tile.selectedFileContent == nil)
        #expect(tile.selectedFileName == nil)
        #expect(tile.isLoading == false)
        #expect(tile.error == nil)
    }

    // MARK: - Loading

    @Test("Loads root directory from provider")
    func loadsRootDirectory() {
        let provider = StubResourceProvider()
        provider.scanResult = [
            FileTreeNode(id: "test.txt", name: "test.txt", url: URL(fileURLWithPath: "/tmp/test.txt"), isDirectory: false, fileExtension: "txt"),
            FileTreeNode(id: "src", name: "src", url: URL(fileURLWithPath: "/tmp/src"), isDirectory: true),
        ]
        let tile = Self.makeTile(provider: provider)

        tile.loadRootDirectory()

        #expect(tile.rootNodes.count == 2)
        #expect(tile.error == nil)
    }

    @Test("Load error sets error message")
    func loadErrorSetsError() {
        let provider = StubResourceProvider()
        provider.scanError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Access denied"])
        let tile = Self.makeTile(provider: provider)

        tile.loadRootDirectory()

        #expect(tile.rootNodes.isEmpty)
        #expect(tile.error == "Access denied")
    }

    // MARK: - Directory Expansion

    @Test("Toggle directory expands and loads children")
    func toggleDirectoryExpands() {
        let provider = StubResourceProvider()
        let dirNode = FileTreeNode(id: "src", name: "src", url: URL(fileURLWithPath: "/tmp/src"), isDirectory: true)
        provider.scanResult = [dirNode]
        provider.childrenResult = [
            FileTreeNode(id: "src/main.swift", name: "main.swift", url: URL(fileURLWithPath: "/tmp/src/main.swift"), isDirectory: false, fileExtension: "swift"),
        ]
        let tile = Self.makeTile(provider: provider)
        tile.loadRootDirectory()

        tile.toggleDirectory(tile.rootNodes[0])

        #expect(tile.rootNodes[0].isExpanded == true)
        #expect(tile.rootNodes[0].children?.count == 1)
        #expect(tile.rootNodes[0].children?[0].name == "main.swift")
    }

    @Test("Toggle expanded directory collapses it")
    func toggleCollapse() {
        let provider = StubResourceProvider()
        let dirNode = FileTreeNode(id: "src", name: "src", url: URL(fileURLWithPath: "/tmp/src"), isDirectory: true)
        provider.scanResult = [dirNode]
        provider.childrenResult = [
            FileTreeNode(id: "src/main.swift", name: "main.swift", url: URL(fileURLWithPath: "/tmp/src/main.swift"), isDirectory: false, fileExtension: "swift"),
        ]
        let tile = Self.makeTile(provider: provider)
        tile.loadRootDirectory()

        tile.toggleDirectory(tile.rootNodes[0])
        #expect(tile.rootNodes[0].isExpanded == true)

        tile.toggleDirectory(tile.rootNodes[0])
        #expect(tile.rootNodes[0].isExpanded == false)
        #expect(tile.rootNodes[0].children != nil) // children still cached
    }

    // MARK: - File Selection

    @Test("Select file loads content")
    func selectFileLoadsContent() {
        let provider = StubResourceProvider()
        let fileNode = FileTreeNode(id: "hello.txt", name: "hello.txt", url: URL(fileURLWithPath: "/tmp/hello.txt"), isDirectory: false, fileExtension: "txt")
        provider.scanResult = [fileNode]
        provider.fileContent = "Hello, World!"
        let tile = Self.makeTile(provider: provider)
        tile.loadRootDirectory()

        tile.selectFile(tile.rootNodes[0])

        #expect(tile.selectedFileName == "hello.txt")
        #expect(tile.selectedFileContent == "Hello, World!")
        #expect(tile.isLoading == false)
    }

    @Test("Deselect file clears state")
    func deselectFile() {
        let provider = StubResourceProvider()
        let fileNode = FileTreeNode(id: "test.txt", name: "test.txt", url: URL(fileURLWithPath: "/tmp/test.txt"), isDirectory: false, fileExtension: "txt")
        provider.scanResult = [fileNode]
        provider.fileContent = "content"
        let tile = Self.makeTile(provider: provider)
        tile.loadRootDirectory()
        tile.selectFile(tile.rootNodes[0])
        #expect(tile.selectedFileURL != nil)

        tile.deselectFile()

        #expect(tile.selectedFileURL == nil)
        #expect(tile.selectedFileContent == nil)
        #expect(tile.selectedFileName == nil)
    }

    // MARK: - Edge Cases

    @Test("Binary file sets error")
    func binaryFileDetection() {
        let provider = StubResourceProvider()
        let fileNode = FileTreeNode(id: "image.bin", name: "image.bin", url: URL(fileURLWithPath: "/tmp/image.bin"), isDirectory: false, fileExtension: "bin")
        provider.scanResult = [fileNode]
        provider.isBinary = true
        let tile = Self.makeTile(provider: provider)
        tile.loadRootDirectory()

        tile.selectFile(tile.rootNodes[0])

        #expect(tile.selectedFileContent == nil)
        #expect(tile.error?.contains("Binary") == true)
    }

    @Test("File too large sets error")
    func fileTooLargeHandling() {
        let provider = StubResourceProvider()
        let fileNode = FileTreeNode(id: "large.txt", name: "large.txt", url: URL(fileURLWithPath: "/tmp/large.txt"), isDirectory: false, fileExtension: "txt")
        provider.scanResult = [fileNode]
        provider.isTooLarge = true
        let tile = Self.makeTile(provider: provider)
        tile.loadRootDirectory()

        tile.selectFile(tile.rootNodes[0])

        #expect(tile.selectedFileContent == nil)
        #expect(tile.error?.contains("too large") == true)
    }

    @Test("File read error sets error")
    func fileReadErrorHandling() {
        let provider = StubResourceProvider()
        let fileNode = FileTreeNode(id: "ghost.txt", name: "ghost.txt", url: URL(fileURLWithPath: "/tmp/ghost.txt"), isDirectory: false, fileExtension: "txt")
        provider.scanResult = [fileNode]
        provider.readError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        let tile = Self.makeTile(provider: provider)
        tile.loadRootDirectory()

        tile.selectFile(tile.rootNodes[0])

        #expect(tile.error != nil)
        #expect(tile.selectedFileContent == nil)
    }

    @Test("Responder fires on file selection")
    func responderFiresOnFileSelection() {
        let provider = StubResourceProvider()
        let fileURL = URL(fileURLWithPath: "/tmp/selected.txt")
        let fileNode = FileTreeNode(id: "selected.txt", name: "selected.txt", url: fileURL, isDirectory: false, fileExtension: "txt")
        provider.scanResult = [fileNode]
        provider.fileContent = "content"

        nonisolated(unsafe) var capturedURL: URL?
        let responder = ResourcePanelResponder(onFileSelected: { url in capturedURL = url })
        let tile = ResourcePanelTile(resourceProvider: provider, responder: responder, rootURL: URL(fileURLWithPath: "/tmp"))
        tile.loadRootDirectory()

        tile.selectFile(tile.rootNodes[0])

        #expect(capturedURL == fileURL)
    }
}

