import Foundation
import Testing
import ClodKit
@testable import TavernCore

// MARK: - Provenance: REQ-ARCH-009, REQ-QA-002, REQ-QA-005

@Suite("ClodSession Tests", .timeLimit(.minutes(1)))
struct ClodSessionTests {

    // MARK: - Helpers

    private func makeStore() throws -> ServitorStore {
        try TestFixtures.createTestStore()
    }

    private func makeConfig(name: String = "TestServitor") -> ClodSession.Config {
        ClodSession.Config(
            systemPrompt: "You are a test servitor.",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            servitorName: name
        )
    }

    /// Create a ClodSession with a pre-saved record so persistence works.
    private func makeSession(
        name: String = "TestServitor",
        store: ServitorStore? = nil,
        mock: MockMessenger? = nil,
        sessionId: String? = nil
    ) throws -> (session: ClodSession, store: ServitorStore, mock: MockMessenger) {
        let store = try store ?? makeStore()
        let mock = mock ?? MockMessenger(responses: ["OK"])

        // Pre-save a record so the session can persist against it
        let record = ServitorRecord(name: name, sessionId: sessionId)
        try store.save(record)

        let config = makeConfig(name: name)
        let session = ClodSession(config: config, store: store, messenger: mock)
        return (session, store, mock)
    }

    // MARK: - Basic Send Tests

    @Test("First message has no resume", .tags(.reqARCH009))
    func firstMessageNoResume() async throws {
        let (session, _, mock) = try makeSession()

        let _ = try await session.send("Hello")

        #expect(mock.queryOptions.count == 1)
        #expect(mock.queryOptions[0].resume == nil)
    }

    @Test("Second message resumes session", .tags(.reqARCH009))
    func secondMessageResumesSession() async throws {
        let sessionId = "sess-abc-123"
        let mock = MockMessenger(responses: ["First", "Second"], sessionId: sessionId)
        let (session, _, _) = try makeSession(mock: mock)

        let _ = try await session.send("Message 1")
        #expect(session.sessionId == sessionId)

        let _ = try await session.send("Message 2")
        #expect(mock.queryOptions.count == 2)
        #expect(mock.queryOptions[1].resume == sessionId)
    }

    @Test("Session ID persisted to store after send", .tags(.reqARCH009))
    func sessionIdPersistedToStore() async throws {
        let sessionId = "sess-persist-test"
        let mock = MockMessenger(responses: ["OK"], sessionId: sessionId)
        let (session, store, _) = try makeSession(name: "Persister", mock: mock)

        let _ = try await session.send("Persist me")

        let record = try store.load(name: "Persister")
        #expect(record?.sessionId == sessionId)
        #expect(session.sessionId == sessionId)
    }

    // MARK: - Resume-with-Fallback (send)

    @Test("Stale session falls back to fresh", .tags(.reqARCH009, .reqQA005))
    func staleSessionFallsBackToFresh() async throws {
        let staleId = "stale-session-id"
        let freshId = "fresh-session-id"
        let mock = MockMessenger(responses: ["Recovered"], sessionId: freshId)
        mock.staleSessionError = ControlProtocolError.timeout(requestId: "req-1")

        let (session, store, _) = try makeSession(name: "FallbackTest", mock: mock, sessionId: staleId)

        // Session starts with the stale ID (loaded from store)
        #expect(session.sessionId == staleId)

        let result = try await session.send("Trigger fallback")

        #expect(result.didFallback == true)
        #expect(result.response == "Recovered")
        #expect(session.sessionId == freshId)

        // Store should have the fresh session
        let record = try store.load(name: "FallbackTest")
        #expect(record?.sessionId == freshId)
    }

    @Test("Stale session logs expired event", .tags(.reqARCH009))
    func staleSessionLogsExpiredEvent() async throws {
        let staleId = "expired-sess"
        let mock = MockMessenger(responses: ["OK"], sessionId: "new-sess")
        mock.staleSessionError = ControlProtocolError.timeout(requestId: "req-1")

        let (session, store, _) = try makeSession(name: "ExpiredLogger", mock: mock, sessionId: staleId)
        let _ = try await session.send("Trigger")

        let events = try store.loadSessionEvents(name: "ExpiredLogger")
        let expiredEvents = events.filter { $0.event == .sessionExpired }
        #expect(expiredEvents.count == 1)
        #expect(expiredEvents[0].sessionId == staleId)
        #expect(expiredEvents[0].reason == "timeout")
    }

