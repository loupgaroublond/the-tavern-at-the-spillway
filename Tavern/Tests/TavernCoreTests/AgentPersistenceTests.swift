import Foundation
import Testing
@testable import TavernCore

@Suite("AgentNode Tests")
struct AgentNodeTests {

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("AgentNode has all required properties")
    func agentNodeHasProperties() {
        let node = AgentNode(
            id: UUID(),
            name: "Test Agent",
            assignment: "Do something",
            state: "idle"
        )

        #expect(!node.id.uuidString.isEmpty)
        #expect(node.name == "Test Agent")
        #expect(node.assignment == "Do something")
        #expect(node.state == "idle")
        #expect(node.commitments.isEmpty)
    }

    @Test("AgentNode creates from Servitor")
    func agentNodeCreatesFromServitor() {
        let commitments = CommitmentList()
        commitments.add(description: "Tests pass", assertion: "swift test")

        let servitor = Servitor(
            name: "Worker",
            assignment: "Build the thing",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            loadSavedSession: false
        )

        let node = AgentNode(from: servitor)

        #expect(node.id == servitor.id)
        #expect(node.name == "Worker")
        #expect(node.assignment == "Build the thing")
        #expect(node.state == "idle")
        #expect(node.commitments.count == 1)
        #expect(node.commitments.first?.description == "Tests pass")
    }

    @Test("AgentNode converts to document")
    func agentNodeConvertsToDocument() {
        let node = AgentNode(
            id: UUID(),
            name: "Doc Agent",
            assignment: "Write documentation",
            state: "working",
            commitments: [
                CommitmentNode(description: "Docs exist", assertion: "test -f docs.md", status: "passed")
            ]
        )

        let doc = node.toDocument()

        #expect(doc.id == "doc-agent")
        #expect(doc.title == "Doc Agent")
        #expect(doc.frontmatter["state"] == "working")
        #expect(doc.content.contains("## Assignment"))
        #expect(doc.content.contains("Write documentation"))
        #expect(doc.content.contains("## Commitments"))
        #expect(doc.content.contains("Docs exist"))
    }

