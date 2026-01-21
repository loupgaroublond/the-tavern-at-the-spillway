import Foundation
import Testing
@testable import TavernCore

@Suite("Document Tests")
struct DocumentTests {

    @Test("Document has all required properties")
    func documentHasProperties() {
        let doc = Document(
            id: "test-doc",
            title: "Test Document",
            frontmatter: ["author": "Test"],
            content: "Hello, world!"
        )

        #expect(doc.id == "test-doc")
        #expect(doc.title == "Test Document")
        #expect(doc.frontmatter["author"] == "Test")
        #expect(doc.content == "Hello, world!")
    }

    @Test("Document renders with frontmatter")
    func documentRendersWithFrontmatter() {
        let doc = Document(
            id: "test",
            title: "My Title",
            frontmatter: ["key": "value"],
            content: "# Hello\n\nContent here."
        )

        let rendered = doc.render()

        #expect(rendered.contains("---"))
        #expect(rendered.contains("title: My Title"))
        #expect(rendered.contains("key: value"))
        #expect(rendered.contains("# Hello"))
        #expect(rendered.contains("Content here."))
    }

    @Test("Document renders without frontmatter when empty")
    func documentRendersWithoutFrontmatter() {
        let doc = Document(
            id: "test",
            content: "Just content"
        )

        let rendered = doc.render()

        #expect(!rendered.contains("---"))
        #expect(rendered == "Just content")
    }

    @Test("Document parses frontmatter correctly")
    func documentParsesFrontmatter() {
        let text = """
        ---
        title: Parsed Title
        author: Test Author
        version: 1.0
        ---

        # Main Content

        This is the body.
        """

        let doc = Document.parse(id: "parsed", from: text)

        #expect(doc.id == "parsed")
        #expect(doc.title == "Parsed Title")
        #expect(doc.frontmatter["author"] == "Test Author")
        #expect(doc.frontmatter["version"] == "1.0")
        #expect(doc.content.contains("# Main Content"))
        #expect(doc.content.contains("This is the body."))
    }

    @Test("Document parses content without frontmatter")
    func documentParsesWithoutFrontmatter() {
        let text = "# Just Content\n\nNo frontmatter here."

        let doc = Document.parse(id: "simple", from: text)

        #expect(doc.title == nil)
        #expect(doc.frontmatter.isEmpty)
        #expect(doc.content == text)
    }

    @Test("Document handles quoted values in frontmatter")
    func documentHandlesQuotedValues() {
        let text = """
        ---
        title: "Value: with colon"
        note: "Has # and other chars"
        ---

        Content
        """

        let doc = Document.parse(id: "quoted", from: text)

        #expect(doc.title == "Value: with colon")
        #expect(doc.frontmatter["note"] == "Has # and other chars")
    }

    @Test("Document escapes special characters when rendering")
    func documentEscapesSpecialChars() {
        let doc = Document(
            id: "escape",
            frontmatter: ["special": "value: with colon"]
        )

        let rendered = doc.render()

        // Should have quotes around the value
        #expect(rendered.contains("special: \"value: with colon\""))
    }
}

@Suite("DocStore Tests")
struct DocStoreTests {

