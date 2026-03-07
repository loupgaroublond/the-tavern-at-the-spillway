import Foundation
import Testing
import ClodKit
@testable import TavernCore

// MARK: - Provenance: REQ-DET-002

@Suite("Streaming Pipeline Tests", .tags(.reqDET002), .timeLimit(.minutes(2)))
struct StreamingPipelineTests {

    // MARK: - CompletionInfo Edge Cases

    @Test("CompletionInfo with all nil fields")
    func completionInfoAllNil() {
        let info = CompletionInfo()
        #expect(info.sessionId == nil)
        #expect(info.usage == nil)
        #expect(info.costUsd == nil)
        #expect(info.totalCostUsd == nil)
        #expect(info.durationMs == nil)
        #expect(info.stopReason == nil)
        #expect(info.numTurns == nil)
    }

    @Test("CompletionInfo with all fields populated")
    func completionInfoFullyPopulated() {
        let usage = SessionUsage(
            inputTokens: 500,
            outputTokens: 200,
            cacheReadInputTokens: 100,
            cacheCreationInputTokens: 50,
            costUsd: 0.0035
        )
        let info = CompletionInfo(
            sessionId: "sess-full",
            usage: usage,
            costUsd: 0.0035,
            totalCostUsd: 0.015,
            durationMs: 1200,
            stopReason: "end_turn",
            numTurns: 3
        )

        #expect(info.sessionId == "sess-full")
        #expect(info.usage?.inputTokens == 500)
        #expect(info.usage?.outputTokens == 200)
        #expect(info.costUsd == 0.0035)
        #expect(info.totalCostUsd == 0.015)
        #expect(info.durationMs == 1200)
        #expect(info.stopReason == "end_turn")
        #expect(info.numTurns == 3)
    }

    @Test("CompletionInfo with zero-cost usage")
    func completionInfoZeroCost() {
        let usage = SessionUsage(inputTokens: 0, outputTokens: 0, costUsd: 0)
        let info = CompletionInfo(sessionId: "sess-zero", usage: usage, costUsd: 0)

        #expect(info.usage?.inputTokens == 0)
        #expect(info.usage?.outputTokens == 0)
        #expect(info.usage?.totalTokens == 0)
        #expect(info.usage?.costUsd == 0)
        #expect(info.costUsd == 0)
    }

    @Test("CompletionInfo equatable distinguishes different session IDs")
    func completionInfoEquatableSessionId() {
        let a = CompletionInfo(sessionId: "sess-a")
        let b = CompletionInfo(sessionId: "sess-b")
        let a2 = CompletionInfo(sessionId: "sess-a")

        #expect(a != b)
        #expect(a == a2)
    }

    @Test("CompletionInfo equatable with usage differences")
    func completionInfoEquatableUsage() {
        let u1 = SessionUsage(inputTokens: 10, outputTokens: 5)
        let u2 = SessionUsage(inputTokens: 10, outputTokens: 6)

        let a = CompletionInfo(usage: u1)
        let b = CompletionInfo(usage: u2)
        let a2 = CompletionInfo(usage: u1)

        #expect(a != b)
        #expect(a == a2)
    }

    // MARK: - SessionUsage Tests

    @Test("SessionUsage totalTokens is sum of input and output")
    func sessionUsageTotalTokens() {
        let usage = SessionUsage(inputTokens: 300, outputTokens: 150)
        #expect(usage.totalTokens == 450)
    }

    @Test("SessionUsage zero values")
    func sessionUsageZeroValues() {
        let usage = SessionUsage(inputTokens: 0, outputTokens: 0)
        #expect(usage.totalTokens == 0)
        #expect(usage.cacheReadInputTokens == 0)
        #expect(usage.cacheCreationInputTokens == 0)
        #expect(usage.costUsd == 0)
    }

    @Test("SessionUsage with cache tokens")
    func sessionUsageWithCacheTokens() {
        let usage = SessionUsage(
            inputTokens: 1000,
            outputTokens: 500,
            cacheReadInputTokens: 800,
            cacheCreationInputTokens: 200,
            costUsd: 0.01
        )

        #expect(usage.inputTokens == 1000)
        #expect(usage.outputTokens == 500)
        #expect(usage.cacheReadInputTokens == 800)
        #expect(usage.cacheCreationInputTokens == 200)
        #expect(usage.totalTokens == 1500)
        #expect(usage.costUsd == 0.01)
    }

