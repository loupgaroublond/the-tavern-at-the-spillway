import Foundation
import os.log

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

    /// Whether the process was terminated due to timeout
    public let timedOut: Bool

    public init(passed: Bool, output: String, errorOutput: String, exitCode: Int32, timedOut: Bool = false) {
        self.passed = passed
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
        self.timedOut = timedOut
    }
}

/// Error thrown when an assertion times out
public struct AssertionTimeoutError: Error, CustomStringConvertible {
    public let command: String
    public let timeout: Duration

    public var description: String {
        "Assertion timed out after \(timeout): \(command)"
    }
}

/// Thread-safe boolean flag for coordinating between terminationHandler and launch failure
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false

    /// Returns the current value
    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    /// Sets the flag to true
    func set() {
        lock.lock()
        _value = true
        lock.unlock()
    }

    /// Atomically tests if false and sets to true. Returns true if this call set it (was false).
    func testAndSet() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _value { return false }
        _value = true
        return true
    }
}

/// Thread-safe mutable reference holder
private final class LockedRef<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) {
        self._value = value
    }

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            _value = newValue
            lock.unlock()
        }
    }
}

/// Default shell-based assertion runner
/// Runs commands in /bin/bash with optional timeout
public final class ShellAssertionRunner: AssertionRunner, @unchecked Sendable {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "commitments")

    /// Working directory for running commands
    public let workingDirectory: URL?

    /// Maximum time to wait for an assertion before terminating
    /// nil means no timeout (wait indefinitely)
    public let timeout: Duration?

    /// Create a shell runner
    /// - Parameters:
    ///   - workingDirectory: Optional directory to run commands in
    ///   - timeout: Maximum time to wait for assertions (default: 30 seconds)
    public init(workingDirectory: URL? = nil, timeout: Duration? = .seconds(30)) {
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }

    public func run(_ command: String) async throws -> AssertionResult {
        Self.logger.info("Running assertion: \(command)")

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        if let workDir = workingDirectory {
            process.currentDirectoryURL = workDir
        }

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            // Track whether we've already resumed the continuation (timeout vs normal completion race)
            let hasResumed = LockedFlag()
            let didTimeout = LockedFlag()
            let timeoutRef = LockedRef<DispatchWorkItem?>(nil)

            // Use terminationHandler instead of blocking waitUntilExit()
            process.terminationHandler = { _ in
                timeoutRef.value?.cancel()

                guard hasResumed.testAndSet() else { return }

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                let timedOut = didTimeout.value
                let passed = !timedOut && process.terminationStatus == 0

                Self.logger.info("Assertion finished: passed=\(passed), exitCode=\(process.terminationStatus), timedOut=\(timedOut)")

                let result = AssertionResult(
                    passed: passed,
                    output: output,
                    errorOutput: timedOut ? "Assertion timed out" : errorOutput,
                    exitCode: process.terminationStatus,
                    timedOut: timedOut
                )

                continuation.resume(returning: result)
            }

            // Set up timeout if configured
            if let timeout {
                let timeoutSeconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
                let workItem = DispatchWorkItem {
                    didTimeout.set()
                    Self.logger.warning("Assertion timed out after \(timeoutSeconds)s, terminating: \(command)")
                    process.terminate()
                }
                timeoutRef.value = workItem
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + timeoutSeconds,
                    execute: workItem
                )
            }

            do {
                try process.run()
            } catch {
                // Prevent terminationHandler from also resuming
                guard hasResumed.testAndSet() else { return }
                timeoutRef.value?.cancel()
                Self.logger.error("Failed to launch assertion process: \(error.localizedDescription)")
                continuation.resume(throwing: error)
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

/// Verifies commitments by running their assertions
public final class CommitmentVerifier: @unchecked Sendable {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "commitments")

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
        // Capture values from inout parameter before using in logger (autoclosures can't capture inout)
        let desc = commitment.description
        let assertion = commitment.assertion
        let commitmentId = commitment.id

        Self.logger.info("Verifying commitment '\(desc)': \(assertion)")

        // Mark as verifying
        commitment.markVerifying()
        list?.updateStatus(id: commitmentId, status: .verifying)

        // Run the assertion
        let result = try await runner.run(assertion)

        if result.passed {
            Self.logger.info("Commitment passed: '\(desc)'")
            commitment.markPassed()
            list?.markPassed(id: commitmentId)
        } else {
            let message: String
            if result.timedOut {
                message = "Assertion timed out"
                Self.logger.warning("Commitment timed out: '\(desc)'")
            } else if result.errorOutput.isEmpty {
                message = "Assertion failed with exit code \(result.exitCode)"
            } else {
                message = result.errorOutput
            }
            Self.logger.error("Commitment failed: '\(desc)' - \(message)")
            commitment.markFailed(message: message)
            list?.markFailed(id: commitmentId, message: message)
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
