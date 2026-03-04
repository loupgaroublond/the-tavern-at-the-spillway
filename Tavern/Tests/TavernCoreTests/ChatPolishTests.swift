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

    @Test("SessionUsage includes cache and cost fields")
    func sessionUsageCacheAndCost() {
        let usage = SessionUsage(
            inputTokens: 100, outputTokens: 50,
            cacheReadInputTokens: 80, cacheCreationInputTokens: 20,
            costUsd: 0.005
        )
        #expect(usage.cacheReadInputTokens == 80)
        #expect(usage.cacheCreationInputTokens == 20)
        #expect(usage.costUsd == 0.005)
    }

    // MARK: - StreamEvent Tool Events

    @Test("StreamEvent toolUseStarted carries tool info")
    func streamEventToolUseStarted() {
        let info = ToolUseInfo(toolUseId: "tu-1", toolName: "Read")
        let event = StreamEvent.toolUseStarted(info)
        if case .toolUseStarted(let received) = event {
            #expect(received.toolName == "Read")
            #expect(received.toolUseId == "tu-1")
        } else {
            Issue.record("Expected toolUseStarted")
        }
    }

    @Test("StreamEvent toolResult carries result info")
    func streamEventToolResult() {
        let info = ToolResultInfo(toolUseId: "tu-1", content: "file.txt", isError: false)
        let event = StreamEvent.toolResult(info)
        if case .toolResult(let received) = event {
            #expect(received.content == "file.txt")
            #expect(received.isError == false)
        } else {
            Issue.record("Expected toolResult")
        }
    }

    @Test("StreamEvent tool events are equatable")
    func streamEventToolEventsEquatable() {
        let info1 = ToolUseInfo(toolUseId: "tu-1", toolName: "Read")
        let info2 = ToolUseInfo(toolUseId: "tu-1", toolName: "Read")
        let info3 = ToolUseInfo(toolUseId: "tu-2", toolName: "Write")
        #expect(StreamEvent.toolUseStarted(info1) == StreamEvent.toolUseStarted(info2))
        #expect(StreamEvent.toolUseStarted(info1) != StreamEvent.toolUseStarted(info3))
    }

    @Test("StreamEvent thinkingDelta carries thinking text")
    func streamEventThinkingDelta() {
        let event = StreamEvent.thinkingDelta("Let me think...")
        if case .thinkingDelta(let text) = event {
            #expect(text == "Let me think...")
        } else {
            Issue.record("Expected thinkingDelta")
        }
    }

    @Test("StreamEvent blockFinished carries index")
    func streamEventBlockFinished() {
        let event = StreamEvent.blockFinished(index: 2)
        if case .blockFinished(let idx) = event {
            #expect(idx == 2)
        } else {
            Issue.record("Expected blockFinished")
        }
    }

    @Test("StreamEvent promptSuggestion carries text")
    func streamEventPromptSuggestion() {
        let event = StreamEvent.promptSuggestion("Tell me more")
        if case .promptSuggestion(let text) = event {
            #expect(text == "Tell me more")
        } else {
            Issue.record("Expected promptSuggestion")
        }
    }

    @Test("StreamEvent systemStatus carries status")
    func streamEventSystemStatus() {
        let event = StreamEvent.systemStatus("compacting")
        if case .systemStatus(let status) = event {
            #expect(status == "compacting")
        } else {
            Issue.record("Expected systemStatus")
        }
    }

    // MARK: - CompletionInfo Tests

    @Test("CompletionInfo carries all fields")
    func completionInfoFields() {
        let usage = SessionUsage(inputTokens: 100, outputTokens: 50)
        let info = CompletionInfo(
            sessionId: "sess-1", usage: usage,
            costUsd: 0.01, totalCostUsd: 0.05,
            durationMs: 3000, stopReason: "end_turn", numTurns: 2
        )
        #expect(info.sessionId == "sess-1")
        #expect(info.usage?.totalTokens == 150)
        #expect(info.costUsd == 0.01)
        #expect(info.totalCostUsd == 0.05)
        #expect(info.durationMs == 3000)
        #expect(info.stopReason == "end_turn")
        #expect(info.numTurns == 2)
    }

    // MARK: - RateLimitInfo Tests

    @Test("RateLimitInfo carries status and utilization")
    func rateLimitInfoFields() {
        let info = RateLimitInfo(status: "warning", utilization: 0.85)
        #expect(info.status == "warning")
        #expect(info.utilization == 0.85)
        #expect(info.resetsAt == nil)
    }

    // MARK: - ServitorState Error Case

    @Test("ServitorState error case exists and has correct raw value")
    func agentStateErrorCase() {
        let state = ServitorState.error
        #expect(state.rawValue == "error")
        #expect(ServitorState(rawValue: "error") == .error)
    }

}