    @Test("SessionUsage large token counts")
    func sessionUsageLargeTokenCounts() {
        let usage = SessionUsage(inputTokens: 1_000_000, outputTokens: 500_000)
        #expect(usage.totalTokens == 1_500_000)
    }

    @Test("SessionUsage equatable")
    func sessionUsageEquatable() {
        let a = SessionUsage(inputTokens: 10, outputTokens: 5, costUsd: 0.001)
        let b = SessionUsage(inputTokens: 10, outputTokens: 5, costUsd: 0.001)
        let c = SessionUsage(inputTokens: 10, outputTokens: 5, costUsd: 0.002)

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - StreamEvent Variant Coverage

    @Test("StreamEvent textDelta carries content")
    func textDelta() {
        let event = StreamEvent.textDelta("chunk")
        if case .textDelta(let text) = event {
            #expect(text == "chunk")
        } else {
            Issue.record("Expected textDelta")
        }
    }

    @Test("StreamEvent thinkingDelta carries content")
    func thinkingDelta() {
        let event = StreamEvent.thinkingDelta("reasoning about problem")
        if case .thinkingDelta(let text) = event {
            #expect(text == "reasoning about problem")
        } else {
            Issue.record("Expected thinkingDelta")
        }
    }

    @Test("StreamEvent toolUseStarted carries info")
    func toolUseStarted() {
        let info = ToolUseInfo(toolUseId: "tu-1", toolName: "Bash")
        let event = StreamEvent.toolUseStarted(info)
        if case .toolUseStarted(let i) = event {
            #expect(i.toolUseId == "tu-1")
            #expect(i.toolName == "Bash")
        } else {
            Issue.record("Expected toolUseStarted")
        }
    }

    @Test("StreamEvent toolInputDelta carries fragment")
    func toolInputDelta() {
        let event = StreamEvent.toolInputDelta(toolUseId: "tu-2", json: "{\"cmd\":")
        if case .toolInputDelta(let id, let json) = event {
            #expect(id == "tu-2")
            #expect(json == "{\"cmd\":")
        } else {
            Issue.record("Expected toolInputDelta")
        }
    }

    @Test("StreamEvent toolResult carries result info")
    func toolResult() {
        let info = ToolResultInfo(toolUseId: "tu-3", content: "file contents here", isError: false)
        let event = StreamEvent.toolResult(info)
        if case .toolResult(let r) = event {
            #expect(r.toolUseId == "tu-3")
            #expect(r.content == "file contents here")
            #expect(r.isError == false)
        } else {
            Issue.record("Expected toolResult")
        }
    }

    @Test("StreamEvent toolResult with error flag")
    func toolResultError() {
        let info = ToolResultInfo(toolUseId: "tu-4", content: "permission denied", isError: true)
        let event = StreamEvent.toolResult(info)
        if case .toolResult(let r) = event {
            #expect(r.isError == true)
            #expect(r.content == "permission denied")
        } else {
            Issue.record("Expected toolResult")
        }
    }

    @Test("StreamEvent blockFinished carries index")
    func blockFinished() {
        let event = StreamEvent.blockFinished(index: 2)
        if case .blockFinished(let idx) = event {
            #expect(idx == 2)
        } else {
            Issue.record("Expected blockFinished")
        }
    }

    @Test("StreamEvent toolProgress carries timing")
    func toolProgress() {
        let info = ToolProgressInfo(toolUseId: "tu-5", toolName: "Read", elapsedSeconds: 3.7)
        let event = StreamEvent.toolProgress(info)
        if case .toolProgress(let p) = event {
            #expect(p.toolUseId == "tu-5")
            #expect(p.toolName == "Read")
            #expect(p.elapsedSeconds == 3.7)
        } else {
            Issue.record("Expected toolProgress")
        }
    }

    @Test("StreamEvent systemStatus carries status string")
    func systemStatus() {
        let event = StreamEvent.systemStatus("compacting")
        if case .systemStatus(let s) = event {
            #expect(s == "compacting")
        } else {
            Issue.record("Expected systemStatus")
        }
    }

    @Test("StreamEvent promptSuggestion carries suggestion")
    func promptSuggestion() {
        let event = StreamEvent.promptSuggestion("Try asking about tests")
        if case .promptSuggestion(let s) = event {
            #expect(s == "Try asking about tests")
        } else {
            Issue.record("Expected promptSuggestion")
        }
    }

    @Test("StreamEvent rateLimitWarning carries info")
    func rateLimitWarning() {
        let resetDate = Date(timeIntervalSince1970: 1700000000)
        let info = RateLimitInfo(status: "warning", utilization: 0.85, resetsAt: resetDate)
        let event = StreamEvent.rateLimitWarning(info)
        if case .rateLimitWarning(let r) = event {
            #expect(r.status == "warning")
            #expect(r.utilization == 0.85)
            #expect(r.resetsAt == resetDate)
        } else {
            Issue.record("Expected rateLimitWarning")
        }
    }

    @Test("StreamEvent rateLimitWarning with nil optional fields")
    func rateLimitWarningMinimal() {
        let info = RateLimitInfo(status: "ok")
        let event = StreamEvent.rateLimitWarning(info)
        if case .rateLimitWarning(let r) = event {
            #expect(r.status == "ok")
            #expect(r.utilization == nil)
            #expect(r.resetsAt == nil)
        } else {
            Issue.record("Expected rateLimitWarning")
        }
    }

    @Test("StreamEvent sessionBreak carries stale ID")
    func sessionBreak() {
        let event = StreamEvent.sessionBreak(staleSessionId: "stale-sess-99")
        if case .sessionBreak(let id) = event {
            #expect(id == "stale-sess-99")
        } else {
            Issue.record("Expected sessionBreak")
        }
    }

    @Test("StreamEvent completed carries CompletionInfo")
    func completed() {
        let info = CompletionInfo(sessionId: "s-1", stopReason: "end_turn", numTurns: 2)
        let event = StreamEvent.completed(info)
        if case .completed(let c) = event {
            #expect(c.sessionId == "s-1")
            #expect(c.stopReason == "end_turn")
            #expect(c.numTurns == 2)
        } else {
            Issue.record("Expected completed")
        }
    }

    @Test("StreamEvent error carries description")
    func errorEvent() {
        let event = StreamEvent.error("connection lost")
        if case .error(let desc) = event {
            #expect(desc == "connection lost")
        } else {
            Issue.record("Expected error")
        }
    }

    // MARK: - StreamEvent Equatable Cross-Variant

    @Test("StreamEvent different variants are never equal")
    func crossVariantInequality() {
        let events: [StreamEvent] = [
            .textDelta("a"),
            .thinkingDelta("a"),
            .toolUseStarted(ToolUseInfo(toolUseId: "a", toolName: "a")),
            .toolInputDelta(toolUseId: "a", json: "a"),
            .toolResult(ToolResultInfo(toolUseId: "a", content: "a", isError: false)),
            .blockFinished(index: 0),
            .toolProgress(ToolProgressInfo(toolUseId: "a", toolName: "a", elapsedSeconds: 0)),
            .systemStatus("a"),
            .promptSuggestion("a"),
            .rateLimitWarning(RateLimitInfo(status: "a")),
            .sessionBreak(staleSessionId: "a"),
            .completed(CompletionInfo()),
            .error("a"),
        ]

        for i in 0..<events.count {
            for j in (i + 1)..<events.count {
                #expect(events[i] != events[j],
                        "Expected \(events[i]) != \(events[j])")
            }
        }
    }

