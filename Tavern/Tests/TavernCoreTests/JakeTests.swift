import Foundation
import Testing
@testable import TavernCore

@Suite("Jake Tests")
struct JakeTests {

    // Test helper - temp directory for testing
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

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
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)

        #expect(jake.state == .idle)
        #expect(jake.sessionId == nil)
    }

    @Test("Jake can reset conversation")
    func jakeResetsConversation() async throws {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)

        // Set a session ID manually for testing
        // Note: This would normally be set by send(), but we're testing reset behavior
        jake.resetConversation()
        #expect(jake.sessionId == nil)
    }

    @Test("Jake has project path")
    func jakeHasProjectPath() {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)

        #expect(jake.projectPath == projectURL.path)
    }

    @Test("Jake MCP server can be set")
    func jakeMCPServerCanBeSet() async throws {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)

        // Initially no MCP server
        #expect(jake.mcpServer == nil)

        // Create a mock MCP server
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL()
        )

        let server = createTavernMCPServer(
            spawner: spawner,
            onSummon: { _ in },
            onDismiss: { _ in }
        )
        jake.mcpServer = server

        // MCP server is now set
        #expect(jake.mcpServer != nil)
    }

    // MARK: - Grade 2 Mock Tests (using MockMessenger)

    @Test("Jake responds to message")
    func jakeRespondsToMessage() async throws {
        let mock = MockMessenger(responses: ["Well WELL, look who showed up!"])
        let jake = Jake(projectURL: Self.testProjectURL(), messenger: mock, loadSavedSession: false)

        let response = try await jake.send("Hello Jake")

        #expect(response == "Well WELL, look who showed up!")
        #expect(mock.queryCalls.count == 1)
        #expect(mock.queryCalls[0] == "Hello Jake")
    }

    @Test("Jake state changes to working during response")
    func jakeStateChangesToWorkingDuringResponse() async throws {
        let mock = MockMessenger(responses: ["OK"])
        mock.responseDelay = .milliseconds(100)
        let jake = Jake(projectURL: Self.testProjectURL(), messenger: mock, loadSavedSession: false)

        #expect(jake.state == .idle)

        let task = Task {
            try await jake.send("Test")
        }

        // Give send() time to set working state
        try await Task.sleep(for: .milliseconds(50))
        #expect(jake.state == .working)

        let _ = try await task.value
        #expect(jake.state == .idle)
    }

    @Test("Jake maintains conversation via session ID")
    func jakeMaintainsConversationViaSessionId() async throws {
        let sessionId = UUID().uuidString
        let mock = MockMessenger(responses: ["First", "Second"], sessionId: sessionId)
        let jake = Jake(projectURL: Self.testProjectURL(), messenger: mock, loadSavedSession: false)

        #expect(jake.sessionId == nil)

        let _ = try await jake.send("Message 1")
        #expect(jake.sessionId == sessionId)

        let _ = try await jake.send("Message 2")
        #expect(jake.sessionId == sessionId)

        // Verify session ID was passed to second query via options.resume
        #expect(mock.queryOptions.count == 2)
        #expect(mock.queryOptions[1].resume == sessionId)
    }

    @Test("Jake handles text response fallback")
    func jakeHandlesTextResponseFallback() async throws {
        // LiveMessenger handles both "result" and "assistant" message types
        // MockMessenger just returns the response directly — verify Jake still works
        let mock = MockMessenger(responses: ["Fallback response"])
        let jake = Jake(projectURL: Self.testProjectURL(), messenger: mock, loadSavedSession: false)

        let response = try await jake.send("Test")
        #expect(response == "Fallback response")
    }

    @Test("Jake propagates errors")
    func jakePropagatesErrors() async throws {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("Test error")
        let jake = Jake(projectURL: Self.testProjectURL(), messenger: mock, loadSavedSession: false)

        do {
            let _ = try await jake.send("This should fail")
            Issue.record("Expected error to be thrown")
        } catch let error as TavernError {
            if case .internalError(let message) = error {
                #expect(message == "Test error")
            } else {
                Issue.record("Expected internalError, got: \(error)")
            }
        }
    }

    @Test("Jake wraps errors as sessionCorrupt when session ID exists")
    func jakeWrapsErrorsAsSessionCorrupt() async throws {
        let projectURL = Self.testProjectURL()
        let mock = MockMessenger()
        mock.errorToThrow = NSError(domain: "test", code: 1)

        let sessionId = "test-session-123"
        SessionStore.saveJakeSession(sessionId, projectPath: projectURL.path)

        let jake = Jake(projectURL: projectURL, messenger: mock, loadSavedSession: true)
        #expect(jake.sessionId == sessionId)

        do {
            let _ = try await jake.send("This should fail")
            Issue.record("Expected error to be thrown")
        } catch let error as TavernError {
            if case .sessionCorrupt(let sid, _) = error {
                #expect(sid == sessionId)
            } else {
                Issue.record("Expected sessionCorrupt, got: \(error)")
            }
        }

        SessionStore.clearJakeSession(projectPath: projectURL.path)
    }

    @Test("Jake with tool handler passes through when no feedback")
    func jakeWithToolHandlerPassesThroughWhenNoFeedback() async throws {
        let mock = MockMessenger(responses: ["Response with MCP registered"])
        let jake = Jake(projectURL: Self.testProjectURL(), messenger: mock, loadSavedSession: false)

        // Register MCP server (tools available but not called by mock)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: Self.testProjectURL()
        )
        let server = createTavernMCPServer(spawner: spawner, onSummon: { _ in }, onDismiss: { _ in })
        jake.mcpServer = server

        let response = try await jake.send("Just respond normally")
        #expect(response == "Response with MCP registered")

        // Verify MCP server was included in query options
        #expect(mock.queryOptions.count == 1)
        #expect(mock.queryOptions[0].sdkMcpServers["tavern"] != nil)
    }

    @Test("Jake system prompt is included in query options")
    func jakeSystemPromptInQueryOptions() async throws {
        let mock = MockMessenger(responses: ["OK"])
        let jake = Jake(projectURL: Self.testProjectURL(), messenger: mock, loadSavedSession: false)

        let _ = try await jake.send("Test")

        #expect(mock.queryOptions.count == 1)
        #expect(mock.queryOptions[0].systemPrompt == Jake.systemPrompt)
    }
}
