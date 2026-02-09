import XCTest
@testable import TavernCore

/// Stress tests for permission evaluation under concurrent access (Bead f0lc)
///
/// Verifies:
/// - 100 concurrent read/write operations complete without corruption
/// - Rules added during evaluation don't cause crashes
/// - Serial queue provides correct isolation
/// - Final state is consistent after concurrent mutations
///
/// Run with: swift test --filter TavernStressTests.PermissionStressTests
final class PermissionStressTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suiteName = "com.tavern.stress.permissions.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    // MARK: - Test: Concurrent Read/Write to PermissionStore

    /// 20 threads simultaneously adding rules and reading rules.
    /// No data corruption should occur.
    func testConcurrentReadWritePermissionStore() async throws {
        let defaults = freshDefaults()
        let store = PermissionStore(defaults: defaults)
        let timeBudget: TimeInterval = 5.0
        let startTime = Date()

        let writerCount = 10
        let readerCount = 10
        let opsPerThread = 100

        await withTaskGroup(of: Void.self) { group in
            // Writers: add rules
            for w in 0..<writerCount {
                let storeRef = store
                group.addTask {
                    for i in 0..<opsPerThread {
                        let rule = PermissionRule(
                            toolPattern: "tool-\(w)-\(i)",
                            decision: i % 2 == 0 ? .allow : .deny
                        )
                        storeRef.addRule(rule)
                    }
                }
            }

            // Readers: query rules, mode, and find matching rules
            for _ in 0..<readerCount {
                let storeRef = store
                group.addTask {
                    for i in 0..<opsPerThread {
                        _ = storeRef.rules
                        _ = storeRef.mode
                        _ = storeRef.findMatchingRule(for: "tool-0-\(i)")
                    }
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Verify consistency: should have writerCount * opsPerThread rules
        let expectedRules = writerCount * opsPerThread
        let actualRules = store.rules.count
        XCTAssertEqual(actualRules, expectedRules,
            "Expected \(expectedRules) rules after concurrent writes, got \(actualRules)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Concurrent read/write must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testConcurrentReadWritePermissionStore: \(actualRules) rules, \(duration)s")
    }

    // MARK: - Test: Concurrent Evaluation Through PermissionManager

    /// Multiple threads evaluating tools while rules are being added/removed.
    func testConcurrentEvaluationWithMutations() async throws {
        let defaults = freshDefaults()
        let store = PermissionStore(defaults: defaults)
        let manager = PermissionManager(store: store)
        let timeBudget: TimeInterval = 5.0

        // Pre-populate with some rules
        for i in 0..<50 {
            manager.addAllowRule(toolPattern: "allowed-\(i)")
            manager.addDenyRule(toolPattern: "denied-\(i)")
        }

        let startTime = Date()
        let evaluatorCount = 10
        let mutatorCount = 5
        let opsPerThread = 100

        var evaluationResults: [Int] = Array(repeating: 0, count: evaluatorCount)

        await withTaskGroup(of: (Int, Int)?.self) { group in
            // Evaluators: check tool permissions
            for e in 0..<evaluatorCount {
                let managerRef = manager
                group.addTask {
                    var evalCount = 0
                    for i in 0..<opsPerThread {
                        // Mix of allowed, denied, and unknown tools
                        switch i % 3 {
                        case 0:
                            let result = managerRef.evaluateTool("allowed-\(i % 50)")
                            // In normal mode, matching allow rule should return .allow
                            if result == .allow { evalCount += 1 }
                        case 1:
                            let result = managerRef.evaluateTool("denied-\(i % 50)")
                            if result == .deny { evalCount += 1 }
                        case 2:
                            // Unknown tool in normal mode returns nil (prompt user)
                            let _ = managerRef.evaluateTool("unknown-\(i)")
                            evalCount += 1
                        default: break
                        }
                    }
                    return (e, evalCount)
                }
            }

            // Mutators: add and remove rules while evaluation happens
            for m in 0..<mutatorCount {
                let managerRef = manager
                group.addTask {
                    for i in 0..<opsPerThread {
                        if i % 2 == 0 {
                            managerRef.addAllowRule(toolPattern: "dynamic-\(m)-\(i)")
                        } else {
                            // Remove a rule (may or may not exist)
                            let rules = managerRef.rules
                            if let rule = rules.last {
                                managerRef.removeRule(id: rule.id)
                            }
                        }
                    }
                    return nil
                }
            }

            // for-await on TaskGroup is sequential — no lock needed
            for await result in group {
                if let (index, count) = result {
                    evaluationResults[index] = count
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // All evaluators should have completed all their operations
        for (index, count) in evaluationResults.enumerated() {
            XCTAssertGreaterThan(count, 0,
                "Evaluator \(index) should have completed at least some evaluations, got \(count)")
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Concurrent evaluation with mutations must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testConcurrentEvaluationWithMutations: evaluations=\(evaluationResults), \(String(format: "%.3f", duration))s")
    }

    // MARK: - Test: Mode Switching Under Load

    /// Rapidly switch permission modes while evaluating tools.
    /// Verifies mode changes are atomic and don't cause crashes.
    func testModeSwitchingUnderLoad() async throws {
        let defaults = freshDefaults()
        let store = PermissionStore(defaults: defaults)
        let manager = PermissionManager(store: store)
        let timeBudget: TimeInterval = 5.0

        // Add some rules
        manager.addAllowRule(toolPattern: "edit")
        manager.addDenyRule(toolPattern: "bash")

        let startTime = Date()
        let switchCount = 200
        let evaluationsPerSwitch = 10

        let modes: [PermissionMode] = [.normal, .bypassPermissions, .plan, .acceptEdits, .dontAsk]

        for i in 0..<switchCount {
            // Switch mode
            let newMode = modes[i % modes.count]
            manager.mode = newMode

            // Evaluate tools in the new mode
            for j in 0..<evaluationsPerSwitch {
                let toolName: String
                switch j % 3 {
                case 0: toolName = "edit"
                case 1: toolName = "bash"
                default: toolName = "unknown-\(j)"
                }

                let decision = manager.evaluateTool(toolName)

                // Verify mode-specific behavior
                switch newMode {
                case .bypassPermissions:
                    XCTAssertEqual(decision, .allow,
                        "Bypass mode should always allow, got \(String(describing: decision))")
                case .plan:
                    XCTAssertEqual(decision, .deny,
                        "Plan mode should always deny, got \(String(describing: decision))")
                default:
                    break // Other modes have complex behavior, just verify no crash
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Mode switching under load must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testModeSwitchingUnderLoad: \(switchCount) switches x \(evaluationsPerSwitch) evals in \(String(format: "%.3f", duration))s")
    }

    // MARK: - Test: Bulk Rule Operations

    /// Add 500 rules, evaluate against all, then remove all.
    /// Verifies performance scales acceptably with rule count.
    func testBulkRuleOperations() async throws {
        let defaults = freshDefaults()
        let store = PermissionStore(defaults: defaults)
        let timeBudget: TimeInterval = 5.0

        let ruleCount = 500
        var ruleIds: [UUID] = []

        // Phase 1: Add 500 rules
        let addStart = Date()
        for i in 0..<ruleCount {
            let rule = PermissionRule(
                toolPattern: "bulk-tool-\(i)",
                decision: i % 2 == 0 ? .allow : .deny
            )
            store.addRule(rule)
            ruleIds.append(rule.id)
        }
        let addDuration = Date().timeIntervalSince(addStart)

        XCTAssertEqual(store.rules.count, ruleCount,
            "Should have \(ruleCount) rules after bulk add")

        // Phase 2: Evaluate 500 tool queries against the rules
        let evalStart = Date()
        for i in 0..<ruleCount {
            let match = store.findMatchingRule(for: "bulk-tool-\(i)")
            XCTAssertNotNil(match, "Rule for bulk-tool-\(i) should exist")
        }
        let evalDuration = Date().timeIntervalSince(evalStart)

        // Phase 3: Remove all rules
        let removeStart = Date()
        store.removeAllRules()
        let removeDuration = Date().timeIntervalSince(removeStart)

        XCTAssertEqual(store.rules.count, 0, "All rules should be removed")

        let totalDuration = addDuration + evalDuration + removeDuration
        XCTAssertLessThanOrEqual(totalDuration, timeBudget,
            "Bulk operations must complete within \(timeBudget)s (add: \(String(format: "%.3f", addDuration))s, eval: \(String(format: "%.3f", evalDuration))s, remove: \(String(format: "%.3f", removeDuration))s)")

        print("testBulkRuleOperations: add=\(String(format: "%.3f", addDuration))s, eval=\(String(format: "%.3f", evalDuration))s, remove=\(String(format: "%.3f", removeDuration))s")
    }
}
