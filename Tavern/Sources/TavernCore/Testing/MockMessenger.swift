import Foundation
import ClodKit

// MARK: - MockMessenger

/// Test messenger that returns canned responses without calling Claude.
/// Thread-safe via dispatch queue.
///
/// Usage:
/// ```swift
/// let mock = MockMessenger(responses: ["Hello!", "Goodbye!"])
/// let jake = Jake(projectURL: url, messenger: mock)
/// let response = try await jake.send("Hi")
/// // response == "Hello!"
/// // mock.queryCalls.count == 1
/// ```
public final class MockMessenger: AgentMessenger, @unchecked Sendable {

    /// Responses to return, popped from front on each `query()` call.
    /// When empty, returns `defaultResponse`.
    private var responses: [String]

    /// Returned when `responses` is exhausted.
    public let defaultResponse: String

    /// Session ID to return (simulates session continuity).
    public var sessionId: String?

    /// If set, `query()` throws this error instead of returning.
    public var errorToThrow: (any Error)?

    /// Delay before returning response.
    public var responseDelay: Duration?

    /// Every prompt passed to `query()`, in order.
    public private(set) var queryCalls: [String] = []

    /// Every QueryOptions passed to `query()`, in order.
    public private(set) var queryOptions: [QueryOptions] = []

    private let queue = DispatchQueue(label: "com.tavern.MockMessenger")

    /// Create a mock messenger
    /// - Parameters:
    ///   - responses: Ordered responses to return
    ///   - defaultResponse: Fallback when responses exhausted
    ///   - sessionId: Session ID to return (default: auto-generated)
    public init(
        responses: [String] = [],
        defaultResponse: String = "",
        sessionId: String? = UUID().uuidString
    ) {
        self.responses = responses
        self.defaultResponse = defaultResponse
        self.sessionId = sessionId
    }

    /// Number of characters per streaming chunk (default 5).
    /// Set to customize how MockMessenger breaks responses into chunks.
    public var streamingChunkSize: Int = 5

    public func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?) {
        queue.sync {
            queryCalls.append(prompt)
            queryOptions.append(options)
        }

        if let delay = responseDelay {
            try await Task.sleep(for: delay)
        }

        if let error = errorToThrow {
            throw error
        }

        let response = queue.sync {
            if !responses.isEmpty {
                return responses.removeFirst()
            }
            return defaultResponse
        }

        return (response: response, sessionId: sessionId)
    }

    public func queryStreaming(prompt: String, options: QueryOptions) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let cancelled = UnsafeSendableBox(false)

        // Capture what we need before entering the stream closure
        let response: String = queue.sync {
            queryCalls.append(prompt)
            queryOptions.append(options)
            if !responses.isEmpty {
                return responses.removeFirst()
            }
            return defaultResponse
        }
        let delay = responseDelay
        let error = errorToThrow
        let sid = sessionId
        let chunkSize = streamingChunkSize

        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task {
                if let delay {
                    try await Task.sleep(for: delay)
                }

                if let error {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                    return
                }

                // Yield response in chunks
                var index = response.startIndex
                while index < response.endIndex {
                    if cancelled.value {
                        continuation.finish()
                        return
                    }
                    let end = response.index(index, offsetBy: chunkSize, limitedBy: response.endIndex) ?? response.endIndex
                    let chunk = String(response[index..<end])
                    continuation.yield(.textDelta(chunk))
                    index = end
                    // Small yield to simulate async behavior
                    await Task.yield()
                }

                continuation.yield(.completed(sessionId: sid, usage: nil))
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
}
