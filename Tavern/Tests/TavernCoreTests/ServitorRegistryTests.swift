import Foundation
import Testing
@testable import TavernCore

// MARK: - Test Servitor Implementation

/// Simple servitor implementation for testing
final class TestServitor: Servitor, @unchecked Sendable {
    let id: UUID
    let name: String
    private(set) var state: ServitorState = .idle
    var sessionMode: PermissionMode = .plan

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    func send(_ message: String) async throws -> String {
        state = .working
        defer { state = .idle }
        return "Response to: \(message)"
    }

    func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let response = "Response to: \(message)"
        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            continuation.yield(.textDelta(response))
            continuation.yield(.completed(sessionId: nil, usage: nil))
            continuation.finish()
        }
        return (stream: stream, cancel: {})
    }

    func resetConversation() {
        state = .idle
    }
}

// MARK: - Tests

@Suite("ServitorRegistry Tests")
struct ServitorRegistryTests {

    @Test("Registry adds servitor", .tags(.reqSPN005))
    func registryAddsServitor() throws {
        let registry = ServitorRegistry()
        let servitor = TestServitor(name: "TestServitor1")

        try registry.register(servitor)

        #expect(registry.count == 1)
        #expect(registry.servitor(id: servitor.id) != nil)
    }

    @Test("Registry gets servitor by ID")
    func registryGetsServitorById() throws {
        let registry = ServitorRegistry()
        let servitor = TestServitor(name: "TestServitor2")

        try registry.register(servitor)

        let retrieved = registry.servitor(id: servitor.id)
        #expect(retrieved != nil)
        #expect(retrieved?.id == servitor.id)
        #expect(retrieved?.name == servitor.name)
    }

    @Test("Registry gets servitor by name")
    func registryGetsServitorByName() throws {
        let registry = ServitorRegistry()
        let servitor = TestServitor(name: "UniqueTestServitor")

        try registry.register(servitor)

        let retrieved = registry.servitor(named: "UniqueTestServitor")
        #expect(retrieved != nil)
        #expect(retrieved?.id == servitor.id)
    }

    @Test("Registry lists all servitors")
    func registryListsServitors() throws {
        let registry = ServitorRegistry()
        let servitor1 = TestServitor(name: "Servitor1")
        let servitor2 = TestServitor(name: "Servitor2")
        let servitor3 = TestServitor(name: "Servitor3")

        try registry.register(servitor1)
        try registry.register(servitor2)
        try registry.register(servitor3)

        let all = registry.allServitors()
        #expect(all.count == 3)

        let names = Set(all.map { $0.name })
        #expect(names.contains("Servitor1"))
        #expect(names.contains("Servitor2"))
        #expect(names.contains("Servitor3"))
    }

    @Test("Registry removes servitor", .tags(.reqARCH006))
    func registryRemovesServitor() throws {
        let registry = ServitorRegistry()
        let servitor = TestServitor(name: "ToBeRemoved")

        try registry.register(servitor)
        #expect(registry.count == 1)

        try registry.remove(id: servitor.id)
        #expect(registry.count == 0)
        #expect(registry.servitor(id: servitor.id) == nil)
    }

    @Test("Registry enforces unique names", .tags(.reqSPN005))
    func registryEnforcesUniqueNames() throws {
        let registry = ServitorRegistry()
        let servitor1 = TestServitor(name: "DuplicateName")
        let servitor2 = TestServitor(name: "DuplicateName")

        try registry.register(servitor1)

        do {
            try registry.register(servitor2)
            Issue.record("Expected error for duplicate name")
        } catch let error as ServitorRegistryError {
            if case .nameAlreadyExists(let name) = error {
                #expect(name == "DuplicateName")
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Registry throws when removing non-existent servitor")
    func registryThrowsOnRemoveNonExistent() {
        let registry = ServitorRegistry()
        let fakeId = UUID()

        do {
            try registry.remove(id: fakeId)
            Issue.record("Expected error for non-existent servitor")
        } catch let error as ServitorRegistryError {
            if case .servitorNotFound(let id) = error {
                #expect(id == fakeId)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Registry isNameTaken returns correct value")
    func registryIsNameTaken() throws {
        let registry = ServitorRegistry()
        let servitor = TestServitor(name: "TakenName")

        #expect(registry.isNameTaken("TakenName") == false)

        try registry.register(servitor)

        #expect(registry.isNameTaken("TakenName") == true)
        #expect(registry.isNameTaken("OtherName") == false)
    }

    @Test("Registry removeAll clears all servitors")
    func registryRemoveAll() throws {
        let registry = ServitorRegistry()
        try registry.register(TestServitor(name: "A1"))
        try registry.register(TestServitor(name: "A2"))
        try registry.register(TestServitor(name: "A3"))

        #expect(registry.count == 3)

        registry.removeAll()

        #expect(registry.count == 0)
        #expect(registry.allServitors().isEmpty)
    }

    @Test("Registry allows reusing name after removal")
    func registryAllowsNameReuseAfterRemoval() throws {
        let registry = ServitorRegistry()
        let servitor1 = TestServitor(name: "ReusableName")

        try registry.register(servitor1)
        try registry.remove(id: servitor1.id)

        // Should be able to register new servitor with same name
        let servitor2 = TestServitor(name: "ReusableName")
        try registry.register(servitor2)

        #expect(registry.count == 1)
        #expect(registry.servitor(named: "ReusableName")?.id == servitor2.id)
    }
}
