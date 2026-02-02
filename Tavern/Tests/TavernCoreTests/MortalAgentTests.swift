import Foundation
import Testing
@testable import TavernCore

@Suite("MortalAgent Tests")
struct MortalAgentTests {

    // Test helper - temp directory for testing
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("Mortal agent has assignment")
    func mortalAgentHasAssignment() {
        let agent = MortalAgent(
            name: "TestWorker",
            assignment: "Parse the input file and extract data",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        #expect(agent.assignment == "Parse the input file and extract data")
        #expect(agent.name == "TestWorker")
    }

    @Test("Mortal agent initializes with idle state")
    func mortalAgentInitializesIdle() {
        let agent = MortalAgent(
            name: "IdleWorker",
            assignment: "Do something",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        #expect(agent.state == .idle)
        #expect(agent.sessionId == nil)
    }

    @Test("Mortal agent can be explicitly marked waiting")
    func mortalAgentExplicitlyMarkedWaiting() {
        let agent = MortalAgent(
            name: "ExplicitWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        #expect(agent.state == .idle)

        agent.markWaiting()

        #expect(agent.state == .waiting)
    }

    @Test("Mortal agent can be explicitly marked done")
    func mortalAgentExplicitlyMarkedDone() {
        let agent = MortalAgent(
            name: "DoneWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        agent.markDone()

        #expect(agent.state == .done)
    }

    @Test("Mortal agent done state is terminal")
    func mortalAgentDoneStateIsTerminal() {
        let agent = MortalAgent(
            name: "TerminalWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
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

    @Test("Mortal agent reset clears session")
    func mortalAgentResetClearsSession() async throws {
        let agent = MortalAgent(
            name: "ResetWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        // Session starts nil
        #expect(agent.sessionId == nil)

        // Reset should keep it nil and return to idle
        agent.resetConversation()
        #expect(agent.sessionId == nil)
        #expect(agent.state == .idle)
    }

    @Test("Add commitment helper works")
    func addCommitmentHelperWorks() {
        let agent = MortalAgent(
            name: "CommitHelper",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
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
        let commitments = CommitmentList()

        let agent = MortalAgent(
            name: "PassCheckWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            loadSavedSession: false
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
        let commitments = CommitmentList()

        let agent = MortalAgent(
            name: "FailCheckWorker",
            assignment: "Task",
            projectURL: Self.testProjectURL(),
            commitments: commitments,
            loadSavedSession: false
        )

        #expect(agent.hasFailedCommitments == false)

        let c1 = commitments.add(description: "Test", assertion: "cmd")
        #expect(agent.hasFailedCommitments == false)

        commitments.markFailed(id: c1.id, message: "Oops")
        #expect(agent.hasFailedCommitments == true)
    }

    // Note: MortalAgent.projectURL is private, so we can't test it directly
    // The project URL is used internally for session storage

    // MARK: - Tests requiring SDK mocking (skipped for now)
    // TODO: These tests need dependency injection or SDK mocking to work
    // - mortalAgentRespondsToMessages
    // - mortalAgentTracksWorkingState
    // - mortalAgentTransitionsToDone (via response)
    // - mortalAgentTransitionsToWaiting (via response)
    // - mortalAgentMaintainsConversation
    // - mortalAgentPropagatesErrors
    // - agentWithNoCommitmentsGoesToDone (via response)
    // - doneTriggersVerification (via response)
    // - verificationPassMarksDone (via response)
    // - verificationFailContinuesWork (via response)
    // - agentNotDoneUntilAllCommitmentsVerified (via response)
}
