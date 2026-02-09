import XCTest
@testable import TavernCore

/// Stress tests for concurrent agent spawning and dismissal (Bead 1z56)
///
/// Verifies AgentRegistry stays consistent under concurrent load:
/// - 50+ concurrent spawn/dismiss cycles complete without deadlock
/// - Registry count matches expected state after all operations
/// - No duplicate names produced
/// - All operations complete within time budget (5 seconds)
///
/// Run with: swift test --filter TavernStressTests.ConcurrencyStressTests
final class ConcurrencyStressTests: XCTestCase {

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: 50 Concurrent Spawn/Dismiss Cycles

    /// Rapidly spawn and dismiss 50+ servitors concurrently.
    /// Each of 10 tasks performs 5 spawn/dismiss cycles in parallel.
    /// Verifies: no deadlock, registry empty at end, completes within budget.
    func testConcurrentSpawnDismiss50Cycles() async throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
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
                            let agent = try spawner.summon(assignment: "Concurrent-\(taskIndex)-\(i)")
                            try? await Task.sleep(nanoseconds: UInt64.random(in: 100...1000))
                            try spawner.dismiss(agent)
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

        // Registry must be empty — all spawned agents were dismissed
        XCTAssertEqual(registry.count, 0,
            "Registry should be empty after all dismiss operations, found \(registry.count) agents")

        // Must complete within budget
        XCTAssertLessThanOrEqual(duration, timeBudget,
            "50+ concurrent spawn/dismiss cycles must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testConcurrentSpawnDismiss50Cycles: \(totalSuccess)/\(taskCount * cyclesPerTask) succeeded in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Registry Thread Safety Under Heavy Concurrent Access

    /// Register 100 agents, then bombard the registry with concurrent lookups.
    /// 20 threads performing simultaneous reads should not cause data corruption.
    func testRegistryThreadSafetyHeavyReads() async throws {
        let registry = AgentRegistry()
        let projectURL = testProjectURL()
        let timeBudget: TimeInterval = 5.0

        // Pre-register 100 agents
        let agentCount = 100
        var agents: [Servitor] = []
        for i in 0..<agentCount {
            let servitor = Servitor(
                name: "ReadTest-\(i)",
                assignment: "Test \(i)",
                projectURL: projectURL,
                loadSavedSession: false
            )
            try registry.register(servitor)
            agents.append(servitor)
        }
        XCTAssertEqual(registry.count, agentCount)

        let startTime = Date()
        let readTaskCount = 20
        let queriesPerTask = 500

        // Concurrent reads: id lookup, name lookup, allAgents
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<readTaskCount {
                let registryRef = registry
                let agentsCopy = agents
                group.addTask {
                    var queryCount = 0
                    for agent in agentsCopy.prefix(queriesPerTask / 3) {
                        _ = registryRef.agent(id: agent.id)
                        _ = registryRef.agent(named: agent.name)
                        _ = registryRef.allAgents()
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
        XCTAssertEqual(registry.count, agentCount,
            "Registry count changed during concurrent reads: expected \(agentCount), got \(registry.count)")

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

    /// Simultaneously register new agents while removing others.
    /// Verifies no data corruption (registry count matches expected).
    func testConcurrentRegisterAndRemove() async throws {
        let registry = AgentRegistry()
        let projectURL = testProjectURL()
        let timeBudget: TimeInterval = 5.0

        // Pre-register 50 agents to remove
        var agentsToRemove: [Servitor] = []
        for i in 0..<50 {
            let servitor = Servitor(
                name: "Remove-\(i)",
                assignment: nil,
                projectURL: projectURL,
                loadSavedSession: false
            )
            try registry.register(servitor)
            agentsToRemove.append(servitor)
        }
        XCTAssertEqual(registry.count, 50)

        // Prepare 50 agents to add
        var agentsToAdd: [Servitor] = []
        for i in 0..<50 {
            agentsToAdd.append(Servitor(
                name: "Add-\(i)",
                assignment: nil,
                projectURL: projectURL,
                loadSavedSession: false
            ))
        }

        let startTime = Date()

        // Capture IDs for removal (UUIDs are Sendable)
        let removeIds = agentsToRemove.map { $0.id }
        let addAgents = agentsToAdd

        // Run add and remove in parallel
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Remove pre-registered agents
            let registryRef = registry
            group.addTask {
                for id in removeIds {
                    try? registryRef.remove(id: id)
                }
            }

            // Task 2: Register new agents
            group.addTask {
                for agent in addAgents {
                    _ = try? registryRef.register(agent)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Final count should be 50 (all old removed, all new added)
        XCTAssertEqual(registry.count, 50,
            "After concurrent add/remove, registry should have 50 agents, got \(registry.count)")

        // Verify all new agents are findable
        for agent in agentsToAdd {
            XCTAssertNotNil(registry.agent(id: agent.id),
                "Newly added agent \(agent.name) should be in registry")
        }

        // Verify all old agents are gone
        for agent in agentsToRemove {
            XCTAssertNil(registry.agent(id: agent.id),
                "Removed agent \(agent.name) should not be in registry")
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Concurrent register/remove must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testConcurrentRegisterAndRemove: completed in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Name Uniqueness Under Concurrent Spawning

    /// Spawn 50 servitors concurrently and verify all names are unique.
    func testNameUniquenessUnderConcurrentSpawning() async throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let spawnCount = 50
        let timeBudget: TimeInterval = 5.0
        let startTime = Date()

        // Spawn all concurrently
        var spawned: [Servitor] = []

        await withTaskGroup(of: Servitor?.self) { group in
            for i in 0..<spawnCount {
                group.addTask {
                    return try? spawner.summon(assignment: "NameTest-\(i)")
                }
            }

            // for-await on TaskGroup is sequential — no lock needed
            for await agent in group {
                if let agent = agent {
                    spawned.append(agent)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // All names must be unique
        let names = Set(spawned.map { $0.name })
        XCTAssertEqual(names.count, spawned.count,
            "All \(spawned.count) spawned agents must have unique names, found \(names.count) unique")

        // Registry count matches spawned count
        XCTAssertEqual(registry.count, spawned.count,
            "Registry count (\(registry.count)) must match spawned count (\(spawned.count))")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Concurrent spawning must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testNameUniquenessUnderConcurrentSpawning: \(spawned.count)/\(spawnCount) spawned, \(names.count) unique names in \(String(format: "%.2f", duration))s")
    }
}
