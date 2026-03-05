import Foundation
import Testing
@testable import TavernCore

@Suite("ServitorNode Tests", .timeLimit(.minutes(1)))
struct ServitorNodeTests {

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("ServitorNode has all required properties")
    func servitorNodeHasProperties() {
        let node = ServitorNode(
            id: UUID(),
            name: "Test Servitor",
            assignment: "Do something",
            state: "idle"
        )

        #expect(!node.id.uuidString.isEmpty)
        #expect(node.name == "Test Servitor")
        #expect(node.assignment == "Do something")
        #expect(node.state == "idle")
        #expect(node.commitments.isEmpty)
    }

    @Test("ServitorNode creates from Mortal")
    func servitorNodeCreatesFromMortal() throws {
        let commitments = CommitmentList()
        commitments.add(description: "Tests pass", assertion: "swift test")

        let mortal = Mortal(
            name: "Worker",
            assignment: "Build the thing",
            projectURL: Self.testProjectURL(),
            store: try TestFixtures.createTestStore(),
            commitments: commitments
        )

        let node = ServitorNode(from: mortal)

        #expect(node.id == mortal.id)
        #expect(node.name == "Worker")
        #expect(node.assignment == "Build the thing")
        #expect(node.state == "idle")
        #expect(node.commitments.count == 1)
        #expect(node.commitments.first?.description == "Tests pass")
    }

    @Test("ServitorNode converts to document")
    func servitorNodeConvertsToDocument() {
        let node = ServitorNode(
            id: UUID(),
            name: "Doc Servitor",
            assignment: "Write documentation",
            state: "working",
            commitments: [
                CommitmentNode(description: "Docs exist", assertion: "test -f docs.md", status: "passed")
            ]
        )

        let doc = node.toDocument()

        #expect(doc.id == "doc-servitor")
        #expect(doc.title == "Doc Servitor")
        #expect(doc.frontmatter["state"] == "working")
        #expect(doc.content.contains("## Assignment"))
        #expect(doc.content.contains("Write documentation"))
        #expect(doc.content.contains("## Commitments"))
        #expect(doc.content.contains("Docs exist"))
    }

    @Test("ServitorNode parses from document")
    func servitorNodeParsesFromDocument() throws {
        let iso = ISO8601DateFormatter()
        let now = Date()

        let doc = Document(
            id: "parsed-servitor",
            title: "Parsed Servitor",
            frontmatter: [
                "id": UUID().uuidString,
                "state": "waiting",
                "createdAt": iso.string(from: now),
                "updatedAt": iso.string(from: now)
            ],
            content: """
            ## Assignment

            Parse some data and report results

            ## Commitments

            - \u{2705} **Data parsed**
              - Assertion: `test -f output.json`
            - \u{274C} **Report generated**
              - Assertion: `test -f report.md`
              - Failed: File not found
            """
        )

        let node = try ServitorNode.from(document: doc)

        #expect(node.name == "Parsed Servitor")
        #expect(node.state == "waiting")
        #expect(node.assignment?.contains("Parse some data") == true)
        #expect(node.commitments.count == 2)
        #expect(node.commitments[0].status == "passed")
        #expect(node.commitments[1].status == "failed")
        #expect(node.commitments[1].failureMessage == "File not found")
    }

