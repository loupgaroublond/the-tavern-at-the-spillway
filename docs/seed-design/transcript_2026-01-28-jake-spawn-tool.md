# Transcript: Jake Spawn Agent Tool Implementation
**Date:** 2026-01-28

---

## Part 1: Implementation Plan

**[U]** *Provided detailed implementation plan for Jake's spawn agent tool:*

Key architectural decisions from the plan:
- **Swappable design**: Protocol-based `JakeToolHandler` to allow future migration from JSON-based parsing to native SDK tools
- **Continuation loop**: Tool execution uses feedback mechanism where Jake receives tool results and can continue
- **Optional injection**: `toolHandler` is optional on Jake, allowing feature to be disabled or swapped

Architecture diagram from plan:
```
┌─────────────────────────────────────────────────────┐
│  Jake.send()                                        │
│    │                                                │
│    ▼                                                │
│  ┌─────────────────────┐                            │
│  │ JakeToolHandler     │ ◄── Protocol (swappable)   │
│  │ (protocol)          │                            │
│  └─────────────────────┘                            │
│           │                                         │
│           ▼                                         │
│  ┌─────────────────────┐      Future:               │
│  │ JSONActionHandler   │      ┌──────────────────┐  │
│  │ (current impl)      │  ──► │ NativeToolHandler│  │
│  └─────────────────────┘      │ (SDK upgrade)    │  │
│                               └──────────────────────┘
└─────────────────────────────────────────────────────┘
```

---

## Part 2: Implementation

**[C]** *Implemented the plan across these files:*

**JakeToolHandler.swift** (new):
```swift
public protocol JakeToolHandler: Sendable {
    func processResponse(_ response: String) async throws -> ToolResult
}

public struct ToolResult: Sendable {
    public let displayMessage: String
    public let toolFeedback: String?  // nil = done
}

public final class JSONActionHandler: JakeToolHandler {
    // Parses {"message": "...", "spawn": {"assignment": "...", "name": "..."}}
}
```

**Jake.swift** — Added tool handler integration:
```swift
public var toolHandler: JakeToolHandler?

public func send(_ message: String) async throws -> String {
    // ... existing Claude call ...
    let rawResponse = extractResponse(from: result)

    guard let handler = toolHandler else {
        return rawResponse  // Path 1: No handler
    }

    var toolResult = try await handler.processResponse(rawResponse)

    while let feedback = toolResult.toolFeedback {
        let continuation = try await sendContinuation(feedback)
        toolResult = try await handler.processResponse(extractResponse(from: continuation))
    }

    return toolResult.displayMessage  // Path 2: With handler
}
```

**TavernCoordinator.swift** — Wired handler to spawner:
```swift
private func setupJakeToolHandler() {
    let handler = JSONActionHandler { [weak self] assignment, name in
        // Spawn via coordinator
        let agent = try coordinator.spawner.spawn(...)

        // Update UI on MainActor
        await MainActor.run {
            coordinator.persistAgent(agent)
            coordinator.agentListViewModel.agentsDidChange()
        }

        return SpawnResult(agentId: agent.id, agentName: agent.name)
    }
    jake.toolHandler = handler
}
```

---

## Part 3: Issues and Fixes

**Issue 1: Actor Isolation**

**[C]** "I have several issues to fix:
1. The TavernCoordinator spawn closure needs to run on MainActor
2. TavernErrorMessages needs the new internalError case
3. ChatViewModel needs the new internalError case"

**[C]** "Now I need to fix the TavernCoordinator actor isolation issue. The spawn closure is called from a non-MainActor context but needs to access MainActor-isolated methods."

*Solution: Used `MainActor.run` block for UI updates.*

**Issue 2: Test State Pollution**

**[C]** "The tests are failing because TavernCoordinator's `init` calls `restoreAgents()` which loads from UserDefaults. The tests are picking up persisted agents from previous runs. I need to clear persisted state in the tests."

*Solution: Added `SessionStore.clearAgentList()` and `createIsolatedCoordinator()` helper.*

---

## Part 4: Testing Principles Review

**[U]** do all the tests meet our standards about testing all the code paths?

**[C]** No, the tests do not meet our standards. Here's the gap analysis:

### Testing Principles Violations

**Principle #1: Parallel Code Path Testing**

Jake.send() now has two paths that aren't both tested:

