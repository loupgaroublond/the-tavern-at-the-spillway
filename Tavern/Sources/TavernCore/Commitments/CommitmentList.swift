import Foundation

/// A collection of commitments for an agent
/// Thread-safe via serial dispatch queue
public final class CommitmentList: @unchecked Sendable {

    // MARK: - Thread Safety

    private let queue = DispatchQueue(label: "com.tavern.CommitmentList")

    // MARK: - State

    private var _commitments: [Commitment] = []

    /// All commitments in this list
    public var commitments: [Commitment] {
        queue.sync { _commitments }
    }

    /// Number of commitments
    public var count: Int {
        queue.sync { _commitments.count }
    }

    /// Whether all commitments have passed
    public var allPassed: Bool {
        queue.sync { _commitments.allSatisfy { $0.status == .passed } }
    }

    /// Whether there are any pending commitments
    public var hasPending: Bool {
        queue.sync { _commitments.contains { $0.status == .pending } }
    }

    /// Whether there are any failed commitments
    public var hasFailed: Bool {
        queue.sync { _commitments.contains { $0.status == .failed } }
    }

    /// Whether any commitment is currently being verified
    public var hasVerifying: Bool {
        queue.sync { _commitments.contains { $0.status == .verifying } }
    }

    /// All pending commitments
    public var pendingCommitments: [Commitment] {
        queue.sync { _commitments.filter { $0.status == .pending } }
    }

    /// All failed commitments
    public var failedCommitments: [Commitment] {
        queue.sync { _commitments.filter { $0.status == .failed } }
    }

    // MARK: - Initialization

    /// Create an empty commitment list
    public init() {}

    /// Create a commitment list with initial commitments
    public init(commitments: [Commitment]) {
        self._commitments = commitments
    }

    // MARK: - CRUD Operations

    /// Add a commitment to the list
    /// - Parameter commitment: The commitment to add
    public func add(_ commitment: Commitment) {
        queue.sync {
            _commitments.append(commitment)
        }
    }

    /// Add a new commitment with description and assertion
    /// - Parameters:
    ///   - description: What is being committed
    ///   - assertion: Command to verify the commitment
    /// - Returns: The created commitment
    @discardableResult
    public func add(description: String, assertion: String) -> Commitment {
        let commitment = Commitment(description: description, assertion: assertion)
        add(commitment)
        return commitment
    }

    /// Remove a commitment by ID
    /// - Parameter id: The ID of the commitment to remove
    /// - Returns: true if the commitment was found and removed
    @discardableResult
    public func remove(id: UUID) -> Bool {
        queue.sync {
            if let index = _commitments.firstIndex(where: { $0.id == id }) {
                _commitments.remove(at: index)
                return true
            }
            return false
        }
    }

    /// Get a commitment by ID
    /// - Parameter id: The ID of the commitment
    /// - Returns: The commitment if found
    public func get(id: UUID) -> Commitment? {
        queue.sync {
            _commitments.first { $0.id == id }
        }
    }

    /// Update a commitment
    /// - Parameter commitment: The updated commitment (matched by ID)
    /// - Returns: true if the commitment was found and updated
    @discardableResult
    public func update(_ commitment: Commitment) -> Bool {
        queue.sync {
            if let index = _commitments.firstIndex(where: { $0.id == commitment.id }) {
                _commitments[index] = commitment
                return true
            }
            return false
        }
    }

    /// Remove all commitments
    public func removeAll() {
        queue.sync {
            _commitments.removeAll()
        }
    }

    // MARK: - Status Updates

    /// Update the status of a commitment
    /// - Parameters:
    ///   - id: The ID of the commitment
    ///   - status: The new status
    ///   - failureMessage: Optional failure message (for failed status)
    /// - Returns: true if the commitment was found and updated
    @discardableResult
    public func updateStatus(
        id: UUID,
        status: CommitmentStatus,
        failureMessage: String? = nil
    ) -> Bool {
        queue.sync {
            guard let index = _commitments.firstIndex(where: { $0.id == id }) else {
                return false
            }

            _commitments[index].status = status
            _commitments[index].failureMessage = failureMessage
            _commitments[index].updatedAt = Date()
            return true
        }
    }

    /// Mark a commitment as verifying
    @discardableResult
    public func markVerifying(id: UUID) -> Bool {
        updateStatus(id: id, status: .verifying)
    }

    /// Mark a commitment as passed
    @discardableResult
    public func markPassed(id: UUID) -> Bool {
        updateStatus(id: id, status: .passed)
    }

    /// Mark a commitment as failed
    @discardableResult
    public func markFailed(id: UUID, message: String) -> Bool {
        updateStatus(id: id, status: .failed, failureMessage: message)
    }

    /// Reset a commitment to pending
    @discardableResult
    public func reset(id: UUID) -> Bool {
        updateStatus(id: id, status: .pending)
    }

    /// Reset all commitments to pending
    public func resetAll() {
        queue.sync {
            for index in _commitments.indices {
                _commitments[index].status = .pending
                _commitments[index].failureMessage = nil
                _commitments[index].updatedAt = Date()
            }
        }
    }
}