    @Test("ServitorNode throws on missing ID")
    func servitorNodeThrowsOnMissingId() {
        let doc = Document(
            id: "no-id",
            title: "No ID Servitor",
            frontmatter: ["state": "idle"],
            content: "## Assignment\n\nSomething"
        )

        do {
            _ = try ServitorNode.from(document: doc)
            Issue.record("Expected error for missing ID")
        } catch ServitorNodeError.missingField(let field) {
            #expect(field == "id")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("ServitorNode throws on missing title")
    func servitorNodeThrowsOnMissingTitle() {
        let doc = Document(
            id: "no-title",
            title: nil,
            frontmatter: [
                "id": UUID().uuidString,
                "state": "idle"
            ],
            content: "## Assignment\n\nSomething"
        )

        do {
            _ = try ServitorNode.from(document: doc)
            Issue.record("Expected error for missing title")
        } catch ServitorNodeError.missingField(let field) {
            #expect(field == "title")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("CommitmentNode Tests", .timeLimit(.minutes(1)))
struct CommitmentNodeTests {

    @Test("CommitmentNode creates from Commitment")
    func commitmentNodeCreatesFromCommitment() {
        var commitment = Commitment(
            description: "Tests pass",
            assertion: "swift test"
        )
        commitment.markPassed()

        let node = CommitmentNode(from: commitment)

        #expect(node.id == commitment.id)
        #expect(node.description == "Tests pass")
        #expect(node.assertion == "swift test")
        #expect(node.status == "passed")
    }

    @Test("CommitmentNode converts back to Commitment")
    func commitmentNodeConvertsToCommitment() {
        let node = CommitmentNode(
            description: "Build succeeds",
            assertion: "swift build",
            status: "failed",
            failureMessage: "Compilation error"
        )

        let commitment = node.toCommitment()

        #expect(commitment.description == "Build succeeds")
        #expect(commitment.assertion == "swift build")
        #expect(commitment.status == .failed)
        #expect(commitment.failureMessage == "Compilation error")
    }

    @Test("CommitmentNode preserves all statuses")
    func commitmentNodePreservesStatuses() {
        let statuses = ["pending", "verifying", "passed", "failed"]

        for status in statuses {
            let node = CommitmentNode(
                description: "Test",
                assertion: "cmd",
                status: status,
                failureMessage: status == "failed" ? "Error" : nil
            )

            let commitment = node.toCommitment()

            #expect(commitment.status.rawValue == status)
        }
    }
}

@Suite("ServitorPersistence Tests", .timeLimit(.minutes(1)))
struct ServitorPersistenceTests {

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    func makeTempDocStore() throws -> DocStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return try DocStore(rootDirectory: tempDir, createIfNeeded: true)
    }

    func cleanupDocStore(_ store: DocStore) {
        try? FileManager.default.removeItem(at: store.rootDirectory)
    }

    @Test("Servitor creates doc store node on save", .tags(.reqDOC002, .reqLCM004))
    func servitorCreatesDocStoreNode() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = ServitorPersistence(docStore: store)
        let mortal = Mortal(
            name: "Saveable",
            assignment: "Test saving",
            projectURL: Self.testProjectURL(),
            store: try TestFixtures.createTestStore()
        )

        try persistence.save(mortal)

        #expect(persistence.exists(name: "Saveable"))
    }

    @Test("Servitor state synced to file")
    func servitorStateSyncedToFile() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = ServitorPersistence(docStore: store)

        let mortal = Mortal(
            name: "Stateful",
            assignment: "Track state",
            projectURL: Self.testProjectURL(),
            store: try TestFixtures.createTestStore()
        )
        mortal.markWaiting()

        try persistence.save(mortal)

        let loaded = try persistence.load(name: "Stateful")
        #expect(loaded.state == "waiting")
    }

    @Test("Servitor restored from file", .tags(.reqDOC002, .reqLCM004))
    func servitorRestoredFromFile() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }
        let projectURL = Self.testProjectURL()

        let persistence = ServitorPersistence(docStore: store)

        // Create and save mortal
        let originalId = UUID()
        let commitments = CommitmentList()
        let c1 = commitments.add(description: "First", assertion: "cmd1")
        commitments.markPassed(id: c1.id)

        let original = Mortal(
            id: originalId,
            name: "Restorable",
            assignment: "Test restoration",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore(),
            commitments: commitments
        )
        original.markDone()

        try persistence.save(original)

        // Restore from file
        let restored = try persistence.restore(name: "Restorable", projectURL: projectURL, store: try TestFixtures.createTestStore())

        #expect(restored.id == originalId)
        #expect(restored.name == "Restorable")
        #expect(restored.assignment == "Test restoration")
        #expect(restored.state == .done)
        #expect(restored.commitments.count == 1)
        #expect(restored.commitments.commitments.first?.status == .passed)
    }

