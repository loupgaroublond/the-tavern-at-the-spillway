import Foundation
import Testing
@testable import TavernCore

@Suite("Servitor Tests")
struct ServitorTests {

    // Test helper - temp directory for testing
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("Servitor has assignment")
    func servitorHasAssignment() {
        let servitor = Servitor(
            name: "TestWorker",
            assignment: "Parse the input file and extract data",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        #expect(servitor.assignment == "Parse the input file and extract data")
        #expect(servitor.name == "TestWorker")
    }

    @Test("Servitor initializes with idle state")
    func servitorInitializesIdle() {
        let servitor = Servitor(
            name: "IdleWorker",
            assignment: "Do something",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        #expect(servitor.state == .idle)
        #expect(servitor.sessionId == nil)
    }

    @Test("Servitor can be explicitly marked waiting")
    func servitorExplicitlyMarkedWaiting() {
        let servitor = Servitor(
            name: "ExplicitWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        #expect(servitor.state == .idle)

        servitor.markWaiting()

        #expect(servitor.state == .waiting)
    }

    @Test("Servitor can be explicitly marked done")
    func servitorExplicitlyMarkedDone() {
        let servitor = Servitor(
            name: "DoneWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        servitor.markDone()

        #expect(servitor.state == .done)
    }

    @Test("Servitor done state is terminal")
    func servitorDoneStateIsTerminal() {
        let servitor = Servitor(
            name: "TerminalWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        servitor.markDone()
        #expect(servitor.state == .done)

        // Reset conversation should not change done state
        servitor.resetConversation()
        #expect(servitor.state == .done)

        // markWaiting should not change done state
        servitor.markWaiting()
        #expect(servitor.state == .done)
    }

    @Test("Servitor reset clears session")
    func servitorResetClearsSession() async throws {
        let servitor = Servitor(
            name: "ResetWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        // Session starts nil
        #expect(servitor.sessionId == nil)

        // Reset should keep it nil and return to idle
        servitor.resetConversation()
        #expect(servitor.sessionId == nil)
        #expect(servitor.state == .idle)
    }

    @Test("Add commitment helper works")
    func addCommitmentHelperWorks() {
        let servitor = Servitor(
            name: "CommitHelper",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        #expect(servitor.commitments.count == 0)

        let c1 = servitor.addCommitment(description: "First", assertion: "cmd1")
        let c2 = servitor.addCommitment(description: "Second", assertion: "cmd2")

        #expect(servitor.commitments.count == 2)
        #expect(servitor.commitments.get(id: c1.id) != nil)
        #expect(servitor.commitments.get(id: c2.id) != nil)
    }

    @Test("AllCommitmentsPassed returns correct value")
    func allCommitmentsPassedWorks() {
        let commitments = CommitmentList()

        let servitor = Servitor(
            name: "PassCheckWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            loadSavedSession: false
        )

        // Empty commitments = vacuously true
        #expect(servitor.allCommitmentsPassed == true)

        // Add pending commitment
        let c1 = commitments.add(description: "Test", assertion: "cmd")
        #expect(servitor.allCommitmentsPassed == false)

        // Mark passed
        commitments.markPassed(id: c1.id)
        #expect(servitor.allCommitmentsPassed == true)
    }

    @Test("HasFailedCommitments returns correct value")
    func hasFailedCommitmentsWorks() {
        let commitments = CommitmentList()

        let servitor = Servitor(
            name: "FailCheckWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            loadSavedSession: false
        )

        #expect(servitor.hasFailedCommitments == false)

        let c1 = commitments.add(description: "Test", assertion: "cmd")
        #expect(servitor.hasFailedCommitments == false)

        commitments.markFailed(id: c1.id, message: "Oops")
        #expect(servitor.hasFailedCommitments == true)
    }

    // Note: Servitor.projectURL is private, so we can't test it directly
    // The project URL is used internally for session storage

    // MARK: - Tests requiring SDK mocking (skipped for now)
    // TODO: These tests need dependency injection or SDK mocking to work
    // - servitorRespondsToMessages
    // - servitorTracksWorkingState
    // - servitorTransitionsToDone (via response)
    // - servitorTransitionsToWaiting (via response)
    // - servitorMaintainsConversation
    // - servitorPropagatesErrors
    // - servitorWithNoCommitmentsGoesToDone (via response)
    // - doneTriggersVerification (via response)
    // - verificationPassMarksDone (via response)
    // - verificationFailContinuesWork (via response)
    // - servitorNotDoneUntilAllCommitmentsVerified (via response)
}
