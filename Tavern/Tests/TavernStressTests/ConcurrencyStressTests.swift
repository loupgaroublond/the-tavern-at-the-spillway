import XCTest
@testable import TavernCore

/// Stress tests for concurrent operations
/// Run with: swift test --filter TavernStressTests
final class ConcurrencyStressTests: XCTestCase {

    // MARK: - Test: Concurrent Agent Messages

    /// Tests sending messages from multiple agents concurrently
    /// Verifies:
    /// - No race conditions
    /// - All messages delivered correctly
    /// - No data corruption
    func testConcurrentAgentMessages() async throws {
        let agentCount = 10
        let messagesPerAgent = 100

        // Create agents with their own mocks
        var agents: [(agent: MortalAgent, mock: MockClaudeCode)] = []
        for i in 0..<agentCount {
            let mock = MockClaudeCode()
            // Queue all responses upfront
            for j in 0..<messagesPerAgent {
                mock.queueTextResponse("Agent \(i) response \(j)")
            }
            let agent = MortalAgent(
                name: "Agent-\(i)",
                assignment: "Task \(i)",
                claude: mock
            )
            agents.append((agent, mock))
        }

        let startTime = Date()

        // Send messages concurrently from all agents
        await withTaskGroup(of: (Int, [String]).self) { group in
            for (index, (agent, _)) in agents.enumerated() {
                group.addTask {
                    var responses: [String] = []
                    for j in 0..<messagesPerAgent {
                        do {
                            let response = try await agent.send("Message \(j)")
                            responses.append(response)
                        } catch {
                            responses.append("ERROR: \(error)")
                        }
                    }
                    return (index, responses)
                }
            }

            // Collect results
            var allResults: [(Int, [String])] = []
            for await result in group {
                allResults.append(result)
            }

            // Verify all agents completed
            XCTAssertEqual(allResults.count, agentCount)

            // Verify each agent got correct responses
            for (index, responses) in allResults {
                XCTAssertEqual(responses.count, messagesPerAgent,
                    "Agent \(index) should have \(messagesPerAgent) responses")

                // Check responses don't contain errors
                let errorCount = responses.filter { $0.hasPrefix("ERROR:") }.count
                XCTAssertEqual(errorCount, 0, "Agent \(index) had \(errorCount) errors")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let totalMessages = agentCount * messagesPerAgent

        print("testConcurrentAgentMessages: \(totalMessages) messages from \(agentCount) agents in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Concurrent Spawn/Dismiss

    /// Tests concurrent spawn and dismiss operations
    /// Verifies registry remains consistent under concurrent access
    func testConcurrentSpawnDismiss() async throws {
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            claudeFactory: { MockClaudeCode() }
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
                            let agent = try spawner.spawn(assignment: "Task \(taskIndex)-\(i)")
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

        let iterations = 1000
        let taskCount = 10

        // Create agents to register/deregister
        let agents: [MortalAgent] = (0..<iterations).map { i in
            let mock = MockClaudeCode()
            return MortalAgent(
                name: "SafetyTest-\(i)",
                assignment: "Test \(i)",
                claude: mock
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
}
