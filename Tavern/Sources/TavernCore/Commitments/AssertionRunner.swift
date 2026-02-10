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
