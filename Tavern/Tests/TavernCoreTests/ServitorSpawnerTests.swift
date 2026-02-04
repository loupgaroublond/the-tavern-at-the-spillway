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
}
