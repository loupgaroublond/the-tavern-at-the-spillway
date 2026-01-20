import Foundation
import ClaudeCodeSDK
import Combine

/// Mock implementation of ClaudeCode for testing
/// Allows tests to run without real API calls
public final class MockClaudeCode: ClaudeCode, @unchecked Sendable {

    // MARK: - Configuration

    public var configuration: ClaudeCodeConfiguration
    public var lastExecutedCommandInfo: ExecutedCommandInfo? = nil

    // MARK: - Mock State

    /// Responses to return for each prompt (FIFO queue)
    public var queuedResponses: [ClaudeCodeResult] = []

    /// All prompts that were sent (for verification)
    public private(set) var sentPrompts: [String] = []

    /// All sessions that were resumed (for verification)
    public private(set) var resumedSessions: [(sessionId: String, prompt: String?)] = []

    /// Sessions to return from listSessions()
    public var mockSessions: [SessionInfo] = []

    /// Error to throw (if set, overrides queuedResponses)
    public var errorToThrow: Error? = nil

    /// Whether cancel() was called
    public private(set) var wasCancelled = false

    /// Delay before returning response (for testing async behavior)
    public var responseDelay: TimeInterval = 0

    // MARK: - Initialization

    public init(configuration: ClaudeCodeConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Mock Helpers

    /// Queue a text response
    public func queueTextResponse(_ text: String) {
        queuedResponses.append(.text(text))
    }

    /// Queue a JSON response with result text
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
            // Fallback to text if JSON creation fails
            queuedResponses.append(.text(result ?? ""))
            return
        }
        queuedResponses.append(.json(message))
    }

    /// Reset all mock state
    public func reset() {
        queuedResponses.removeAll()
        sentPrompts.removeAll()
        resumedSessions.removeAll()
        mockSessions.removeAll()
        errorToThrow = nil
        wasCancelled = false
    }

    // MARK: - Protocol Implementation

    public func runWithStdin(
        stdinContent: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        sentPrompts.append(stdinContent)
        return try await getNextResponse()
    }

    public func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        sentPrompts.append(prompt)
        return try await getNextResponse()
    }

    public func continueConversation(
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        if let prompt = prompt {
            sentPrompts.append(prompt)
        }
        return try await getNextResponse()
    }

    public func resumeConversation(
        sessionId: String,
        prompt: String?,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        resumedSessions.append((sessionId: sessionId, prompt: prompt))
        if let prompt = prompt {
            sentPrompts.append(prompt)
        }
        return try await getNextResponse()
    }

    public func listSessions() async throws -> [SessionInfo] {
        if let error = errorToThrow {
            throw error
        }
        return mockSessions
    }

    public func cancel() {
        wasCancelled = true
    }

    public func validateCommand(_ command: String) async throws -> Bool {
        // Always return true in mock
        return true
    }

    // MARK: - Private Helpers

    private func getNextResponse() async throws -> ClaudeCodeResult {
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        if let error = errorToThrow {
            throw error
        }

        guard !queuedResponses.isEmpty else {
            // Return a default response if none queued
            return .text("Mock response")
        }

        return queuedResponses.removeFirst()
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
