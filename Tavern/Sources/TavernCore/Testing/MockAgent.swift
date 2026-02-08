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

    public func resetConversation() {
        queue.sync {
            resetCalled = true
            resetCallCount += 1
            _state = .idle
        }
    }
}
