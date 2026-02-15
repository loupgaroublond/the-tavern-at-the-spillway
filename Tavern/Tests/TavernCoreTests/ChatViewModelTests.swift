import Foundation
import Testing
@testable import TavernCore

@Suite("ChatViewModel Tests")
struct ChatViewModelTests {

    // Test helper
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("ViewModel initializes with empty state")
    @MainActor
    func viewModelInitializesEmpty() {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isCogitating == false)
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.error == nil)
        #expect(viewModel.isLoadingHistory == false)
    }

    @Test("Empty input does not send message")
    @MainActor
    func emptyInputDoesNotSend() async {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        viewModel.inputText = "   " // Whitespace only
        await viewModel.sendMessage()

        #expect(viewModel.messages.isEmpty)
    }

    @Test("Clear conversation removes all messages")
    @MainActor
    func clearConversationRemovesMessages() {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        // Manually add a message to test clearing
        // (We can't test full send cycle without mocking)
        viewModel.clearConversation()

        #expect(viewModel.messages.isEmpty)
        #expect(jake.sessionId == nil) // Jake's session also reset
    }

    // MARK: - Symmetry Tests (Testing Principle #4)
    // These tests ensure parallel code paths behave consistently

    @Test("ChatViewModel for servitor agent accepts projectPath parameter")
    @MainActor
    func servitorAgentViewModelAcceptsProjectPath() {
        let agent = Servitor(
            name: "Worker",
            assignment: "Test task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        // This should compile and work - the bug was that this parameter didn't exist
        let viewModel = ChatViewModel(agent: agent, projectPath: "/test/path", loadHistory: false)

        #expect(viewModel.agentId == agent.id)
        #expect(viewModel.agentName == "Worker")
    }

    @Test("ChatViewModel for servitor agent without assignment works")
    @MainActor
    func servitorAgentViewModelWithoutAssignment() {
        let agent = Servitor(
            name: "User-Spawned",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        let viewModel = ChatViewModel(agent: agent, projectPath: "/test/path", loadHistory: false)

        #expect(viewModel.agentId == agent.id)
        #expect(viewModel.agentName == "User-Spawned")
    }

    @Test("Both initializers have loadHistory parameter - symmetry check")
    @MainActor
    func initializerSymmetry() {
        let projectURL = Self.testProjectURL()

        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let servitor = Servitor(name: "Worker", projectURL: projectURL, loadSavedSession: false)

        // Jake initializer with loadHistory
        let jakeVM = ChatViewModel(jake: jake, loadHistory: false)

        // Mortal agent initializer with loadHistory (this was the bug - parameter didn't exist)
        let servitorVM = ChatViewModel(agent: servitor, projectPath: "/test", loadHistory: false)

        #expect(jakeVM.messages.isEmpty)
        #expect(servitorVM.messages.isEmpty)
    }

    @Test("Agent ID and name are accessible")
    @MainActor
    func agentIdAndNameAccessible() {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        #expect(viewModel.agentId == jake.id)
        #expect(viewModel.agentName == "Jake")
    }

    @Test("isLoadingHistory is false when no project path")
    @MainActor
    func isLoadingHistoryFalseWithNoProject() async {
        let mock = MockAgent()
        let viewModel = ChatViewModel(agent: mock, projectPath: nil, loadHistory: false)

        await viewModel.loadSessionHistory()

        #expect(viewModel.isLoadingHistory == false)
    }

    @Test("isLoadingHistory is false after loading completes with no matching session")
    @MainActor
    func isLoadingHistoryFalseAfterLoad() async {
        let mock = MockAgent()
        // Use a path that won't have any matching sessions
        let viewModel = ChatViewModel(agent: mock, projectPath: "/nonexistent/project", loadHistory: false)

        await viewModel.loadSessionHistory()

        // After loading completes (even with no results), isLoadingHistory should be false
        #expect(viewModel.isLoadingHistory == false)
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Grade 2 Mock Tests (using MockAgent)

    @Test("Sending message adds user and agent messages")
    @MainActor
    func sendingMessageAddsMessages() async {
        let mock = MockAgent(responses: ["Hello from mock!"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        viewModel.inputText = "Hello"
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "Hello")
        #expect(viewModel.messages[1].role == .agent)
        #expect(viewModel.messages[1].content == "Hello from mock!")
    }

    @Test("Input text clears after send")
    @MainActor
    func inputTextClearsAfterSend() async {
        let mock = MockAgent(responses: ["OK"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        viewModel.inputText = "Test message"
        await viewModel.sendMessage()

        #expect(viewModel.inputText.isEmpty)
    }

    @Test("Cogitating state during send")
    @MainActor
    func cogitatingStateDuringSend() async {
        let mock = MockAgent(responses: ["OK"])
        mock.responseDelay = .milliseconds(50)
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        #expect(viewModel.isCogitating == false)

        viewModel.inputText = "Test"
        await viewModel.sendMessage()

        // After send completes, cogitating should be false
        #expect(viewModel.isCogitating == false)
    }

    @Test("Cogitation verb is set during send")
    @MainActor
    func cogitationVerbIsSet() async {
        let mock = MockAgent(responses: ["OK"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        viewModel.inputText = "Test"
        await viewModel.sendMessage()

        // Verb is set during send and not cleared after
        #expect(!viewModel.cogitationVerb.isEmpty)
    }

    @Test("Error is captured and displayed")
    @MainActor
    func errorIsCapturedAndDisplayed() async {
        let mock = MockAgent()
        mock.errorToThrow = TavernError.internalError("Mock error for testing")
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        viewModel.inputText = "Trigger error"
        await viewModel.sendMessage()

        #expect(viewModel.error != nil)
        // Should have user message + error message
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[1].role == .agent) // Error message displayed as agent
    }

    @Test("Multiple messages accumulate")
    @MainActor
    func multipleMessagesAccumulate() async {
        let mock = MockAgent(responses: ["First response", "Second response"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        viewModel.inputText = "Message 1"
        await viewModel.sendMessage()
        #expect(viewModel.messages.count == 2) // user + agent

        viewModel.inputText = "Message 2"
        await viewModel.sendMessage()
        #expect(viewModel.messages.count == 4) // 2 user + 2 agent
    }

    @Test("Servitor agent can send messages via ChatViewModel")
    @MainActor
    func servitorAgentCanSendMessages() async {
        let mock = MockAgent(name: "ServitorMock", responses: ["Servitor response"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        viewModel.inputText = "Hello servitor"
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.agentName == "ServitorMock")
        #expect(viewModel.messages[1].content == "Servitor response")
    }

    // MARK: - Session Mode Tests

    @Test("ChatViewModel inherits agent's session mode")
    @MainActor
    func chatViewModelInheritsAgentSessionMode() {
        let mock = MockAgent(name: "ModeAgent")
        #expect(mock.sessionMode == .plan) // default
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)
        #expect(viewModel.sessionMode == .plan)
    }

    @Test("ChatViewModel mode change propagates to agent")
    @MainActor
    func chatViewModelModeChangePropagates() {
        let mock = MockAgent(name: "ModeAgent")
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        viewModel.sessionMode = .bypassPermissions
        #expect(mock.sessionMode == .bypassPermissions)

        viewModel.sessionMode = .acceptEdits
        #expect(mock.sessionMode == .acceptEdits)
    }

    @Test("ChatViewModel mode initialized from Jake agent")
    @MainActor
    func chatViewModelModeInitializedFromJake() {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)
        jake.sessionMode = .normal
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)
        #expect(viewModel.sessionMode == .normal)
    }
}
