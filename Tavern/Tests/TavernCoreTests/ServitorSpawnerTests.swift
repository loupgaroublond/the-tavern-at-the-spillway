import Foundation
import Testing
@testable import TavernCore

@Suite("ServitorSpawner Tests")
struct ServitorSpawnerTests {

    // MARK: - Test Setup

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    func createSpawner() -> (ServitorSpawner, AgentRegistry, NameGenerator) {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL()
        )
        return (spawner, registry, nameGenerator)
    }

    // MARK: - Summon Tests

    @Test("Summon creates servitor with themed name")
    func summonCreatesServitorWithThemedName() throws {
        let (spawner, registry, _) = createSpawner()

        let servitor = try spawner.summon(assignment: "Test assignment")

        #expect(registry.count == 1)
        #expect(!servitor.name.isEmpty)
        #expect(NamingTheme.lotr.allNames.contains(servitor.name))
        #expect(servitor.assignment == "Test assignment")
    }

    @Test("Summon registers servitor in registry")
    func summonRegistersServitorInRegistry() throws {
        let (spawner, registry, _) = createSpawner()

        let servitor = try spawner.summon(assignment: "Task")

        #expect(registry.agent(id: servitor.id) != nil)
        #expect(registry.agent(named: servitor.name) != nil)
    }

    @Test("Summoned servitor has assignment")
    func summonedServitorHasAssignment() throws {
        let (spawner, _, _) = createSpawner()

        let servitor = try spawner.summon(assignment: "Parse JSON files")

        #expect(servitor.assignment == "Parse JSON files")
    }

    @Test("Summoned servitor gets themed name")
    func summonedServitorGetsThemedName() throws {
        let (spawner, _, _) = createSpawner()

        let servitor = try spawner.summon(assignment: "Task")

        // Should be from LOTR theme
        #expect(NamingTheme.lotr.allNames.contains(servitor.name))
    }

    @Test("Multiple summons get unique names")
    func multipleSummonsGetUniqueNames() throws {
        let (spawner, _, _) = createSpawner()

        let servitor1 = try spawner.summon(assignment: "Task 1")
        let servitor2 = try spawner.summon(assignment: "Task 2")
        let servitor3 = try spawner.summon(assignment: "Task 3")

        #expect(servitor1.name != servitor2.name)
        #expect(servitor2.name != servitor3.name)
        #expect(servitor1.name != servitor3.name)
    }

    @Test("Summon with specific name works")
    func summonWithSpecificNameWorks() throws {
        let (spawner, registry, _) = createSpawner()

        let servitor = try spawner.summon(name: "CustomName", assignment: "Task")

        #expect(servitor.name == "CustomName")
        #expect(registry.agent(named: "CustomName") != nil)
    }

    @Test("Summon with duplicate name fails")
    func summonWithDuplicateNameFails() throws {
        let (spawner, _, _) = createSpawner()

        _ = try spawner.summon(name: "TakenName", assignment: "Task 1")

        do {
            _ = try spawner.summon(name: "TakenName", assignment: "Task 2")
            Issue.record("Expected error for duplicate name")
        } catch let error as AgentRegistryError {
            if case .nameAlreadyExists(let name) = error {
                #expect(name == "TakenName")
            } else {
                Issue.record("Wrong error type")
            }
        }
    }

    // MARK: - Dismiss Tests

    @Test("Dismiss removes servitor from registry")
    func dismissRemovesServitorFromRegistry() throws {
        let (spawner, registry, _) = createSpawner()

        let servitor = try spawner.summon(assignment: "Task")
        #expect(registry.count == 1)

        try spawner.dismiss(servitor)
        #expect(registry.count == 0)
    }

    @Test("Dismiss releases name for reuse")
    func dismissReleasesNameForReuse() throws {
        let (spawner, _, nameGenerator) = createSpawner()

        let servitor = try spawner.summon(name: "ReusableName", assignment: "Task")
        #expect(!nameGenerator.isNameAvailable("ReusableName"))

        try spawner.dismiss(servitor)
        #expect(nameGenerator.isNameAvailable("ReusableName"))
    }

    @Test("Dismiss by ID works")
    func dismissByIdWorks() throws {
        let (spawner, registry, _) = createSpawner()

        let servitor = try spawner.summon(assignment: "Task")
        let id = servitor.id

        try spawner.dismiss(id: id)
        #expect(registry.count == 0)
    }

    @Test("Dismiss non-existent servitor throws")
    func dismissNonExistentServitorThrows() {
        let (spawner, _, _) = createSpawner()
        let fakeId = UUID()

        do {
            try spawner.dismiss(id: fakeId)
            Issue.record("Expected error for non-existent servitor")
        } catch let error as AgentRegistryError {
            if case .agentNotFound(let id) = error {
                #expect(id == fakeId)
            } else {
                Issue.record("Wrong error type")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Query Tests

    @Test("Active servitors returns all summoned servitors")
    func activeServitorsReturnsAllSummoned() throws {
        let (spawner, _, _) = createSpawner()

        _ = try spawner.summon(assignment: "Task 1")
        _ = try spawner.summon(assignment: "Task 2")

        #expect(spawner.activeServitors.count == 2)
    }

    @Test("Servitor count matches summoned count")
    func servitorCountMatchesSummoned() throws {
        let (spawner, _, _) = createSpawner()

        #expect(spawner.servitorCount == 0)

        _ = try spawner.summon(assignment: "Task 1")
        #expect(spawner.servitorCount == 1)

        _ = try spawner.summon(assignment: "Task 2")
        #expect(spawner.servitorCount == 2)
    }

    // MARK: - MessengerFactory Tests (Bead 96m + p70)

    @Test("Spawner uses default LiveMessenger factory")
    func spawnerUsesDefaultFactory() throws {
        // Default init should not crash — uses LiveMessenger
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL()
        )

        // Can summon successfully
        let servitor = try spawner.summon(assignment: "Test")
        #expect(!servitor.name.isEmpty)
    }

    @Test("Spawner uses injected messenger factory")
    func spawnerUsesInjectedMessengerFactory() throws {
        let counter = CallCounter()
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: {
                counter.increment()
                return MockMessenger(responses: ["Factory response"])
            }
        )

        _ = try spawner.summon(assignment: "Task 1")
        #expect(counter.value == 1)

        _ = try spawner.summon(assignment: "Task 2")
        #expect(counter.value == 2)
    }

    @Test("Spawned servitor with mock factory can respond")
    func spawnedServitorWithMockFactoryCanRespond() async throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: { MockMessenger(responses: ["Mock response"]) }
        )

        let servitor = try spawner.summon(assignment: "Task")
        let response = try await servitor.send("Hello")

        #expect(response == "Mock response")
    }

    @Test("Each spawned servitor gets its own messenger instance")
    func eachSpawnedServitorGetsOwnMessenger() async throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: { MockMessenger(responses: ["Response A", "Response B"]) }
        )

        let s1 = try spawner.summon(assignment: "Task 1")
        let s2 = try spawner.summon(assignment: "Task 2")

        // Each should get "Response A" as their first response (separate messenger instances)
        let r1 = try await s1.send("Hello")
        let r2 = try await s2.send("Hello")

        #expect(r1 == "Response A")
        #expect(r2 == "Response A")
    }

    @Test("Summon with name uses messenger factory")
    func summonWithNameUsesMessengerFactory() async throws {
        let counter = CallCounter()
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: {
                counter.increment()
                return MockMessenger(responses: ["Named response"])
            }
        )

        let servitor = try spawner.summon(name: "CustomAgent", assignment: "Task")
        let response = try await servitor.send("Hello")

        #expect(counter.value == 1)
        #expect(response == "Named response")
    }

    @Test("User-spawned servitor (no assignment) uses messenger factory")
    func userSpawnedServitorUsesMessengerFactory() async throws {
        let counter = CallCounter()
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: {
                counter.increment()
                return MockMessenger(responses: ["User response"])
            }
        )

        let servitor = try spawner.summon()
        let response = try await servitor.send("Hello")

        #expect(counter.value == 1)
        #expect(response == "User response")
        #expect(servitor.assignment == nil)
    }
}

// MARK: - Test Helpers

/// Thread-safe call counter for use in @Sendable closures
private final class CallCounter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.tavern.test.CallCounter")
    private var _value = 0

    var value: Int {
        queue.sync { _value }
    }

    func increment() {
        queue.sync { _value += 1 }
    }
}
