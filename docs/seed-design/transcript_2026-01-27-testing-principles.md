# Transcript: Simplified Agent Spawning & Testing Principles
**Date:** 2026-01-27 (spans multiple sessions from 2026-01-26)

---

## Part 0: Session Start & Evolution

**[U]** what's next in implementation?

*[C] Explored codebase, reported on current state (173 tests passing, Phases 0-5 complete).*

**[U]** can i spawn an agent without a tag in it, or better yet, change what that tag is? does the agent see it or just me?

**[U]** sorry, i mean, the assignment field in the UI

*[T] User questioning the spawn dialog UX — why require an assignment field?*

**[U]** actually, let's drop the whole spawn dialog, we don't need to support custom names right now either

*[T] This led directly to the two-mode spawn design below.*

---

## Part 1: Design Direction

**[U]** let's do it this way, we need to support a few different behaviors, depending on the situation. One is when jake spawns an agent, he'll have an assignment in mind, and that agent will have a custom prompt instructing the agent to give its response first to the assignment before waiting for the user to say something. another is when the user just creates a new agent, then they don't want a weird field to type the assignment into, when we have a perfectly good chat UI, so we give the agent a prompt that has the agent wait for the user's first input.

**[U]** Also, i want to make it easier for the user to see at a glance what a chat window is about. this needs to be a short description that includes the original ask, plus whatever's current. this is going to be a thing both the user and the agent (with tools) can alter at any time.

**[U]** actually, also make sure that agents are also persisted too, just like jake

*[T] User then provided a detailed implementation plan with five parts:*
1. *Remove spawn dialog — "+" instantly creates agent*
2. *Two spawn modes — user-spawn (waits) vs Jake-spawn (works immediately)*
3. *Persist agents via UserDefaults — like Jake's session storage*
4. *Add mutable chat description — visible in sidebar, persisted*
5. *Fix sidebar wiring bug*

---

## Part 2: Implementation

**[C]** *Implemented across multiple files:*

**SessionStore.swift** — Added `PersistedAgent` type:
```swift
public struct PersistedAgent: Codable, Equatable {
    public let id: UUID
    public let name: String
    public var sessionId: String?
    public var chatDescription: String?
}
```

**MortalAgent.swift** — Made assignment optional:
```swift
public let assignment: String?  // Was String
public var chatDescription: String?

// Two system prompt variants based on assignment presence
```

**AgentSpawner.swift** — Added spawn variants:
```swift
@discardableResult
public func spawn() throws -> MortalAgent  // User-spawned, no assignment

@discardableResult
public func spawn(assignment: String) throws -> MortalAgent  // Jake-spawned

public func register(_ agent: MortalAgent) throws  // For restoration
```

**TavernCoordinator.swift** — Added persistence and restoration:
```swift
private func restoreAgents()  // Called in init, loads from SessionStore
public func spawnAgent(selectAfterSpawn: Bool = true) throws -> MortalAgent
public func closeAgent(id: UUID) throws
private func persistAgent(_ agent: MortalAgent)
```

**AgentListView.swift** — Removed SpawnAgentSheet, added context menu with edit/close

---

## Part 3: Sidebar Selection Bug

**[U]** the agent list sidebar is still dead, clicking on any one agent does not open up that specific agent chat, go take a look at logs

**[C]** *Investigated logs. Tried `.onChange(of: selectedAgentId)` — didn't work because List selection binding wasn't firing.*

**[U]** it does not

**[U]** i just did some clicking, did you wait for me to do that?

**[C]** *Solution: Added explicit `onTapGesture` with `onSelectAgent` callback. The SwiftUI List selection binding wasn't propagating reliably.*

**[U]** you need to run the run redo task for me every time you do this, for a faster workflow. when i see you're ready for me to test, i want to jump right in and test right away

*[T] Workflow directive: always run `redo run` after changes so user can test immediately.*

---

## Part 4: Platform Policy

**[U]** we should use only compatibility with tahoe or newer

**[U]** also, add to claude.md that we're targeting only the most recent release of macos

**[C]** *Updated project.yml and Package.swift to target macOS 26.0. Added to CLAUDE.md: "Target only the most recent macOS release. No backwards compatibility cruft."*

---

## Part 5: Log Scripts

