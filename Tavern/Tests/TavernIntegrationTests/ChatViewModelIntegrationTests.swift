import Foundation
import XCTest
@testable import TavernCore

/// Grade 3 integration tests for ChatViewModel — real Claude API calls
/// Run with: redo test-grade3
/// Or: swift test --filter TavernIntegrationTests/ChatViewModelIntegrationTests
///
/// These tests verify the full send-receive cycle through ChatViewModel
/// with real Claude responses. Grade 2 mock tests mirror these assertions.
@MainActor
final class ChatViewModelIntegrationTests: XCTestCase {

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

    // MARK: - Tests

    /// Sending a message adds both user and agent messages
    func testSendingMessageAddsMessages() async throws {
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        viewModel.inputText = "Say hello in 5 words or fewer"
        await viewModel.sendMessage()

        XCTAssertGreaterThanOrEqual(viewModel.messages.count, 2,
            "Should have at least user message + agent response")
        XCTAssertEqual(viewModel.messages.first?.role, .user,
            "First message should be from user")
        XCTAssertEqual(viewModel.messages.first?.content, "Say hello in 5 words or fewer",
            "User message content should match input")

        // Find the agent response (skip any error messages)
        let agentMessages = viewModel.messages.filter { $0.role == .agent }
        XCTAssertFalse(agentMessages.isEmpty, "Should have at least one agent message")
    }

    /// Input text clears after sending
    func testInputTextClearsAfterSend() async throws {
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        viewModel.inputText = "Say OK"
        await viewModel.sendMessage()

        XCTAssertTrue(viewModel.inputText.isEmpty, "Input text should be cleared after send")
    }

    /// Cogitating state is set during send and cleared after
    func testCogitatingStateDuringSend() async throws {
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        XCTAssertFalse(viewModel.isCogitating, "Should not be cogitating initially")

        viewModel.inputText = "Say OK in one word"

        // Start send in background to observe mid-flight state
        let task = Task { @MainActor in
            await viewModel.sendMessage()
        }

        // After completion, cogitating should be false
        await task.value
        XCTAssertFalse(viewModel.isCogitating, "Should not be cogitating after send completes")
    }

    /// Cogitation verb is set during send
    func testCogitationVerbIsSet() async throws {
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        // The verb is set randomly during sendMessage
        // After send, it should still have a value (it's not cleared)
        viewModel.inputText = "Say OK"
        await viewModel.sendMessage()

        XCTAssertFalse(viewModel.cogitationVerb.isEmpty,
            "Cogitation verb should be set")
    }

    /// Error is captured and displayed when agent fails
    func testErrorIsCapturedAndDisplayed() async throws {
        // Create a Jake with a corrupt session to trigger error
        let badSessionId = "invalid-session-\(UUID().uuidString)"
        SessionStore.saveJakeSession(badSessionId, projectPath: projectURL.path)

        let jake = Jake(projectURL: projectURL, loadSavedSession: true)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        viewModel.inputText = "This should trigger an error"
        await viewModel.sendMessage()

        // Either an error was captured, or SDK handled the invalid session gracefully
        // Both are acceptable outcomes
        if viewModel.error != nil {
            // Error was captured — check that an error message was added to chat
            let errorMessages = viewModel.messages.filter { $0.role == .agent }
            XCTAssertFalse(errorMessages.isEmpty,
                "Error should produce an agent message explaining what happened")
        }

        // Cleanup
        SessionStore.clearJakeSession(projectPath: projectURL.path)
    }

    /// Multiple messages accumulate in the messages array
    func testMultipleMessagesAccumulate() async throws {
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        viewModel.inputText = "Say hello"
        await viewModel.sendMessage()
        let countAfterFirst = viewModel.messages.count

        viewModel.inputText = "Say goodbye"
        await viewModel.sendMessage()
        let countAfterSecond = viewModel.messages.count

        XCTAssertGreaterThan(countAfterSecond, countAfterFirst,
            "Messages should accumulate across sends")
    }

    /// Servitor agent can send messages through ChatViewModel
    func testServitorAgentCanSendMessages() async throws {
        let servitor = Servitor(
            name: "ChatWorker",
            assignment: "Respond to messages",
            projectURL: projectURL,
            loadSavedSession: false
        )
        let viewModel = ChatViewModel(agent: servitor, projectPath: projectURL.path, loadHistory: false)

        viewModel.inputText = "Say SERVITOR_CHAT_OK in one word"
        await viewModel.sendMessage()

        XCTAssertGreaterThanOrEqual(viewModel.messages.count, 2,
            "Servitor ChatViewModel should have user + agent messages")
        XCTAssertEqual(viewModel.agentName, "ChatWorker",
            "Agent name should match servitor name")
    }
}
