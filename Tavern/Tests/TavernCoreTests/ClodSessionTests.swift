import Foundation
import Testing
import ClodKit
@testable import TavernCore

// MARK: - Provenance: REQ-ARCH-009, REQ-QA-002, REQ-QA-005

@Suite("ClodSession Tests", .timeLimit(.minutes(1)))
struct ClodSessionTests {

    // MARK: - Helpers

    private func makeConfig(name: String = "TestServitor") -> ClodSession.Config {
        ClodSession.Config(
            systemPrompt: "You are a test servitor.",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            servitorName: name
        )
    }

    private func makeSession(
        name: String = "TestServitor",
        mock: MockMessenger? = nil,
        initialSessionId: String? = nil
    ) -> (session: ClodSession, mock: MockMessenger) {
        let mock = mock ?? MockMessenger(responses: ["OK"])
        let config = makeConfig(name: name)
        let session = ClodSession(config: config, initialSessionId: initialSessionId, messenger: mock)
        return (session, mock)
    }

    // MARK: - Basic Send Tests

    @Test("First message has no resume", .tags(.reqARCH009))
    func firstMessageNoResume() async throws {
        let (session, mock) = makeSession()

        let _ = try await session.send("Hello")

        #expect(mock.queryOptions.count == 1)
        #expect(mock.queryOptions[0].resume == nil)
    }

    @Test("Second message resumes session", .tags(.reqARCH009))
    func secondMessageResumesSession() async throws {
        let sessionId = "sess-abc-123"
        let mock = MockMessenger(responses: ["First", "Second"], sessionId: sessionId)
        let (session, _) = makeSession(mock: mock)

        let _ = try await session.send("Message 1")
        #expect(session.sessionId == sessionId)

        let _ = try await session.send("Message 2")
        #expect(mock.queryOptions.count == 2)
        #expect(mock.queryOptions[1].resume == sessionId)
    }

    @Test("Session ID updated in memory after send", .tags(.reqARCH009))
    func sessionIdUpdatedInMemory() async throws {
        let sessionId = "sess-persist-test"
        let mock = MockMessenger(responses: ["OK"], sessionId: sessionId)
        let (session, _) = makeSession(name: "Persister", mock: mock)

        let result = try await session.send("Persist me")

        #expect(session.sessionId == sessionId)
        #expect(result.sessionId == sessionId)
    }

    // MARK: - Resume-with-Fallback (send)

    @Test("Stale session falls back to fresh", .tags(.reqARCH009, .reqQA005))
    func staleSessionFallsBackToFresh() async throws {
        let staleId = "stale-session-id"
        let freshId = "fresh-session-id"
        let mock = MockMessenger(responses: ["Recovered"], sessionId: freshId)
        mock.staleSessionError = ControlProtocolError.timeout(requestId: "req-1")

        let (session, _) = makeSession(name: "FallbackTest", mock: mock, initialSessionId: staleId)

        #expect(session.sessionId == staleId)

        let result = try await session.send("Trigger fallback")

        #expect(result.didFallback == true)
        #expect(result.response == "Recovered")
        #expect(result.expiredSessionId == staleId)
        #expect(session.sessionId == freshId)
    }

    @Test("Fallback returns expired session ID for caller persistence", .tags(.reqARCH009))
    func fallbackReturnsExpiredSessionId() async throws {
        let staleId = "expired-sess"
        let mock = MockMessenger(responses: ["OK"], sessionId: "new-sess")
        mock.staleSessionError = ControlProtocolError.timeout(requestId: "req-1")

        let (session, _) = makeSession(name: "ExpiredLogger", mock: mock, initialSessionId: staleId)
        let result = try await session.send("Trigger")

        #expect(result.expiredSessionId == staleId)
        #expect(result.didFallback == true)
        #expect(session.sessionId == "new-sess")
    }

