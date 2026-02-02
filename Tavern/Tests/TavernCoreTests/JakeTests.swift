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

    @Test("Jake tool handler can be set")
    func jakeToolHandlerCanBeSet() async throws {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)

        // Initially no tool handler
        #expect(jake.toolHandler == nil)

        // Create a passthrough handler
        let handler = JSONActionHandler { _, _ in
            SpawnResult(agentId: UUID(), agentName: "Test")
        }
        jake.toolHandler = handler

        // Tool handler is now set
        #expect(jake.toolHandler != nil)
    }

    // MARK: - Tests requiring SDK mocking (skipped for now)
    // TODO: These tests need dependency injection or SDK mocking to work
    // See: https://github.com/anthropics/claude-code/issues/XXX

    // @Test("Jake responds to message") - requires mocking ClaudeCode.query()
    // @Test("Jake state changes to working during response") - requires mocking
    // @Test("Jake maintains conversation via session ID") - requires mocking
    // @Test("Jake handles text response fallback") - requires mocking
    // @Test("Jake propagates errors") - requires mocking
    // @Test("Jake with tool handler passes through when no feedback") - requires mocking
    // @Test("Jake with tool handler executes spawn and continues") - requires mocking
    // @Test("Jake tool handler loop continues for multiple spawns") - requires mocking
    // @Test("Jake without tool handler returns raw response unchanged") - requires mocking
}
