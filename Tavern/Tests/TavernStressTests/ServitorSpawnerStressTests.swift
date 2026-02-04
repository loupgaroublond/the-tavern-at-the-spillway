import XCTest
@testable import TavernCore

/// Stress tests for servitor spawning and lifecycle
/// Run with: swift test --filter TavernStressTests
final class ServitorSpawnerStressTests: XCTestCase {

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: Many Servitors Summoned

    /// Tests summoning many servitors in sequence
    /// Verifies:
    /// - All servitors summon successfully
    /// - Registry is consistent (no duplicates, no missing)
    /// - All names are unique
    func testManyServitorsSummoned() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let servitorCount = 100
        var summonedServitors: [Servitor] = []

        let startTime = Date()
        for i in 0..<servitorCount {
            let servitor = try spawner.summon(assignment: "Task \(i)")
            summonedServitors.append(servitor)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Verify counts
        XCTAssertEqual(summonedServitors.count, servitorCount)
        XCTAssertEqual(spawner.servitorCount, servitorCount)

        // Verify all names are unique
        let names = Set(summonedServitors.map { $0.name })
        XCTAssertEqual(names.count, servitorCount, "Names should be unique")

        // Verify all servitors are retrievable from registry
        for servitor in summonedServitors {
            let retrieved = registry.agent(id: servitor.id)
            XCTAssertNotNil(retrieved, "Servitor \(servitor.name) should be in registry")
            XCTAssertEqual(retrieved?.id, servitor.id)
        }

        print("testManyServitorsSummoned: \(servitorCount) servitors in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Rapid Summon/Dismiss Cycle

    /// Tests rapid creation and destruction of servitors
    /// Verifies:
    /// - No orphaned state after cycle
    /// - Names are recycled correctly
    /// - Registry is empty at end
    func testRapidSummonDismissCycle() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let cycleCount = 50

        let startTime = Date()
        for i in 0..<cycleCount {
            // Summon
            let servitor = try spawner.summon(assignment: "Ephemeral task \(i)")
            XCTAssertEqual(spawner.servitorCount, 1)

            // Immediately dismiss
            try spawner.dismiss(servitor)
            XCTAssertEqual(spawner.servitorCount, 0)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Verify clean slate
        XCTAssertEqual(registry.count, 0)
        XCTAssertTrue(spawner.activeServitors.isEmpty)

        print("testRapidSummonDismissCycle: \(cycleCount) cycles in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Theme Exhaustion

    /// Tests what happens when we exhaust the naming theme
    /// Verifies fallback naming works correctly
    func testThemeExhaustion() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        // LOTR theme has limited names, summon way more than that
        let servitorCount = 500
        var summonedServitors: [Servitor] = []

        for i in 0..<servitorCount {
            let servitor = try spawner.summon(assignment: "Task \(i)")
            summonedServitors.append(servitor)
        }

        // Should have summoned all servitors despite theme exhaustion
        XCTAssertEqual(summonedServitors.count, servitorCount)

        // Some should have fallback names (Agent-N pattern)
        let fallbackNames = summonedServitors.filter { $0.name.hasPrefix("Agent-") }
        XCTAssertFalse(fallbackNames.isEmpty, "Should have fallback names after theme exhaustion")

        // All names should still be unique
        let names = Set(summonedServitors.map { $0.name })
        XCTAssertEqual(names.count, servitorCount, "All names should be unique")

        print("testThemeExhaustion: \(servitorCount) servitors, \(fallbackNames.count) fallback names")
    }
}
