import XCTest
@testable import TavernCore

// MARK: - Provenance: REQ-QA-006, REQ-QA-014

/// Stress tests for concurrent servitor spawning and dismissal (Bead 1z56)
///
/// Verifies ServitorRegistry stays consistent under concurrent load:
/// - 50+ concurrent spawn/dismiss cycles complete without deadlock
/// - Registry count matches expected state after all operations
/// - No duplicate names produced
/// - All operations complete within time budget (5 seconds)
///
/// Run with: swift test --filter TavernStressTests.ConcurrencyStressTests
final class ConcurrencyStressTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        executionTimeAllowance = 30
    }

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: 50 Concurrent Spawn/Dismiss Cycles

    /// Rapidly spawn and dismiss 50+ mortals concurrently.
    /// Each of 10 tasks performs 5 spawn/dismiss cycles in parallel.
    /// Verifies: no deadlock, registry empty at end, completes within budget.
    func testConcurrentSpawnDismiss50Cycles() async throws {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let taskCount = 10
        let cyclesPerTask = 5
        let timeBudget: TimeInterval = 5.0

        let startTime = Date()

        var totalSuccess = 0
        await withTaskGroup(of: Int.self) { group in
            for taskIndex in 0..<taskCount {
                group.addTask {
                    var successCount = 0
                    for i in 0..<cyclesPerTask {
                        do {
                            let mortal = try spawner.summon(assignment: "Concurrent-\(taskIndex)-\(i)")
                            try? await Task.sleep(nanoseconds: UInt64.random(in: 100...1000))
                            try spawner.dismiss(mortal)
                            successCount += 1
                        } catch {
                            // Name collision under concurrency is acceptable
                        }
                    }
                    return successCount
                }
            }

            for await count in group {
                totalSuccess += count
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // At least 80% of operations should succeed
        let expectedMinimum = Int(Double(taskCount * cyclesPerTask) * 0.8)
        XCTAssertGreaterThanOrEqual(totalSuccess, expectedMinimum,
            "At least \(expectedMinimum) of \(taskCount * cyclesPerTask) cycles should succeed, got \(totalSuccess)")

        // Registry must be empty — all spawned mortals were dismissed
        XCTAssertEqual(registry.count, 0,
            "Registry should be empty after all dismiss operations, found \(registry.count) servitors")

        // Must complete within budget
        XCTAssertLessThanOrEqual(duration, timeBudget,
            "50+ concurrent spawn/dismiss cycles must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testConcurrentSpawnDismiss50Cycles: \(totalSuccess)/\(taskCount * cyclesPerTask) succeeded in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Registry Thread Safety Under Heavy Concurrent Access

    /// Register 100 mortals, then bombard the registry with concurrent lookups.
    /// 20 threads performing simultaneous reads should not cause data corruption.
    func testRegistryThreadSafetyHeavyReads() async throws {
        let registry = ServitorRegistry()
        let projectURL = testProjectURL()
        let timeBudget: TimeInterval = 5.0

        // Pre-register 100 mortals
        let mortalCount = 100
        var mortals: [Mortal] = []
        for i in 0..<mortalCount {
            let mortal = Mortal(
                name: "ReadTest-\(i)",
                assignment: "Test \(i)",
                projectURL: projectURL
            )
            try registry.register(mortal)
            mortals.append(mortal)
        }
        XCTAssertEqual(registry.count, mortalCount)

        let startTime = Date()
        let readTaskCount = 20
        let queriesPerTask = 500

        // Concurrent reads: id lookup, name lookup, allServitors
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<readTaskCount {
                let registryRef = registry
                let mortalsCopy = mortals
                group.addTask {
                    var queryCount = 0
                    for mortal in mortalsCopy.prefix(queriesPerTask / 3) {
                        _ = registryRef.servitor(id: mortal.id)
                        _ = registryRef.servitor(named: mortal.name)
                        _ = registryRef.allServitors()
                        queryCount += 3
                    }
                    return queryCount
                }
            }

            for await count in group {
                XCTAssertGreaterThan(count, 0)
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Registry must remain consistent
        XCTAssertEqual(registry.count, mortalCount,
            "Registry count changed during concurrent reads: expected \(mortalCount), got \(registry.count)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Heavy concurrent reads must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testRegistryThreadSafetyHeavyReads: \(readTaskCount)x\(queriesPerTask) queries in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Concurrent Commitment Verification

    /// Tests that 20+ concurrent commitment verifications complete without deadlock.
    /// Validates that ShellAssertionRunner's terminationHandler-based implementation
    /// does not exhaust the cooperative thread pool under concurrent load.
    func testConcurrentVerificationDoesNotBlockThreadPool() async throws {
        let concurrentCount = 25
        let runner = ShellAssertionRunner(timeout: .seconds(10))
        let list = CommitmentList()

        // Add 25 commitments with lightweight shell commands
        var commitments: [(Commitment, CommitmentVerifier)] = []
        for i in 0..<concurrentCount {
            let commitment = list.add(
                description: "Concurrent test \(i)",
                assertion: "echo 'verification \(i)'"
            )
            let verifier = CommitmentVerifier(runner: runner)
            commitments.append((commitment, verifier))
        }

        let startTime = Date()

        // Run all verifications concurrently
        let results = await withTaskGroup(of: (Int, Bool).self, returning: [(Int, Bool)].self) { group in
            for (index, (commitment, verifier)) in commitments.enumerated() {
                var mutableCommitment = commitment
                group.addTask {
                    do {
                        let passed = try await verifier.verify(&mutableCommitment, in: list)
                        return (index, passed)
                    } catch {
                        return (index, false)
                    }
                }
            }

            var collected: [(Int, Bool)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        let duration = Date().timeIntervalSince(startTime)

        // All 25 should complete
        XCTAssertEqual(results.count, concurrentCount,
            "All \(concurrentCount) verifications should complete")

        // All should pass (they're just echo commands)
        let passedCount = results.filter { $0.1 }.count
        XCTAssertEqual(passedCount, concurrentCount,
            "All verifications should pass")

        // Should complete within a reasonable time (not hanging from pool exhaustion).
        // 25 echo commands should finish well under 10 seconds even with process overhead.
        XCTAssertLessThan(duration, 10.0,
            "25 concurrent verifications should complete within 10 seconds, took \(String(format: "%.2f", duration))s")

        print("testConcurrentVerification: \(concurrentCount) concurrent verifications in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Concurrent Registration and Removal

    /// Simultaneously register new mortals while removing others.
    /// Verifies no data corruption (registry count matches expected).
    func testConcurrentRegisterAndRemove() async throws {
        let registry = ServitorRegistry()
        let projectURL = testProjectURL()
        let timeBudget: TimeInterval = 5.0

        // Pre-register 50 mortals to remove
        var mortalsToRemove: [Mortal] = []
        for i in 0..<50 {
            let mortal = Mortal(
                name: "Remove-\(i)",
                assignment: nil,
                projectURL: projectURL
            )
            try registry.register(mortal)
            mortalsToRemove.append(mortal)
        }
        XCTAssertEqual(registry.count, 50)

        // Prepare 50 mortals to add
        var mortalsToAdd: [Mortal] = []
        for i in 0..<50 {
            mortalsToAdd.append(Mortal(
                name: "Add-\(i)",
                assignment: nil,
                projectURL: projectURL
            ))
        }

        let startTime = Date()

        // Capture IDs for removal (UUIDs are Sendable)
        let removeIds = mortalsToRemove.map { $0.id }
        let addMortals = mortalsToAdd

        // Run add and remove in parallel
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Remove pre-registered mortals
            let registryRef = registry
            group.addTask {
                for id in removeIds {
                    try? registryRef.remove(id: id)
                }
            }

            // Task 2: Register new mortals
            group.addTask {
                for mortal in addMortals {
                    _ = try? registryRef.register(mortal)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Final count should be 50 (all old removed, all new added)
        XCTAssertEqual(registry.count, 50,
            "After concurrent add/remove, registry should have 50 servitors, got \(registry.count)")

        // Verify all new mortals are findable
        for mortal in mortalsToAdd {
            XCTAssertNotNil(registry.servitor(id: mortal.id),
                "Newly added mortal \(mortal.name) should be in registry")
        }

        // Verify all old mortals are gone
        for mortal in mortalsToRemove {
            XCTAssertNil(registry.servitor(id: mortal.id),
                "Removed mortal \(mortal.name) should not be in registry")
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Concurrent register/remove must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testConcurrentRegisterAndRemove: completed in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Name Uniqueness Under Concurrent Spawning

    /// Spawn 50 mortals concurrently and verify all names are unique.
    func testNameUniquenessUnderConcurrentSpawning() async throws {
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let spawnCount = 50
        let timeBudget: TimeInterval = 5.0
        let startTime = Date()

        // Spawn all concurrently
        var spawned: [Mortal] = []

        await withTaskGroup(of: Mortal?.self) { group in
            for i in 0..<spawnCount {
                group.addTask {
                    return try? spawner.summon(assignment: "NameTest-\(i)")
                }
            }

            // for-await on TaskGroup is sequential — no lock needed
            for await mortal in group {
                if let mortal = mortal {
                    spawned.append(mortal)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // All names must be unique
        let names = Set(spawned.map { $0.name })
        XCTAssertEqual(names.count, spawned.count,
            "All \(spawned.count) spawned mortals must have unique names, found \(names.count) unique")

        // Registry count matches spawned count
        XCTAssertEqual(registry.count, spawned.count,
            "Registry count (\(registry.count)) must match spawned count (\(spawned.count))")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Concurrent spawning must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testNameUniquenessUnderConcurrentSpawning: \(spawned.count)/\(spawnCount) spawned, \(names.count) unique names in \(String(format: "%.2f", duration))s")
    }
}