| Code Path | Tested? |
|-----------|---------|
| No tool handler → returns rawResponse | ✅ All existing JakeTests |
| Tool handler, no feedback → returns displayMessage | ❌ |
| Tool handler with feedback → continuation loop | ❌ |
| Multiple feedbacks → loop iterates | ❌ |

**Principle #2: Feature Toggle Coverage**

toolHandler is nil in all Jake tests. No tests exercise Jake WITH a tool handler configured.

**Principle #3: User Journey Integration Tests**

Missing: User asks Jake to delegate work → Jake spawns agent → agent appears in sidebar

**Principle #5: New Entity = New Test Coverage**

JakeToolHandler is tested in isolation, but Jake's integration with it is NOT tested.

---

## Part 5: Tests Added

**[C]** *Following the principles, added 8 tests:*

**JakeTests.swift** (4 tests for Principle #1):
- `jakeWithToolHandlerPassthrough` — Tool handler returns nil feedback
- `jakeWithToolHandlerSpawnAndContinue` — Single spawn with continuation
- `jakeToolHandlerMultipleSpawns` — Loop continues for multiple spawns
- `jakeWithoutToolHandlerReturnsRaw` — Symmetry: raw JSON returned without handler

**TavernCoordinatorTests.swift** (4 tests for Principle #3):
- `jakeToolHandlerConfigured` — Handler wired up on init
- `jakeSpawnActionCreatesAgent` — Full user journey: ask → spawn → appears
- `jakeSpawnActionWithName` — Named spawn uses specified name
- `jakeSpawnFailureReportsError` — Duplicate name error in feedback

---

## Part 6: Two-Level Agent Orchestration Model

**[C]** *After implementing the spawn tool, realized Jake's system prompt needed explicit guidance on when to use spawn (Tavern agents) vs the Task tool (subagents):*

Added to Jake's system prompt:
```
AGENT ORCHESTRATION MODEL:
You operate a two-level agent system:

Level 1 - Tavern Agents (via spawn action):
- Full Claude Code sessions with their own context
- Appear in sidebar, persist across sessions
- For substantial, independent work streams
- Use your JSON spawn action to create these

Level 2 - Subagents (via Task tool):
- Internal parallel workers within any agent's session
- Lightweight, ephemeral, don't persist
- For quick parallel tasks within a single work stream
- Any agent (including you) can spawn these directly via Task tool

When to use which:
- Spawn Tavern agent: "Help me build feature X" (substantial, tracked work)
- Use Task tool: "Search these 5 files in parallel" (quick, internal parallelism)
```

*[T] The distinction matters because Jake has access to BOTH mechanisms. Without explicit guidance, he might spawn a persistent Tavern agent for a quick search, or use an ephemeral Task subagent for substantial work that should be tracked.*

---

## Part 7: ChatHeader Component

**[U]** "that button looks like you would use it to add a file to the session, make it look different and put it in a different location"

**[C]** "You're right. Let me move it to a header area and use a compose/reset style icon instead."

*Moved "New Conversation" from input bar to a header component:*

```swift
private struct ChatHeader: View {
    let agentName: String
    let isEnabled: Bool
    let onNewConversation: () -> Void

    var body: some View {
        HStack {
            Text(agentName)
                .font(.headline)
            Spacer()
            Button(action: onNewConversation) {
                Image(systemName: "square.and.pencil")
            }
            .disabled(!isEnabled)
            .help("New Conversation")
        }
    }
}
```

*[T] The `square.and.pencil` icon matches Apple's compose convention (Messages, Mail). Header placement makes it discoverable without cluttering the input area.*

---

## Synthesis

*[S] The swappable design isolates tool handling behind a protocol. When the Swift SDK catches up to Python/TypeScript with native tool support, we swap `JSONActionHandler` for `NativeToolHandler` without touching Jake's core logic.*

*[S] Testing review after implementation caught missing coverage. The principles work: "does this code path have a test?" is a concrete question with a verifiable answer.*

*[S] Test count: 192 → 200 tests. The 8 new tests cover both the WITH and WITHOUT handler paths, plus user journey integration.*

*[S] Two-level orchestration — Tavern agents for tracked work, Task subagents for ephemeral parallelism — gives Jake clear guidance on which mechanism to use. The user sees Tavern agents in the sidebar; subagents are invisible implementation details.*