    func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        return tempDir
    }

    func cleanupDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("DocStore creates directory if needed")
    func docStoreCreatesDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nested")

        defer { cleanupDirectory(tempDir.deletingLastPathComponent()) }

        let store = try DocStore(rootDirectory: tempDir, createIfNeeded: true)

        #expect(FileManager.default.fileExists(atPath: store.rootDirectory.path))
    }

    @Test("DocStore creates file")
    func docStoreCreatesFile() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)
        let doc = Document(
            id: "new-doc",
            title: "New Document",
            content: "Content here"
        )

        try store.create(doc)

        let fileURL = tempDir.appendingPathComponent("new-doc.md")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(contents.contains("title: New Document"))
        #expect(contents.contains("Content here"))
    }

    @Test("DocStore reads file")
    func docStoreReadsFile() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        // Create a file directly
        let fileURL = tempDir.appendingPathComponent("readable.md")
        let content = """
        ---
        title: Readable Doc
        ---

        This is readable content.
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = try DocStore(rootDirectory: tempDir)
        let doc = try store.read(id: "readable")

        #expect(doc.id == "readable")
        #expect(doc.title == "Readable Doc")
        #expect(doc.content.contains("This is readable content."))
    }

    @Test("DocStore updates file")
    func docStoreUpdatesFile() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        // Create initial document
        var doc = Document(
            id: "update-me",
            title: "Original Title",
            content: "Original content"
        )
        try store.create(doc)

        // Update it
        doc.title = "Updated Title"
        doc.content = "Updated content"
        try store.update(doc)

        // Read back
        let updated = try store.read(id: "update-me")
        #expect(updated.title == "Updated Title")
        #expect(updated.content == "Updated content")
    }

    @Test("DocStore deletes file")
    func docStoreDeletesFile() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        let doc = Document(id: "delete-me", content: "Goodbye")
        try store.create(doc)

        #expect(store.exists(id: "delete-me") == true)

        try store.delete(id: "delete-me")

        #expect(store.exists(id: "delete-me") == false)
    }

    @Test("DocStore parses frontmatter on read")
    func docStoreParsesFrontmatter() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        // Create file with frontmatter
        let fileURL = tempDir.appendingPathComponent("with-fm.md")
        let content = """
        ---
        title: Frontmatter Doc
        author: Test Author
        priority: high
        ---

        # Document Content

        This document has metadata.
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = try DocStore(rootDirectory: tempDir)
        let doc = try store.read(id: "with-fm")

        #expect(doc.title == "Frontmatter Doc")
        #expect(doc.frontmatter["author"] == "Test Author")
        #expect(doc.frontmatter["priority"] == "high")
        #expect(doc.content.contains("# Document Content"))
    }

    @Test("DocStore throws on duplicate create")
    func docStoreThrowsOnDuplicateCreate() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)
        let doc = Document(id: "duplicate", content: "First")

        try store.create(doc)

        do {
            try store.create(doc)
            Issue.record("Expected error for duplicate create")
        } catch DocStoreError.documentAlreadyExists(let id) {
            #expect(id == "duplicate")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("DocStore throws on read missing")
    func docStoreThrowsOnReadMissing() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        do {
            _ = try store.read(id: "nonexistent")
            Issue.record("Expected error for missing document")
        } catch DocStoreError.documentNotFound(let id) {
            #expect(id == "nonexistent")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("DocStore throws on update missing")
    func docStoreThrowsOnUpdateMissing() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)
        let doc = Document(id: "missing", content: "Content")

        do {
            try store.update(doc)
            Issue.record("Expected error for updating missing document")
        } catch DocStoreError.documentNotFound(let id) {
            #expect(id == "missing")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("DocStore throws on delete missing")
    func docStoreThrowsOnDeleteMissing() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        do {
            try store.delete(id: "missing")
            Issue.record("Expected error for deleting missing document")
        } catch DocStoreError.documentNotFound(let id) {
            #expect(id == "missing")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("DocStore lists all documents")
    func docStoreListsAll() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        try store.create(Document(id: "doc-a", content: "A"))
        try store.create(Document(id: "doc-b", content: "B"))
        try store.create(Document(id: "doc-c", content: "C"))

        let ids = try store.listAll()

        #expect(ids.count == 3)
        #expect(ids.contains("doc-a"))
        #expect(ids.contains("doc-b"))
        #expect(ids.contains("doc-c"))
    }

    @Test("DocStore reads all documents")
    func docStoreReadsAll() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        try store.create(Document(id: "first", title: "First", content: "1"))
        try store.create(Document(id: "second", title: "Second", content: "2"))

        let docs = try store.readAll()

        #expect(docs.count == 2)
        #expect(docs.contains { $0.id == "first" && $0.title == "First" })
        #expect(docs.contains { $0.id == "second" && $0.title == "Second" })
    }

    @Test("DocStore save creates or updates")
    func docStoreSaveCreatesOrUpdates() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        // Save creates new
        var doc = Document(id: "saveable", title: "Original", content: "Original")
        try store.save(doc)
        #expect(store.exists(id: "saveable"))

        // Save updates existing
        doc.title = "Updated"
        try store.save(doc)

        let read = try store.read(id: "saveable")
        #expect(read.title == "Updated")
    }

    @Test("DocStore exists returns correct value")
    func docStoreExistsWorks() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanupDirectory(tempDir) }

        let store = try DocStore(rootDirectory: tempDir)

        #expect(store.exists(id: "test") == false)

        try store.create(Document(id: "test", content: "Exists"))

        #expect(store.exists(id: "test") == true)
    }
}
