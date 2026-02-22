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

    @Test("ViewModel initializes with empty state", .tags(.reqARCH003))
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

    @Test("ChatViewModel for mortal servitor accepts projectPath parameter")
    @MainActor
    func mortalServitorViewModelAcceptsProjectPath() {
        let mortal = Mortal(
            name: "Worker",
            assignment: "Test task",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        // This should compile and work - the bug was that this parameter didn't exist
        let viewModel = ChatViewModel(servitor: mortal, projectPath: "/test/path", loadHistory: false)

        #expect(viewModel.servitorId == mortal.id)
        #expect(viewModel.servitorName == "Worker")
    }

    @Test("ChatViewModel for mortal servitor without assignment works")
    @MainActor
    func mortalServitorViewModelWithoutAssignment() {
        let mortal = Mortal(
            name: "User-Spawned",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )

        let viewModel = ChatViewModel(servitor: mortal, projectPath: "/test/path", loadHistory: false)

        #expect(viewModel.servitorId == mortal.id)
        #expect(viewModel.servitorName == "User-Spawned")
    }

    @Test("Both initializers have loadHistory parameter - symmetry check")
    @MainActor
    func initializerSymmetry() {
        let projectURL = Self.testProjectURL()

        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let mortal = Mortal(name: "Worker", projectURL: projectURL, loadSavedSession: false)

        // Jake initializer with loadHistory
        let jakeVM = ChatViewModel(jake: jake, loadHistory: false)

        // Mortal servitor initializer with loadHistory (this was the bug - parameter didn't exist)
        let mortalVM = ChatViewModel(servitor: mortal, projectPath: "/test", loadHistory: false)

        #expect(jakeVM.messages.isEmpty)
        #expect(mortalVM.messages.isEmpty)
    }

    @Test("Servitor ID and name are accessible")
    @MainActor
    func servitorIdAndNameAccessible() {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let viewModel = ChatViewModel(jake: jake, loadHistory: false)

        #expect(viewModel.servitorId == jake.id)
        #expect(viewModel.servitorName == "Jake")
    }

    @Test("isLoadingHistory is false when no project path")
    @MainActor
    func isLoadingHistoryFalseWithNoProject() async {
        let mock = MockServitor()
        let viewModel = ChatViewModel(servitor: mock, projectPath: nil, loadHistory: false)

        await viewModel.loadSessionHistory()

        #expect(viewModel.isLoadingHistory == false)
    }

    @Test("isLoadingHistory is false after loading completes with no matching session")
    @MainActor
    func isLoadingHistoryFalseAfterLoad() async {
        let mock = MockServitor()
        // Use a path that won't have any matching sessions
        let viewModel = ChatViewModel(servitor: mock, projectPath: "/nonexistent/project", loadHistory: false)

        await viewModel.loadSessionHistory()

        // After loading completes (even with no results), isLoadingHistory should be false
        #expect(viewModel.isLoadingHistory == false)
        #expect(viewModel.messages.isEmpty)
    }

    // MARK: - Grade 2 Mock Tests (using MockServitor)

    @Test("Sending message adds user and servitor messages", .tags(.reqAGT010))
    @MainActor
    func sendingMessageAddsMessages() async {
        let mock = MockServitor(responses: ["Hello from mock!"])
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

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
        let mock = MockServitor(responses: ["OK"])
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

        viewModel.inputText = "Test message"
        await viewModel.sendMessage()

        #expect(viewModel.inputText.isEmpty)
    }

    @Test("Cogitating state during send")
    @MainActor
    func cogitatingStateDuringSend() async {
        let mock = MockServitor(responses: ["OK"])
        mock.responseDelay = .milliseconds(50)
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

        #expect(viewModel.isCogitating == false)

        viewModel.inputText = "Test"
        await viewModel.sendMessage()

        // After send completes, cogitating should be false
        #expect(viewModel.isCogitating == false)
    }

    @Test("Cogitation verb is set during send")
    @MainActor
    func cogitationVerbIsSet() async {
        let mock = MockServitor(responses: ["OK"])
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

        viewModel.inputText = "Test"
        await viewModel.sendMessage()

        // Verb is set during send and not cleared after
        #expect(!viewModel.cogitationVerb.isEmpty)
    }

    @Test("Error is captured and displayed")
    @MainActor
    func errorIsCapturedAndDisplayed() async {
        let mock = MockServitor()
        mock.errorToThrow = TavernError.internalError("Mock error for testing")
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

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
        let mock = MockServitor(responses: ["First response", "Second response"])
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

        viewModel.inputText = "Message 1"
        await viewModel.sendMessage()
        #expect(viewModel.messages.count == 2) // user + agent

        viewModel.inputText = "Message 2"
        await viewModel.sendMessage()
        #expect(viewModel.messages.count == 4) // 2 user + 2 agent
    }

    @Test("Mortal servitor can send messages via ChatViewModel")
    @MainActor
    func mortalServitorCanSendMessages() async {
        let mock = MockServitor(name: "MortalMock", responses: ["Mortal response"])
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

        viewModel.inputText = "Hello mortal"
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.servitorName == "MortalMock")
        #expect(viewModel.messages[1].content == "Mortal response")
    }

    // MARK: - Session Mode Tests

    @Test("ChatViewModel inherits servitor's session mode", .tags(.reqOPM001, .reqOPM002))
    @MainActor
    func chatViewModelInheritsServitorSessionMode() {
        let mock = MockServitor(name: "ModeServitor")
        #expect(mock.sessionMode == .plan) // default
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)
        #expect(viewModel.sessionMode == .plan)
    }

    @Test("ChatViewModel mode change propagates to servitor", .tags(.reqOPM001, .reqOPM002))
    @MainActor
    func chatViewModelModeChangePropagates() {
        let mock = MockServitor(name: "ModeServitor")
        let viewModel = ChatViewModel(servitor: mock, loadHistory: false)

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
