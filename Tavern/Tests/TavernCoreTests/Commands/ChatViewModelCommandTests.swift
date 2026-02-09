import Foundation
import Testing
@testable import TavernCore

@Suite("ChatViewModel Slash Command Integration Tests")
struct ChatViewModelCommandTests {

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("Slash command is intercepted and not sent to agent")
    @MainActor
    func slashCommandIntercepted() async {
        let mock = MockAgent(name: "TestAgent", responses: ["should not appear"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "test", result: .message("command output")))
        viewModel.commandDispatcher = dispatcher

        viewModel.inputText = "/test"
        await viewModel.sendMessage()

        // Agent should NOT have been called
        #expect(mock.sendCalls.isEmpty)

        // Should have user message + command response
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "/test")
        #expect(viewModel.messages[1].role == .agent)
        #expect(viewModel.messages[1].content == "command output")
    }

    @Test("Slash command error shows in chat")
    @MainActor
    func slashCommandErrorShowsInChat() async {
        let mock = MockAgent(name: "TestAgent")
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "fail", result: .error("something broke")))
        viewModel.commandDispatcher = dispatcher

        viewModel.inputText = "/fail"
        await viewModel.sendMessage()

        #expect(mock.sendCalls.isEmpty)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[1].content == "something broke")
    }

    @Test("Silent command produces no response message")
    @MainActor
    func silentCommandNoResponse() async {
        let mock = MockAgent(name: "TestAgent")
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "quiet", result: .silent))
        viewModel.commandDispatcher = dispatcher

        viewModel.inputText = "/quiet"
        await viewModel.sendMessage()

        #expect(mock.sendCalls.isEmpty)
        // Only user message, no response
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].role == .user)
    }

    @Test("Unknown slash command shows error with available commands")
    @MainActor
    func unknownSlashCommandShowsError() async {
        let mock = MockAgent(name: "TestAgent")
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "known"))
        viewModel.commandDispatcher = dispatcher

        viewModel.inputText = "/nope"
        await viewModel.sendMessage()

        #expect(mock.sendCalls.isEmpty)
        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[1].content.contains("Unknown command"))
        #expect(viewModel.messages[1].content.contains("/known"))
    }

    @Test("Regular text passes through to agent when dispatcher is set")
    @MainActor
    func regularTextPassesThrough() async {
        let mock = MockAgent(name: "TestAgent", responses: ["agent response"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        let dispatcher = SlashCommandDispatcher()
        viewModel.commandDispatcher = dispatcher

        viewModel.inputText = "hello world"
        await viewModel.sendMessage()

        // Agent SHOULD have been called
        #expect(mock.sendCalls == ["hello world"])
        #expect(viewModel.messages.count == 2)
    }

    @Test("Slash command without dispatcher passes through to agent")
    @MainActor
    func slashCommandWithoutDispatcherPassesThrough() async {
        let mock = MockAgent(name: "TestAgent", responses: ["agent response"])
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)
        // No dispatcher set

        viewModel.inputText = "/compact"
        await viewModel.sendMessage()

        // Without dispatcher, /compact goes to agent as regular text
        #expect(mock.sendCalls == ["/compact"])
    }

    @Test("Slash command clears input text")
    @MainActor
    func slashCommandClearsInput() async {
        let mock = MockAgent(name: "TestAgent")
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "test", result: .message("ok")))
        viewModel.commandDispatcher = dispatcher

        viewModel.inputText = "/test"
        await viewModel.sendMessage()

        #expect(viewModel.inputText.isEmpty)
    }

    @Test("Slash command does not set cogitating state")
    @MainActor
    func slashCommandDoesNotCogitate() async {
        let mock = MockAgent(name: "TestAgent")
        let viewModel = ChatViewModel(agent: mock, loadHistory: false)

        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "test", result: .message("ok")))
        viewModel.commandDispatcher = dispatcher

        viewModel.inputText = "/test"
        await viewModel.sendMessage()

        #expect(viewModel.isCogitating == false)
    }
}
