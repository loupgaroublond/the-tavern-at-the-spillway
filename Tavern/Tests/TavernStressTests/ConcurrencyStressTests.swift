import XCTest
@testable import TavernCore

/// Stress tests for concurrent operations
/// Run with: swift test --filter TavernStressTests
final class ConcurrencyStressTests: XCTestCase {

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: Concurrent Spawn/Dismiss

    /// Tests concurrent spawn and dismiss operations
    /// Verifies registry remains consistent under concurrent access
    func testConcurrentSpawnDismiss() async throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: testProjectURL()
        )

        let operationsPerTask = 20
        let taskCount = 5

        let startTime = Date()

        // Multiple tasks spawning and dismissing
        await withTaskGroup(of: Int.self) { group in
            for taskIndex in 0..<taskCount {
                group.addTask {
                    var successCount = 0
                    for i in 0..<operationsPerTask {
                        do {
                            let agent = try spawner.summon(assignment: "Task \(taskIndex)-\(i)")
                            // Small delay to increase chance of interleaving
                            try? await Task.sleep(nanoseconds: 1000)
                            try spawner.dismiss(agent)
                            successCount += 1
                        } catch {
                            // Name collision or other error - expected under concurrency
                        }
                    }
                    return successCount
                }
            }

            var totalSuccess = 0
            for await count in group {
                totalSuccess += count
            }

            // Should complete most operations (some may fail due to name collisions)
            XCTAssertGreaterThan(totalSuccess, 0, "Should complete at least some operations")
        }

        let duration = Date().timeIntervalSince(startTime)

        // Registry should be empty or near-empty at end
        XCTAssertEqual(registry.count, 0,
            "Registry should be empty after all dismiss operations")

        print("testConcurrentSpawnDismiss: \(taskCount) tasks, \(operationsPerTask) ops each in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Registry Thread Safety

    /// Tests that the AgentRegistry is thread-safe under heavy concurrent access
    func testRegistryThreadSafety() async throws {
        let registry = AgentRegistry()
        let projectURL = testProjectURL()

        let iterations = 1000
        let taskCount = 10

        // Create agents to register/deregister
        let agents: [Servitor] = (0..<iterations).map { i in
            Servitor(
                name: "SafetyTest-\(i)",
                assignment: "Test \(i)",
                projectURL: projectURL,
                loadSavedSession: false
            )
        }

        let startTime = Date()

        // Concurrent registration
        await withTaskGroup(of: Void.self) { group in
            for (index, agent) in agents.enumerated() {
                let registryRef = registry
                let indexCopy = index
                group.addTask {
                    // Only try to register if no other task is using this agent
                    if indexCopy % taskCount == 0 {
                        _ = try? registryRef.register(agent)
                    }
                }
            }
        }

        // Concurrent queries (should not crash)
        let agentsCopy = agents
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<taskCount {
                let registryRef = registry
                group.addTask {
                    var accessCount = 0
                    for agent in agentsCopy {
                        _ = registryRef.agent(id: agent.id)
                        _ = registryRef.agent(named: agent.name)
                        _ = registryRef.allAgents()
                        accessCount += 3
                    }
                    return accessCount
                }
            }

            for await count in group {
                XCTAssertGreaterThan(count, 0)
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Should not crash - that's the main test
        print("testRegistryThreadSafety: completed in \(String(format: "%.2f", duration))s")
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

    // MARK: - Tests requiring SDK mocking (skipped)
    // TODO: These tests need dependency injection or SDK mocking to work
    // - testConcurrentAgentMessages
}
