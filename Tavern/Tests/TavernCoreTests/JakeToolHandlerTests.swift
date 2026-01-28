import Foundation
import Testing
@testable import TavernCore

/// Thread-safe mock spawn context for testing
final class MockSpawnContext: @unchecked Sendable {
    private let lock = NSLock()
    private var _spawnCalls: [(assignment: String, name: String?)] = []
    private var _spawnResults: [SpawnResult] = []
    private var _spawnError: Error?

    var spawnCalls: [(assignment: String, name: String?)] {
        lock.withLock { _spawnCalls }
    }

    var spawnError: Error? {
        get { lock.withLock { _spawnError } }
        set { lock.withLock { _spawnError = newValue } }
    }

    func addResult(id: UUID = UUID(), name: String) {
        lock.withLock {
            _spawnResults.append(SpawnResult(agentId: id, agentName: name))
        }
    }

    func recordCall(assignment: String, name: String?) {
        lock.withLock {
            _spawnCalls.append((assignment: assignment, name: name))
        }
    }

    func nextResult() -> SpawnResult {
        lock.withLock {
            guard !_spawnResults.isEmpty else {
                return SpawnResult(agentId: UUID(), agentName: "MockAgent")
            }
            return _spawnResults.removeFirst()
        }
    }
}

@Suite("JakeToolHandler Tests")
struct JakeToolHandlerTests {

    // MARK: - Test Helpers

    static func makeHandler(context: MockSpawnContext) -> JSONActionHandler {
        JSONActionHandler { assignment, name in
            if let error = context.spawnError {
                throw error
            }
            context.recordCall(assignment: assignment, name: name)
            return context.nextResult()
        }
    }

    // MARK: - JSON Parsing Tests

    @Test("Valid spawn action is parsed and executed")
    func validSpawnAction() async throws {
        let context = MockSpawnContext()
        let agentId = UUID()
        context.addResult(id: agentId, name: "TestAgent")

        let handler = Self.makeHandler(context: context)

        let json = """
        {"message": "I'll spawn an agent for that!", "spawn": {"assignment": "Write tests", "name": "Tester"}}
        """

        let result = try await handler.processResponse(json)

        #expect(result.displayMessage == "I'll spawn an agent for that!")
        #expect(result.toolFeedback != nil)
        #expect(result.toolFeedback!.contains("TestAgent"))
        #expect(result.toolFeedback!.contains("Write tests"))

        #expect(context.spawnCalls.count == 1)
        #expect(context.spawnCalls[0].assignment == "Write tests")
        #expect(context.spawnCalls[0].name == "Tester")
    }

    @Test("Spawn action without name passes nil")
    func spawnWithoutName() async throws {
        let context = MockSpawnContext()
        context.addResult(name: "AutoNamed")

        let handler = Self.makeHandler(context: context)

        let json = """
        {"message": "Spawning!", "spawn": {"assignment": "Do the thing"}}
        """

        let result = try await handler.processResponse(json)

        #expect(result.displayMessage == "Spawning!")
        #expect(result.toolFeedback != nil)

        #expect(context.spawnCalls.count == 1)
        #expect(context.spawnCalls[0].assignment == "Do the thing")
        #expect(context.spawnCalls[0].name == nil)
    }

    @Test("Message without spawn returns nil toolFeedback")
    func messageOnly() async throws {
        let context = MockSpawnContext()
        let handler = Self.makeHandler(context: context)

        let json = """
        {"message": "Just a regular response"}
        """

        let result = try await handler.processResponse(json)

        #expect(result.displayMessage == "Just a regular response")
        #expect(result.toolFeedback == nil)
        #expect(context.spawnCalls.isEmpty)
    }

    @Test("Invalid JSON returns raw string as display message")
    func invalidJSON() async throws {
        let context = MockSpawnContext()
        let handler = Self.makeHandler(context: context)

        let rawText = "This is not JSON at all!"

        let result = try await handler.processResponse(rawText)

        #expect(result.displayMessage == rawText)
        #expect(result.toolFeedback == nil)
        #expect(context.spawnCalls.isEmpty)
    }

    @Test("Malformed JSON returns raw string")
    func malformedJSON() async throws {
        let context = MockSpawnContext()
        let handler = Self.makeHandler(context: context)

        let malformed = """
        {"message": "incomplete
        """

        let result = try await handler.processResponse(malformed)

        #expect(result.displayMessage == malformed)
        #expect(result.toolFeedback == nil)
    }

    @Test("JSON missing required 'message' field returns raw string")
    func missingMessageField() async throws {
        let context = MockSpawnContext()
        let handler = Self.makeHandler(context: context)

        let json = """
        {"spawn": {"assignment": "Do something"}}
        """

        let result = try await handler.processResponse(json)

        // Should fail to decode because 'message' is required
        #expect(result.displayMessage == json)
        #expect(result.toolFeedback == nil)
        #expect(context.spawnCalls.isEmpty)
    }

    @Test("Spawn error returns feedback with error message")
    func spawnError() async throws {
        let context = MockSpawnContext()
        context.spawnError = AgentRegistryError.nameAlreadyExists("Duplicate")

        let handler = Self.makeHandler(context: context)

        let json = """
        {"message": "Let me spawn that", "spawn": {"assignment": "Task", "name": "Duplicate"}}
        """

        let result = try await handler.processResponse(json)

        #expect(result.displayMessage == "Let me spawn that")
        #expect(result.toolFeedback != nil)
        #expect(result.toolFeedback!.contains("Failed to spawn"))
    }

    // MARK: - Edge Cases

    @Test("Empty string returns empty display message")
    func emptyString() async throws {
        let context = MockSpawnContext()
        let handler = Self.makeHandler(context: context)

        let result = try await handler.processResponse("")

        #expect(result.displayMessage == "")
        #expect(result.toolFeedback == nil)
    }

    @Test("JSON with extra fields is still parsed")
    func extraFields() async throws {
        let context = MockSpawnContext()
        context.addResult(name: "Agent")

        let handler = Self.makeHandler(context: context)

        let json = """
        {"message": "Hello", "spawn": {"assignment": "Task"}, "extra": "ignored", "nested": {"also": "ignored"}}
        """

        let result = try await handler.processResponse(json)

        #expect(result.displayMessage == "Hello")
        #expect(result.toolFeedback != nil)
        #expect(context.spawnCalls.count == 1)
    }

    @Test("Unicode in message and assignment works correctly")
    func unicodeContent() async throws {
        let context = MockSpawnContext()
        context.addResult(name: "UniAgent")

        let handler = Self.makeHandler(context: context)

        let json = """
        {"message": "Let's go! 🚀", "spawn": {"assignment": "Handle émojis and ñ characters"}}
        """

        let result = try await handler.processResponse(json)

        #expect(result.displayMessage == "Let's go! 🚀")
        #expect(context.spawnCalls[0].assignment == "Handle émojis and ñ characters")
    }
}

// MARK: - Tool Result Tests

@Suite("ToolResult Tests")
struct ToolResultTests {

    @Test("ToolResult initializes with defaults")
    func defaultInit() {
        let result = ToolResult(displayMessage: "Hello")

        #expect(result.displayMessage == "Hello")
        #expect(result.toolFeedback == nil)
    }

    @Test("ToolResult initializes with feedback")
    func withFeedback() {
        let result = ToolResult(displayMessage: "Hello", toolFeedback: "Spawned agent")

        #expect(result.displayMessage == "Hello")
        #expect(result.toolFeedback == "Spawned agent")
    }
}
