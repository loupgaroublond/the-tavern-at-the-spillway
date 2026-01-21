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

@Suite("CommitmentVerifier Tests")
struct CommitmentVerifierTests {

    @Test("Verifier runs assertion")
    func verifierRunsAssertion() async throws {
        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "echo test", output: "test\n")

        let verifier = CommitmentVerifier(runner: mockRunner)

        var commitment = Commitment(
            description: "Echo test",
            assertion: "echo test"
        )

        let passed = try await verifier.verify(&commitment)

        #expect(passed == true)
        #expect(mockRunner.ranCommands.count == 1)
        #expect(mockRunner.ranCommands.first == "echo test")
    }

    @Test("Verifier updates status on pass")
    func verifierUpdatesStatusOnPass() async throws {
        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "swift test")

        let verifier = CommitmentVerifier(runner: mockRunner)

        var commitment = Commitment(
            description: "Tests pass",
            assertion: "swift test"
        )

        try await verifier.verify(&commitment)

        #expect(commitment.status == .passed)
        #expect(commitment.failureMessage == nil)
    }

    @Test("Verifier updates status on fail")
    func verifierUpdatesStatusOnFail() async throws {
        let mockRunner = MockAssertionRunner()
        mockRunner.setFail(for: "swift test", message: "3 tests failed")

        let verifier = CommitmentVerifier(runner: mockRunner)

        var commitment = Commitment(
            description: "Tests pass",
            assertion: "swift test"
        )

        let passed = try await verifier.verify(&commitment)

        #expect(passed == false)
        #expect(commitment.status == .failed)
        #expect(commitment.failureMessage == "3 tests failed")
    }

    @Test("Verifier updates commitment list")
    func verifierUpdatesCommitmentList() async throws {
        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "echo ok")

        let verifier = CommitmentVerifier(runner: mockRunner)
        let list = CommitmentList()

        var commitment = list.add(description: "Test", assertion: "echo ok")

        try await verifier.verify(&commitment, in: list)

        // List should be updated too
        let updated = list.get(id: commitment.id)
        #expect(updated?.status == .passed)
    }

    @Test("VerifyAll verifies all pending commitments")
    func verifyAllVerifiesAllPending() async throws {
        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "echo 1")
        mockRunner.setPass(for: "echo 2")
        mockRunner.setPass(for: "echo 3")

        let verifier = CommitmentVerifier(runner: mockRunner)
        let list = CommitmentList()

        list.add(description: "Test 1", assertion: "echo 1")
        list.add(description: "Test 2", assertion: "echo 2")
        list.add(description: "Test 3", assertion: "echo 3")

        let allPassed = try await verifier.verifyAll(in: list)

        #expect(allPassed == true)
        #expect(list.allPassed == true)
        #expect(mockRunner.ranCommands.count == 3)
    }

    @Test("VerifyAll returns false if any fail")
    func verifyAllReturnsFalseIfAnyFail() async throws {
        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "echo 1")
        mockRunner.setFail(for: "echo 2", message: "Oops")
        mockRunner.setPass(for: "echo 3")

        let verifier = CommitmentVerifier(runner: mockRunner)
        let list = CommitmentList()

        let c1 = list.add(description: "Test 1", assertion: "echo 1")
        let c2 = list.add(description: "Test 2", assertion: "echo 2")
        let c3 = list.add(description: "Test 3", assertion: "echo 3")

        let allPassed = try await verifier.verifyAll(in: list)

        #expect(allPassed == false)
        #expect(list.allPassed == false)
        #expect(list.get(id: c1.id)?.status == .passed)
        #expect(list.get(id: c2.id)?.status == .failed)
        #expect(list.get(id: c3.id)?.status == .passed)
    }

    @Test("RetryFailed only retries failed commitments")
    func retryFailedOnlyRetriesFailed() async throws {
        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "echo ok")

        let verifier = CommitmentVerifier(runner: mockRunner)
        let list = CommitmentList()

        let c1 = list.add(description: "Already passed", assertion: "echo already")
        let c2 = list.add(description: "Failed", assertion: "echo ok")

        // Simulate c1 passed, c2 failed
        list.markPassed(id: c1.id)
        list.markFailed(id: c2.id, message: "Initial failure")

        // Retry failed
        let allPassed = try await verifier.retryFailed(in: list)

        #expect(allPassed == true)
        #expect(list.get(id: c2.id)?.status == .passed)
        // Only the failed one should have been run
        #expect(mockRunner.ranCommands.count == 1)
        #expect(mockRunner.ranCommands.first == "echo ok")
    }

    @Test("MockAssertionRunner tracks commands")
    func mockRunnerTracksCommands() async throws {
        let runner = MockAssertionRunner()

        _ = try await runner.run("command1")
        _ = try await runner.run("command2")

        #expect(runner.ranCommands.count == 2)
        #expect(runner.ranCommands[0] == "command1")
        #expect(runner.ranCommands[1] == "command2")
    }

    @Test("MockAssertionRunner reset clears state")
    func mockRunnerResetClearsState() async throws {
        let runner = MockAssertionRunner()

        runner.setPass(for: "test")
        _ = try await runner.run("test")

        runner.reset()

        #expect(runner.ranCommands.isEmpty)
    }
}
