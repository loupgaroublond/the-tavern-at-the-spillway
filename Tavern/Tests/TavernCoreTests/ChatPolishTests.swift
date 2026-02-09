import Foundation
import Testing
@testable import TavernCore

@Suite("Chat Polish Tests")
struct ChatPolishTests {

    // MARK: - SessionUsage Tests

    @Test("SessionUsage tracks input and output tokens")
    func sessionUsageTracksTokens() {
        let usage = SessionUsage(inputTokens: 100, outputTokens: 50)
        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
        #expect(usage.totalTokens == 150)
    }

    @Test("SessionUsage zero tokens")
    func sessionUsageZeroTokens() {
        let usage = SessionUsage(inputTokens: 0, outputTokens: 0)
        #expect(usage.totalTokens == 0)
    }

    @Test("SessionUsage equatable")
    func sessionUsageEquatable() {
        let a = SessionUsage(inputTokens: 100, outputTokens: 50)
        let b = SessionUsage(inputTokens: 100, outputTokens: 50)
        let c = SessionUsage(inputTokens: 200, outputTokens: 50)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - StreamEvent Tool Events

    @Test("StreamEvent toolUseStarted carries tool name")
    func streamEventToolUseStarted() {
        let event = StreamEvent.toolUseStarted("Read")
        if case .toolUseStarted(let name) = event {
            #expect(name == "Read")
        } else {
            Issue.record("Expected toolUseStarted")
        }
    }

    @Test("StreamEvent toolUseFinished carries tool name")
    func streamEventToolUseFinished() {
        let event = StreamEvent.toolUseFinished("Write")
        if case .toolUseFinished(let name) = event {
            #expect(name == "Write")
        } else {
            Issue.record("Expected toolUseFinished")
        }
    }

    @Test("StreamEvent tool events are equatable")
    func streamEventToolEventsEquatable() {
        #expect(StreamEvent.toolUseStarted("Read") == StreamEvent.toolUseStarted("Read"))
        #expect(StreamEvent.toolUseStarted("Read") != StreamEvent.toolUseStarted("Write"))
        #expect(StreamEvent.toolUseFinished("X") == StreamEvent.toolUseFinished("X"))
    }

    // MARK: - AgentState Error Case

    @Test("AgentState error case exists and has correct raw value")
    func agentStateErrorCase() {
        let state = AgentState.error
        #expect(state.rawValue == "error")
        #expect(AgentState(rawValue: "error") == .error)
    }

    // MARK: - ChatViewModel Token Tracking

    @Test("ChatViewModel starts with zero tokens")
    @MainActor
    func viewModelStartsWithZeroTokens() {
        let mock = MockAgent()
        let vm = ChatViewModel(agent: mock, loadHistory: false)
        #expect(vm.totalInputTokens == 0)
        #expect(vm.totalOutputTokens == 0)
        #expect(vm.hasUsageData == false)
    }

    @Test("ChatViewModel formattedTokens shows correct format")
    @MainActor
    func viewModelFormattedTokens() {
        let mock = MockAgent()
        let vm = ChatViewModel(agent: mock, loadHistory: false)
        // Zero state
        #expect(vm.formattedTokens == "0 in / 0 out")
    }

    @Test("ChatViewModel clearConversation resets tokens")
    @MainActor
    func viewModelClearResetsTokens() {
        let mock = MockAgent(responses: ["Hi"])
        let vm = ChatViewModel(agent: mock, loadHistory: false)
        vm.clearConversation()
        #expect(vm.totalInputTokens == 0)
        #expect(vm.totalOutputTokens == 0)
    }

    // MARK: - ChatViewModel Tool Tracking

    @Test("ChatViewModel starts with no tool active")
    @MainActor
    func viewModelStartsNoTool() {
        let mock = MockAgent()
        let vm = ChatViewModel(agent: mock, loadHistory: false)
        #expect(vm.currentToolName == nil)
        #expect(vm.toolStartTime == nil)
    }

    @Test("ChatViewModel tool state is nil after streaming completes")
    @MainActor
    func viewModelToolStateNilAfterComplete() async {
        let mock = MockAgent(responses: ["Done"])
        let vm = ChatViewModel(agent: mock, loadHistory: false)

        vm.inputText = "Test"
        await vm.sendMessage()

        #expect(vm.currentToolName == nil)
        #expect(vm.toolStartTime == nil)
    }

    @Test("ChatViewModel cancelStreaming clears tool state")
    @MainActor
    func viewModelCancelClearsToolState() {
        let mock = MockAgent(responses: ["x"])
        let vm = ChatViewModel(agent: mock, loadHistory: false)

        // cancelStreaming should not crash when not streaming
        vm.cancelStreaming()
        #expect(vm.currentToolName == nil)
        #expect(vm.toolStartTime == nil)
    }

    // MARK: - ChatViewModel Scroll State

    @Test("ChatViewModel starts with showScrollToBottom false")
    @MainActor
    func viewModelStartsScrollToBottomFalse() {
        let mock = MockAgent()
        let vm = ChatViewModel(agent: mock, loadHistory: false)
        #expect(vm.showScrollToBottom == false)
    }

    @Test("ChatViewModel showScrollToBottom is settable")
    @MainActor
    func viewModelScrollToBottomSettable() {
        let mock = MockAgent()
        let vm = ChatViewModel(agent: mock, loadHistory: false)
        vm.showScrollToBottom = true
        #expect(vm.showScrollToBottom == true)
        vm.showScrollToBottom = false
        #expect(vm.showScrollToBottom == false)
    }
}
