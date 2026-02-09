import Foundation
import Testing
@testable import TavernCore

@Suite("TavernErrorMessages Tests")
struct TavernErrorMessagesTests {

    // MARK: - Exhaustive coverage: every TavernError case produces a non-empty message

    @Test("sessionCorrupt produces actionable message")
    func sessionCorruptMessage() {
        let error = TavernError.sessionCorrupt(sessionId: "test-123", underlyingError: nil)
        let message = TavernErrorMessages.message(for: error)
        #expect(!message.isEmpty)
        #expect(message.contains("test-123"))
        #expect(message.contains("Start Fresh"))
    }

    @Test("agentNameConflict produces actionable message")
    func agentNameConflictMessage() {
        let error = TavernError.agentNameConflict(name: "Marcos Antonio")
        let message = TavernErrorMessages.message(for: error)
        #expect(!message.isEmpty)
        #expect(message.contains("Marcos Antonio"))
        #expect(message.contains("already taken"))
    }

    @Test("commitmentTimeout produces actionable message")
    func commitmentTimeoutMessage() {
        let error = TavernError.commitmentTimeout(commitmentId: "commit-456")
        let message = TavernErrorMessages.message(for: error)
        #expect(!message.isEmpty)
        #expect(message.contains("commit-456"))
        #expect(message.contains("timed out"))
    }

    @Test("mcpServerFailed produces actionable message")
    func mcpServerFailedMessage() {
        let error = TavernError.mcpServerFailed(reason: "port already in use")
        let message = TavernErrorMessages.message(for: error)
        #expect(!message.isEmpty)
        #expect(message.contains("port already in use"))
    }

    @Test("permissionDenied produces actionable message")
    func permissionDeniedMessage() {
        let error = TavernError.permissionDenied(toolName: "bash")
        let message = TavernErrorMessages.message(for: error)
        #expect(!message.isEmpty)
        #expect(message.contains("bash"))
        #expect(message.contains("permission"))
    }

    @Test("commandNotFound produces actionable message")
    func commandNotFoundMessage() {
        let error = TavernError.commandNotFound(name: "foo")
        let message = TavernErrorMessages.message(for: error)
        #expect(!message.isEmpty)
        #expect(message.contains("/foo"))
        #expect(message.contains("/help"))
    }

    @Test("internalError produces actionable message")
    func internalErrorMessage() {
        let error = TavernError.internalError("unexpected nil")
        let message = TavernErrorMessages.message(for: error)
        #expect(!message.isEmpty)
        #expect(message.contains("unexpected nil"))
    }

    // MARK: - TavernError routed through generic message(for: Error)

    @Test("TavernError cases route correctly through generic handler")
    func genericHandlerRoutesTavernError() {
        let errors: [TavernError] = [
            .sessionCorrupt(sessionId: "s1", underlyingError: nil),
            .agentNameConflict(name: "n1"),
            .commitmentTimeout(commitmentId: "c1"),
            .mcpServerFailed(reason: "r1"),
            .permissionDenied(toolName: "t1"),
            .commandNotFound(name: "cmd1"),
            .internalError("msg1"),
        ]

        for error in errors {
            let direct = TavernErrorMessages.message(for: error)
            let generic = TavernErrorMessages.message(for: error as Error)
            #expect(direct == generic, "Mismatch for \(error)")
        }
    }

    // MARK: - errorDescription (LocalizedError conformance)

    @Test("All TavernError cases have non-empty errorDescription")
    func allCasesHaveErrorDescription() {
        let errors: [TavernError] = [
            .sessionCorrupt(sessionId: "s", underlyingError: nil),
            .agentNameConflict(name: "n"),
            .commitmentTimeout(commitmentId: "c"),
            .mcpServerFailed(reason: "r"),
            .permissionDenied(toolName: "t"),
            .commandNotFound(name: "x"),
            .internalError("m"),
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Missing errorDescription for \(error)")
            #expect(!error.errorDescription!.isEmpty, "Empty errorDescription for \(error)")
        }
    }
}
