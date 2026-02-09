import Foundation

/// A mock agent for testing ViewModels and coordinators without real Claude calls
/// Conforms to `Agent` protocol — pops canned responses from a queue.
///
/// Usage:
/// ```swift
/// let mock = MockAgent(responses: ["Hello!", "Goodbye!"])
/// let vm = ChatViewModel(agent: mock, loadHistory: false)
/// vm.inputText = "Hi"
/// await vm.sendMessage()
/// // mock.sendCalls == ["Hi"]
/// // vm.messages contains user + agent messages
/// ```
public final class MockAgent: Agent, @unchecked Sendable {

    // MARK: - Agent Protocol

    public let id: UUID
    public let name: String

    public var state: AgentState {
        queue.sync { _state }
    }

    // MARK: - Mock Configuration

    /// Responses to return, popped from front on each `send()` call.
    /// When empty, returns `defaultResponse`.
    public var responses: [String]

    /// Returned when `responses` is exhausted. Defaults to empty string.
    public var defaultResponse: String

    /// If set, `send()` throws this error instead of returning a response.
    public var errorToThrow: (any Error)?

    /// Delay before returning response (simulates network latency).
    public var responseDelay: Duration?

    // MARK: - Call Tracking

    /// Every message passed to `send()`, in order.
    public private(set) var sendCalls: [String] = []

    /// Whether `resetConversation()` was called.
    public private(set) var resetCalled: Bool = false

    /// Number of times `resetConversation()` was called.
    public private(set) var resetCallCount: Int = 0

    // MARK: - Private State

    private let queue = DispatchQueue(label: "com.tavern.MockAgent")
    private var _state: AgentState = .idle

    // MARK: - Initialization

    /// Create a mock agent with canned responses
    /// - Parameters:
    ///   - name: Display name (default "MockAgent")
    ///   - responses: Ordered responses to return from send()
    ///   - defaultResponse: Fallback when responses exhausted (default "")
    public init(
        id: UUID = UUID(),
        name: String = "MockAgent",
        responses: [String] = [],
        defaultResponse: String = ""
    ) {
        self.id = id
        self.name = name
        self.responses = responses
        self.defaultResponse = defaultResponse
    }

    // MARK: - Agent Protocol

    public func send(_ message: String) async throws -> String {
        queue.sync {
            sendCalls.append(message)
            _state = .working
        }

        defer {
            queue.sync { _state = .idle }
        }

        if let delay = responseDelay {
            try await Task.sleep(for: delay)
        }

        if let error = errorToThrow {
            throw error
        }

        return queue.sync {
            if !responses.isEmpty {
                return responses.removeFirst()
            }
            return defaultResponse
        }
    }

    /// Number of characters per streaming chunk (default 5).
    public var streamingChunkSize: Int = 5

    public func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let cancelled = UnsafeSendableBox(false)

        let response: String = queue.sync {
            sendCalls.append(message)
            _state = .working
            if !responses.isEmpty {
                return responses.removeFirst()
            }
            return defaultResponse
        }
        let error = errorToThrow
        let delay = responseDelay
        let chunkSize = streamingChunkSize

        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task { [weak self] in
                defer {
                    self?.queue.sync { self?._state = .idle }
                }

                if let delay {
                    try await Task.sleep(for: delay)
                }

                if let error {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                    return
                }

                // Yield in chunks
                var index = response.startIndex
                while index < response.endIndex {
                    if cancelled.value {
                        continuation.finish()
                        return
                    }
                    let end = response.index(index, offsetBy: chunkSize, limitedBy: response.endIndex) ?? response.endIndex
                    continuation.yield(.textDelta(String(response[index..<end])))
                    index = end
                    await Task.yield()
                }

                continuation.yield(.completed(sessionId: nil))
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        let cancel: @Sendable () -> Void = {
            cancelled.value = true
        }

        return (stream: stream, cancel: cancel)
    }

    public func resetConversation() {
        queue.sync {
            resetCalled = true
            resetCallCount += 1
            _state = .idle
        }
    }
}
