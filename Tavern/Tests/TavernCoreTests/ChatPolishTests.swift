import Foundation
import Testing
@testable import TavernCore

@Suite("Chat Polish Tests", .timeLimit(.minutes(1)))
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

    // MARK: - ServitorState Error Case

    @Test("ServitorState error case exists and has correct raw value")
    func agentStateErrorCase() {
        let state = ServitorState.error
        #expect(state.rawValue == "error")
        #expect(ServitorState(rawValue: "error") == .error)
    }

}
