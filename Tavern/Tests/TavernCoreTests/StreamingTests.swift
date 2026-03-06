import Foundation
import Testing
import ClodKit
@testable import TavernCore

@Suite("Streaming Tests", .timeLimit(.minutes(1)))
struct StreamingTests {

    // Test helper
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-streaming-test-\(UUID().uuidString)")
    }

    // MARK: - StreamEvent Tests

    @Test("StreamEvent textDelta carries content")
    func streamEventTextDelta() {
        let event = StreamEvent.textDelta("Hello")
        if case .textDelta(let text) = event {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected textDelta")
        }
    }

    @Test("StreamEvent completed carries session ID")
    func streamEventCompleted() {
        let event = StreamEvent.completed(CompletionInfo(sessionId: "sess-123"))
        if case .completed(let info) = event {
            #expect(info.sessionId == "sess-123")
        } else {
            Issue.record("Expected completed")
        }
    }

    @Test("StreamEvent completed can have nil session ID")
    func streamEventCompletedNil() {
        let event = StreamEvent.completed(CompletionInfo())
        if case .completed(let info) = event {
            #expect(info.sessionId == nil)
        } else {
            Issue.record("Expected completed")
        }
    }

    @Test("StreamEvent completed carries usage data")
    func streamEventCompletedWithUsage() {
        let usage = SessionUsage(inputTokens: 100, outputTokens: 50)
        let event = StreamEvent.completed(CompletionInfo(sessionId: "sess-456", usage: usage))
        if case .completed(let info) = event {
            #expect(info.sessionId == "sess-456")
            #expect(info.usage?.inputTokens == 100)
            #expect(info.usage?.outputTokens == 50)
            #expect(info.usage?.totalTokens == 150)
        } else {
            Issue.record("Expected completed")
        }
    }

    @Test("StreamEvent error carries description")
    func streamEventError() {
        let event = StreamEvent.error("Something went wrong")
        if case .error(let desc) = event {
            #expect(desc == "Something went wrong")
        } else {
            Issue.record("Expected error")
        }
    }

    @Test("StreamEvent equatable works correctly")
    func streamEventEquatable() {
        #expect(StreamEvent.textDelta("a") == StreamEvent.textDelta("a"))
        #expect(StreamEvent.textDelta("a") != StreamEvent.textDelta("b"))
        #expect(StreamEvent.completed(CompletionInfo(sessionId: "x")) == StreamEvent.completed(CompletionInfo(sessionId: "x")))
        #expect(StreamEvent.completed(CompletionInfo()) == StreamEvent.completed(CompletionInfo()))
        #expect(StreamEvent.error("e") == StreamEvent.error("e"))
    }

    // MARK: - MockMessenger Streaming Tests

    @Test("MockMessenger queryStreaming yields text chunks then completed")
    func mockMessengerStreamingYieldsChunks() async throws {
        let mock = MockMessenger(responses: ["Hello World!"])
        mock.streamingChunkSize = 5

        let (stream, _) = mock.queryStreaming(prompt: "Hi", options: QueryOptions())

        var chunks: [String] = []
        var completed = false
        var sessionId: String?

        for try await event in stream {
            switch event {
            case .textDelta(let text):
                chunks.append(text)
            case .completed(let info):
                completed = true
                sessionId = info.sessionId
            case .error:
                Issue.record("Unexpected error event")
            default:
                break
            }
        }

        // "Hello World!" = 12 chars, chunks of 5 = "Hello", " Worl", "d!"
        #expect(chunks.count == 3)
        #expect(chunks.joined() == "Hello World!")
        #expect(completed)
        #expect(sessionId == mock.sessionId)
    }

    @Test("MockMessenger queryStreaming tracks calls")
    func mockMessengerStreamingTracksCalls() async throws {
        let mock = MockMessenger(responses: ["OK"])

        let (stream, _) = mock.queryStreaming(prompt: "Test", options: QueryOptions())
        // Consume stream
        for try await _ in stream {}

        #expect(mock.queryCalls.count == 1)
        #expect(mock.queryCalls[0] == "Test")
    }

    @Test("MockMessenger queryStreaming throws on error")
    func mockMessengerStreamingThrowsOnError() async {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("Stream error test")

        let (stream, _) = mock.queryStreaming(prompt: "Hi", options: QueryOptions())

        var gotError = false
        do {
            for try await event in stream {
                if case .error = event {
                    gotError = true
                }
            }
        } catch {
            gotError = true
        }

        #expect(gotError)
    }

    @Test("MockMessenger queryStreaming cancellation stops yielding")
    func mockMessengerStreamingCancellation() async throws {
        let mock = MockMessenger(responses: [String(repeating: "x", count: 100)])
        mock.streamingChunkSize = 1 // 1 char at a time for many yields

        let (stream, cancel) = mock.queryStreaming(prompt: "Hi", options: QueryOptions())

        var chunkCount = 0
        for try await event in stream {
            if case .textDelta = event {
                chunkCount += 1
                if chunkCount >= 5 {
                    cancel()
                    break
                }
            }
        }

        // Should have stopped after ~5 chunks (not all 100)
        #expect(chunkCount <= 10)
    }

    // MARK: - MockServitor Streaming Tests

    @Test("MockServitor sendStreaming yields chunks and completes")
    func mockServitorStreamingYieldsChunks() async throws {
        let mock = MockServitor(responses: ["Test response"])
        mock.streamingChunkSize = 4

        let (stream, _) = mock.sendStreaming("Hello")

        var content = ""
        var completed = false

        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                content += delta
            case .completed:
                completed = true
            case .error:
                Issue.record("Unexpected error")
            default:
                break
            }
        }

        #expect(content == "Test response")
        #expect(completed)
        #expect(mock.sendCalls == ["Hello"])
    }

    @Test("MockServitor sendStreaming throws on error")
    func mockServitorStreamingThrowsOnError() async {
        let mock = MockServitor()
        mock.errorToThrow = TavernError.internalError("Test error")

        let (stream, _) = mock.sendStreaming("Hi")

        var gotError = false
        do {
            for try await _ in stream {}
        } catch {
            gotError = true
        }

        #expect(gotError)
    }

    // MARK: - ChatMessage isStreaming Tests

    @Test("ChatMessage defaults to isStreaming false")
    func chatMessageDefaultsNotStreaming() {
        let msg = ChatMessage(role: .agent, content: "Hello")
        #expect(msg.isStreaming == false)
    }

    @Test("ChatMessage can be created with isStreaming true")
    func chatMessageCanBeStreaming() {
        let msg = ChatMessage(role: .agent, content: "", isStreaming: true)
        #expect(msg.isStreaming == true)
    }

    @Test("ChatMessage isStreaming can be toggled")
    func chatMessageStreamingToggle() {
        var msg = ChatMessage(role: .agent, content: "", isStreaming: true)
        #expect(msg.isStreaming == true)

        msg.isStreaming = false
        #expect(msg.isStreaming == false)
    }

    @Test("ChatMessage content can be appended during streaming")
    func chatMessageContentAppend() {
        var msg = ChatMessage(role: .agent, content: "", isStreaming: true)
        msg.content += "Hello"
        msg.content += " World"
        #expect(msg.content == "Hello World")
    }

    // MARK: - Symmetry Tests

    @Test("Both MockServitor and MockMessenger produce equivalent streaming results")
    func streamingSymmetryMockServitorAndMessenger() async throws {
        let agentResponse = "Symmetry test"

        // MockServitor streaming
        let mockServitor = MockServitor(responses: [agentResponse])
        mockServitor.streamingChunkSize = 5
        let (servitorStream, _) = mockServitor.sendStreaming("test")
        var servitorContent = ""
        for try await event in servitorStream {
            if case .textDelta(let delta) = event {
                servitorContent += delta
            }
        }

        // MockMessenger streaming
        let mockMessenger = MockMessenger(responses: [agentResponse])
        mockMessenger.streamingChunkSize = 5
        let (messengerStream, _) = mockMessenger.queryStreaming(prompt: "test", options: QueryOptions())
        var messengerContent = ""
        for try await event in messengerStream {
            if case .textDelta(let delta) = event {
                messengerContent += delta
            }
        }

        // Both should produce the same content
        #expect(servitorContent == agentResponse)
        #expect(messengerContent == agentResponse)
        #expect(servitorContent == messengerContent)
    }

    // MARK: - Streaming Cancellation Race Condition Regression Tests

    @Test("Jake state is idle after rapid cancel during streaming")
    func jakeStateIdleAfterRapidCancel() async throws {
        let mock = MockMessenger(responses: [String(repeating: "x", count: 200)])
        mock.streamingChunkSize = 1
        mock.responseDelay = .milliseconds(10)

        let jake = Jake(
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let (stream, cancel) = jake.sendStreaming("Test")

        // Read a few events then cancel immediately
        var eventCount = 0
        for try await _ in stream {
            eventCount += 1
            if eventCount >= 3 {
                cancel()
                break
            }
        }

        // State must be idle after cancel regardless of timing
        #expect(jake.state == .idle)
        #expect(jake.isCogitating == false)
    }

    @Test("Mortal state is idle after rapid cancel during streaming")
    func mortalStateIdleAfterRapidCancel() async throws {
        let mock = MockMessenger(responses: [String(repeating: "x", count: 200)])
        mock.streamingChunkSize = 1
        mock.responseDelay = .milliseconds(10)

        let mortal = Mortal(
            name: "CancelTest",
            assignment: "Test",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let (stream, cancel) = mortal.sendStreaming("Test")

        var eventCount = 0
        for try await _ in stream {
            eventCount += 1
            if eventCount >= 3 {
                cancel()
                break
            }
        }

        // State must be idle after cancel
        #expect(mortal.state == .idle)
    }

    @Test("Jake cancel and completion do not produce inconsistent state")
    func jakeCancelCompletionConsistency() async throws {
        // Run multiple cancel/complete cycles to shake out races
        for _ in 0..<10 {
            let mock = MockMessenger(responses: ["Short"])
            mock.streamingChunkSize = 5

            let jake = Jake(
                projectURL: Self.testProjectURL(),
                messenger: mock
            )

            let (stream, cancel) = jake.sendStreaming("Test")

            // Race: consume stream while calling cancel
            let consumeTask = Task {
                for try await _ in stream {}
            }

            // Small delay then cancel
            try? await Task.sleep(for: .milliseconds(1))
            cancel()

            try? await consumeTask.value

            // Regardless of who wins, state must be idle
            #expect(jake.state == .idle)
            #expect(jake.isCogitating == false)
        }
    }

    @Test("Mortal cancel and completion do not produce inconsistent state")
    func mortalCancelCompletionConsistency() async throws {
        for _ in 0..<10 {
            let mock = MockMessenger(responses: ["Short"])
            mock.streamingChunkSize = 5

            let mortal = Mortal(
                name: "RaceTest-\(UUID().uuidString.prefix(4))",
                projectURL: Self.testProjectURL(),
                messenger: mock
            )

            let (stream, cancel) = mortal.sendStreaming("Test")

            let consumeTask = Task {
                for try await _ in stream {}
            }

            try? await Task.sleep(for: .milliseconds(1))
            cancel()

            try? await consumeTask.value

            #expect(mortal.state == .idle)
        }
    }

    @Test("Batch and streaming produce same content")
    func batchAndStreamingProduceSameContent() async throws {
        let response = "Hello from Claude"

        // Batch query
        let batchMock = MockMessenger(responses: [response])
        let batchResult = try await batchMock.query(prompt: "test", options: QueryOptions())

        // Streaming query
        let streamMock = MockMessenger(responses: [response])
        let (stream, _) = streamMock.queryStreaming(prompt: "test", options: QueryOptions())
        var streamContent = ""
        for try await event in stream {
            if case .textDelta(let delta) = event {
                streamContent += delta
            }
        }

        #expect(batchResult.response == streamContent)
    }
}
