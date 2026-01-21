import Foundation
import Testing
@testable import TavernCore

@Suite("ChatViewModel Tests")
struct ChatViewModelTests {

    @Test("ViewModel initializes with empty state")
    @MainActor
    func viewModelInitializesEmpty() {
        let mock = MockClaudeCode()
        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.isCogitating == false)
        #expect(viewModel.inputText.isEmpty)
        #expect(viewModel.error == nil)
    }

    @Test("Sending message adds user and agent messages")
    @MainActor
    func sendingMessageAddsMessages() async {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Hello back!", sessionId: "session-123")

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "Hello Jake!"
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "Hello Jake!")
        #expect(viewModel.messages[1].role == .agent)
        #expect(viewModel.messages[1].content == "Hello back!")
    }

    @Test("Input text clears after sending")
    @MainActor
    func inputTextClearsAfterSend() async {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "Test message"
        await viewModel.sendMessage()

        #expect(viewModel.inputText.isEmpty)
    }

    @Test("Empty input does not send message")
    @MainActor
    func emptyInputDoesNotSend() async {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Should not see this", sessionId: "session-123")

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "   " // Whitespace only
        await viewModel.sendMessage()

        #expect(viewModel.messages.isEmpty)
        #expect(mock.sentPrompts.isEmpty)
    }

    @Test("Cogitating state changes during send")
    @MainActor
    func cogitatingStateDuringSend() async {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")
        mock.responseDelay = 0.1 // Add delay to observe state

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "Test"

        // Before sending
        #expect(viewModel.isCogitating == false)

        // Start sending in background
        let task = Task {
            await viewModel.sendMessage()
        }

        // Wait a bit for cogitating to start
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.isCogitating == true)

        // Wait for completion
        await task.value

        #expect(viewModel.isCogitating == false)
    }

    @Test("Cogitation verb is set during send")
    @MainActor
    func cogitationVerbIsSet() async {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")
        mock.responseDelay = 0.1

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "Test"

        let task = Task {
            await viewModel.sendMessage()
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        // Cogitation verb should be non-empty when cogitating
        #expect(!viewModel.cogitationVerb.isEmpty)

        await task.value
    }

    @Test("Error is captured and displayed in chat")
    @MainActor
    func errorIsCapturedAndDisplayed() async {
        let mock = MockClaudeCode()
        mock.errorToThrow = ClaudeCodeError.executionFailed("Network error")

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "Test"
        await viewModel.sendMessage()

        // Should have user message and error message
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[1].role == .agent)
        // TavernErrorMessages converts "Network error" to an informative message
        #expect(viewModel.messages[1].content.contains("Network hiccup"))
        #expect(viewModel.error != nil)
    }

    @Test("Clear conversation removes all messages")
    @MainActor
    func clearConversationRemovesMessages() async {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "Test"
        await viewModel.sendMessage()

        #expect(!viewModel.messages.isEmpty)

        viewModel.clearConversation()

        #expect(viewModel.messages.isEmpty)
        #expect(jake.sessionId == nil) // Jake's session also reset
    }

    @Test("Multiple messages accumulate in conversation")
    @MainActor
    func multipleMessagesAccumulate() async {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "First response", sessionId: "session-123")
        mock.queueJSONResponse(result: "Second response", sessionId: "session-123")

        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        viewModel.inputText = "First"
        await viewModel.sendMessage()

        viewModel.inputText = "Second"
        await viewModel.sendMessage()

        #expect(viewModel.messages.count == 4)
        #expect(viewModel.messages[0].content == "First")
        #expect(viewModel.messages[1].content == "First response")
        #expect(viewModel.messages[2].content == "Second")
        #expect(viewModel.messages[3].content == "Second response")
    }
}