    @Test("Non-stale error propagates without fallback")
    func nonStaleErrorPropagates() async throws {
        let mock = MockMessenger()
        mock.errorToThrow = TavernError.internalError("not a timeout")

        let (session, _, _) = try makeSession(mock: mock)

        do {
            let _ = try await session.send("Trigger error")
            Issue.record("Expected error to be thrown")
        } catch {
            // Should propagate the original error
            #expect(error is TavernError)
        }
    }

    // MARK: - Resume-with-Fallback (streaming)

    @Test("Streaming stale session yields sessionBreak then content", .tags(.reqARCH009))
    func streamingStaleSessionFallback() async throws {
        let staleId = "stale-stream-sess"
        let freshId = "fresh-stream-sess"
        // Two responses: first gets consumed by the stale call (then thrown away), second for retry
        let mock = MockMessenger(responses: ["wasted", "Recovered content"], sessionId: freshId)
        mock.staleSessionError = ControlProtocolError.timeout(requestId: "req-stream")

        let (session, _, _) = try makeSession(name: "StreamFallback", mock: mock, sessionId: staleId)

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

        // Should have text content from the recovery
        let textEvents = events.filter {
            if case .textDelta = $0 { return true }
            return false
        }
        #expect(!textEvents.isEmpty)

        // Should have completion
        let completedEvents = events.filter {
            if case .completed = $0 { return true }
            return false
        }
        #expect(completedEvents.count == 1)
    }

    // MARK: - Reset Conversation

    @Test("Reset clears session and logs break event", .tags(.reqARCH009))
    func resetClearsSessionAndLogsBreak() async throws {
        let sessionId = "active-sess"
        let mock = MockMessenger(responses: ["OK"], sessionId: sessionId)
        let (session, store, _) = try makeSession(name: "ResetTest", mock: mock)

        // Send a message to establish a session
        let _ = try await session.send("Establish")
        #expect(session.sessionId == sessionId)

        // Reset
        session.resetConversation(reason: "user_cleared")

        #expect(session.sessionId == nil)

        // Store should have nil session
        let record = try store.load(name: "ResetTest")
        #expect(record?.sessionId == nil)

        // Session events should include a break
        let events = try store.loadSessionEvents(name: "ResetTest")
        let breakEvents = events.filter { $0.event == .break }
        #expect(breakEvents.count == 1)
        #expect(breakEvents[0].reason == "user_cleared")

        // Should also have a session_ended event
        let endedEvents = events.filter { $0.event == .sessionEnded }
        #expect(endedEvents.count == 1)
        #expect(endedEvents[0].sessionId == sessionId)
    }

    @Test("Reset with no active session logs break only")
    func resetWithNoActiveSession() async throws {
        let (session, store, _) = try makeSession(name: "NoSessReset")

        session.resetConversation()

        let events = try store.loadSessionEvents(name: "NoSessReset")
        let breakEvents = events.filter { $0.event == .break }
        #expect(breakEvents.count == 1)

        // No session_ended since there was no active session
        let endedEvents = events.filter { $0.event == .sessionEnded }
        #expect(endedEvents.count == 0)
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
        let (session, _, _) = try makeSession(mock: mock)

        // Default is .plan from makeConfig
        let _ = try await session.send("Test plan mode")
        #expect(mock.queryOptions[0].permissionMode == .plan)

        // Change to bypassPermissions
        session.permissionMode = .bypassPermissions
        let _ = try await session.send("Test bypass mode")
        #expect(mock.queryOptions[1].permissionMode == .bypassPermissions)
    }

    // MARK: - Session Restoration

    @Test("Session ID loaded from store on init", .tags(.reqARCH009))
    func sessionIdLoadedFromStore() async throws {
        let store = try makeStore()
        let existingId = "pre-existing-session"

        // Save a record with a session ID
        let record = ServitorRecord(name: "Restored", sessionId: existingId)
        try store.save(record)

        let config = makeConfig(name: "Restored")
        let session = ClodSession(config: config, store: store, messenger: MockMessenger())

        #expect(session.sessionId == existingId)
    }

    @Test("System prompt can be updated")
    func systemPromptUpdatable() throws {
        let (session, _, _) = try makeSession()

        #expect(session.systemPrompt == "You are a test servitor.")

        session.systemPrompt = "Updated prompt"
        #expect(session.systemPrompt == "Updated prompt")
    }
}