    // MARK: - MockMessenger Streaming Pipeline

    @Test("MockMessenger streaming yields textDelta then completed in order")
    func mockMessengerStreamOrder() async throws {
        let mock = MockMessenger(responses: ["ABC"])
        mock.streamingChunkSize = 1

        let (stream, _) = mock.queryStreaming(prompt: "test", options: QueryOptions())

        var events: [StreamEvent] = []
        for try await event in stream {
            events.append(event)
        }

        // 3 textDelta ("A", "B", "C") + 1 completed = 4 events
        #expect(events.count == 4)

        // First 3 are textDelta
        for i in 0..<3 {
            if case .textDelta = events[i] {
                // expected
            } else {
                Issue.record("Event \(i) should be textDelta, got \(events[i])")
            }
        }

        // Last is completed
        if case .completed = events[3] {
            // expected
        } else {
            Issue.record("Last event should be completed, got \(events[3])")
        }
    }

    @Test("MockMessenger streaming with empty response yields only completed")
    func mockMessengerEmptyResponse() async throws {
        let mock = MockMessenger(responses: [""])

        let (stream, _) = mock.queryStreaming(prompt: "test", options: QueryOptions())

        var events: [StreamEvent] = []
        for try await event in stream {
            events.append(event)
        }

        // Empty string produces no textDelta, just completed
        #expect(events.count == 1)
        if case .completed = events[0] {
            // expected
        } else {
            Issue.record("Expected completed, got \(events[0])")
        }
    }

