import Foundation
import Testing
import ClodKit
@testable import TavernCore

@Suite("Mortal Tests", .timeLimit(.minutes(1)))
struct MortalTests {

    // Test helper - temp directory for testing
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    // MARK: - Grade 1 Property Tests (no mocks needed)

    @Test("Mortal has assignment", .tags(.reqAGT002, .reqSPN009))
    func mortalHasAssignment() throws {
        let mortal = Mortal(
            name: "TestWorker",
            assignment: "Parse the input file and extract data",
            projectURL: Self.testProjectURL()
        )

        #expect(mortal.assignment == "Parse the input file and extract data")
        #expect(mortal.name == "TestWorker")
    }

    @Test("Mortal initializes with idle state", .tags(.reqAGT002, .reqAGT005))
    func mortalInitializesIdle() throws {
        let mortal = Mortal(
            name: "IdleWorker",
            assignment: "Do something",
            projectURL: Self.testProjectURL()
        )

        #expect(mortal.state == .idle)
        #expect(mortal.sessionId == nil)
    }

    @Test("Mortal can be explicitly marked waiting")
    func mortalExplicitlyMarkedWaiting() throws {
        let mortal = Mortal(
            name: "ExplicitWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL()
        )

        #expect(mortal.state == .idle)

        mortal.markWaiting()

        #expect(mortal.state == .waiting)
    }

    @Test("Mortal can be explicitly marked done")
    func mortalExplicitlyMarkedDone() throws {
        let mortal = Mortal(
            name: "DoneWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL()
        )

        mortal.markDone()

        #expect(mortal.state == .done)
    }

    @Test("Mortal done state is terminal", .tags(.reqAGT009))
    func mortalDoneStateIsTerminal() throws {
        let mortal = Mortal(
            name: "TerminalWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL()
        )

        mortal.markDone()
        #expect(mortal.state == .done)

        // Reset conversation should not change done state
        mortal.resetConversation()
        #expect(mortal.state == .done)

        // markWaiting should not change done state
        mortal.markWaiting()
        #expect(mortal.state == .done)
    }

    @Test("Mortal reset clears session")
    func mortalResetClearsSession() async throws {
        let mortal = Mortal(
            name: "ResetWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL()
        )

        // Session starts nil
        #expect(mortal.sessionId == nil)

        // Reset should keep it nil and return to idle
        mortal.resetConversation()
        #expect(mortal.sessionId == nil)
        #expect(mortal.state == .idle)
    }

    @Test("Add commitment helper works")
    func addCommitmentHelperWorks() throws {
        let mortal = Mortal(
            name: "CommitHelper",
            assignment: "Task",
            projectURL: Self.testProjectURL()
        )

        #expect(mortal.commitments.count == 0)

        let c1 = mortal.addCommitment(description: "First", assertion: "cmd1")
        let c2 = mortal.addCommitment(description: "Second", assertion: "cmd2")

        #expect(mortal.commitments.count == 2)
        #expect(mortal.commitments.get(id: c1.id) != nil)
        #expect(mortal.commitments.get(id: c2.id) != nil)
    }

    @Test("AllCommitmentsPassed returns correct value")
    func allCommitmentsPassedWorks() throws {
        let commitments = CommitmentList()

        let mortal = Mortal(
            name: "PassCheckWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            commitments: commitments
        )

        // Empty commitments = vacuously true
        #expect(mortal.allCommitmentsPassed == true)

        // Add pending commitment
        let c1 = commitments.add(description: "Test", assertion: "cmd")
        #expect(mortal.allCommitmentsPassed == false)

        // Mark passed
        commitments.markPassed(id: c1.id)
        #expect(mortal.allCommitmentsPassed == true)
    }

    @Test("HasFailedCommitments returns correct value")
    func hasFailedCommitmentsWorks() throws {
        let commitments = CommitmentList()

        let mortal = Mortal(
            name: "FailCheckWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            commitments: commitments
        )

        #expect(mortal.hasFailedCommitments == false)

        let c1 = commitments.add(description: "Test", assertion: "cmd")
        #expect(mortal.hasFailedCommitments == false)

        commitments.markFailed(id: c1.id, message: "Oops")
        #expect(mortal.hasFailedCommitments == true)
    }

    // MARK: - Grade 2 Mock Tests (using MockMessenger)