    @Test("Servitor persistence saves commitments")
    func servitorPersistenceSavesCommitments() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = ServitorPersistence(docStore: store)

        let commitments = CommitmentList()
        commitments.add(description: "Build passes", assertion: "swift build")
        commitments.add(description: "Tests pass", assertion: "swift test")

        let mortal = Mortal(
            name: "Committed",
            assignment: "Task with commitments",
            projectURL: Self.testProjectURL(),
            store: try TestFixtures.createTestStore(),
            commitments: commitments
        )

        try persistence.save(mortal)

        let loaded = try persistence.load(name: "Committed")
        #expect(loaded.commitments.count == 2)
        #expect(loaded.commitments.contains { $0.description == "Build passes" })
        #expect(loaded.commitments.contains { $0.description == "Tests pass" })
    }

    @Test("Servitor persistence deletes servitor")
    func servitorPersistenceDeletesServitor() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = ServitorPersistence(docStore: store)

        let mortal = Mortal(
            name: "Deletable",
            assignment: "To be deleted",
            projectURL: Self.testProjectURL(),
            store: try TestFixtures.createTestStore()
        )

        try persistence.save(mortal)
        #expect(persistence.exists(name: "Deletable"))

        try persistence.delete(name: "Deletable")
        #expect(!persistence.exists(name: "Deletable"))
    }

    @Test("Servitor persistence lists all servitors")
    func servitorPersistenceListsAll() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = ServitorPersistence(docStore: store)
        let projectURL = Self.testProjectURL()

        let mortal1 = Mortal(name: "Alpha", assignment: "A", projectURL: projectURL, store: try TestFixtures.createTestStore())
        let mortal2 = Mortal(name: "Beta", assignment: "B", projectURL: projectURL, store: try TestFixtures.createTestStore())
        let mortal3 = Mortal(name: "Gamma", assignment: "C", projectURL: projectURL, store: try TestFixtures.createTestStore())

        try persistence.save(mortal1)
        try persistence.save(mortal2)
        try persistence.save(mortal3)

        let names = try persistence.listAll()

        #expect(names.count == 3)
        #expect(names.contains("Alpha"))
        #expect(names.contains("Beta"))
        #expect(names.contains("Gamma"))
    }

    @Test("Servitor persistence loads all servitor nodes")
    func servitorPersistenceLoadsAll() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = ServitorPersistence(docStore: store)
        let projectURL = Self.testProjectURL()

        let mortal1 = Mortal(name: "First", assignment: "Task 1", projectURL: projectURL, store: try TestFixtures.createTestStore())
        let mortal2 = Mortal(name: "Second", assignment: "Task 2", projectURL: projectURL, store: try TestFixtures.createTestStore())

        try persistence.save(mortal1)
        try persistence.save(mortal2)

        let nodes = try persistence.loadAll()

        #expect(nodes.count == 2)
        #expect(nodes.contains { $0.name == "First" })
        #expect(nodes.contains { $0.name == "Second" })
    }

    @Test("Servitor persistence updates existing servitor")
    func servitorPersistenceUpdatesExisting() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = ServitorPersistence(docStore: store)

        let mortal = Mortal(
            name: "Updatable",
            assignment: "Initial task",
            projectURL: Self.testProjectURL(),
            store: try TestFixtures.createTestStore()
        )

        try persistence.save(mortal)

        // Modify and save again
        mortal.markWaiting()
        try persistence.save(mortal)

        let loaded = try persistence.load(name: "Updatable")
        #expect(loaded.state == "waiting")
    }
}
