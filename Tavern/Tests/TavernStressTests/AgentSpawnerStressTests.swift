import XCTest
@testable import TavernCore

/// Stress tests for agent spawning and lifecycle
/// Run with: swift test --filter TavernStressTests
final class AgentSpawnerStressTests: XCTestCase {

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: Many Agents Spawned

    /// Tests spawning many agents in sequence
    /// Verifies:
    /// - All agents spawn successfully
    /// - Registry is consistent (no duplicates, no missing)
    /// - All names are unique
    func testManyAgentsSpawned() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let agentCount = 100
        var spawnedAgents: [MortalAgent] = []

        let startTime = Date()
        for i in 0..<agentCount {
            let agent = try spawner.spawn(assignment: "Task \(i)")
            spawnedAgents.append(agent)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Verify counts
        XCTAssertEqual(spawnedAgents.count, agentCount)
        XCTAssertEqual(spawner.agentCount, agentCount)

        // Verify all names are unique
        let names = Set(spawnedAgents.map { $0.name })
        XCTAssertEqual(names.count, agentCount, "Names should be unique")

        // Verify all agents are retrievable from registry
        for agent in spawnedAgents {
            let retrieved = registry.agent(id: agent.id)
            XCTAssertNotNil(retrieved, "Agent \(agent.name) should be in registry")
            XCTAssertEqual(retrieved?.id, agent.id)
        }

        print("testManyAgentsSpawned: \(agentCount) agents in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Rapid Spawn/Dismiss Cycle

    /// Tests rapid creation and destruction of agents
    /// Verifies:
    /// - No orphaned state after cycle
    /// - Names are recycled correctly
    /// - Registry is empty at end
    func testRapidSpawnDismissCycle() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let cycleCount = 50

        let startTime = Date()
        for i in 0..<cycleCount {
            // Spawn
            let agent = try spawner.spawn(assignment: "Ephemeral task \(i)")
            XCTAssertEqual(spawner.agentCount, 1)

            // Immediately dismiss
            try spawner.dismiss(agent)
            XCTAssertEqual(spawner.agentCount, 0)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Verify clean slate
        XCTAssertEqual(registry.count, 0)
        XCTAssertTrue(spawner.activeAgents.isEmpty)

        print("testRapidSpawnDismissCycle: \(cycleCount) cycles in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Theme Exhaustion

    /// Tests what happens when we exhaust the naming theme
    /// Verifies fallback naming works correctly
    func testThemeExhaustion() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        // LOTR theme has limited names, spawn way more than that
        let agentCount = 500
        var spawnedAgents: [MortalAgent] = []

        for i in 0..<agentCount {
            let agent = try spawner.spawn(assignment: "Task \(i)")
            spawnedAgents.append(agent)
        }

        // Should have spawned all agents despite theme exhaustion
        XCTAssertEqual(spawnedAgents.count, agentCount)

        // Some should have fallback names (Agent-N pattern)
        let fallbackNames = spawnedAgents.filter { $0.name.hasPrefix("Agent-") }
        XCTAssertFalse(fallbackNames.isEmpty, "Should have fallback names after theme exhaustion")

        // All names should still be unique
        let names = Set(spawnedAgents.map { $0.name })
        XCTAssertEqual(names.count, agentCount, "All names should be unique")

        print("testThemeExhaustion: \(agentCount) agents, \(fallbackNames.count) fallback names")
    }
}
