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

    // MARK: - Grade 1 Property Tests (no mocks needed)

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

    // MARK: - Grade 2 Mock Tests (using MockMessenger)

    @Test("Servitor responds to messages")
    func servitorRespondsToMessages() async throws {
        let mock = MockMessenger(responses: ["Task acknowledged"])
        let servitor = Servitor(
            name: "ResponseWorker",
            assignment: "Handle messages",
            projectURL: Self.testProjectURL(),
            messenger: mock,
            loadSavedSession: false
        )

        let response = try await servitor.send("Do the thing")

        #expect(response == "Task acknowledged")
        #expect(mock.queryCalls.count == 1)
        #expect(mock.queryCalls[0] == "Do the thing")
    }

    @Test("Servitor tracks working state")
    func servitorTracksWorkingState() async throws {
        let mock = MockMessenger(responses: ["OK"])
        mock.responseDelay = .milliseconds(100)
        let servitor = Servitor(
            name: "StateWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            messenger: mock,
            loadSavedSession: false
        )

        #expect(servitor.state == .idle)

        let task = Task {
            try await servitor.send("Work")
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(servitor.state == .working)

        let _ = try await task.value
        #expect(servitor.state == .idle)
    }

    @Test("Servitor transitions to done via response")
    func servitorTransitionsToDone() async throws {
        let mock = MockMessenger(responses: ["Assignment complete. DONE"])
        let servitor = Servitor(
            name: "DoneViaResponse",
            assignment: "Finish up",
            projectURL: Self.testProjectURL(),
            messenger: mock,
            loadSavedSession: false
        )

        let _ = try await servitor.send("Finish it")

        #expect(servitor.state == .done)
    }

    @Test("Servitor transitions to waiting via response")
    func servitorTransitionsToWaiting() async throws {
        let mock = MockMessenger(responses: ["I need clarification. WAITING for your input."])
        let servitor = Servitor(
            name: "WaitViaResponse",
            assignment: "Need info",
            projectURL: Self.testProjectURL(),
            messenger: mock,
            loadSavedSession: false
        )

        let _ = try await servitor.send("Do the ambiguous thing")

        #expect(servitor.state == .waiting)
    }

    @Test("Servitor maintains conversation via session ID")
    func servitorMaintainsConversation() async throws {
        let sessionId = UUID().uuidString
        let mock = MockMessenger(responses: ["First", "Second"], sessionId: sessionId)
        let servitor = Servitor(
            name: "ConvoWorker",
            assignment: "Chat",
            projectURL: Self.testProjectURL(),
            messenger: mock,
            loadSavedSession: false
        )

        #expect(servitor.sessionId == nil)

        let _ = try await servitor.send("Message 1")
        #expect(servitor.sessionId == sessionId)

        let _ = try await servitor.send("Message 2")
        #expect(mock.queryOptions[1].resume == sessionId)
    }

    @Test("Servitor propagates errors")
    func servitorPropagatesErrors() async throws {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("Servitor test error")
        let servitor = Servitor(
            name: "ErrorWorker",
            assignment: "Fail",
            projectURL: Self.testProjectURL(),
            messenger: mock,
            loadSavedSession: false
        )

        do {
            let _ = try await servitor.send("Trigger error")
            Issue.record("Expected error to be thrown")
        } catch let error as TavernError {
            if case .internalError(let message) = error {
                #expect(message == "Servitor test error")
            } else {
                Issue.record("Expected internalError, got: \(error)")
            }
        }
    }

    @Test("Servitor with no commitments goes to done")
    func servitorWithNoCommitmentsGoesToDone() async throws {
        let mock = MockMessenger(responses: ["All DONE here!"])
        let servitor = Servitor(
            name: "NoPledgeWorker",
            assignment: "Quick task",
            projectURL: Self.testProjectURL(),
            commitments: CommitmentList(),
            messenger: mock,
            loadSavedSession: false
        )

        #expect(servitor.commitments.count == 0)

        let _ = try await servitor.send("Finish")

        #expect(servitor.state == .done)
    }

    @Test("Done triggers verification when commitments exist")
    func doneTriggersVerification() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Always passes", assertion: "true")

        let mock = MockMessenger(responses: ["Task DONE"])
        let servitor = Servitor(
            name: "VerifyWorker",
            assignment: "Verify task",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock,
            loadSavedSession: false
        )

        let _ = try await servitor.send("Complete the task")

        // "DONE" in response triggers verification; "true" always passes
        #expect(servitor.state == .done)
        #expect(servitor.allCommitmentsPassed == true)
    }

    @Test("Verification pass marks done")
    func verificationPassMarksDone() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Check 1", assertion: "true")
        commitments.add(description: "Check 2", assertion: "echo pass")

        let mock = MockMessenger(responses: ["DONE"])
        let servitor = Servitor(
            name: "PassVerifyWorker",
            assignment: "Pass all checks",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock,
            loadSavedSession: false
        )

        let _ = try await servitor.send("Verify")

        #expect(servitor.state == .done)
    }

    @Test("Verification fail continues work")
    func verificationFailContinuesWork() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Always fails", assertion: "false")

        let mock = MockMessenger(responses: ["DONE"])
        let servitor = Servitor(
            name: "FailVerifyWorker",
            assignment: "Fail checks",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock,
            loadSavedSession: false
        )

        let _ = try await servitor.send("Try to finish")

        // "false" always exits 1 → verification fails → back to idle
        #expect(servitor.state == .idle)
    }

    @Test("Servitor not done until all commitments verified")
    func servitorNotDoneUntilAllCommitmentsVerified() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Passes", assertion: "true")
        commitments.add(description: "Fails", assertion: "false")

        let mock = MockMessenger(responses: ["DONE"])
        let servitor = Servitor(
            name: "PartialVerifyWorker",
            assignment: "Partial verification",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock,
            loadSavedSession: false
        )

        let _ = try await servitor.send("Complete")

        // One commitment fails → not done
        #expect(servitor.state != .done)
        #expect(servitor.state == .idle)
    }
}
