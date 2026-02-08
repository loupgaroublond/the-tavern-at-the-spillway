# Transcript: Autonomous Testing Infrastructure Implementation

**Date:** 2026-02-08
**Session type:** Implementation (multi-session, 2 context windows)
**Topics:** Graded testing system, MockAgent, MockMessenger protocol extraction, ViewInspector wiring tests, XCUITest setup, ADRs, ClodKit SDK merge


---


## Mandate

**[U]** Implement the following plan: [Autonomous Testing Infrastructure plan — 6 phases, ~85 new tests establishing a graded testing system (Grades 1-5) so Claude can autonomously verify end-to-end correctness without a human in the loop. All work in `autonomous-testing` worktree.]

*Key principles from the plan: Grade 3 (real Claude) tests first as source of truth. Grade 2 mocks are optimization layer on top. E2E never mocks. Any test that steals focus = Grade 4.*


---


## Phase 1: Grade 3 Integration Tests

**[C]** Created `TavernIntegrationTests` SPM test target with 32 tests across 4 files:
- `JakeIntegrationTests.swift` — 8 tests (responds, state changes, session ID, fallback, errors, MCP passthrough, summon, multi-summon)
- `ServitorIntegrationTests.swift` — 11 tests (responds, state tracking, done/waiting transitions, conversation, errors, commitments, verification pass/fail)
- `ChatViewModelIntegrationTests.swift` — 7 tests (send adds messages, input clears, cogitating state/verb, error capture, accumulation, servitor send)
- `CoordinatorIntegrationTests.swift` — 6 tests (history preserved, servitor chat, both histories, summon creates/names, failure reports)

All call real Claude via ClodKit SDK. No mocks.


## Phase 2a: MockAgent

**[C]** Created `MockAgent` conforming to `Agent` protocol. Returns canned responses, tracks calls, can throw errors. Unlocked 9 Grade 2 tests in `ChatViewModelTests` and `TavernCoordinatorTests` — same assertions as Grade 3 but fast and offline.


## Phase 2b: MockMessenger (Protocol Extraction)

**[C]** Extracted `AgentMessenger` protocol from the SDK coupling point. Three types:
- `AgentMessenger` protocol — `func query(prompt:options:) async throws -> (response: String, sessionId: String?)`
- `LiveMessenger` — wraps `Clod.query()`, iterates the `ClaudeQuery` AsyncSequence, extracts response text + session ID. Jake's version (handles both `result` and `assistant` message types) became the canonical implementation.
- `MockMessenger` — returns canned responses with configurable delay and errors

Modified `Jake.swift` and `Servitor.swift`: added `messenger` parameter to init, defaulting to `LiveMessenger()`. Replaced direct `Clod.query()` calls with `messenger.query()`. Production behavior unchanged.

Unlocked 23 Grade 2 tests: 8 Jake, 11 Servitor, 4 Coordinator.


## Phase 3: ViewInspector Wiring Tests

**[C]** Added ViewInspector as SPM dependency. Created wiring tests verifying SwiftUI views are correctly bound to ViewModels:
- `ChatViewWiringTests.swift` — 7 tests (input field, send button disabled states, cogitation indicator, header name, message count, session recovery banner)
- `AgentListViewWiringTests.swift` — 5 tests (list exists, spawn button, Jake appears, Jake selected, selection binding)

Added accessibility identifiers to `ChatView.swift` and `AgentListView.swift` to support inspection.


## Phase 4: XCUITest Setup

**[C]** Added `TavernUITests` target to `project.yml`. Modified `TavernApp.swift` to support `--ui-testing` and `--project-path` launch arguments for deterministic test setup. Created:
- `SmokeTests.swift` — 4 tests (app launches, Jake in sidebar, input field exists, can type)
- `E2ETests.swift` — 4 tests (send/receive, spawn agent, switch agents, close agent)


## Phase 5: Test Runner Scripts

**[C]** Created redo scripts per grade:
- `test.do` — Grade 1+2 (skips integration and stress)
- `test-grade3.do` — Grade 3 integration tests only
- `test-grade4.do` — XCUITest via xcodebuild
- `test-all.do` — Grade 1+2+3 combined


## Phase 6: ADRs

**[C]** Created 4 Architecture Decision Records in `docs/3-adr/`:
- ADR-002: Testing Grade System
- ADR-003: Agent Mocking Strategy
- ADR-004: View Wiring Testing with ViewInspector
- ADR-005: XCUITest Strategy


---


## SDK Rename Merge

**[U]** Can you pull down the latest content from main? We changed the name of the SDK and that's been pushed up already.

**[C]** Merged local main into autonomous-testing. Main had renamed `ClodeMonster → ClodKit` and reorganized docs (`docs/architecture-proposals/` → `docs/3-adr/`). Four merge conflicts resolved:
1. `Package.swift` — kept ClodKit + added ViewInspector
2. `Jake.swift` — kept `import ClodKit` + messenger abstraction
3. `Servitor.swift` — same pattern
4. `JakeTests.swift` — kept implemented mock tests (not the commented-out stubs from main)

Propagated SDK rename through all new files: `AgentMessenger.swift`, all integration test files.


---


## Verification

**[U]** You haven't verified the tests work yet? Let's do that.

**[C]** First build attempt: ViewInspector URL was wrong (`nicklama` → `nalexn`). Fixed. Second: `AppIcon.icon` missing (not tracked in git). Copied from main worktree. Third: `TavernError.internalError` API changed — no `message:` label. Fixed in 4 test files. Fourth: Swift 6 Sendable violations in integration tests. Fixed with `nonisolated(unsafe)`.

TavernCoreTests: 187 tests, 1 failure — `jakeWrapsErrorsAsSessionCorrupt`. Bug: `Self.testProjectURL()` generates a new UUID per call. Session saved to path A, Jake loaded from path B. Fixed by capturing URL in local variable. Re-ran: 187/187 passed.

TavernTests: 31/31 passed (including all ViewInspector wiring tests).

**[U]** Have you run all the integration tests that use Claude itself?

**[U]** Everything you're going to commit must work, so eventually you have to test it.

**[C]** Ran TavernIntegrationTests. 32/32 passed (~4 minutes, all hitting real Claude).

**[U]** Do all the tests have timeouts?

**[U]** Duh.

**[C]** Added `executionTimeAllowance = 60` to all 4 integration test classes. Re-ran: 32/32 passed. No test came close to the 60s limit (longest ~21s).

**Final count: 250 tests, all green.**
- TavernCoreTests (Grade 1+2): 187
- TavernTests (wiring + SDK): 31
- TavernIntegrationTests (Grade 3): 32


---


## Key Bugs Found During Implementation

1. **ViewInspector URL** — `nicklama` should be `nalexn` (the actual author)
2. **TavernError.internalError API** — parameter label `message:` was removed; now positional
3. **testProjectURL() UUID freshness** — static helper generates new UUID per call; must capture in local variable when used across save/load/cleanup
4. **Swift 6 Sendable** — vars captured in `@Sendable` closures need `nonisolated(unsafe)` for test-only mutation tracking
5. **No timeouts on integration tests** — tests calling real Claude could hang forever; added 60s `executionTimeAllowance`