    @Test("Mortal responds to messages", .tags(.reqARCH009))
    func mortalRespondsToMessages() async throws {
        let mock = MockMessenger(responses: ["Task acknowledged"])
        let mortal = Mortal(
            name: "ResponseWorker",
            assignment: "Handle messages",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let response = try await mortal.send("Do the thing")

        #expect(response == "Task acknowledged")
        #expect(mock.queryCalls.count == 1)
        #expect(mock.queryCalls[0] == "Do the thing")
    }

    @Test("Mortal tracks working state")
    func mortalTracksWorkingState() async throws {
        let mock = MockMessenger(responses: ["OK"])
        mock.responseDelay = .milliseconds(100)
        let mortal = Mortal(
            name: "StateWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        #expect(mortal.state == .idle)

        let task = Task {
            try await mortal.send("Work")
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(mortal.state == .working)

        let _ = try await task.value
        #expect(mortal.state == .idle)
    }

    @Test("Mortal transitions to done via response", .tags(.reqAGT009, .reqV1005))
    func mortalTransitionsToDone() async throws {
        let mock = MockMessenger(responses: ["Assignment complete. DONE"])
        let mortal = Mortal(
            name: "DoneViaResponse",
            assignment: "Finish up",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let _ = try await mortal.send("Finish it")

        #expect(mortal.state == .done)
    }

    @Test("Mortal transitions to waiting via response", .tags(.reqAGT009))
    func mortalTransitionsToWaiting() async throws {
        let mock = MockMessenger(responses: ["I need clarification. WAITING for your input."])
        let mortal = Mortal(
            name: "WaitViaResponse",
            assignment: "Need info",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let _ = try await mortal.send("Do the ambiguous thing")

        #expect(mortal.state == .waiting)
    }

    @Test("Mortal maintains conversation via session ID")
    func mortalMaintainsConversation() async throws {
        let sessionId = UUID().uuidString
        let mock = MockMessenger(responses: ["First", "Second"], sessionId: sessionId)
        let mortal = Mortal(
            name: "ConvoWorker",
            assignment: "Chat",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        #expect(mortal.sessionId == nil)

        let _ = try await mortal.send("Message 1")
        #expect(mortal.sessionId == sessionId)

        let _ = try await mortal.send("Message 2")
        // Resume is now enabled — second message should include the session ID
        #expect(mock.queryOptions[1].resume == sessionId)
    }

    @Test("Mortal propagates errors")
    func mortalPropagatesErrors() async throws {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("Mortal test error")
        let mortal = Mortal(
            name: "ErrorWorker",
            assignment: "Fail",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        do {
            let _ = try await mortal.send("Trigger error")
            Issue.record("Expected error to be thrown")
        } catch let error as TavernError {
            if case .internalError(let message) = error {
                #expect(message == "Mortal test error")
            } else {
                Issue.record("Expected internalError, got: \(error)")
            }
        }
    }

    @Test("Mortal with no commitments goes to done")
    func mortalWithNoCommitmentsGoesToDone() async throws {
        let mock = MockMessenger(responses: ["All DONE here!"])
        let mortal = Mortal(
            name: "NoPledgeWorker",
            assignment: "Quick task",
            projectURL: Self.testProjectURL(),
            commitments: CommitmentList(),
            messenger: mock
        )

        #expect(mortal.commitments.count == 0)

        let _ = try await mortal.send("Finish")

        #expect(mortal.state == .done)
    }

    @Test("Done triggers verification when commitments exist", .tags(.reqDET004, .reqV1005, .reqV1006))
    func doneTriggersVerification() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Always passes", assertion: "true")

        let mock = MockMessenger(responses: ["Task DONE"])
        let mortal = Mortal(
            name: "VerifyWorker",
            assignment: "Verify task",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock
        )

        let _ = try await mortal.send("Complete the task")

        // "DONE" in response triggers verification; "true" always passes
        #expect(mortal.state == .done)
        #expect(mortal.allCommitmentsPassed == true)
    }

    @Test("Verification pass marks done", .tags(.reqDET004, .reqV1006))
    func verificationPassMarksDone() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Check 1", assertion: "true")
        commitments.add(description: "Check 2", assertion: "echo pass")

        let mock = MockMessenger(responses: ["DONE"])
        let mortal = Mortal(
            name: "PassVerifyWorker",
            assignment: "Pass all checks",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock
        )

        let _ = try await mortal.send("Verify")

        #expect(mortal.state == .done)
    }

    @Test("Verification fail continues work", .tags(.reqDET004, .reqV1006))
    func verificationFailContinuesWork() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Always fails", assertion: "false")

        let mock = MockMessenger(responses: ["DONE"])
        let mortal = Mortal(
            name: "FailVerifyWorker",
            assignment: "Fail checks",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock
        )

        let _ = try await mortal.send("Try to finish")

        // "false" always exits 1 → verification fails → back to idle
        #expect(mortal.state == .idle)
    }

    @Test("Mortal not done until all commitments verified")
    func mortalNotDoneUntilAllCommitmentsVerified() async throws {
        let commitments = CommitmentList()
        commitments.add(description: "Passes", assertion: "true")
        commitments.add(description: "Fails", assertion: "false")

        let mock = MockMessenger(responses: ["DONE"])
        let mortal = Mortal(
            name: "PartialVerifyWorker",
            assignment: "Partial verification",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            messenger: mock
        )

        let _ = try await mortal.send("Complete")

        // One commitment fails → not done
        #expect(mortal.state != .done)
        #expect(mortal.state == .idle)
    }

    // MARK: - Session Mode Tests

    @Test("Mortal defaults to plan mode")
    func mortalDefaultsToPlanMode() throws {
        let mortal = Mortal(
            name: "ModeWorker",
            projectURL: Self.testProjectURL()
        )
        #expect(mortal.sessionMode == .plan)
    }

    @Test("Mortal session mode can be changed")
    func mortalSessionModeCanBeChanged() throws {
        let mortal = Mortal(
            name: "ModeWorker",
            projectURL: Self.testProjectURL()
        )
        #expect(mortal.sessionMode == .plan)

        mortal.sessionMode = .acceptEdits
        #expect(mortal.sessionMode == .acceptEdits)
    }

    @Test("Mortal includes permission mode in query options")
    func mortalIncludesPermissionModeInQueryOptions() async throws {
        let mock = MockMessenger(responses: ["OK", "OK"])
        let mortal = Mortal(
            name: "ModeQueryWorker",
            assignment: "Test modes",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        // Default plan mode
        let _ = try await mortal.send("Test plan")
        #expect(mock.queryOptions.count == 1)
        #expect(mock.queryOptions[0].permissionMode == .plan)

        // Switch to bypassPermissions and verify
        mortal.sessionMode = .bypassPermissions
        let _ = try await mortal.send("Test bypass")
        #expect(mock.queryOptions.count == 2)
        #expect(mock.queryOptions[1].permissionMode == .bypassPermissions)
    }
}
