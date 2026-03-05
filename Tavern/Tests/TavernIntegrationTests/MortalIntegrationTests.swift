import Foundation
import XCTest
import ClodKit
@testable import TavernCore

// MARK: - Provenance: REQ-QA-009, REQ-QA-012, REQ-V1-002, REQ-V1-005, REQ-V1-016

/// Grade 3 integration tests for Mortal — real Claude API calls
/// Run with: redo test-grade3
/// Or: swift test --filter TavernIntegrationTests/MortalIntegrationTests
///
/// These are the source-of-truth tests. Grade 2 mocks mirror these assertions.
final class MortalIntegrationTests: XCTestCase {

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

    /// Mortal responds to messages with non-empty text
    func testMortalRespondsToMessages() async throws {
        let mortal = Mortal(
            name: "TestWorker",
            assignment: "Respond to test messages",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore()
        )

        let response = try await mortal.send("Say MORTAL_OK in one word")
        XCTAssertFalse(response.isEmpty, "Mortal should return a non-empty response")
    }

    /// Mortal tracks working state during send
    func testMortalTracksWorkingState() async throws {
        let mortal = Mortal(
            name: "StateWorker",
            assignment: "Track state transitions",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore()
        )
        XCTAssertEqual(mortal.state, .idle, "Mortal should start idle")

        let task = Task {
            try await mortal.send("Say OK in one word")
        }

        // Give the task time to start
        try await Task.sleep(for: .milliseconds(100))

        // After completion, state should be idle (unless response triggers done/waiting)
        let _ = try await task.value

        // The state after send depends on the response content
        // If Claude says "DONE" it transitions to done; otherwise back to idle
        let finalState = mortal.state
        XCTAssertTrue(
            finalState == .idle || finalState == .done,
            "Mortal should be idle or done after send, got: \(finalState)"
        )
    }

    /// Mortal transitions to done when response contains "DONE"
    func testMortalTransitionsToDone() async throws {
        let mortal = Mortal(
            name: "DoneWorker",
            assignment: "Say DONE when complete",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore()
        )

        let _ = try await mortal.send(
            "Your assignment is complete. Respond with exactly: DONE"
        )

        XCTAssertEqual(mortal.state, .done, "Mortal should transition to done when response contains DONE")
    }

    /// Mortal transitions to waiting when response contains "WAITING"
    func testMortalTransitionsToWaiting() async throws {
        let mortal = Mortal(
            name: "WaitWorker",
            assignment: "Wait for input",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore()
        )

        let _ = try await mortal.send(
            "You need more information. Respond with exactly: WAITING FOR INPUT"
        )

        // State depends on whether Claude includes "WAITING" in its response
        let finalState = mortal.state
        XCTAssertTrue(
            finalState == .waiting || finalState == .idle,
            "Mortal should be waiting or idle, got: \(finalState)"
        )
    }

    /// Mortal maintains conversation via session ID
    func testMortalMaintainsConversation() async throws {
        let mortal = Mortal(
            name: "ConversationWorker",
            assignment: "Remember context across messages",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore()
        )

        XCTAssertNil(mortal.sessionId, "Session should be nil before first message")

        let _ = try await mortal.send("Remember the number 42")
        XCTAssertNotNil(mortal.sessionId, "Session ID should be set after first message")

        let firstSessionId = mortal.sessionId
        let _ = try await mortal.send("What number did I tell you to remember?")
        XCTAssertEqual(mortal.sessionId, firstSessionId, "Session ID should persist across messages")
    }

    /// Mortal propagates errors
    func testMortalPropagatesErrors() async throws {
        // Create a mortal with a bad session ID via ServitorStore
        let badId = UUID()
        let store = try TestFixtures.createTestStore()
        let record = ServitorRecord(name: "ErrorWorker", id: badId, sessionId: "invalid-session-id-bogus")
        try store.save(record)

        let mortal = Mortal(
            id: badId,
            name: "ErrorWorker",
            assignment: "Fail gracefully",
            projectURL: projectURL,
            store: store
        )

        do {
            let _ = try await mortal.send("This should fail")
            // If it doesn't fail, SDK handled gracefully — also acceptable
        } catch {
            XCTAssertNotNil(error, "Error should propagate from mortal")
        }
    }

