# ADR-003: Agent Mocking Strategy

**Status:** Accepted
**Date:** 2026-02-07
**Context:** Enabling fast, offline testing of agent-dependent code without calling real Claude


## Decision

Two mocking layers, each targeting a different level of the architecture:

### 1. MockAgent (ViewModel-level)

`MockAgent` conforms to the `Agent` protocol and returns canned responses. Used for testing `ChatViewModel` and `TavernCoordinator` without any SDK dependency.

```swift
public final class MockAgent: Agent, @unchecked Sendable {
    public var responses: [String]       // Pops from front on each send()
    public var errorToThrow: Error?      // Throws instead of returning
    public var sendCalls: [String]       // Captured for verification
    public var resetCalled: Bool         // Tracks resetConversation calls
}
```

**Unblocks:** 7 ChatViewModel tests + 2 Coordinator tests = 9 tests (Grade 2)

### 2. AgentMessenger Protocol (SDK-level)

Extracted from the direct `ClaudeCode.query()` + stream collection calls in Jake and Servitor. The `AgentMessenger` protocol abstracts the SDK boundary:

```swift
public protocol AgentMessenger: Sendable {
    func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?)
}
```

- `LiveMessenger` — Production implementation. Calls `ClaudeCode.query()`, iterates the `AsyncSequence`, extracts response text and session ID.

- `MockMessenger` — Test double. Returns canned responses, tracks calls, supports configurable delays and errors.

Jake and Servitor accept an `AgentMessenger` via constructor injection, defaulting to `LiveMessenger()`. No existing call sites change.

**Unblocks:** 8 Jake tests + 11 Servitor tests + 4 Coordinator tests = 23 tests (Grade 2)


## Context

The 33 blocked tests all depended on `ClaudeCode.query()` — a static function on the ClodeMonster SDK that makes real API calls. There was no seam for testing.

The key insight: **Grade 3 integration tests (real Claude) are the source of truth. Mocks are an optimization layer on top — they can never be more correct than the real thing.** Therefore:

1. All 33 tests were first implemented as Grade 3 integration tests (Phase 1).
2. Mock infrastructure was then built as a Grade 2 mirror (Phase 2).
3. Both coexist: Grade 3 validates correctness, Grade 2 provides speed.


## Alternatives Considered

- **Subclassing ClaudeCode**: Not possible — it's a struct with static methods.

- **Environment-based switching**: A global `useMocks` flag would be fragile and leak into production code.

- **Protocol on ClaudeCode itself**: Would require modifying the SDK. Constructor injection on our own types is simpler.


## Consequences

- **Production code changes**: Jake.swift and Servitor.swift gain a `messenger` parameter. `LiveMessenger` preserves exact existing behavior. The removed `collectResponse()` methods were private and their logic now lives in `LiveMessenger.query()`.

- **No behavior change**: Default parameter means all existing `Jake(projectURL:)` and `Servitor(...)` call sites work unchanged.

- **Testing seam**: Any future agent type that calls the SDK should accept `AgentMessenger` for testability.
