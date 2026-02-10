import Foundation

/// Mock assertion runner for testing
public final class MockAssertionRunner: AssertionRunner, @unchecked Sendable {

    private let queue = DispatchQueue(label: "com.tavern.MockAssertionRunner")

    /// Pre-configured results keyed by command pattern
    private var _results: [String: AssertionResult] = [:]

    /// Commands that were run
    private var _ranCommands: [String] = []

    /// Commands that were run
    public var ranCommands: [String] {
        queue.sync { _ranCommands }
    }

    /// Default result if no specific result configured
    public var defaultResult: AssertionResult = AssertionResult(
        passed: true,
        output: "OK",
        errorOutput: "",
        exitCode: 0
    )

    public init() {}

    /// Configure a result for a specific command
    public func setResult(_ result: AssertionResult, for command: String) {
        queue.sync { _results[command] = result }
    }

    /// Configure a passing result for a command
    public func setPass(for command: String, output: String = "OK") {
        setResult(AssertionResult(
            passed: true,
            output: output,
            errorOutput: "",
            exitCode: 0
        ), for: command)
    }

    /// Configure a failing result for a command
    public func setFail(for command: String, message: String = "Failed") {
        setResult(AssertionResult(
            passed: false,
            output: "",
            errorOutput: message,
            exitCode: 1
        ), for: command)
    }

    /// Configure a timeout result for a command
    public func setTimeout(for command: String) {
        setResult(AssertionResult(
            passed: false,
            output: "",
            errorOutput: "Assertion timed out",
            exitCode: 15, // SIGTERM
            timedOut: true
        ), for: command)
    }

    public func run(_ command: String) async throws -> AssertionResult {
        queue.sync {
            _ranCommands.append(command)
            return _results[command] ?? defaultResult
        }
    }

    /// Reset all state
    public func reset() {
        queue.sync {
            _ranCommands.removeAll()
            _results.removeAll()
        }
    }
}
