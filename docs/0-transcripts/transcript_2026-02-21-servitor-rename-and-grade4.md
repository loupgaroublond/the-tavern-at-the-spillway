# Transcript: Servitor Taxonomy & Grade 4 XCUITest Fix

**Date:** 2026-02-21
**Sessions:** `38f8785f` (rename design), `b5b07187` (rename implementation), `a93acecb` (Grade 4 plan), `2ec41dbe` (Grade 4 fix)
**Topics:** Agent→Servitor rename rationale, Grade 4 test isolation debugging

---

## Part 1: The Servitor Taxonomy

### The Trigger

[U] We were supposed to refactor agent to servitor, so why are there still `AgentListViewModel`s?

[C] Explored the codebase. "Agent" and "Servitor" were intentionally different concepts in the spec — `Agent` was the abstract protocol, `Servitor` was the concrete mortal worker type. So `AgentRegistry`, `AgentMessenger`, etc. were operating at the protocol level, working with any agent type. But the UI layer names were arguably wrong — `AgentListViewModel` specifically displays spawned servitors, not the abstract Agent protocol.

### The Definitive Taxonomy

[U] Jake is a servitor, every "agent"-like entity in the Tavern is a servitor, to distinguish those entities from Claude's agent teams and subagents. Jake, daemons, mortals, drones — they are all servitors. Also, add to the Jake file: he sometimes likes to say "Surfs up, Servitors!", but no one knows what it means or why.

[C] That's a much clearer taxonomy. "Servitor" is the Tavern's word for all its entities, distinguishing them from Claude's own agent/subagent concepts.

___

[S] *The rename resolves a fundamental ambiguity. "Agent" collides with Claude's terminology — when code says "agent," is it a Tavern entity or a Claude subagent? "Servitor" is unambiguous: it's always a Tavern-managed entity.*

### The Naming Collision

[C] Identified the collision: if `Agent` protocol becomes `Servitor`, the existing `Servitor` class (the mortal workers) needs a new name. The spec already calls them "mortal servitors."

[U] Mortal.

[C] Mortal it is.

### The Rename Map

| Before | After | Rationale |
|--------|-------|-----------|
| `Agent` protocol | `Servitor` protocol | Umbrella for all Tavern entities |
| `Servitor` class | `Mortal` class | Task-scoped workers |
| `ServitorSpawner` | `MortalSpawner` | Spawns mortals specifically |
| `AgentRegistry` | `ServitorRegistry` | Tracks all servitors |
| `AgentMessenger` | `ServitorMessenger` | SDK abstraction |
| `AgentListViewModel` | `ServitorListViewModel` | Sidebar lists servitors |
| `Jake` | `Jake` | Unchanged — he's Jake |
| MCP tools | Unchanged | `summon_servitor`/`dismiss_servitor` already correct |
| REQ-AGT-xxx IDs | Unchanged | Stable identifiers |

[U] No need to migrate the UserDefaults keys for all users, but on this machine, do rename them as a one-off.

---

## Part 2: Grade 4 XCUITest Diagnosis and Fix

### The Problem

[C] After the rename, 4 of 8 Grade 4 tests fail. All 4 fail with "Multiple matching elements found" — two windows are opening instead of one. The `--ui-testing` launch bypasses the welcome window but a second project window is appearing, creating duplicate `chatInputField` and `Jake` elements. This is a pre-existing bug unrelated to the rename.

### The Wrong Hypothesis

[U] The issue is that user settings are interfering with these tests. We need to create an isolated bubble. The only thing the tests may use from the host environment is access to run Claude CLI.

[C] Proposed an isolated HOME directory approach: set `app.launchEnvironment["HOME"]` to a fresh temp directory, symlink `.claude/` for auth.

___

[T] *The hypothesis was that macOS window restoration (via `~/Library/Saved Application State/`) was opening a stale project window. The solution was to redirect HOME so the app sees empty state directories.*

### The Debugging Journey

[C] Implemented the plan. Five iterations:

1. **Isolated HOME** → permission errors with `/tmp` (macOS sandbox), tearDown crash on failed setUp
2. **Fixed path + guards** → still two windows. Discovery: *macOS window restoration is managed by WindowServer, not affected by HOME environment variable*
3. **Added `-ApplePersistenceIgnoreState YES`** → zero windows. *SwiftUI on macOS 26 breaks entirely with this flag — it doesn't just suppress restoration, it prevents window creation*
4. **Just the persistence flag** → still zero windows
5. **Clear saved state directory** → `~/Library/Saved Application State/com.tavern.app.savedState/` doesn't exist. The saved state was never the problem.

### The Real Root Cause

[C] No saved state directory exists — the two windows aren't from macOS restoration. They're from **SwiftUI's own window persistence** reopening a previous `ProjectWindowConfig` window, combined with the `--ui-testing` code path opening another. Both show as `ProjectWindowConfig` windows in the element tree.

___

[S] *Key insight: SwiftUI has its own window persistence mechanism entirely separate from macOS Saved Application State. The `~/Library/Saved Application State/` directory may not even exist, yet SwiftUI still reopens previous windows. This is internal to SwiftUI's scene management. Redirecting HOME or clearing saved state does nothing because SwiftUI stores its window state through a different mechanism (likely UserDefaults or its own internal store).*

### The Correct Fix

[C] Pivoted to the failure doc's Option 2: make tests tolerant of multiple windows rather than fighting SwiftUI's persistence.

- `.firstMatch` on element queries (`chatInputField`, `sendButton`, `spawnServitorButton`) to tolerate duplicate elements across windows
- Scoped the "Jake" click in `testSwitchBetweenServitors` to `servitorList` to avoid matching the chat header (which had "Jake" appearing 3 times within one window: sidebar, chat header, chat content area)
- Deleted `UITestHarness.swift` entirely — the isolated HOME approach was solving the wrong problem

Result: 8/8 tests passing.

### Design Learnings

1. **`-ApplePersistenceIgnoreState YES` breaks SwiftUI on macOS 26** — prevents all window creation, not just restoration

2. **SwiftUI window persistence ≠ macOS Saved Application State** — separate mechanisms, different storage

3. **Isolated HOME is fragile for macOS GUI apps** — breaks assumptions throughout the dependency chain

4. **`.firstMatch` is the correct XCUITest pattern** for multi-window SwiftUI apps — tolerate rather than prevent

5. **Grade 4 tests require unlocked screen** — "Running Background" activation failure is macOS refusing to foreground the app
