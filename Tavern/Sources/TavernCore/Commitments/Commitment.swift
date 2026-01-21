import Foundation

/// The verification status of a commitment
public enum CommitmentStatus: String, Equatable, Sendable, Codable {
    /// Commitment has not been verified yet
    case pending

    /// Verification is currently running
    case verifying

    /// Commitment was verified and passed
    case passed

    /// Commitment was verified and failed
    case failed
}

/// A commitment made by an agent about their work
/// Commitments are verified independently before an agent can be considered "done"
public struct Commitment: Identifiable, Equatable, Sendable, Codable {

    /// Unique identifier for this commitment
    public let id: UUID

    /// Human-readable description of what is committed
    /// Example: "All tests pass", "File is created with correct format"
    public let description: String

    /// The assertion to run to verify this commitment
    /// This is a command or check that returns success/failure
    /// Example: "swift test", "test -f output.json"
    public let assertion: String

    /// Current verification status
    public var status: CommitmentStatus

    /// Error message if verification failed
    public var failureMessage: String?

    /// When this commitment was created
    public let createdAt: Date

    /// When the status last changed
    public var updatedAt: Date

    // MARK: - Initialization

    /// Create a new commitment
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - description: What is being committed
    ///   - assertion: Command to verify the commitment
    public init(
        id: UUID = UUID(),
        description: String,
        assertion: String
    ) {
        self.id = id
        self.description = description
        self.assertion = assertion
        self.status = .pending
        self.failureMessage = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Status Updates

    /// Mark this commitment as currently being verified
    public mutating func markVerifying() {
        status = .verifying
        updatedAt = Date()
    }

    /// Mark this commitment as passed
    public mutating func markPassed() {
        status = .passed
        failureMessage = nil
        updatedAt = Date()
    }

    /// Mark this commitment as failed
    /// - Parameter message: Description of why verification failed
    public mutating func markFailed(message: String) {
        status = .failed
        failureMessage = message
        updatedAt = Date()
    }

    /// Reset to pending status (for re-verification)
    public mutating func reset() {
        status = .pending
        failureMessage = nil
        updatedAt = Date()
    }
}

// MARK: - Convenience

extension Commitment {

    /// Whether this commitment has been verified (passed or failed)
    public var isVerified: Bool {
        status == .passed || status == .failed
    }

    /// Whether this commitment is complete (passed)
    public var isComplete: Bool {
        status == .passed
    }

    /// Whether this commitment is still pending verification
    public var isPending: Bool {
        status == .pending
    }
}
