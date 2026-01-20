import Foundation
import Testing
@testable import TavernCore

@Suite("Jake Tests")
struct JakeTests {

    @Test("Jake has system prompt")
    func jakeHasSystemPrompt() {
        // The system prompt should be non-empty and contain key character elements
        let prompt = Jake.systemPrompt

        #expect(!prompt.isEmpty)
        #expect(prompt.contains("Jake"))
        #expect(prompt.contains("Proprietor"))
        #expect(prompt.contains("Tavern"))
        #expect(prompt.contains("Slop Squad"))
    }

    @Test("Jake initializes with correct state")
    func jakeInitializesCorrectly() {
        let mock = MockClaudeCode()
        let jake = Jake(claude: mock)

        #expect(jake.state == .idle)
        #expect(jake.sessionId == nil)
    }

    @Test("Jake responds to message")
    func jakeRespondsToMessage() async throws {
        let mock = MockClaudeCode()
        let sessionId = "test-session-abc"
        mock.queueJSONResponse(result: "Well well WELL!", sessionId: sessionId)

        let jake = Jake(claude: mock)
        let response = try await jake.send("Hello Jake!")

        #expect(response == "Well well WELL!")
        #expect(jake.sessionId == sessionId)
        #expect(mock.sentPrompts.count == 1)
        #expect(mock.sentPrompts.first == "Hello Jake!")
    }

    @Test("Jake state changes to cogitating during response")
    func jakeStateCogitating() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")
        // Add small delay to observe state
        mock.responseDelay = 0.1

        let jake = Jake(claude: mock)

        // Start the send task
        let task = Task {
            try await jake.send("Test")
        }

        // Wait a tiny bit for state to change
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Should be cogitating while waiting
        #expect(jake.state == .cogitating)

        // Wait for completion
        _ = try await task.value

        // Should be idle after completion
        #expect(jake.state == .idle)
    }

    @Test("Jake maintains conversation via session ID")
    func jakeMaintainsConversation() async throws {
        let mock = MockClaudeCode()
        let sessionId1 = "session-001"
        let sessionId2 = "session-001" // Same session continues

        mock.queueJSONResponse(result: "First response", sessionId: sessionId1)
        mock.queueJSONResponse(result: "Second response", sessionId: sessionId2)

        let jake = Jake(claude: mock)

        // First message - should use runSinglePrompt
        let _ = try await jake.send("First message")
        #expect(jake.sessionId == sessionId1)
        #expect(mock.resumedSessions.isEmpty) // No resume yet

        // Second message - should use resumeConversation
        let _ = try await jake.send("Second message")
        #expect(mock.resumedSessions.count == 1)
        #expect(mock.resumedSessions.first?.sessionId == sessionId1)
    }

    @Test("Jake can reset conversation")
    func jakeResetsConversation() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")
        mock.queueJSONResponse(result: "New response", sessionId: "session-456")

        let jake = Jake(claude: mock)

        // Start a conversation
        _ = try await jake.send("Hello")
        #expect(jake.sessionId == "session-123")

        // Reset
        jake.resetConversation()
        #expect(jake.sessionId == nil)

        // New conversation should use runSinglePrompt again
        _ = try await jake.send("Hello again")
        #expect(jake.sessionId == "session-456")
        // Should have been a new conversation, not a resume
        #expect(mock.resumedSessions.count == 0 || mock.resumedSessions.last?.sessionId != "session-123")
    }

    @Test("Jake handles text response fallback")
    func jakeHandlesTextResponse() async throws {
        let mock = MockClaudeCode()
        mock.queueTextResponse("Plain text response")

        let jake = Jake(claude: mock)
        let response = try await jake.send("Test")

        #expect(response == "Plain text response")
        // Session ID remains nil for text responses
        #expect(jake.sessionId == nil)
    }

    @Test("Jake propagates errors")
    func jakePropagatesErrors() async throws {
        let mock = MockClaudeCode()
        mock.errorToThrow = ClaudeCodeError.executionFailed("Network error")

        let jake = Jake(claude: mock)

        do {
            _ = try await jake.send("Test")
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is ClaudeCodeError)
        }

        // State should return to idle after error
        #expect(jake.state == .idle)
    }
}
