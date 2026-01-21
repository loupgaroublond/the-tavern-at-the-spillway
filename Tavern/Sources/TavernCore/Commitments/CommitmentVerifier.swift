import Foundation

/// Protocol for running assertions to verify commitments
/// Allows injection of mock runners for testing
public protocol AssertionRunner: Sendable {
    /// Run an assertion command
    /// - Parameter command: The shell command to run
    /// - Returns: Result with output on success or error message on failure
    func run(_ command: String) async throws -> AssertionResult
}

/// Result of running an assertion
public struct AssertionResult: Sendable {
    /// Whether the assertion passed (exit code 0)
    public let passed: Bool

    /// Standard output from the command
    public let output: String

    /// Standard error from the command
    public let errorOutput: String

    /// Exit code
    public let exitCode: Int32

    public init(passed: Bool, output: String, errorOutput: String, exitCode: Int32) {
        self.passed = passed
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
    }
}

/// Default shell-based assertion runner
/// Runs commands in /bin/bash
public final class ShellAssertionRunner: AssertionRunner, @unchecked Sendable {

    /// Working directory for running commands
    public let workingDirectory: URL?

    /// Create a shell runner
    /// - Parameter workingDirectory: Optional directory to run commands in
    public init(workingDirectory: URL? = nil) {
        self.workingDirectory = workingDirectory
    }

    public func run(_ command: String) async throws -> AssertionResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]

                if let workDir = self.workingDirectory {
                    process.currentDirectoryURL = workDir
                }

                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                    let result = AssertionResult(
                        passed: process.terminationStatus == 0,
                        output: output,
                        errorOutput: errorOutput,
                        exitCode: process.terminationStatus
                    )

                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

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

/// Verifies commitments by running their assertions
public final class CommitmentVerifier: @unchecked Sendable {

    // MARK: - Dependencies

    private let runner: AssertionRunner

    // MARK: - Initialization

    /// Create a verifier with an assertion runner
    /// - Parameter runner: The runner to use for assertions (defaults to ShellAssertionRunner)
    public init(runner: AssertionRunner = ShellAssertionRunner()) {
        self.runner = runner
    }

    // MARK: - Verification

    /// Verify a single commitment
    /// - Parameters:
    ///   - commitment: The commitment to verify (will be updated in place)
    ///   - list: Optional list containing the commitment (for status updates)
    /// - Returns: true if the commitment passed verification
    @discardableResult
    public func verify(_ commitment: inout Commitment, in list: CommitmentList? = nil) async throws -> Bool {
        // Mark as verifying
        commitment.markVerifying()
        list?.updateStatus(id: commitment.id, status: .verifying)

        // Run the assertion
        let result = try await runner.run(commitment.assertion)

        if result.passed {
            commitment.markPassed()
            list?.markPassed(id: commitment.id)
        } else {
            let message = result.errorOutput.isEmpty ? "Assertion failed with exit code \(result.exitCode)" : result.errorOutput
            commitment.markFailed(message: message)
            list?.markFailed(id: commitment.id, message: message)
        }

        return result.passed
    }

    /// Verify all commitments in a list
    /// - Parameter list: The list of commitments to verify
    /// - Returns: true if all commitments passed verification
    @discardableResult
    public func verifyAll(in list: CommitmentList) async throws -> Bool {
        var allPassed = true

        for commitment in list.pendingCommitments {
            var mutableCommitment = commitment

            let passed = try await verify(&mutableCommitment, in: list)
            if !passed {
                allPassed = false
            }
        }

        return allPassed
    }

    /// Verify only failed commitments (retry)
    /// - Parameter list: The list containing failed commitments
    /// - Returns: true if all re-verified commitments now pass
    @discardableResult
    public func retryFailed(in list: CommitmentList) async throws -> Bool {
        var allPassed = true

        for commitment in list.failedCommitments {
            // Reset to pending first
            list.reset(id: commitment.id)

            var mutableCommitment = commitment

            let passed = try await verify(&mutableCommitment, in: list)
            if !passed {
                allPassed = false
            }
        }

        return allPassed
    }
}