**[U]** can you also make a few scripts you can use to view logs and other output? this way you won't stumble on the params

**[C]** *Created four scripts in `scripts/`:*
- `logs.sh` — View logs from last N minutes
- `logs-stream.sh` — Stream logs in real-time
- `logs-category.sh` — Filter by category
- `logs-errors.sh` — View only errors

---

## Part 6: Session History Bug Discovery

**[U]** ok, now only jake's conversation is getting restored, but if i click on another agent, the chat window does switch

*[T] Sidebar selection working, but mortal agent history not restoring. Session compacted here.*

---

## Part 7: Session History Fix (New Day, Post-Compaction)

**[U]** now, remind me where we were? it's a new day since last

**[C]** *Summarized: sidebar selection working, but mortal agent history not restoring. Investigated `ChatViewModel`. Found root cause:*

- `init(jake:loadHistory:)` called `loadSessionHistory()`
- `init(agent:)` did NOT call `loadSessionHistory()`

*Fix: Added `loadAgentSessionHistory(agentId:projectPath:)` to SessionStore. Updated `ChatViewModel` to accept projectPath and load history for all agents. Updated `TavernCoordinator` to pass `jake.projectPath` when creating mortal agent ViewModels.*

---

## Part 8: Testing Principles Discussion

**[U]** it works, look things over, use a rewind agent as needed, did you learn any new lessons about automated testing or instrumentation here? remember, the goal is that automated testing should catch bugs like this

**[C]** *Used rewind agent to analyze. Key findings:*

The bug: Two parallel code paths, only one tested. `ChatViewModel(agent:)` didn't load history.

Why tests didn't catch it:
1. All tests disable history loading (`loadHistory: false`)
2. No integration test for mortal agent restoration
3. No symmetry assertion for initializer behavior

**[U]** no, i want to first ask, how can we make sure that you implement correct testing here all the time in the future? let's make sure we update all the instructions first, and then, yes, follow them, add testing

**[C]** *Updated CLAUDE.md with new Testing Principles section:*

1. **Parallel Code Path Testing** — All paths to same outcome need tests
2. **Feature Toggle Coverage** — If tests disable a feature, other tests must enable it
3. **User Journey Integration Tests** — Test what users actually do end-to-end
4. **Symmetry Assertions** — Assert parallel APIs behave consistently
5. **New Entity = New Test Coverage** — New types need equivalent tests

*Also updated Honor System to reference these principles.*

---

## Part 9: Tests Added

**[C]** *Following the new principles, added 7 tests:*

**ChatViewModelTests.swift** (4 tests):
- `ChatViewModel for mortal agent accepts projectPath parameter`
- `ChatViewModel for mortal agent without assignment works`
- `Both initializers have loadHistory parameter - symmetry check`
- `Mortal agent ChatViewModel can send messages`

**TavernCoordinatorTests.swift** (3 tests):
- `User-spawned agent gets ChatViewModel when selected`
- `Mortal agent ChatViewModel can receive messages after selection`
- `Switching between Jake and mortal agent preserves both histories`

*The symmetry test would fail to compile if parallel APIs drift.*

---

## Part 10: Jake Character Note

**[U]** a jake joke, instead of just saying he'll make your HEAD spin, he might riff on that and say "it'll make your git repo's HEAD spin" playing on how he uses caps but also it can mean something else in git, moodwise

**[C]** That's a great character beat. Jake's wordplay working on multiple levels - the idiom, his signature CAPS, and the tech double meaning.

"This feature's gonna make your HEAD spin - and I ain't just talking about your git repo, though THAT'S gonna be doing backflips too!"

**[U]** yeah, also include the line i gave you verbatim

*Added to `docs/jake-character.md` under Fresh Material as "Git HEAD puns (multi-layered wordplay)"*

---

## Synthesis

*[S] Two spawn modes emerged from user workflow analysis: Jake assigns work immediately, users want the chat UI for their first message. No dialog needed.*

*[S] Chat description is a mutable field that both user and agent can edit — allows the "what's this about" to evolve as conversation progresses.*

*[S] Testing insight: Instructions need to be specific about patterns ("test parallel paths", "assert symmetry"), not just "write tests." The symmetry test pattern makes API drift a compile-time error.*

*[S] Platform policy simplified: macOS 26+ only. No backwards compatibility maintenance burden.*