    @Test("Non-stale error propagates without fallback")
    func nonStaleErrorPropagates() async throws {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("not a timeout")

        let (session, _) = makeSession(mock: mock)

        do {
            let _ = try await session.send("Trigger error")
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is TavernError)
        }
    }

    // MARK: - Resume-with-Fallback (streaming)

    @Test("Streaming stale session yields sessionBreak then content", .tags(.reqARCH009))
    func streamingStaleSessionFallback() async throws {
        let staleId = "stale-stream-sess"
        let freshId = "fresh-stream-sess"
        let mock = MockMessenger(responses: ["wasted", "Recovered content"], sessionId: freshId)
        mock.staleSessionError = ControlProtocolError.timeout(requestId: "req-stream")

        let (session, _) = makeSession(name: "StreamFallback", mock: mock, initialSessionId: staleId)

        let (stream, _) = session.sendStreaming("Stream me")

        var events: [StreamEvent] = []
        for try await event in stream {
            events.append(event)
        }

        // Should have: sessionBreak, textDelta(s), completed
        let breakEvents = events.filter {
            if case .sessionBreak = $0 { return true }
            return false
        }
        #expect(breakEvents.count == 1)
        if case .sessionBreak(let id) = breakEvents[0] {
            #expect(id == staleId)
        }

        let textEvents = events.filter {
            if case .textDelta = $0 { return true }
            return false
        }
        #expect(!textEvents.isEmpty)

        let completedEvents = events.filter {
            if case .completed = $0 { return true }
            return false
        }
        #expect(completedEvents.count == 1)
    }

    // MARK: - Reset Conversation

    @Test("Reset clears in-memory session ID", .tags(.reqARCH009))
    func resetClearsSession() async throws {
        let sessionId = "active-sess"
        let mock = MockMessenger(responses: ["OK"], sessionId: sessionId)
        let (session, _) = makeSession(name: "ResetTest", mock: mock)

        let _ = try await session.send("Establish")
        #expect(session.sessionId == sessionId)

        session.resetConversation()
        #expect(session.sessionId == nil)
    }

    @Test("Reset with no active session is safe")
    func resetWithNoActiveSession() async throws {
        let (session, _) = makeSession(name: "NoSessReset")

        session.resetConversation()
        #expect(session.sessionId == nil)
    }

    // MARK: - Permission Mode Mapping

    @Test("All permission modes map correctly", .tags(.reqOPM001, .reqOPM002))
    func permissionModeMapping() {
        #expect(ClodSession.mapPermissionMode(.normal) == .default)
        #expect(ClodSession.mapPermissionMode(.acceptEdits) == .acceptEdits)
        #expect(ClodSession.mapPermissionMode(.plan) == .plan)
        #expect(ClodSession.mapPermissionMode(.bypassPermissions) == .bypassPermissions)
        #expect(ClodSession.mapPermissionMode(.dontAsk) == .dontAsk)
    }

    @Test("Permission mode included in query options", .tags(.reqOPM001))
    func permissionModeInQueryOptions() async throws {
        let mock = MockMessenger(responses: ["OK"])
        let (session, _) = makeSession(mock: mock)

        let _ = try await session.send("Test plan mode")
        #expect(mock.queryOptions[0].permissionMode == .plan)

        session.permissionMode = .bypassPermissions
        let _ = try await session.send("Test bypass mode")
        #expect(mock.queryOptions[1].permissionMode == .bypassPermissions)
    }

    // MARK: - Session Restoration

    @Test("Session ID passed via initialSessionId", .tags(.reqARCH009))
    func sessionIdFromInitialParam() {
        let existingId = "pre-existing-session"
        let (session, _) = makeSession(name: "Restored", initialSessionId: existingId)

        #expect(session.sessionId == existingId)
    }

    @Test("System prompt can be updated")
    func systemPromptUpdatable() {
        let (session, _) = makeSession()

        #expect(session.systemPrompt == "You are a test servitor.")

        session.systemPrompt = "Updated prompt"
        #expect(session.systemPrompt == "Updated prompt")
    }
}
