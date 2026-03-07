import Foundation
import ClodKit

// MARK: - Provenance: REQ-QA-002, REQ-QA-005

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
public final class MockMessenger: ServitorMessenger, @unchecked Sendable {

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

    /// If set, the first call where options.resume is non-nil will throw this error.
    /// Simulates a stale session that fails on resume attempt.
    public var staleSessionError: (any Error)?

    /// Whether the stale session error has already been triggered.
    /// Reset to false to simulate another stale session.
    public var hasSimulatedStaleSession = false

    /// Every prompt passed to `query()`, in order.
    public private(set) var queryCalls: [String] = []

    /// Every QueryOptions passed to `query()`, in order.
    public private(set) var queryOptions: [QueryOptions] = []

    /// Canned account info to return from `fetchAccountInfo()`.
    public var mockAccountInfo: AccountInfo = AccountInfo(
        email: "test@example.com",
        organization: "Test Org",
        subscriptionType: "pro"
    )

    /// Canned initialization result to return from `fetchAccountInfo()`.
    public var mockInitResult: SDKControlInitializeResponse = MockMessenger.defaultInitResult()

    /// Number of times `fetchAccountInfo()` has been called.
    public private(set) var fetchAccountInfoCallCount: Int = 0

    /// Recorded MCP control calls for assertions.
    public private(set) var mcpStatusCalls: Int = 0
    public private(set) var reconnectCalls: [String] = []
    public private(set) var toggleCalls: [(name: String, enabled: Bool)] = []

    /// Canned MCP server statuses to return from `mcpServerStatus()`.
    public var mcpStatuses: [McpServerStatus] = []

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

    /// Notifications to emit during streaming, yielded before text chunks.
    /// Consumed (cleared) after each `queryStreaming()` call.
    public var notificationsToEmit: [NotificationInfo] = []

    public func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?) {
        queue.sync {
            queryCalls.append(prompt)
            queryOptions.append(options)
        }

        if let delay = responseDelay {
            try await Task.sleep(for: delay)
        }

        // Simulate stale session failure on resume attempt
        let shouldSimulateStale: Bool = queue.sync {
            if staleSessionError != nil && !hasSimulatedStaleSession && options.resume != nil {
                hasSimulatedStaleSession = true
                return true
            }
            return false
        }
        if shouldSimulateStale, let staleError = staleSessionError {
            throw staleError
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

    public func fetchAccountInfo(options: QueryOptions) async throws -> (account: AccountInfo, initResult: SDKControlInitializeResponse) {
        queue.sync { fetchAccountInfoCallCount += 1 }
        if let error = errorToThrow { throw error }
        return (account: mockAccountInfo, initResult: mockInitResult)
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
        let staleError = staleSessionError
        let notifications: [NotificationInfo] = queue.sync {
            let n = notificationsToEmit
            notificationsToEmit = []
            return n
        }

        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task {
                if let delay {
                    try await Task.sleep(for: delay)
                }

                // Simulate stale session failure on resume attempt
                let shouldSimulateStale: Bool = self.queue.sync {
                    if staleError != nil && !self.hasSimulatedStaleSession && options.resume != nil {
                        self.hasSimulatedStaleSession = true
                        return true
                    }
                    return false
                }
                if shouldSimulateStale, let staleError {
                    continuation.finish(throwing: staleError)
                    return
                }

                if let error {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                    return
                }

                // Yield any queued notifications before content
                for notification in notifications {
                    continuation.yield(.notification(notification))
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

                continuation.yield(.completed(CompletionInfo(sessionId: sid)))
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

    // MARK: - MCP Runtime Control

    public func mcpServerStatus() async throws -> [McpServerStatus] {
        queue.sync { mcpStatusCalls += 1 }
        return mcpStatuses
    }

    public func reconnectMcpServer(name: String) async throws {
        queue.sync { reconnectCalls.append(name) }
    }

    public func toggleMcpServer(name: String, enabled: Bool) async throws {
        queue.sync { toggleCalls.append((name: name, enabled: enabled)) }
    }

    // MARK: - Helpers

    /// Default init result decoded from JSON (SDKControlInitializeResponse has no public memberwise init).
    private static func defaultInitResult() -> SDKControlInitializeResponse {
        let json = """
        {
            "commands": [],
            "agents": [],
            "output_style": "text",
            "available_output_styles": ["text"],
            "models": [
                {
                    "value": "claude-sonnet-4-20250514",
                    "display_name": "Claude Sonnet 4",
                    "description": "Fast and capable"
                }
            ],
            "account": {
                "email": "test@example.com",
                "organization": "Test Org",
                "subscription_type": "pro"
            }
        }
        """
        // Force-unwrap acceptable in test infrastructure — failure is a developer error
        return try! JSONDecoder().decode(SDKControlInitializeResponse.self, from: Data(json.utf8))
    }
}
