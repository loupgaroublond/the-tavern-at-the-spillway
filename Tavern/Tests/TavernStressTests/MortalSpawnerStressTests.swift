import XCTest
@testable import TavernCore

/// Stress tests for mortal spawning and lifecycle (Bead 1z56 — supplemental)
///
/// Tests sequential spawning at scale: 100+ mortals, rapid summon/dismiss cycles,
/// and theme exhaustion with fallback naming. All with timing assertions.
///
/// Run with: swift test --filter TavernStressTests.MortalSpawnerStressTests
final class MortalSpawnerStressTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        executionTimeAllowance = 30
    }

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: 100 Mortals Summoned

    /// Summon 100 mortals sequentially. All must succeed with unique names.
    /// Performance budget: under 2 seconds for 100 sequential spawns.
    func testManyMortalsSummoned() throws {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let mortalCount = 100
        let timeBudget: TimeInterval = 2.0
        var summonedMortals: [Mortal] = []

        let startTime = Date()
        for i in 0..<mortalCount {
            let mortal = try spawner.summon(assignment: "Task \(i)")
            summonedMortals.append(mortal)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Verify counts
        XCTAssertEqual(summonedMortals.count, mortalCount)
        XCTAssertEqual(spawner.mortalCount, mortalCount)

        // Verify all names are unique
        let names = Set(summonedMortals.map { $0.name })
        XCTAssertEqual(names.count, mortalCount, "All \(mortalCount) names must be unique")

        // Verify all mortals are retrievable from registry
        for mortal in summonedMortals {
            let retrieved = registry.servitor(id: mortal.id)
            XCTAssertNotNil(retrieved, "Mortal \(mortal.name) should be in registry")
            XCTAssertEqual(retrieved?.id, mortal.id)
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "100 sequential spawns must complete within \(timeBudget)s, took \(String(format: "%.4f", duration))s")

        print("testManyMortalsSummoned: \(mortalCount) mortals in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Rapid Summon/Dismiss Cycle

    /// 50 rapid summon/dismiss cycles. Registry must be empty at end, no orphan state.
    /// Performance budget: under 1 second.
    func testRapidSummonDismissCycle() throws {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let cycleCount = 50
        let timeBudget: TimeInterval = 1.0

        let startTime = Date()
        for i in 0..<cycleCount {
            let mortal = try spawner.summon(assignment: "Ephemeral task \(i)")
            XCTAssertEqual(spawner.mortalCount, 1)
            try spawner.dismiss(mortal)
            XCTAssertEqual(spawner.mortalCount, 0)
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(registry.count, 0, "Registry should be empty after all cycles")
        XCTAssertTrue(spawner.activeMortals.isEmpty, "Active mortals should be empty")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(cycleCount) summon/dismiss cycles must complete within \(timeBudget)s, took \(String(format: "%.4f", duration))s")

        print("testRapidSummonDismissCycle: \(cycleCount) cycles in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Theme Exhaustion and Fallback

    /// Summon 500 mortals to exhaust the naming theme.
    /// Verifies fallback naming produces unique Servitor-N names.
    func testThemeExhaustion() throws {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let mortalCount = 500
        let timeBudget: TimeInterval = 5.0
        var summonedMortals: [Mortal] = []

        let startTime = Date()
        for i in 0..<mortalCount {
            let mortal = try spawner.summon(assignment: "Task \(i)")
            summonedMortals.append(mortal)
        }
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(summonedMortals.count, mortalCount)

        // Some should have fallback names (Servitor-N pattern)
        let fallbackNames = summonedMortals.filter { $0.name.hasPrefix("Servitor-") }
        XCTAssertFalse(fallbackNames.isEmpty, "Should have fallback names after theme exhaustion")

        // All names must still be unique
        let names = Set(summonedMortals.map { $0.name })
        XCTAssertEqual(names.count, mortalCount, "All \(mortalCount) names must be unique")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(mortalCount) spawns (with fallback) must complete within \(timeBudget)s, took \(String(format: "%.4f", duration))s")

        print("testThemeExhaustion: \(mortalCount) mortals, \(fallbackNames.count) fallback names in \(String(format: "%.4f", duration))s")
    }
}
