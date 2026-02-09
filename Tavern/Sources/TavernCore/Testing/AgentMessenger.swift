import Foundation
import ClodKit
import os.log

// MARK: - Stream Event

/// Events yielded during a streaming response from Claude.
/// Each event represents a discrete update that the UI can act on.
public enum StreamEvent: Sendable, Equatable {
    /// A chunk of text content to append to the current message
    case textDelta(String)

    /// The stream completed successfully with the final session ID
    case completed(sessionId: String?)

    /// The stream encountered an error
    case error(String)
}

// MARK: - AgentMessenger Protocol

/// Protocol abstracting the Claude SDK communication layer.
/// Jake and Servitor use this to send messages — `LiveMessenger` calls real Claude,
/// `MockMessenger` returns canned responses for testing.
public protocol AgentMessenger: Sendable {
    /// Send a prompt to Claude and get a response (batch mode)
    /// - Parameters:
    ///   - prompt: The user's message
    ///   - options: Query options (system prompt, session ID, etc.)
    /// - Returns: Tuple of (response text, session ID if available)
    func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?)

    /// Send a prompt to Claude and receive a stream of events (streaming mode)
    /// - Parameters:
    ///   - prompt: The user's message
    ///   - options: Query options (system prompt, session ID, etc.)
    /// - Returns: A stream of StreamEvent values and a cancellation handle
    func queryStreaming(prompt: String, options: QueryOptions) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void)
}

// MARK: - LiveMessenger

/// Production messenger that calls real Claude via ClodKit SDK.
/// Extracts response text from the ClaudeQuery stream, handling both
/// "result" and "assistant" message types.
public struct LiveMessenger: AgentMessenger {

    public init() {}

    public func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?) {
        let query = try await Clod.query(prompt: prompt, options: options)
        var responseText = ""
        var messageCount = 0

        for try await message in query {
            messageCount += 1
            switch message {
            case .regular(let sdkMessage):
                // Look for result message with the final response
                if sdkMessage.type == "result" {
                    if let content = sdkMessage.content?.stringValue {
                        responseText = content
                    }
                } else if sdkMessage.type == "assistant" {
                    // Fallback: extract content from assistant messages
                    if let content = sdkMessage.content?.stringValue, responseText.isEmpty {
                        responseText = content
                    }
                }
            case .controlRequest, .controlResponse, .controlCancelRequest, .keepAlive:
                break
            }
        }

        let sessionId = await query.sessionId
        return (response: responseText, sessionId: sessionId)
    }

    public func queryStreaming(prompt: String, options: QueryOptions) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        // Shared cancellation state
        let cancelled = UnsafeSendableBox(false)
        // Hold query reference for interrupt support
        let queryBox = UnsafeSendableBox<ClaudeQuery?>(nil)

        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task {
                do {
                    let query = try await Clod.query(prompt: prompt, options: options)
                    queryBox.value = query

                    var lastText = ""

                    for try await message in query {
                        if cancelled.value {
                            try await query.interrupt()
                            continuation.finish()
                            return
                        }

                        switch message {
                        case .regular(let sdkMessage):
                            if sdkMessage.type == "assistant" {
                                if let content = sdkMessage.content?.stringValue, content.count > lastText.count {
                                    let delta = String(content.dropFirst(lastText.count))
                                    lastText = content
                                    continuation.yield(.textDelta(delta))
                                }
                            } else if sdkMessage.type == "result" {
                                // Result may contain the final complete text
                                if let content = sdkMessage.content?.stringValue, content.count > lastText.count {
                                    let delta = String(content.dropFirst(lastText.count))
                                    continuation.yield(.textDelta(delta))
                                }
                            }
                        case .controlRequest, .controlResponse, .controlCancelRequest, .keepAlive:
                            break
                        }
                    }

                    let sessionId = await query.sessionId
                    continuation.yield(.completed(sessionId: sessionId))
                    continuation.finish()
                } catch {
                    if cancelled.value {
                        continuation.finish()
                    } else {
                        continuation.yield(.error(error.localizedDescription))
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        let cancel: @Sendable () -> Void = {
            cancelled.value = true
            Task {
                try? await queryBox.value?.interrupt()
            }
        }

        return (stream: stream, cancel: cancel)
    }
}

/// Thread-unsafe mutable box marked @unchecked Sendable for use in
/// structured concurrency where access is logically sequential.
/// Used internally by LiveMessenger streaming to share cancellation state.
final class UnsafeSendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

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

                continuation.yield(.completed(sessionId: sid))
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
