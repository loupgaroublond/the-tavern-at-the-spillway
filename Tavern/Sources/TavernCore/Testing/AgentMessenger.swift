import Foundation
import ClodKit
import os.log

/// Protocol abstracting the Claude SDK communication layer.
/// Jake and Servitor use this to send messages — `LiveMessenger` calls real Claude,
/// `MockMessenger` returns canned responses for testing.
public protocol AgentMessenger: Sendable {
    /// Send a prompt to Claude and get a response
    /// - Parameters:
    ///   - prompt: The user's message
    ///   - options: Query options (system prompt, session ID, etc.)
    /// - Returns: Tuple of (response text, session ID if available)
    func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?)
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
}
