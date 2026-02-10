import Foundation
import os.log

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
