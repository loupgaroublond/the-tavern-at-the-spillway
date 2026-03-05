import Foundation
import Testing
@testable import TavernCore

// MARK: - Provenance: REQ-DOC-004, REQ-DOC-008

@Suite("ServitorStore Tests", .timeLimit(.minutes(1)))
struct ServitorStoreTests {

    // MARK: - Helpers

    private func makeStore() throws -> ServitorStore {
        try TestFixtures.createTestStore()
    }

    private func makeRecord(
        name: String = "TestServitor",
        id: UUID = UUID(),
        assignment: String? = "Do the thing",
        sessionId: String? = "sess-abc-123",
        sessionMode: PermissionMode = .normal,
        description: String? = "A test servitor",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> ServitorRecord {
        ServitorRecord(
            name: name,
            id: id,
            assignment: assignment,
            sessionId: sessionId,
            sessionMode: sessionMode,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Tests

    @Test("Save and load round-trips all fields", .tags(.reqDOC002))
    func testSaveAndLoad() throws {
        let store = try makeStore()
        let id = UUID()
        let now = Date()
        let record = makeRecord(
            name: "Marcos",
            id: id,
            assignment: "Build the pipeline",
            sessionId: "sess-xyz-789",
            sessionMode: .bypassPermissions,
            description: "Pipeline builder",
            createdAt: now,
            updatedAt: now
        )

        try store.save(record)
        let loaded = try store.load(name: "Marcos")

        #expect(loaded != nil)
        let r = try #require(loaded)
        #expect(r.name == "Marcos")
        #expect(r.id == id)
        #expect(r.assignment == "Build the pipeline")
        #expect(r.sessionId == "sess-xyz-789")
        #expect(r.sessionMode == .bypassPermissions)
        #expect(r.description == "Pipeline builder")
        // ISO8601 round-trip loses sub-second precision, compare to nearest second
        #expect(abs(r.createdAt.timeIntervalSince(now)) < 1.0)
        #expect(abs(r.updatedAt.timeIntervalSince(now)) < 1.0)
    }

    @Test("listAll returns all saved records", .tags(.reqDOC002))
    func testListAll() throws {
        let store = try makeStore()

        try store.save(makeRecord(name: "Alpha"))
        try store.save(makeRecord(name: "Beta"))
        try store.save(makeRecord(name: "Gamma"))

        let all = try store.listAll()

        #expect(all.count == 3)
        let names = Set(all.map(\.name))
        #expect(names.contains("Alpha"))
        #expect(names.contains("Beta"))
        #expect(names.contains("Gamma"))
    }

    @Test("Remove deletes record from disk", .tags(.reqDOC002))
    func testRemove() throws {
        let store = try makeStore()
        try store.save(makeRecord(name: "Ephemeral"))

        // Verify it exists
        #expect(try store.load(name: "Ephemeral") != nil)

        try store.remove(name: "Ephemeral")

        // Verify it's gone
        #expect(try store.load(name: "Ephemeral") == nil)
        let all = try store.listAll()
        #expect(!all.contains { $0.name == "Ephemeral" })
    }

    @Test("Append and load session events preserves order and content")
    func testAppendAndLoadSessionEvents() throws {
        let store = try makeStore()
        let name = "EventServitor"
        try store.save(makeRecord(name: name))

        let event1 = SessionEvent(event: .sessionStarted, sessionId: "sess-1", timestamp: Date())
        let event2 = SessionEvent(event: .sessionExpired, sessionId: "sess-1", timestamp: Date())
        let event3 = SessionEvent(event: .sessionStarted, sessionId: "sess-2", timestamp: Date())

        try store.appendSessionEvent(event1, name: name)
        try store.appendSessionEvent(event2, name: name)
        try store.appendSessionEvent(event3, name: name)

        let events = try store.loadSessionEvents(name: name)

        #expect(events.count == 3)
        #expect(events[0].event == .sessionStarted)
        #expect(events[0].sessionId == "sess-1")
        #expect(events[1].event == .sessionExpired)
        #expect(events[1].sessionId == "sess-1")
        #expect(events[2].event == .sessionStarted)
        #expect(events[2].sessionId == "sess-2")
    }

    @Test("Break event with reason round-trips correctly")
    func testBreakSigil() throws {
        let store = try makeStore()
        let name = "BreakServitor"
        try store.save(makeRecord(name: name))

        let breakEvent = SessionEvent(
            event: .break,
            sessionId: nil,
            timestamp: Date(),
            reason: "user_cleared"
        )

        try store.appendSessionEvent(breakEvent, name: name)

        let events = try store.loadSessionEvents(name: name)
        #expect(events.count == 1)
        #expect(events[0].event == .break)
        #expect(events[0].reason == "user_cleared")
        #expect(events[0].sessionId == nil)
    }

    @Test("Overwrite record updates persisted state", .tags(.reqDOC002))
    func testOverwriteRecord() throws {
        let store = try makeStore()
        let id = UUID()

        let original = makeRecord(name: "Mutable", id: id, sessionId: "old-session")
        try store.save(original)

        let updated = ServitorRecord(
            name: "Mutable",
            id: id,
            assignment: original.assignment,
            sessionId: "new-session",
            sessionMode: .acceptEdits,
            description: original.description,
            createdAt: original.createdAt,
            updatedAt: Date()
        )
        try store.save(updated)

        let loaded = try #require(try store.load(name: "Mutable"))
        #expect(loaded.sessionId == "new-session")
        #expect(loaded.sessionMode == .acceptEdits)
        #expect(loaded.id == id)
    }

    @Test("Load nonexistent name returns nil without throwing")
    func testLoadNonexistent() throws {
        let store = try makeStore()

        let result = try store.load(name: "NoSuchServitor")
        #expect(result == nil)
    }

    @Test("YAML escaping handles special characters in description", .tags(.reqDOC002))
    func testYAMLEscaping() throws {
        let store = try makeStore()

        let tricky = makeRecord(
            name: "Escaper",
            description: "line1: value\nline2: \"quoted\"\nkey: #comment & more!"
        )

        try store.save(tricky)
        let loaded = try #require(try store.load(name: "Escaper"))

        #expect(loaded.description == tricky.description)
    }
}
