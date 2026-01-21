import Foundation
import Testing
@testable import TavernCore

@Suite("Commitment Tests")
struct CommitmentTests {

    @Test("Commitment is created with correct initial state")
    func commitmentCreated() {
        let commitment = Commitment(
            description: "All tests pass",
            assertion: "swift test"
        )

        #expect(!commitment.description.isEmpty)
        #expect(!commitment.assertion.isEmpty)
        #expect(commitment.status == .pending)
        #expect(commitment.failureMessage == nil)
        #expect(commitment.isPending == true)
        #expect(commitment.isComplete == false)
        #expect(commitment.isVerified == false)
    }

    @Test("Commitment status transitions work correctly")
    func commitmentStatusTransitions() {
        var commitment = Commitment(
            description: "Test",
            assertion: "echo test"
        )

        // Start as pending
        #expect(commitment.status == .pending)

        // Mark as verifying
        commitment.markVerifying()
        #expect(commitment.status == .verifying)
        #expect(commitment.isVerified == false)

        // Mark as passed
        commitment.markPassed()
        #expect(commitment.status == .passed)
        #expect(commitment.isComplete == true)
        #expect(commitment.isVerified == true)

        // Reset
        commitment.reset()
        #expect(commitment.status == .pending)
        #expect(commitment.isPending == true)

        // Mark as failed
        commitment.markVerifying()
        commitment.markFailed(message: "Test failed")
        #expect(commitment.status == .failed)
        #expect(commitment.failureMessage == "Test failed")
        #expect(commitment.isVerified == true)
        #expect(commitment.isComplete == false)
    }

    @Test("Commitment updatedAt changes on status update")
    func commitmentUpdatedAtChanges() {
        var commitment = Commitment(
            description: "Test",
            assertion: "echo test"
        )

        let initialUpdatedAt = commitment.updatedAt

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        commitment.markVerifying()

        #expect(commitment.updatedAt > initialUpdatedAt)
    }

    @Test("Commitment is Codable")
    func commitmentCodable() throws {
        let original = Commitment(
            description: "All tests pass",
            assertion: "swift test"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Commitment.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.description == original.description)
        #expect(decoded.assertion == original.assertion)
        #expect(decoded.status == original.status)
    }
}

@Suite("CommitmentList Tests")
struct CommitmentListTests {

    @Test("List starts empty")
    func listStartsEmpty() {
        let list = CommitmentList()

        #expect(list.count == 0)
        #expect(list.commitments.isEmpty)
        #expect(list.allPassed == true) // Vacuously true
        #expect(list.hasPending == false)
        #expect(list.hasFailed == false)
    }

    @Test("Add commitment works")
    func addCommitmentWorks() {
        let list = CommitmentList()

        let commitment = list.add(
            description: "Test passes",
            assertion: "swift test"
        )

        #expect(list.count == 1)
        #expect(list.get(id: commitment.id) != nil)
    }

    @Test("Remove commitment works")
    func removeCommitmentWorks() {
        let list = CommitmentList()

        let commitment = list.add(
            description: "Test",
            assertion: "echo test"
        )

        #expect(list.count == 1)

        let removed = list.remove(id: commitment.id)
        #expect(removed == true)
        #expect(list.count == 0)
        #expect(list.get(id: commitment.id) == nil)
    }

    @Test("Update commitment works")
    func updateCommitmentWorks() {
        let list = CommitmentList()

        var commitment = list.add(
            description: "Test",
            assertion: "echo test"
        )

        commitment.markPassed()
        let updated = list.update(commitment)

        #expect(updated == true)
        #expect(list.get(id: commitment.id)?.status == .passed)
    }

    @Test("Status update methods work")
    func statusUpdateMethodsWork() {
        let list = CommitmentList()

        let commitment = list.add(
            description: "Test",
            assertion: "echo test"
        )

        list.markVerifying(id: commitment.id)
        #expect(list.get(id: commitment.id)?.status == .verifying)
        #expect(list.hasVerifying == true)

        list.markPassed(id: commitment.id)
        #expect(list.get(id: commitment.id)?.status == .passed)
        #expect(list.allPassed == true)

        list.reset(id: commitment.id)
        #expect(list.get(id: commitment.id)?.status == .pending)
        #expect(list.hasPending == true)

        list.markFailed(id: commitment.id, message: "Failed")
        #expect(list.get(id: commitment.id)?.status == .failed)
        #expect(list.get(id: commitment.id)?.failureMessage == "Failed")
        #expect(list.hasFailed == true)
    }

    @Test("AllPassed returns false when commitments pending")
    func allPassedReturnsFalseWhenPending() {
        let list = CommitmentList()

        list.add(description: "Test 1", assertion: "echo 1")
        list.add(description: "Test 2", assertion: "echo 2")

        #expect(list.allPassed == false)
        #expect(list.hasPending == true)
    }

    @Test("AllPassed returns true when all passed")
    func allPassedReturnsTrueWhenAllPassed() {
        let list = CommitmentList()

        let c1 = list.add(description: "Test 1", assertion: "echo 1")
        let c2 = list.add(description: "Test 2", assertion: "echo 2")

        list.markPassed(id: c1.id)
        #expect(list.allPassed == false)

        list.markPassed(id: c2.id)
        #expect(list.allPassed == true)
    }

    @Test("PendingCommitments returns only pending")
    func pendingCommitmentsReturnsOnlyPending() {
        let list = CommitmentList()

        let c1 = list.add(description: "Test 1", assertion: "echo 1")
        let c2 = list.add(description: "Test 2", assertion: "echo 2")

        list.markPassed(id: c1.id)

        let pending = list.pendingCommitments
        #expect(pending.count == 1)
        #expect(pending.first?.id == c2.id)
    }

    @Test("FailedCommitments returns only failed")
    func failedCommitmentsReturnsOnlyFailed() {
        let list = CommitmentList()

        let c1 = list.add(description: "Test 1", assertion: "echo 1")
        let c2 = list.add(description: "Test 2", assertion: "echo 2")

        list.markFailed(id: c1.id, message: "Oops")
        list.markPassed(id: c2.id)

        let failed = list.failedCommitments
        #expect(failed.count == 1)
        #expect(failed.first?.id == c1.id)
    }

    @Test("ResetAll resets all commitments")
    func resetAllResetsAll() {
        let list = CommitmentList()

        let c1 = list.add(description: "Test 1", assertion: "echo 1")
        let c2 = list.add(description: "Test 2", assertion: "echo 2")

        list.markPassed(id: c1.id)
        list.markFailed(id: c2.id, message: "Failed")

        #expect(list.allPassed == false)

        list.resetAll()

        #expect(list.get(id: c1.id)?.status == .pending)
        #expect(list.get(id: c2.id)?.status == .pending)
        #expect(list.get(id: c2.id)?.failureMessage == nil)
        #expect(list.hasPending == true)
    }

    @Test("RemoveAll clears the list")
    func removeAllClearsList() {
        let list = CommitmentList()

        list.add(description: "Test 1", assertion: "echo 1")
        list.add(description: "Test 2", assertion: "echo 2")

        #expect(list.count == 2)

        list.removeAll()

        #expect(list.count == 0)
        #expect(list.commitments.isEmpty)
    }
}
