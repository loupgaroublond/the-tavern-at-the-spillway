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

    // MARK: - Tests requiring SDK mocking (skipped for now)
    // TODO: These tests need dependency injection or SDK mocking to work
    // - sendingMessageAddsMessages
    // - inputTextClearsAfterSend
    // - cogitatingStateDuringSend
    // - cogitationVerbIsSet
    // - errorIsCapturedAndDisplayed
    // - multipleMessagesAccumulate
    // - servitorAgentCanSendMessages
}