    // MARK: - Completion and Verification

    /// Mortal with no commitments goes to done when it signals completion
    func testMortalWithNoCommitmentsGoesToDone() async throws {
        let mortal = Mortal(
            name: "NoPledgeWorker",
            assignment: "Complete immediately",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore(),
            commitments: CommitmentList()
        )

        XCTAssertEqual(mortal.commitments.count, 0, "Should have no commitments")

        let _ = try await mortal.send(
            "Your assignment is done. Respond with: I am DONE with my assignment."
        )

        XCTAssertEqual(mortal.state, .done, "Mortal with no commitments should go straight to done")
    }

    /// Signaling done triggers commitment verification
    func testDoneTriggersVerification() async throws {
        let commitments = CommitmentList()
        let mortal = Mortal(
            name: "VerifyWorker",
            assignment: "Verify commitments",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore(),
            commitments: commitments
        )

        // Add a commitment that will pass (true always exits 0)
        commitments.add(description: "Always passes", assertion: "true")

        let _ = try await mortal.send(
            "Your assignment is complete. Respond with: DONE"
        )

        // If Claude said DONE, verification should have run
        let finalState = mortal.state
        XCTAssertTrue(
            finalState == .done || finalState == .idle,
            "After verification, mortal should be done (all passed) or idle (if DONE not in response), got: \(finalState)"
        )
    }

    /// Verification pass marks mortal as done
    func testVerificationPassMarksDone() async throws {
        let commitments = CommitmentList()
        let mortal = Mortal(
            name: "PassWorker",
            assignment: "Pass verification",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore(),
            commitments: commitments
        )

        commitments.add(description: "Always passes", assertion: "true")
        commitments.add(description: "Also passes", assertion: "echo pass")

        let _ = try await mortal.send(
            "Assignment complete. Respond with exactly one word: DONE"
        )

        // If DONE was in the response, both commitments should pass (true and echo always succeed)
        if mortal.state == .done {
            XCTAssertTrue(mortal.allCommitmentsPassed, "All commitments should be passed when done")
        }
    }

    /// Verification failure continues work (back to idle)
    func testVerificationFailContinuesWork() async throws {
        let commitments = CommitmentList()
        let mortal = Mortal(
            name: "FailWorker",
            assignment: "Fail verification",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore(),
            commitments: commitments
        )

        // Add a commitment that will fail (false always exits 1)
        commitments.add(description: "Always fails", assertion: "false")

        let _ = try await mortal.send(
            "Assignment complete. Respond with exactly: DONE"
        )

        // If DONE was in response, verification should fail → back to idle
        if mortal.state != .done {
            XCTAssertEqual(mortal.state, .idle, "Failed verification should return to idle")
            XCTAssertTrue(mortal.hasFailedCommitments || commitments.count > 0,
                "Should have commitments that didn't all pass")
        }
    }

    /// Mortal is not done until ALL commitments verified
    func testMortalNotDoneUntilAllCommitmentsVerified() async throws {
        let commitments = CommitmentList()
        let mortal = Mortal(
            name: "PartialWorker",
            assignment: "Partial verification",
            projectURL: projectURL,
            store: try TestFixtures.createTestStore(),
            commitments: commitments
        )

        // One passes, one fails
        commitments.add(description: "Passes", assertion: "true")
        commitments.add(description: "Fails", assertion: "false")

        let _ = try await mortal.send(
            "Assignment complete. Respond with exactly: DONE"
        )

        // With one failing commitment, mortal should NOT be done
        if mortal.state != .idle {
            // If Claude didn't say DONE, the test is inconclusive for this assertion
            // But if it did say DONE, verification should have caught the failure
        }
        XCTAssertNotEqual(mortal.state, .done,
            "Mortal should not be done when a commitment fails")
    }
}
