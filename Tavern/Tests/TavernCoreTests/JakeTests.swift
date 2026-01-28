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
        let jake = Jake(claude: mock, loadSavedSession: false)

        #expect(jake.state == .idle)
        #expect(jake.sessionId == nil)
    }

    @Test("Jake responds to message")
    func jakeRespondsToMessage() async throws {
        let mock = MockClaudeCode()
        let sessionId = "test-session-abc"
        mock.queueJSONResponse(result: "Well well WELL!", sessionId: sessionId)

        let jake = Jake(claude: mock, loadSavedSession: false)
        let response = try await jake.send("Hello Jake!")

        #expect(response == "Well well WELL!")
        #expect(jake.sessionId == sessionId)
        #expect(mock.sentPrompts.count == 1)
        #expect(mock.sentPrompts.first == "Hello Jake!")
    }

    @Test("Jake state changes to working during response")
    func jakeStateWorking() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: "Response", sessionId: "session-123")
        // Add small delay to observe state
        mock.responseDelay = 0.1

        let jake = Jake(claude: mock, loadSavedSession: false)

        // Start the send task
        let task = Task {
            try await jake.send("Test")
        }

        // Wait a tiny bit for state to change
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Should be working while waiting (Jake maps cogitating to working)
        #expect(jake.state == .working)

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

        let jake = Jake(claude: mock, loadSavedSession: false)

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

        let jake = Jake(claude: mock, loadSavedSession: false)

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

        let jake = Jake(claude: mock, loadSavedSession: false)
        let response = try await jake.send("Test")

        #expect(response == "Plain text response")
        // Session ID remains nil for text responses
        #expect(jake.sessionId == nil)
    }

    @Test("Jake propagates errors")
    func jakePropagatesErrors() async throws {
        let mock = MockClaudeCode()
        mock.errorToThrow = ClaudeCodeError.executionFailed("Network error")

        let jake = Jake(claude: mock, loadSavedSession: false)

        do {
            _ = try await jake.send("Test")
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is ClaudeCodeError)
        }

        // State should return to idle after error
        #expect(jake.state == .idle)
    }

    // MARK: - Tool Handler Integration Tests (Principle #1: Parallel Code Paths)
    // These tests cover the WITH tool handler path, complementing tests above (without)

    @Test("Jake with tool handler passes through when no feedback")
    func jakeWithToolHandlerPassthrough() async throws {
        let mock = MockClaudeCode()
        mock.queueJSONResponse(result: #"{"message": "Just chatting"}"#, sessionId: "session-123")

        let jake = Jake(claude: mock, loadSavedSession: false)

        // Create a passthrough handler that returns no feedback
        let handler = JSONActionHandler { _, _ in
            Issue.record("Spawn should not be called for message-only response")
            return SpawnResult(agentId: UUID(), agentName: "Unused")
        }
        jake.toolHandler = handler

        let response = try await jake.send("Hello")

        // Should extract the message from JSON
        #expect(response == "Just chatting")
        #expect(jake.sessionId == "session-123")
    }

    @Test("Jake with tool handler executes spawn and continues")
    func jakeWithToolHandlerSpawnAndContinue() async throws {
        let mock = MockClaudeCode()
        // First response: spawn action
        mock.queueJSONResponse(
            result: #"{"message": "Spawning helper!", "spawn": {"assignment": "Write tests"}}"#,
            sessionId: "session-123"
        )
        // Second response: after receiving spawn feedback (continuation)
        mock.queueJSONResponse(
            result: #"{"message": "Helper is on it!"}"#,
            sessionId: "session-123"
        )

        let jake = Jake(claude: mock, loadSavedSession: false)

        let spawnContext = MockSpawnContext()
        spawnContext.addResult(name: "TestHelper")
        let handler = JSONActionHandler { assignment, name in
            spawnContext.recordCall(assignment: assignment, name: name)
            return spawnContext.nextResult()
        }
        jake.toolHandler = handler

        let response = try await jake.send("I need help with tests")

        #expect(spawnContext.spawnCalls.count == 1)
        #expect(spawnContext.spawnCalls[0].assignment == "Write tests")
        #expect(spawnContext.spawnCalls[0].name == nil)
        // Final response should be from the continuation
        #expect(response == "Helper is on it!")
        // Should have sent the continuation message
        #expect(mock.resumedSessions.count == 1)
        #expect(mock.resumedSessions[0].sessionId == "session-123")
        // The continuation prompt should mention the spawn
        #expect(mock.sentPrompts.last?.contains("TestHelper") == true)
    }

    @Test("Jake tool handler loop continues for multiple spawns")
    func jakeToolHandlerMultipleSpawns() async throws {
        let mock = MockClaudeCode()
        // First: spawn agent 1
        mock.queueJSONResponse(
            result: #"{"message": "Spawning first!", "spawn": {"assignment": "Task 1"}}"#,
            sessionId: "session-123"
        )
        // Second: spawn agent 2
        mock.queueJSONResponse(
            result: #"{"message": "Spawning second!", "spawn": {"assignment": "Task 2"}}"#,
            sessionId: "session-123"
        )
        // Third: done
        mock.queueJSONResponse(
            result: #"{"message": "Both agents ready!"}"#,
            sessionId: "session-123"
        )

        let jake = Jake(claude: mock, loadSavedSession: false)

        let spawnContext = MockSpawnContext()
        spawnContext.addResult(name: "Agent1")
        spawnContext.addResult(name: "Agent2")
        let handler = JSONActionHandler { assignment, name in
            spawnContext.recordCall(assignment: assignment, name: name)
            return spawnContext.nextResult()
        }
        jake.toolHandler = handler

        let response = try await jake.send("Spawn two agents")

        #expect(spawnContext.spawnCalls.count == 2)
        #expect(response == "Both agents ready!")
        // Should have 2 continuations (after each spawn)
        #expect(mock.resumedSessions.count == 2)
    }

    @Test("Jake without tool handler returns raw response unchanged")
    func jakeWithoutToolHandlerReturnsRaw() async throws {
        let mock = MockClaudeCode()
        // Return JSON that LOOKS like it has a spawn action
        let rawJSON = #"{"message": "Hello", "spawn": {"assignment": "Task"}}"#
        mock.queueJSONResponse(result: rawJSON, sessionId: "session-123")

        let jake = Jake(claude: mock, loadSavedSession: false)
        // No tool handler set - should return raw response

        let response = try await jake.send("Test")

        // Without handler, the raw JSON string is returned as-is
        #expect(response == rawJSON)
    }
}
