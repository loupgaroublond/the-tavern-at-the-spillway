import Foundation
import ClaudeCodeSDK
import Combine

/// Mock implementation of ClaudeCode for testing
/// Allows tests to run without real API calls
/// Thread-safe via serial dispatch queue
public final class MockClaudeCode: ClaudeCode, @unchecked Sendable {

    // MARK: - Configuration

    public var configuration: ClaudeCodeConfiguration
    public var lastExecutedCommandInfo: ExecutedCommandInfo? = nil

    // MARK: - Thread Safety

    private let queue = DispatchQueue(label: "com.tavern.MockClaudeCode")

    // MARK: - Mock State (access via queue)

    private var _queuedResponses: [ClaudeCodeResult] = []
    private var _sentPrompts: [String] = []
    private var _resumedSessions: [(sessionId: String, prompt: String?)] = []
    private var _mockSessions: [SessionInfo] = []
    private var _errorToThrow: Error? = nil
    private var _wasCancelled = false
    private var _responseDelay: TimeInterval = 0
    private var _validateCommandResult: Bool = true

    /// Responses to return for each prompt (FIFO queue)
    public var queuedResponses: [ClaudeCodeResult] {
        get { queue.sync { _queuedResponses } }
        set { queue.sync { _queuedResponses = newValue } }
    }

    /// All prompts that were sent (for verification)
    public var sentPrompts: [String] {
        queue.sync { _sentPrompts }
    }

    /// All sessions that were resumed (for verification)
    public var resumedSessions: [(sessionId: String, prompt: String?)] {
        queue.sync { _resumedSessions }
    }

    /// Sessions to return from listSessions()
    public var mockSessions: [SessionInfo] {
        get { queue.sync { _mockSessions } }
        set { queue.sync { _mockSessions = newValue } }
    }

    /// Error to throw (if set, overrides queuedResponses)
    public var errorToThrow: Error? {
        get { queue.sync { _errorToThrow } }
        set { queue.sync { _errorToThrow = newValue } }
    }

    /// Whether cancel() was called
    public var wasCancelled: Bool {
        queue.sync { _wasCancelled }
    }

    /// Delay before returning response (for testing async behavior)
    public var responseDelay: TimeInterval {
        get { queue.sync { _responseDelay } }
        set { queue.sync { _responseDelay = newValue } }
    }

    /// Result to return from validateCommand
    public var validateCommandResult: Bool {
        get { queue.sync { _validateCommandResult } }
        set { queue.sync { _validateCommandResult = newValue } }
    }

    // MARK: - Initialization

    public init(configuration: ClaudeCodeConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Mock Helpers

    /// Queue a text response
    public func queueTextResponse(_ text: String) {
        queue.sync { _queuedResponses.append(.text(text)) }
    }

    /// Queue a JSON response with result text
    /// - Throws: Assertion failure in debug if JSON creation fails (catches test setup errors)
    public func queueJSONResponse(
        result: String?,
        sessionId: String = UUID().uuidString,
        isError: Bool = false
    ) {
        guard let message = ResultMessageFactory.make(
            isError: isError,
            result: result,
            sessionId: sessionId
        ) else {
            assertionFailure("MockClaudeCode: Failed to create ResultMessage - check JSON factory")
            // Fallback to text in release builds
            queue.sync { _queuedResponses.append(.text(result ?? "")) }
            return
        }
        queue.sync { _queuedResponses.append(.json(message)) }
    }

    /// Reset all mock state
    public func reset() {
        queue.sync {
            _queuedResponses.removeAll()
            _sentPrompts.removeAll()
            _resumedSessions.removeAll()
            _mockSessions.removeAll()
            _errorToThrow = nil
            _wasCancelled = false
            _responseDelay = 0
            _validateCommandResult = true
        }
    }

    // MARK: - Protocol Implementation

    public func runWithStdin(
        stdinContent: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        queue.sync { _sentPrompts.append(stdinContent) }
        return try await getNextResponse()
    }

    public func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        queue.sync { _sentPrompts.append(prompt) }
        return try await getNextResponse()
    }

    public func continueConversation(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        if let prompt = prompt {
            queue.sync { _sentPrompts.append(prompt) }
        }
        return try await getNextResponse()
    }

    public func resumeConversation(
        sessionId: String,
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        queue.sync {
            _resumedSessions.append((sessionId: sessionId, prompt: prompt))
            if let prompt = prompt {
                _sentPrompts.append(prompt)
            }
        }
        return try await getNextResponse()
    }

    public func listSessions() async throws -> [SessionInfo] {
        let error = queue.sync { _errorToThrow }
        if let error = error {
            throw error
        }
        return queue.sync { _mockSessions }
    }

    public func cancel() {
        queue.sync { _wasCancelled = true }
    }

    public func validateCommand(_ command: String) async throws -> Bool {
        return queue.sync { _validateCommandResult }
    }

    // MARK: - Private Helpers

    private func getNextResponse() async throws -> ClaudeCodeResult {
        let delay = queue.sync { _responseDelay }
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        let error: Error? = queue.sync { _errorToThrow }
        if let error = error {
            throw error
        }

        // Atomic check-and-dequeue to prevent race conditions
        return queue.sync {
            guard !_queuedResponses.isEmpty else {
                return .text("Mock response")
            }
            return _queuedResponses.removeFirst()
        }
    }
}

// MARK: - ResultMessage Factory for Testing

/// Factory for creating ResultMessage instances in tests
/// (ResultMessage doesn't have a public memberwise init)
public enum ResultMessageFactory {

    /// Create a ResultMessage for testing via JSON decoding
    public static func make(
        type: String = "result",
        subtype: String = "success",
        totalCostUsd: Double = 0.001,
        durationMs: Int = 100,
        durationApiMs: Int = 80,
        isError: Bool = false,
        numTurns: Int = 1,
        result: String? = nil,
        sessionId: String = UUID().uuidString
    ) -> ResultMessage? {
        // ResultMessage uses default Codable (camelCase)
        var json: [String: Any] = [
            "type": type,
            "subtype": subtype,
            "totalCostUsd": totalCostUsd,
            "durationMs": durationMs,
            "durationApiMs": durationApiMs,
            "isError": isError,
            "numTurns": numTurns,
            "sessionId": sessionId
        ]

        if let result = result {
            json["result"] = result
        }

        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let message = try? JSONDecoder().decode(ResultMessage.self, from: data) else {
            return nil
        }
        return message
    }
}