    @Test("MockMessenger streaming session ID flows through to CompletionInfo")
    func mockMessengerSessionIdInCompletion() async throws {
        let mock = MockMessenger(responses: ["OK"], sessionId: "mock-sess-42")

        let (stream, _) = mock.queryStreaming(prompt: "test", options: QueryOptions())

        var completionSessionId: String?
        for try await event in stream {
            if case .completed(let info) = event {
                completionSessionId = info.sessionId
            }
        }

        #expect(completionSessionId == "mock-sess-42")
    }

    @Test("MockMessenger streaming with nil session ID yields nil in CompletionInfo")
    func mockMessengerNilSessionId() async throws {
        let mock = MockMessenger(responses: ["OK"], sessionId: nil)

        let (stream, _) = mock.queryStreaming(prompt: "test", options: QueryOptions())

        var completionSessionId: String? = "sentinel"
        for try await event in stream {
            if case .completed(let info) = event {
                completionSessionId = info.sessionId
            }
        }

        #expect(completionSessionId == nil)
    }

    @Test("MockMessenger streaming error yields error event then throws")
    func mockMessengerStreamingErrorSequence() async throws {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("pipeline failure")

        let (stream, _) = mock.queryStreaming(prompt: "test", options: QueryOptions())

        var errorEvents: [String] = []
        var thrownError: (any Error)?
        do {
            for try await event in stream {
                if case .error(let desc) = event {
                    errorEvents.append(desc)
                }
            }
        } catch {
            thrownError = error
        }

        #expect(errorEvents.count == 1)
        #expect(thrownError != nil)
    }

    @Test("MockMessenger streaming consumes responses in FIFO order")
    func mockMessengerStreamingFIFO() async throws {
        let mock = MockMessenger(responses: ["first", "second", "third"])
        mock.streamingChunkSize = 100

        // Consume three streams in sequence
        for expected in ["first", "second", "third"] {
            let (stream, _) = mock.queryStreaming(prompt: "q", options: QueryOptions())
            var text = ""
            for try await event in stream {
                if case .textDelta(let delta) = event {
                    text += delta
                }
            }
            #expect(text == expected)
        }
    }

    @Test("MockMessenger streaming falls back to defaultResponse when queue exhausted")
    func mockMessengerStreamingDefaultResponse() async throws {
        let mock = MockMessenger(responses: ["only-one"], defaultResponse: "fallback")
        mock.streamingChunkSize = 100

        // First call uses queued response
        let (s1, _) = mock.queryStreaming(prompt: "q", options: QueryOptions())
        var t1 = ""
        for try await event in s1 {
            if case .textDelta(let d) = event { t1 += d }
        }
        #expect(t1 == "only-one")

        // Second call uses default
        let (s2, _) = mock.queryStreaming(prompt: "q", options: QueryOptions())
        var t2 = ""
        for try await event in s2 {
            if case .textDelta(let d) = event { t2 += d }
        }
        #expect(t2 == "fallback")
    }

    @Test("MockMessenger streaming chunk size 1 produces one char per delta")
    func mockMessengerChunkSizeOne() async throws {
        let mock = MockMessenger(responses: ["Hi!"])
        mock.streamingChunkSize = 1

        let (stream, _) = mock.queryStreaming(prompt: "test", options: QueryOptions())

        var chunks: [String] = []
        for try await event in stream {
            if case .textDelta(let delta) = event {
                chunks.append(delta)
            }
        }

        #expect(chunks == ["H", "i", "!"])
    }

    @Test("MockMessenger streaming chunk size larger than response yields single delta")
    func mockMessengerChunkSizeLargerThanResponse() async throws {
        let mock = MockMessenger(responses: ["tiny"])
        mock.streamingChunkSize = 1000

        let (stream, _) = mock.queryStreaming(prompt: "test", options: QueryOptions())

        var chunks: [String] = []
        for try await event in stream {
            if case .textDelta(let delta) = event {
                chunks.append(delta)
            }
        }

        #expect(chunks.count == 1)
        #expect(chunks[0] == "tiny")
    }

    // MARK: - MockMessenger Batch vs Streaming Symmetry

