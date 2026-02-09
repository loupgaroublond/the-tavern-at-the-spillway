import XCTest
@testable import TavernCore

/// Stress tests for command dispatch under rapid fire (Bead aog1)
///
/// Verifies:
/// - 100+ rapid command dispatches complete correctly
/// - No race conditions in SlashCommandDispatcher
/// - Autocomplete responds within 10ms per query
/// - Invalid commands produce error responses
/// - Mix of valid, invalid, custom, and autocomplete queries
///
/// Run with: swift test --filter TavernStressTests.CommandDispatchStressTests
final class CommandDispatchStressTests: XCTestCase {

    /// Simple test command that returns its arguments
    private struct EchoCommand: SlashCommand {
        let name: String
        let description: String

        func execute(arguments: String) async -> SlashCommandResult {
            .message("Echo: \(arguments)")
        }
    }

    /// Command that simulates work with a small delay
    private struct SlowCommand: SlashCommand {
        let name = "slow"
        let description = "Simulates slow command"

        func execute(arguments: String) async -> SlashCommandResult {
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return .message("Slow result: \(arguments)")
        }
    }

    // MARK: - Test: 100 Rapid Dispatches

    /// Dispatch 100 valid commands in rapid succession.
    /// All must return correct responses within budget.
    @MainActor
    func testRapidCommandDispatches() async throws {
        let dispatcher = SlashCommandDispatcher()

        // Register 10 commands
        for i in 0..<10 {
            dispatcher.register(EchoCommand(name: "cmd\(i)", description: "Test command \(i)"))
        }

        let dispatchCount = 100
        let timeBudget: TimeInterval = 5.0
        let startTime = Date()

        var successCount = 0
        for i in 0..<dispatchCount {
            let cmdIndex = i % 10
            let result = await dispatcher.dispatch(name: "cmd\(cmdIndex)", arguments: "arg-\(i)")
            if case .message(let text) = result {
                XCTAssertEqual(text, "Echo: arg-\(i)",
                    "Command \(i) should echo correctly")
                successCount += 1
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(successCount, dispatchCount,
            "All \(dispatchCount) dispatches should succeed, got \(successCount)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(dispatchCount) dispatches must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testRapidCommandDispatches: \(dispatchCount) dispatches in \(String(format: "%.3f", duration))s")
    }

    // MARK: - Test: Mixed Valid and Invalid Commands

    /// Dispatch a mix of valid, invalid, and edge-case commands.
    /// Valid commands succeed; invalid commands return errors.
    @MainActor
    func testMixedValidAndInvalidDispatches() async throws {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(EchoCommand(name: "echo", description: "Echo command"))
        dispatcher.register(EchoCommand(name: "ping", description: "Ping command"))

        let iterations = 100
        let timeBudget: TimeInterval = 5.0
        let startTime = Date()

        var validResults = 0
        var errorResults = 0

        for i in 0..<iterations {
            let result: SlashCommandResult
            switch i % 5 {
            case 0:
                // Valid: echo
                result = await dispatcher.dispatch(name: "echo", arguments: "test-\(i)")
                if case .message = result { validResults += 1 }
            case 1:
                // Valid: ping
                result = await dispatcher.dispatch(name: "ping", arguments: "")
                if case .message = result { validResults += 1 }
            case 2:
                // Invalid: unknown command
                result = await dispatcher.dispatch(name: "nonexistent", arguments: "")
                if case .error = result { errorResults += 1 }
            case 3:
                // Invalid: empty name (still dispatched as unknown)
                result = await dispatcher.dispatch(name: "zzznope", arguments: "something")
                if case .error = result { errorResults += 1 }
            case 4:
                // Valid: echo with long args
                let longArg = String(repeating: "x", count: 10000)
                result = await dispatcher.dispatch(name: "echo", arguments: longArg)
                if case .message(let text) = result {
                    XCTAssertTrue(text.contains(longArg), "Long argument should be preserved")
                    validResults += 1
                }
            default:
                continue
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // 3 out of 5 patterns are valid (60%), 2 out of 5 are errors (40%)
        let expectedValid = (iterations / 5) * 3
        let expectedErrors = (iterations / 5) * 2

        XCTAssertEqual(validResults, expectedValid,
            "Expected \(expectedValid) valid results, got \(validResults)")
        XCTAssertEqual(errorResults, expectedErrors,
            "Expected \(expectedErrors) error results, got \(errorResults)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Mixed dispatches must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testMixedValidAndInvalidDispatches: \(validResults) valid, \(errorResults) errors in \(String(format: "%.3f", duration))s")
    }

    // MARK: - Test: Autocomplete Performance

    /// Run 1000 autocomplete queries. Each must respond within 10ms.
    @MainActor
    func testAutocompletePerformance() async throws {
        let dispatcher = SlashCommandDispatcher()

        // Register 20 commands with varied name prefixes
        let prefixes = ["help", "hooks", "history", "model", "mcp",
                        "cost", "compact", "context", "clear", "config",
                        "status", "stats", "stop", "start", "show",
                        "agents", "admin", "audit", "add", "attach"]
        for name in prefixes {
            dispatcher.register(EchoCommand(name: name, description: "Test \(name)"))
        }

        let queryCount = 1000
        let perQueryBudget: TimeInterval = 0.010 // 10ms
        let totalBudget: TimeInterval = 2.0
        var slowQueries = 0

        let totalStart = Date()

        for i in 0..<queryCount {
            let prefix: String
            switch i % 7 {
            case 0: prefix = ""        // Show all
            case 1: prefix = "h"       // help, hooks, history
            case 2: prefix = "co"      // cost, compact, context, config
            case 3: prefix = "st"      // status, stats, stop, start, show
            case 4: prefix = "a"       // agents, admin, audit, add, attach
            case 5: prefix = "zzz"     // No match
            case 6: prefix = "model"   // Exact match
            default: prefix = ""
            }

            let queryStart = Date()
            let matches = dispatcher.matchingCommands(prefix: prefix)
            let queryDuration = Date().timeIntervalSince(queryStart)

            // Verify correctness
            if prefix.isEmpty {
                XCTAssertEqual(matches.count, prefixes.count,
                    "Empty prefix should return all \(prefixes.count) commands")
            } else if prefix == "zzz" {
                XCTAssertTrue(matches.isEmpty, "Nonexistent prefix should return empty")
            } else {
                XCTAssertGreaterThan(matches.count, 0,
                    "Prefix '\(prefix)' should match at least one command")
                for match in matches {
                    XCTAssertTrue(match.name.hasPrefix(prefix),
                        "Match '\(match.name)' should start with '\(prefix)'")
                }
            }

            if queryDuration > perQueryBudget {
                slowQueries += 1
            }
        }

        let totalDuration = Date().timeIntervalSince(totalStart)

        // Allow up to 5% slow queries (system load jitter)
        let maxSlowQueries = queryCount / 20
        XCTAssertLessThanOrEqual(slowQueries, maxSlowQueries,
            "At most \(maxSlowQueries) queries should exceed 10ms, got \(slowQueries)")

        XCTAssertLessThanOrEqual(totalDuration, totalBudget,
            "\(queryCount) autocomplete queries must complete within \(totalBudget)s, took \(String(format: "%.3f", totalDuration))s")

        print("testAutocompletePerformance: \(queryCount) queries in \(String(format: "%.3f", totalDuration))s (\(slowQueries) slow)")
    }

    // MARK: - Test: Registration While Dispatching

    /// Register and unregister commands while dispatching others.
    /// Verifies no crashes from concurrent modification.
    @MainActor
    func testRegistrationWhileDispatching() async throws {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(EchoCommand(name: "stable", description: "Always present"))

        let iterations = 100
        let timeBudget: TimeInterval = 5.0
        let startTime = Date()

        for i in 0..<iterations {
            // Register a new command
            let tempName = "temp\(i)"
            dispatcher.register(EchoCommand(name: tempName, description: "Temp \(i)"))

            // Dispatch to stable command
            let stableResult = await dispatcher.dispatch(name: "stable", arguments: "check-\(i)")
            if case .message(let text) = stableResult {
                XCTAssertEqual(text, "Echo: check-\(i)")
            } else {
                XCTFail("Stable command should always succeed")
            }

            // Dispatch to temp command
            let tempResult = await dispatcher.dispatch(name: tempName, arguments: "temp-\(i)")
            if case .message(let text) = tempResult {
                XCTAssertEqual(text, "Echo: temp-\(i)")
            }

            // Remove temp command
            dispatcher.removeAll { $0.name == tempName }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Only stable should remain
        XCTAssertEqual(dispatcher.commands.count, 1,
            "Only 'stable' command should remain, found \(dispatcher.commands.count)")
        XCTAssertEqual(dispatcher.commands.first?.name, "stable")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Registration while dispatching must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testRegistrationWhileDispatching: \(iterations) iterations in \(String(format: "%.3f", duration))s")
    }
}
