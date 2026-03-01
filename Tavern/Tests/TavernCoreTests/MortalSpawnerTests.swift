import Foundation
import Testing
@testable import TavernCore

@Suite("MortalSpawner Tests", .timeLimit(.minutes(1)))
struct MortalSpawnerTests {

    // MARK: - Test Setup

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    func createSpawner() -> (MortalSpawner, ServitorRegistry, NameGenerator) {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL()
        )
        return (spawner, registry, nameGenerator)
    }

    // MARK: - Summon Tests

    @Test("Summon creates mortal with themed name", .tags(.reqSPN001, .reqSPN010))
    func summonCreatesMortalWithThemedName() throws {
        let (spawner, registry, _) = createSpawner()

        let mortal = try spawner.summon(assignment: "Test assignment")

        #expect(registry.count == 1)
        #expect(!mortal.name.isEmpty)
        #expect(NamingTheme.lotr.allNames.contains(mortal.name))
        #expect(mortal.assignment == "Test assignment")
    }

    @Test("Summon registers mortal in registry", .tags(.reqAGT007, .reqSPN001))
    func summonRegistersMortalInRegistry() throws {
        let (spawner, registry, _) = createSpawner()

        let mortal = try spawner.summon(assignment: "Task")

        #expect(registry.servitor(id: mortal.id) != nil)
        #expect(registry.servitor(named: mortal.name) != nil)
    }

    @Test("Summoned mortal has assignment", .tags(.reqSPN002))
    func summonedMortalHasAssignment() throws {
        let (spawner, _, _) = createSpawner()

        let mortal = try spawner.summon(assignment: "Parse JSON files")

        #expect(mortal.assignment == "Parse JSON files")
    }

    @Test("Summoned mortal gets themed name")
    func summonedMortalGetsThemedName() throws {
        let (spawner, _, _) = createSpawner()

        let mortal = try spawner.summon(assignment: "Task")

        // Should be from LOTR theme
        #expect(NamingTheme.lotr.allNames.contains(mortal.name))
    }

    @Test("Multiple summons get unique names")
    func multipleSummonsGetUniqueNames() throws {
        let (spawner, _, _) = createSpawner()

        let mortal1 = try spawner.summon(assignment: "Task 1")
        let mortal2 = try spawner.summon(assignment: "Task 2")
        let mortal3 = try spawner.summon(assignment: "Task 3")

        #expect(mortal1.name != mortal2.name)
        #expect(mortal2.name != mortal3.name)
        #expect(mortal1.name != mortal3.name)
    }

    @Test("Summon with specific name works")
    func summonWithSpecificNameWorks() throws {
        let (spawner, registry, _) = createSpawner()

        let mortal = try spawner.summon(name: "CustomName", assignment: "Task")

        #expect(mortal.name == "CustomName")
        #expect(registry.servitor(named: "CustomName") != nil)
    }

    @Test("Summon with duplicate name fails")
    func summonWithDuplicateNameFails() throws {
        let (spawner, _, _) = createSpawner()

        _ = try spawner.summon(name: "TakenName", assignment: "Task 1")

        do {
            _ = try spawner.summon(name: "TakenName", assignment: "Task 2")
            Issue.record("Expected error for duplicate name")
        } catch let error as ServitorRegistryError {
            if case .nameAlreadyExists(let name) = error {
                #expect(name == "TakenName")
            } else {
                Issue.record("Wrong error type")
            }
        }
    }

    // MARK: - Dismiss Tests

    @Test("Dismiss removes mortal from registry", .tags(.reqSPN003))
    func dismissRemovesMortalFromRegistry() throws {
        let (spawner, registry, _) = createSpawner()

        let mortal = try spawner.summon(assignment: "Task")
        #expect(registry.count == 1)

        try spawner.dismiss(mortal)
        #expect(registry.count == 0)
    }

    @Test("Dismiss releases name for reuse")
    func dismissReleasesNameForReuse() throws {
        let (spawner, _, nameGenerator) = createSpawner()

        let mortal = try spawner.summon(name: "ReusableName", assignment: "Task")
        #expect(!nameGenerator.isNameAvailable("ReusableName"))

        try spawner.dismiss(mortal)
        #expect(nameGenerator.isNameAvailable("ReusableName"))
    }

    @Test("Dismiss by ID works")
    func dismissByIdWorks() throws {
        let (spawner, registry, _) = createSpawner()

        let mortal = try spawner.summon(assignment: "Task")
        let id = mortal.id

        try spawner.dismiss(id: id)
        #expect(registry.count == 0)
    }

    @Test("Dismiss non-existent mortal throws")
    func dismissNonExistentMortalThrows() {
        let (spawner, _, _) = createSpawner()
        let fakeId = UUID()

        do {
            try spawner.dismiss(id: fakeId)
            Issue.record("Expected error for non-existent mortal")
        } catch let error as ServitorRegistryError {
            if case .servitorNotFound(let id) = error {
                #expect(id == fakeId)
            } else {
                Issue.record("Wrong error type")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Query Tests

    @Test("Active mortals returns all summoned mortals")
    func activeMortalsReturnsAllSummoned() throws {
        let (spawner, _, _) = createSpawner()

        _ = try spawner.summon(assignment: "Task 1")
        _ = try spawner.summon(assignment: "Task 2")

        #expect(spawner.activeMortals.count == 2)
    }

    @Test("Mortal count matches summoned count")
    func mortalCountMatchesSummoned() throws {
        let (spawner, _, _) = createSpawner()

        #expect(spawner.mortalCount == 0)

        _ = try spawner.summon(assignment: "Task 1")
        #expect(spawner.mortalCount == 1)

        _ = try spawner.summon(assignment: "Task 2")
        #expect(spawner.mortalCount == 2)
    }

    // MARK: - MessengerFactory Tests (Bead 96m + p70)

    @Test("Spawner uses default LiveMessenger factory", .tags(.reqSPN010))
    func spawnerUsesDefaultFactory() throws {
        // Default init should not crash — uses LiveMessenger
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL()
        )

        // Can summon successfully
        let mortal = try spawner.summon(assignment: "Test")
        #expect(!mortal.name.isEmpty)
    }

    @Test("Spawner uses injected messenger factory")
    func spawnerUsesInjectedMessengerFactory() throws {
        let counter = CallCounter()
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: { _ in
                counter.increment()
                return MockMessenger(responses: ["Factory response"])
            }
        )

        _ = try spawner.summon(assignment: "Task 1")
        #expect(counter.value == 1)

        _ = try spawner.summon(assignment: "Task 2")
        #expect(counter.value == 2)
    }

    @Test("Spawned mortal with mock factory can respond")
    func spawnedMortalWithMockFactoryCanRespond() async throws {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: { _ in MockMessenger(responses: ["Mock response"]) }
        )

        let mortal = try spawner.summon(assignment: "Task")
        let response = try await mortal.send("Hello")

        #expect(response == "Mock response")
    }

    @Test("Each spawned mortal gets its own messenger instance")
    func eachSpawnedMortalGetsOwnMessenger() async throws {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: { _ in MockMessenger(responses: ["Response A", "Response B"]) }
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
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: { _ in
                counter.increment()
                return MockMessenger(responses: ["Named response"])
            }
        )

        let mortal = try spawner.summon(name: "CustomServitor", assignment: "Task")
        let response = try await mortal.send("Hello")

        #expect(counter.value == 1)
        #expect(response == "Named response")
    }

    @Test("User-spawned mortal (no assignment) uses messenger factory")
    func userSpawnedMortalUsesMessengerFactory() async throws {
        let counter = CallCounter()
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL(),
            messengerFactory: { _ in
                counter.increment()
                return MockMessenger(responses: ["User response"])
            }
        )

        let mortal = try spawner.summon()
        let response = try await mortal.send("Hello")

        #expect(counter.value == 1)
        #expect(response == "User response")
        #expect(mortal.assignment == nil)
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