    @Test("MockMessenger batch and streaming produce same content for multi-response queue")
    func batchStreamingSymmetryMultiResponse() async throws {
        // Batch path
        let batchMock = MockMessenger(responses: ["alpha", "beta"])
        let r1 = try await batchMock.query(prompt: "q1", options: QueryOptions())
        let r2 = try await batchMock.query(prompt: "q2", options: QueryOptions())

        // Streaming path
        let streamMock = MockMessenger(responses: ["alpha", "beta"])
        streamMock.streamingChunkSize = 100

        var s1Text = ""
        let (s1, _) = streamMock.queryStreaming(prompt: "q1", options: QueryOptions())
        for try await event in s1 {
            if case .textDelta(let d) = event { s1Text += d }
        }

        var s2Text = ""
        let (s2, _) = streamMock.queryStreaming(prompt: "q2", options: QueryOptions())
        for try await event in s2 {
            if case .textDelta(let d) = event { s2Text += d }
        }

        #expect(r1.response == s1Text)
        #expect(r2.response == s2Text)
    }

    @Test("MockMessenger batch and streaming track same call count")
    func batchStreamingCallTracking() async throws {
        let batchMock = MockMessenger(responses: ["a", "b"])
        _ = try await batchMock.query(prompt: "p1", options: QueryOptions())
        _ = try await batchMock.query(prompt: "p2", options: QueryOptions())

        let streamMock = MockMessenger(responses: ["a", "b"])
        let (s1, _) = streamMock.queryStreaming(prompt: "p1", options: QueryOptions())
        for try await _ in s1 {}
        let (s2, _) = streamMock.queryStreaming(prompt: "p2", options: QueryOptions())
        for try await _ in s2 {}

        #expect(batchMock.queryCalls.count == streamMock.queryCalls.count)
        #expect(batchMock.queryCalls == streamMock.queryCalls)
    }

    // MARK: - Supporting Type Tests

    @Test("ToolUseInfo stores fields correctly")
    func toolUseInfoFields() {
        let info = ToolUseInfo(toolUseId: "tu-abc", toolName: "Write")
        #expect(info.toolUseId == "tu-abc")
        #expect(info.toolName == "Write")
    }

    @Test("ToolUseInfo equatable")
    func toolUseInfoEquatable() {
        let a = ToolUseInfo(toolUseId: "1", toolName: "Read")
        let b = ToolUseInfo(toolUseId: "1", toolName: "Read")
        let c = ToolUseInfo(toolUseId: "2", toolName: "Read")

        #expect(a == b)
        #expect(a != c)
    }

    @Test("ToolResultInfo stores fields correctly")
    func toolResultInfoFields() {
        let info = ToolResultInfo(toolUseId: "tr-1", content: "output text", isError: false)
        #expect(info.toolUseId == "tr-1")
        #expect(info.content == "output text")
        #expect(info.isError == false)
    }

    @Test("ToolProgressInfo stores fields correctly")
    func toolProgressInfoFields() {
        let info = ToolProgressInfo(toolUseId: "tp-1", toolName: "Bash", elapsedSeconds: 12.5)
        #expect(info.toolUseId == "tp-1")
        #expect(info.toolName == "Bash")
        #expect(info.elapsedSeconds == 12.5)
    }

    @Test("ToolProgressInfo equatable")
    func toolProgressInfoEquatable() {
        let a = ToolProgressInfo(toolUseId: "1", toolName: "X", elapsedSeconds: 1.0)
        let b = ToolProgressInfo(toolUseId: "1", toolName: "X", elapsedSeconds: 1.0)
        let c = ToolProgressInfo(toolUseId: "1", toolName: "X", elapsedSeconds: 2.0)

        #expect(a == b)
        #expect(a != c)
    }

    @Test("RateLimitInfo stores fields correctly")
    func rateLimitInfoFields() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let info = RateLimitInfo(status: "throttled", utilization: 0.95, resetsAt: date)
        #expect(info.status == "throttled")
        #expect(info.utilization == 0.95)
        #expect(info.resetsAt == date)
    }

    @Test("RateLimitInfo equatable")
    func rateLimitInfoEquatable() {
        let a = RateLimitInfo(status: "ok")
        let b = RateLimitInfo(status: "ok")
        let c = RateLimitInfo(status: "warning")

        #expect(a == b)
        #expect(a != c)
    }
}
