import XCTest
@testable import TavernCore

/// Stress tests for servitor spawning and lifecycle (Bead 1z56 — supplemental)
///
/// Tests sequential spawning at scale: 100+ servitors, rapid summon/dismiss cycles,
/// and theme exhaustion with fallback naming. All with timing assertions.
///
/// Run with: swift test --filter TavernStressTests.ServitorSpawnerStressTests
final class ServitorSpawnerStressTests: XCTestCase {

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: 100 Servitors Summoned

    /// Summon 100 servitors sequentially. All must succeed with unique names.
    /// Performance budget: under 2 seconds for 100 sequential spawns.
    func testManyServitorsSummoned() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let servitorCount = 100
        let timeBudget: TimeInterval = 2.0
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
        XCTAssertEqual(names.count, servitorCount, "All \(servitorCount) names must be unique")

        // Verify all servitors are retrievable from registry
        for servitor in summonedServitors {
            let retrieved = registry.agent(id: servitor.id)
            XCTAssertNotNil(retrieved, "Servitor \(servitor.name) should be in registry")
            XCTAssertEqual(retrieved?.id, servitor.id)
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "100 sequential spawns must complete within \(timeBudget)s, took \(String(format: "%.4f", duration))s")

        print("testManyServitorsSummoned: \(servitorCount) servitors in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Rapid Summon/Dismiss Cycle

    /// 50 rapid summon/dismiss cycles. Registry must be empty at end, no orphan state.
    /// Performance budget: under 1 second.
    func testRapidSummonDismissCycle() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let cycleCount = 50
        let timeBudget: TimeInterval = 1.0

        let startTime = Date()
        for i in 0..<cycleCount {
            let servitor = try spawner.summon(assignment: "Ephemeral task \(i)")
            XCTAssertEqual(spawner.servitorCount, 1)
            try spawner.dismiss(servitor)
            XCTAssertEqual(spawner.servitorCount, 0)
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(registry.count, 0, "Registry should be empty after all cycles")
        XCTAssertTrue(spawner.activeServitors.isEmpty, "Active servitors should be empty")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(cycleCount) summon/dismiss cycles must complete within \(timeBudget)s, took \(String(format: "%.4f", duration))s")

        print("testRapidSummonDismissCycle: \(cycleCount) cycles in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Theme Exhaustion and Fallback

    /// Summon 500 servitors to exhaust the naming theme.
    /// Verifies fallback naming produces unique Agent-N names.
    func testThemeExhaustion() throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let servitorCount = 500
        let timeBudget: TimeInterval = 5.0
        var summonedServitors: [Servitor] = []

        let startTime = Date()
        for i in 0..<servitorCount {
            let servitor = try spawner.summon(assignment: "Task \(i)")
            summonedServitors.append(servitor)
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(summonedServitors.count, servitorCount)

        // Some should have fallback names (Agent-N pattern)
        let fallbackNames = summonedServitors.filter { $0.name.hasPrefix("Agent-") }
        XCTAssertFalse(fallbackNames.isEmpty, "Should have fallback names after theme exhaustion")

        // All names must still be unique
        let names = Set(summonedServitors.map { $0.name })
        XCTAssertEqual(names.count, servitorCount, "All \(servitorCount) names must be unique")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(servitorCount) spawns (with fallback) must complete within \(timeBudget)s, took \(String(format: "%.4f", duration))s")

        print("testThemeExhaustion: \(servitorCount) servitors, \(fallbackNames.count) fallback names in \(String(format: "%.4f", duration))s")
    }
}