    @Test("AgentNode parses from document")
    func agentNodeParsesFromDocument() throws {
        let iso = ISO8601DateFormatter()
        let now = Date()

        let doc = Document(
            id: "parsed-agent",
            title: "Parsed Agent",
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

            - ✅ **Data parsed**
              - Assertion: `test -f output.json`
            - ❌ **Report generated**
              - Assertion: `test -f report.md`
              - Failed: File not found
            """
        )

        let node = try AgentNode.from(document: doc)

        #expect(node.name == "Parsed Agent")
        #expect(node.state == "waiting")
        #expect(node.assignment?.contains("Parse some data") == true)
        #expect(node.commitments.count == 2)
        #expect(node.commitments[0].status == "passed")
        #expect(node.commitments[1].status == "failed")
        #expect(node.commitments[1].failureMessage == "File not found")
    }

    @Test("AgentNode throws on missing ID")
    func agentNodeThrowsOnMissingId() {
        let doc = Document(
            id: "no-id",
            title: "No ID Agent",
            frontmatter: ["state": "idle"],
            content: "## Assignment\n\nSomething"
        )

        do {
            _ = try AgentNode.from(document: doc)
            Issue.record("Expected error for missing ID")
        } catch AgentNodeError.missingField(let field) {
            #expect(field == "id")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("AgentNode throws on missing title")
    func agentNodeThrowsOnMissingTitle() {
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
            _ = try AgentNode.from(document: doc)
            Issue.record("Expected error for missing title")
        } catch AgentNodeError.missingField(let field) {
            #expect(field == "title")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("CommitmentNode Tests")
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

@Suite("AgentPersistence Tests")
struct AgentPersistenceTests {

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

    @Test("Agent creates doc store node on save")
    func agentCreatesDocStoreNode() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = AgentPersistence(docStore: store)
        let agent = Servitor(
            name: "Saveable",
            assignment: "Test saving",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        try persistence.save(agent)

        #expect(persistence.exists(name: "Saveable"))
    }

    @Test("Agent state synced to file")
    func agentStateSyncedToFile() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = AgentPersistence(docStore: store)

        let agent = Servitor(
            name: "Stateful",
            assignment: "Track state",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )
        agent.markWaiting()

        try persistence.save(agent)

        let loaded = try persistence.load(name: "Stateful")
        #expect(loaded.state == "waiting")
    }

    @Test("Agent restored from file")
    func agentRestoredFromFile() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }
        let projectURL = Self.testProjectURL()

        let persistence = AgentPersistence(docStore: store)

        // Create and save agent
        let originalId = UUID()
        let commitments = CommitmentList()
        let c1 = commitments.add(description: "First", assertion: "cmd1")
        commitments.markPassed(id: c1.id)

        let original = Servitor(
            id: originalId,
            name: "Restorable",
            assignment: "Test restoration",
            projectURL: projectURL,
            commitments: commitments,
            loadSavedSession: false
        )
        original.markDone()

        try persistence.save(original)

        // Restore from file
        let restored = try persistence.restore(name: "Restorable", projectURL: projectURL)

        #expect(restored.id == originalId)
        #expect(restored.name == "Restorable")
        #expect(restored.assignment == "Test restoration")
        #expect(restored.state == .done)
        #expect(restored.commitments.count == 1)
        #expect(restored.commitments.commitments.first?.status == .passed)
    }

    @Test("Agent persistence saves commitments")
    func agentPersistenceSavesCommitments() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = AgentPersistence(docStore: store)

        let commitments = CommitmentList()
        commitments.add(description: "Build passes", assertion: "swift build")
        commitments.add(description: "Tests pass", assertion: "swift test")

        let agent = Servitor(
            name: "Committed",
            assignment: "Task with commitments",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            loadSavedSession: false
        )

        try persistence.save(agent)

        let loaded = try persistence.load(name: "Committed")
        #expect(loaded.commitments.count == 2)
        #expect(loaded.commitments.contains { $0.description == "Build passes" })
        #expect(loaded.commitments.contains { $0.description == "Tests pass" })
    }

    @Test("Agent persistence deletes agent")
    func agentPersistenceDeletesAgent() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = AgentPersistence(docStore: store)

        let agent = Servitor(
            name: "Deletable",
            assignment: "To be deleted",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        try persistence.save(agent)
        #expect(persistence.exists(name: "Deletable"))

        try persistence.delete(name: "Deletable")
        #expect(!persistence.exists(name: "Deletable"))
    }

    @Test("Agent persistence lists all agents")
    func agentPersistenceListsAll() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = AgentPersistence(docStore: store)
        let projectURL = Self.testProjectURL()

        let agent1 = Servitor(name: "Alpha", assignment: "A", projectURL: projectURL, loadSavedSession: false)
        let agent2 = Servitor(name: "Beta", assignment: "B", projectURL: projectURL, loadSavedSession: false)
        let agent3 = Servitor(name: "Gamma", assignment: "C", projectURL: projectURL, loadSavedSession: false)

        try persistence.save(agent1)
        try persistence.save(agent2)
        try persistence.save(agent3)

        let names = try persistence.listAll()

        #expect(names.count == 3)
        #expect(names.contains("Alpha"))
        #expect(names.contains("Beta"))
        #expect(names.contains("Gamma"))
    }

    @Test("Agent persistence loads all agent nodes")
    func agentPersistenceLoadsAll() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = AgentPersistence(docStore: store)
        let projectURL = Self.testProjectURL()

        let agent1 = Servitor(name: "First", assignment: "Task 1", projectURL: projectURL, loadSavedSession: false)
        let agent2 = Servitor(name: "Second", assignment: "Task 2", projectURL: projectURL, loadSavedSession: false)

        try persistence.save(agent1)
        try persistence.save(agent2)

        let nodes = try persistence.loadAll()

        #expect(nodes.count == 2)
        #expect(nodes.contains { $0.name == "First" })
        #expect(nodes.contains { $0.name == "Second" })
    }

    @Test("Agent persistence updates existing agent")
    func agentPersistenceUpdatesExisting() throws {
        let store = try makeTempDocStore()
        defer { cleanupDocStore(store) }

        let persistence = AgentPersistence(docStore: store)

        let agent = Servitor(
            name: "Updatable",
            assignment: "Initial task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        try persistence.save(agent)

        // Modify and save again
        agent.markWaiting()
        try persistence.save(agent)

        let loaded = try persistence.load(name: "Updatable")
        #expect(loaded.state == "waiting")
    }
}
