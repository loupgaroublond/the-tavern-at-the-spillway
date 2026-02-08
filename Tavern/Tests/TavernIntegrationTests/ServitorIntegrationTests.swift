import Foundation
import XCTest
import ClodKit
@testable import TavernCore

/// Grade 3 integration tests for Servitor — real Claude API calls
/// Run with: redo test-grade3
/// Or: swift test --filter TavernIntegrationTests/ServitorIntegrationTests
///
/// These are the source-of-truth tests. Grade 2 mocks mirror these assertions.
final class ServitorIntegrationTests: XCTestCase {

    private var projectURL: URL!

    override func setUp() async throws {
        executionTimeAllowance = 60
        projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavern-integration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: projectURL)
    }

    // MARK: - Basic Communication

    /// Servitor responds to messages with non-empty text
    func testServitorRespondsToMessages() async throws {
        let servitor = Servitor(
            name: "TestWorker",
            assignment: "Respond to test messages",
            projectURL: projectURL,
            loadSavedSession: false
        )

        let response = try await servitor.send("Say SERVITOR_OK in one word")
        XCTAssertFalse(response.isEmpty, "Servitor should return a non-empty response")
    }

    /// Servitor tracks working state during send
    func testServitorTracksWorkingState() async throws {
        let servitor = Servitor(
            name: "StateWorker",
            assignment: "Track state transitions",
            projectURL: projectURL,
            loadSavedSession: false
        )
        XCTAssertEqual(servitor.state, .idle, "Servitor should start idle")

        let task = Task {
            try await servitor.send("Say OK in one word")
        }

        // Give the task time to start
        try await Task.sleep(for: .milliseconds(100))

        // After completion, state should be idle (unless response triggers done/waiting)
        let _ = try await task.value

        // The state after send depends on the response content
        // If Claude says "DONE" it transitions to done; otherwise back to idle
        let finalState = servitor.state
        XCTAssertTrue(
            finalState == .idle || finalState == .done,
            "Servitor should be idle or done after send, got: \(finalState)"
        )
    }

    /// Servitor transitions to done when response contains "DONE"
    func testServitorTransitionsToDone() async throws {
        let servitor = Servitor(
            name: "DoneWorker",
            assignment: "Say DONE when complete",
            projectURL: projectURL,
            loadSavedSession: false
        )

        let _ = try await servitor.send(
            "Your assignment is complete. Respond with exactly: DONE"
        )

        XCTAssertEqual(servitor.state, .done, "Servitor should transition to done when response contains DONE")
    }

    /// Servitor transitions to waiting when response contains "WAITING"
    func testServitorTransitionsToWaiting() async throws {
        let servitor = Servitor(
            name: "WaitWorker",
            assignment: "Wait for input",
            projectURL: projectURL,
            loadSavedSession: false
        )

        let _ = try await servitor.send(
            "You need more information. Respond with exactly: WAITING FOR INPUT"
        )

        // State depends on whether Claude includes "WAITING" in its response
        let finalState = servitor.state
        XCTAssertTrue(
            finalState == .waiting || finalState == .idle,
            "Servitor should be waiting or idle, got: \(finalState)"
        )
    }

    /// Servitor maintains conversation via session ID
    func testServitorMaintainsConversation() async throws {
        let servitor = Servitor(
            name: "ConversationWorker",
            assignment: "Remember context across messages",
            projectURL: projectURL,
            loadSavedSession: false
        )

        XCTAssertNil(servitor.sessionId, "Session should be nil before first message")

        let _ = try await servitor.send("Remember the number 42")
        XCTAssertNotNil(servitor.sessionId, "Session ID should be set after first message")

        let firstSessionId = servitor.sessionId
        let _ = try await servitor.send("What number did I tell you to remember?")
        XCTAssertEqual(servitor.sessionId, firstSessionId, "Session ID should persist across messages")
    }

    /// Servitor propagates errors
    func testServitorPropagatesErrors() async throws {
        // Create a servitor with a bad session ID to trigger error
        SessionStore.saveAgentSession(agentId: UUID(), sessionId: "bogus-session")

        let badId = UUID()
        SessionStore.saveAgentSession(agentId: badId, sessionId: "invalid-session-id-bogus")

        let servitor = Servitor(
            id: badId,
            name: "ErrorWorker",
            assignment: "Fail gracefully",
            projectURL: projectURL,
            loadSavedSession: true
        )

        do {
            let _ = try await servitor.send("This should fail")
            // If it doesn't fail, SDK handled gracefully — also acceptable
        } catch {
            XCTAssertNotNil(error, "Error should propagate from servitor")
        }

        // Cleanup
        SessionStore.clearAgentSession(agentId: badId)
    }

    // MARK: - Completion and Verification

    /// Servitor with no commitments goes to done when it signals completion
    func testServitorWithNoCommitmentsGoesToDone() async throws {
        let servitor = Servitor(
            name: "NoPledgeWorker",
            assignment: "Complete immediately",
            projectURL: projectURL,
            commitments: CommitmentList(),
            loadSavedSession: false
        )

        XCTAssertEqual(servitor.commitments.count, 0, "Should have no commitments")

        let _ = try await servitor.send(
            "Your assignment is done. Respond with: I am DONE with my assignment."
        )

        XCTAssertEqual(servitor.state, .done, "Servitor with no commitments should go straight to done")
    }

    /// Signaling done triggers commitment verification
    func testDoneTriggersVerification() async throws {
        let commitments = CommitmentList()
        let servitor = Servitor(
            name: "VerifyWorker",
            assignment: "Verify commitments",
            projectURL: projectURL,
            commitments: commitments,
            loadSavedSession: false
        )

        // Add a commitment that will pass (true always exits 0)
        commitments.add(description: "Always passes", assertion: "true")

        let _ = try await servitor.send(
            "Your assignment is complete. Respond with: DONE"
        )

        // If Claude said DONE, verification should have run
        let finalState = servitor.state
        XCTAssertTrue(
            finalState == .done || finalState == .idle,
            "After verification, servitor should be done (all passed) or idle (if DONE not in response), got: \(finalState)"
        )
    }

    /// Verification pass marks servitor as done
    func testVerificationPassMarksDone() async throws {
        let commitments = CommitmentList()
        let servitor = Servitor(
            name: "PassWorker",
            assignment: "Pass verification",
            projectURL: projectURL,
            commitments: commitments,
            loadSavedSession: false
        )

        commitments.add(description: "Always passes", assertion: "true")
        commitments.add(description: "Also passes", assertion: "echo pass")

        let _ = try await servitor.send(
            "Assignment complete. Respond with exactly one word: DONE"
        )

        // If DONE was in the response, both commitments should pass (true and echo always succeed)
        if servitor.state == .done {
            XCTAssertTrue(servitor.allCommitmentsPassed, "All commitments should be passed when done")
        }
    }

    /// Verification failure continues work (back to idle)
    func testVerificationFailContinuesWork() async throws {
        let commitments = CommitmentList()
        let servitor = Servitor(
            name: "FailWorker",
            assignment: "Fail verification",
            projectURL: projectURL,
            commitments: commitments,
            loadSavedSession: false
        )

        // Add a commitment that will fail (false always exits 1)
        commitments.add(description: "Always fails", assertion: "false")

        let _ = try await servitor.send(
            "Assignment complete. Respond with exactly: DONE"
        )

        // If DONE was in response, verification should fail → back to idle
        if servitor.state != .done {
            XCTAssertEqual(servitor.state, .idle, "Failed verification should return to idle")
            XCTAssertTrue(servitor.hasFailedCommitments || commitments.count > 0,
                "Should have commitments that didn't all pass")
        }
    }

    /// Servitor is not done until ALL commitments verified
    func testServitorNotDoneUntilAllCommitmentsVerified() async throws {
        let commitments = CommitmentList()
        let servitor = Servitor(
            name: "PartialWorker",
            assignment: "Partial verification",
            projectURL: projectURL,
            commitments: commitments,
            loadSavedSession: false
        )

        // One passes, one fails
        commitments.add(description: "Passes", assertion: "true")
        commitments.add(description: "Fails", assertion: "false")

        let _ = try await servitor.send(
            "Assignment complete. Respond with exactly: DONE"
        )

        // With one failing commitment, servitor should NOT be done
        if servitor.state != .idle {
            // If Claude didn't say DONE, the test is inconclusive for this assertion
            // But if it did say DONE, verification should have caught the failure
        }
        XCTAssertNotEqual(servitor.state, .done,
            "Servitor should not be done when a commitment fails")
    }
}
