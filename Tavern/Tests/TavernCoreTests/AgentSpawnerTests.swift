import Foundation
import Testing
@testable import TavernCore

@Suite("AgentSpawner Tests")
struct AgentSpawnerTests {

    // MARK: - Test Setup

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    func createSpawner() -> (AgentSpawner, AgentRegistry, NameGenerator) {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL()
        )
        return (spawner, registry, nameGenerator)
    }

    // MARK: - Spawn Tests

    @Test("Spawn creates agent with themed name")
    func spawnCreatesAgentWithThemedName() throws {
        let (spawner, registry, _) = createSpawner()

        let agent = try spawner.spawn(assignment: "Test task")

        #expect(registry.count == 1)
        #expect(!agent.name.isEmpty)
        #expect(NamingTheme.lotr.allNames.contains(agent.name))
        #expect(agent.assignment == "Test task")
    }

    @Test("Spawn registers agent in registry")
    func spawnRegistersAgentInRegistry() throws {
        let (spawner, registry, _) = createSpawner()

        let agent = try spawner.spawn(assignment: "Task")

        #expect(registry.agent(id: agent.id) != nil)
        #expect(registry.agent(named: agent.name) != nil)
    }

    @Test("Spawned agent has assignment")
    func spawnedAgentHasAssignment() throws {
        let (spawner, _, _) = createSpawner()

        let agent = try spawner.spawn(assignment: "Parse JSON files")

        #expect(agent.assignment == "Parse JSON files")
    }

    @Test("Spawned agent gets themed name")
    func spawnedAgentGetsThemedName() throws {
        let (spawner, _, _) = createSpawner()

        let agent = try spawner.spawn(assignment: "Task")

        // Should be from LOTR theme
        #expect(NamingTheme.lotr.allNames.contains(agent.name))
    }

    @Test("Multiple spawns get unique names")
    func multipleSpawnsGetUniqueNames() throws {
        let (spawner, _, _) = createSpawner()

        let agent1 = try spawner.spawn(assignment: "Task 1")
        let agent2 = try spawner.spawn(assignment: "Task 2")
        let agent3 = try spawner.spawn(assignment: "Task 3")

        #expect(agent1.name != agent2.name)
        #expect(agent2.name != agent3.name)
        #expect(agent1.name != agent3.name)
    }

    @Test("Spawn with specific name works")
    func spawnWithSpecificNameWorks() throws {
        let (spawner, registry, _) = createSpawner()

        let agent = try spawner.spawn(name: "CustomName", assignment: "Task")

        #expect(agent.name == "CustomName")
        #expect(registry.agent(named: "CustomName") != nil)
    }

    @Test("Spawn with duplicate name fails")
    func spawnWithDuplicateNameFails() throws {
        let (spawner, _, _) = createSpawner()

        _ = try spawner.spawn(name: "TakenName", assignment: "Task 1")

        do {
            _ = try spawner.spawn(name: "TakenName", assignment: "Task 2")
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

    @Test("Dismiss removes agent from registry")
    func dismissRemovesAgentFromRegistry() throws {
        let (spawner, registry, _) = createSpawner()

        let agent = try spawner.spawn(assignment: "Task")
        #expect(registry.count == 1)

        try spawner.dismiss(agent)
        #expect(registry.count == 0)
    }

    @Test("Dismiss releases name for reuse")
    func dismissReleasesNameForReuse() throws {
        let (spawner, _, nameGenerator) = createSpawner()

        let agent = try spawner.spawn(name: "ReusableName", assignment: "Task")
        #expect(!nameGenerator.isNameAvailable("ReusableName"))

        try spawner.dismiss(agent)
        #expect(nameGenerator.isNameAvailable("ReusableName"))
    }

    @Test("Dismiss by ID works")
    func dismissByIdWorks() throws {
        let (spawner, registry, _) = createSpawner()

        let agent = try spawner.spawn(assignment: "Task")
        let id = agent.id

        try spawner.dismiss(id: id)
        #expect(registry.count == 0)
    }

    @Test("Dismiss non-existent agent throws")
    func dismissNonExistentAgentThrows() {
        let (spawner, _, _) = createSpawner()
        let fakeId = UUID()

        do {
            try spawner.dismiss(id: fakeId)
            Issue.record("Expected error for non-existent agent")
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

    @Test("Active agents returns all spawned agents")
    func activeAgentsReturnsAllSpawned() throws {
        let (spawner, _, _) = createSpawner()

        _ = try spawner.spawn(assignment: "Task 1")
        _ = try spawner.spawn(assignment: "Task 2")

        #expect(spawner.activeAgents.count == 2)
    }

    @Test("Agent count matches spawned count")
    func agentCountMatchesSpawned() throws {
        let (spawner, _, _) = createSpawner()

        #expect(spawner.agentCount == 0)

        _ = try spawner.spawn(assignment: "Task 1")
        #expect(spawner.agentCount == 1)

        _ = try spawner.spawn(assignment: "Task 2")
        #expect(spawner.agentCount == 2)
    }
}
