import Foundation
import os.log

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
