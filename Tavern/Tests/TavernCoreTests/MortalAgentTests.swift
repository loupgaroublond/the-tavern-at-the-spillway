import Foundation
import Testing
@testable import TavernCore

@Suite("MortalAgent Tests")
struct MortalAgentTests {

    @Test("Mortal agent has assignment")
    func mortalAgentHasAssignment() {
        let mock = MockClaudeCode()
        let agent = MortalAgent(
            name: "TestWorker",
            assignment: "Parse the input file and extract data",
            claude: mock
        )

        #expect(agent.assignment == "Parse the input file and extract data")
        #expect(agent.name == "TestWorker")
    }

    @Test("Mortal agent initializes with idle state")
    func mortalAgentInitializesIdle() {
        let mock = MockClaudeCode()
        let agent = MortalAgent(
            name: "IdleWorker",
            assignment: "Do something",
            claude: mock
        )

        #expect(agent.state == .idle)
        #expect(agent.sessionId == nil)
    }

    @Test("Mortal agent responds to messages")
    func mortalAgentRespondsToMessages() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Working on it!", sessionId: "worker-session-1")

        let agent = MortalAgent(
            name: "ResponsiveWorker",
            assignment: "Handle requests",
            claude: mock
        )

        let response = try await agent.send("Start working")

        #expect(response == "Working on it!")
        #expect(agent.sessionId == "worker-session-1")
        #expect(mock.sentPrompts.count == 1)
        #expect(mock.sentPrompts.first == "Start working")
    }

    @Test("Mortal agent tracks working state during response")
    func mortalAgentTracksWorkingState() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "In progress...", sessionId: "session-1")
        mock.responseDelay = 0.1

        let agent = MortalAgent(
            name: "WorkingWorker",
            assignment: "Long task",
            claude: mock
        )

        #expect(agent.state == .idle)

        let task = Task {
            try await agent.send("Start")
        }

        // Wait for state to change
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(agent.state == .working)

        // Wait for completion
        _ = try await task.value
        #expect(agent.state == .idle)
    }

    @Test("Mortal agent transitions to done state")
    func mortalAgentTransitionsToDone() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Task is DONE!", sessionId: "session-1")

        let agent = MortalAgent(
            name: "CompletingWorker",
            assignment: "Finish something",
            claude: mock
        )

        _ = try await agent.send("Complete the task")

        #expect(agent.state == .done)
    }

    @Test("Mortal agent transitions to waiting state")
    func mortalAgentTransitionsToWaiting() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(
            result: "I NEED INPUT to continue. What file should I process?",
            sessionId: "session-1"
        )

        let agent = MortalAgent(
            name: "WaitingWorker",
            assignment: "Process file",
            claude: mock
        )

        _ = try await agent.send("Start processing")

        #expect(agent.state == .waiting)
    }

    @Test("Mortal agent can be explicitly marked waiting")
    func mortalAgentExplicitlyMarkedWaiting() {
        let mock = MockClaudeCode()
        let agent = MortalAgent(
            name: "ExplicitWorker",
            assignment: "Task",
            claude: mock
        )

        #expect(agent.state == .idle)

        agent.markWaiting()

        #expect(agent.state == .waiting)
    }

    @Test("Mortal agent can be explicitly marked done")
    func mortalAgentExplicitlyMarkedDone() {
        let mock = MockClaudeCode()
        let agent = MortalAgent(
            name: "DoneWorker",
            assignment: "Task",
            claude: mock
        )

        agent.markDone()

        #expect(agent.state == .done)
    }

    @Test("Mortal agent done state is terminal")
    func mortalAgentDoneStateIsTerminal() {
        let mock = MockClaudeCode()
        let agent = MortalAgent(
            name: "TerminalWorker",
            assignment: "Task",
            claude: mock
        )

        agent.markDone()
        #expect(agent.state == .done)

        // Reset conversation should not change done state
        agent.resetConversation()
        #expect(agent.state == .done)

        // markWaiting should not change done state
        agent.markWaiting()
        #expect(agent.state == .done)
    }

    @Test("Mortal agent maintains conversation via session ID")
    func mortalAgentMaintainsConversation() async throws {
        let mock = MockClaudeCode()
        let sessionId = "persistent-session"
        mock.queueJSONResponse(result: "First response", sessionId: sessionId)
        mock.queueJSONResponse(result: "Second response", sessionId: sessionId)

        let agent = MortalAgent(
            name: "ConversationalWorker",
            assignment: "Multi-turn task",
            claude: mock
        )

        _ = try await agent.send("First message")
        #expect(agent.sessionId == sessionId)
        #expect(mock.resumedSessions.isEmpty)

        _ = try await agent.send("Second message")
        #expect(mock.resumedSessions.count == 1)
        #expect(mock.resumedSessions.first?.sessionId == sessionId)
    }

    @Test("Mortal agent reset clears session but not done state")
    func mortalAgentResetClearsSession() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")

        let agent = MortalAgent(
            name: "ResetWorker",
            assignment: "Task",
            claude: mock
        )

        _ = try await agent.send("Hello")
        #expect(agent.sessionId == "session-123")

        agent.resetConversation()
        #expect(agent.sessionId == nil)
        #expect(agent.state == .idle)
    }

    @Test("Mortal agent propagates errors")
    func mortalAgentPropagatesErrors() async {
        let mock = MockClaudeCode()
        mock.errorToThrow = ClaudeCodeError.executionFailed("Worker error")

        let agent = MortalAgent(
            name: "ErrorWorker",
            assignment: "Fail",
            claude: mock
        )

        do {
            _ = try await agent.send("Cause error")
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is ClaudeCodeError)
        }

        // State should return to idle after error
        #expect(agent.state == .idle)
    }

    // MARK: - Commitment Integration Tests

    @Test("Agent with no commitments transitions to done immediately")
    func agentWithNoCommitmentsGoesToDone() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Task DONE!", sessionId: "s1")

        let agent = MortalAgent(
            name: "NoCommitWorker",
            assignment: "Simple task",
            claude: mock
        )

        // No commitments added
        #expect(agent.commitments.count == 0)

        _ = try await agent.send("Complete it")

        // Should go directly to done since no commitments
        #expect(agent.state == .done)
    }

    @Test("Done triggers verification when commitments exist")
    func doneTriggersVerification() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Work is DONE!", sessionId: "s1")

        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "echo test")
        let verifier = CommitmentVerifier(runner: mockRunner)

        let commitments = CommitmentList()
        commitments.add(description: "Test passes", assertion: "echo test")

        let agent = MortalAgent(
            name: "CommitWorker",
            assignment: "Task with commitment",
            claude: mock,
            commitments: commitments,
            verifier: verifier
        )

        #expect(agent.commitments.count == 1)
        #expect(commitments.pendingCommitments.count == 1)

        _ = try await agent.send("Complete the work")

        // Verifier should have been called
        #expect(mockRunner.ranCommands.count == 1)
        #expect(mockRunner.ranCommands.first == "echo test")
    }

    @Test("Verification pass marks agent done")
    func verificationPassMarksDone() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "I'm DONE!", sessionId: "s1")

        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "swift test")
        let verifier = CommitmentVerifier(runner: mockRunner)

        let commitments = CommitmentList()
        commitments.add(description: "Tests pass", assertion: "swift test")

        let agent = MortalAgent(
            name: "PassWorker",
            assignment: "Make tests pass",
            claude: mock,
            commitments: commitments,
            verifier: verifier
        )

        _ = try await agent.send("Run the tests")

        // Verification passed, so agent should be done
        #expect(agent.state == .done)
        #expect(commitments.allPassed == true)
    }

    @Test("Verification fail returns agent to idle")
    func verificationFailContinuesWork() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Work DONE!", sessionId: "s1")

        let mockRunner = MockAssertionRunner()
        mockRunner.setFail(for: "swift test", message: "2 tests failed")
        let verifier = CommitmentVerifier(runner: mockRunner)

        let commitments = CommitmentList()
        commitments.add(description: "Tests pass", assertion: "swift test")

        let agent = MortalAgent(
            name: "FailWorker",
            assignment: "Fix tests",
            claude: mock,
            commitments: commitments,
            verifier: verifier
        )

        _ = try await agent.send("Are we done?")

        // Verification failed, agent should NOT be done
        #expect(agent.state == .idle) // Ready for more work
        #expect(commitments.hasFailed == true)
        #expect(commitments.allPassed == false)
    }

    @Test("Agent not done until all commitments verified")
    func agentNotDoneUntilAllCommitmentsVerified() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "All DONE!", sessionId: "s1")

        let mockRunner = MockAssertionRunner()
        mockRunner.setPass(for: "echo one")
        mockRunner.setFail(for: "echo two", message: "Oops")
        mockRunner.setPass(for: "echo three")
        let verifier = CommitmentVerifier(runner: mockRunner)

        let commitments = CommitmentList()
        commitments.add(description: "First thing", assertion: "echo one")
        commitments.add(description: "Second thing", assertion: "echo two")
        commitments.add(description: "Third thing", assertion: "echo three")

        let agent = MortalAgent(
            name: "MultiCommitWorker",
            assignment: "Multiple commitments",
            claude: mock,
            commitments: commitments,
            verifier: verifier
        )

        _ = try await agent.send("Finish up")

        // One commitment failed, so agent should NOT be done
        #expect(agent.state == .idle)
        #expect(commitments.allPassed == false)
        #expect(mockRunner.ranCommands.count == 3) // All were checked
    }

    @Test("Add commitment helper works")
    func addCommitmentHelperWorks() {
        let mock = MockClaudeCode()
        let agent = MortalAgent(
            name: "CommitHelper",
            assignment: "Task",
            claude: mock
        )

        #expect(agent.commitments.count == 0)

        let c1 = agent.addCommitment(description: "First", assertion: "cmd1")
        let c2 = agent.addCommitment(description: "Second", assertion: "cmd2")

        #expect(agent.commitments.count == 2)
        #expect(agent.commitments.get(id: c1.id) != nil)
        #expect(agent.commitments.get(id: c2.id) != nil)
    }

    @Test("AllCommitmentsPassed returns correct value")
    func allCommitmentsPassedWorks() {
        let mock = MockClaudeCode()
        let commitments = CommitmentList()

        let agent = MortalAgent(
            name: "PassCheckWorker",
            assignment: "Task",
            claude: mock,
            commitments: commitments
        )

        // Empty commitments = vacuously true
        #expect(agent.allCommitmentsPassed == true)

        // Add pending commitment
        let c1 = commitments.add(description: "Test", assertion: "cmd")
        #expect(agent.allCommitmentsPassed == false)

        // Mark passed
        commitments.markPassed(id: c1.id)
        #expect(agent.allCommitmentsPassed == true)
    }

    @Test("HasFailedCommitments returns correct value")
    func hasFailedCommitmentsWorks() {
        let mock = MockClaudeCode()
        let commitments = CommitmentList()

        let agent = MortalAgent(
            name: "FailCheckWorker",
            assignment: "Task",
            claude: mock,
            commitments: commitments
        )

        #expect(agent.hasFailedCommitments == false)

        let c1 = commitments.add(description: "Test", assertion: "cmd")
        #expect(agent.hasFailedCommitments == false)

        commitments.markFailed(id: c1.id, message: "Oops")
        #expect(agent.hasFailedCommitments == true)
    }
}
