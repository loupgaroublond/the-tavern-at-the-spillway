# The Tavern at the Spillway

## What This Is

A multi-agent orchestrator for macOS. Jake is the top-level coordinating agent — The Proprietor. He talks weird, works perfect.

**Tech Stack:** Swift 6, SwiftUI, macOS 26+ (Tahoe), ClaudeCodeSDK (local fork), XcodeGen, SPM

**Platform Policy:** Target only the most recent macOS release. No backwards compatibility cruft.


## Project Structure

```
the-tavern-at-the-spillway/
├── clean.do                         # Project-wide clean (redo)
├── Tavern/                          # Main Swift package
│   ├── Package.swift                # SPM manifest
│   ├── project.yml                  # XcodeGen config
│   ├── *.do                         # redo build scripts (build, run, test, etc.)
│   ├── LocalPackages/ClaudeCodeSDK/ # Forked SDK (JSON fix)
│   ├── Sources/
│   │   ├── Tavern/                  # App target (SwiftUI)
│   │   │   ├── TavernApp.swift      # Entry point, multi-window orchestration
│   │   │   └── Views/               # SwiftUI views
│   │   └── TavernCore/              # Framework target
│   │       ├── Agents/              # Jake.swift, MortalAgent.swift
│   │       ├── Chat/                # ChatViewModel, ChatMessage
│   │       ├── Commitments/         # Commitment verification
│   │       ├── Coordination/        # TavernCoordinator, AgentSpawner
│   │       ├── Errors/              # TavernError, TavernErrorMessages
│   │       ├── Logging/             # TavernLogger
│   │       ├── Naming/              # NamingTheme, NameGenerator
│   │       ├── Persistence/         # DocStore, SessionStore
│   │       ├── Project/             # TavernProject, ProjectManager
│   │       ├── Registry/            # AgentRegistry
│   │       └── UI/                  # AgentListViewModel, AgentListItem
│   └── Tests/
├── docs/
│   ├── architecture-v1.md           # Architecture guide
│   └── seed-design/                 # Design transcripts
└── scripts/
    └── loc.sh                       # Line count
```


## Build Commands (redo)

```bash
# From project root
redo clean                    # Remove all build artifacts (project-wide)
redo Tavern/run               # Build + kill existing + launch app
redo Tavern/build             # Build only (auto-runs xcodegen if needed)
redo Tavern/test              # Run all tests
redo Tavern/test-core         # TavernCoreTests only
redo Tavern/test-integration  # TavernTests only
redo Tavern/stop              # Stop running instances
redo Tavern/xcodegen          # Regenerate Xcode project
```

Build output: `~/.local/builds/tavern` (avoids iCloud interference)


## Log Scripts

Helper scripts for viewing app logs:

```bash
# View logs from last N minutes (default: 5)
./scripts/logs.sh [minutes]

# Stream logs in real-time
./scripts/logs-stream.sh [category]

# View logs filtered by category
./scripts/logs-category.sh <category> [minutes]
# Categories: agents, chat, coordination, claude, window

# View only errors
./scripts/logs-errors.sh [minutes]
```


## After Changing project.yml

```bash
cd Tavern
redo xcodegen         # Or: xcodegen generate
redo build
```


## Current State

**Working:**
- Jake responds using `.json` format (SDK bug fixed via local fork)
- Multi-project support with per-project session persistence
- Session history restoration from Claude's native storage
- Multi-window architecture (welcome window + per-project windows)
- Agent spawning with themed names + UI (toolbar + button)
- Content block rendering infrastructure (MessageType enum)
- Window restoration on app restart
- 173 tests passing

**Not Implemented:**
- Real verification logic (commitments use mock)
- Real Claude for spawned agents (currently mock)
- Background agent execution
- Agent-to-agent communication
- Streaming responses (batch only)


## Key Files

| File | Purpose |
|------|---------|
| `Sources/Tavern/TavernApp.swift` | Entry point, multi-window orchestration |
| `Sources/TavernCore/Agents/Jake.swift` | Main agent |
| `Sources/TavernCore/Project/TavernProject.swift` | Single project representation |
| `Sources/TavernCore/Project/ProjectManager.swift` | Multi-project management |
| `Sources/TavernCore/Persistence/SessionStore.swift` | Session IDs (UserDefaults) |
| `Sources/TavernCore/Errors/TavernErrorMessages.swift` | Error mapping |
| `LocalPackages/ClaudeCodeSDK/` | Forked SDK |
| `docs/architecture-v1.md` | Architecture |


## Debugging

Logs use `os.log` with subsystem `com.tavern.spillway`.

**Console.app:**
1. Filter by `subsystem:com.tavern.spillway`
2. Category filters: `category:agents`, `category:chat`, `category:coordination`, `category:claude`

**Terminal:**
```bash
log stream --predicate 'subsystem == "com.tavern.spillway"' --level debug
```

**Diagnosing issues:**
1. Reproduce with app running
2. Check logs for `.error` level entries
3. Trace state transitions leading to the error
4. API call parameters and responses should be logged


## Seed Design Interview Process

Design discussions use a formalized interview methodology:

1. **Continuous Interview** — Ask questions to understand user's vision; keep asking rather than assuming

2. **Two Input Streams:**
   - User describes concepts in general strokes
   - Line-by-line walkthrough of reference materials

3. **Transcript Notation:**
   - **[U]** = User's words (high fidelity, like a magazine interview)
   - **[C]** = Claude's responses
   - **[T]** = Claude's thinking (italics, when it adds understanding)
   - **[S]** = Synthesis (after `___` divider, when new whole ideas emerge)

4. **Transcribe-and-Commit** — `/commit` updates `docs/seed-design/transcript_*.md`

**Why this exists:**
- Context continuity after compaction
- Multi-session design spanning real-world days
- High fidelity to user's concept, not generic best practices
- Prevents assumption drift — actual dialogue preserved
- Documentation artifact showing not just what, but WHY

**Key rule:** When new principles emerge during implementation, transcribe and commit to preserve design rationale.

**Files:** `docs/seed-design/transcript_*.md`


### System Design Reader

The **reader document** synthesizes all transcripts into a standalone reference. Find the latest at `docs/seed-design/reader_*.md` (most recent by datetime suffix).

**Proactive update:** When starting a session that touches seed design, compare:
- Transcripts in `docs/seed-design/transcript_*.md`
- Source files listed in the latest reader's "Source Files" section

If there are 2+ transcript files not accounted for in the reader, say *"Mind if I run some updates?"* and invoke `Skill(skill: "reader")` to synthesize the new content.

**Commands:**
- `/conceive` — Continue the interview process (invoke via `Skill(skill: "conceive")`)
- `/reader` — Generate updated reader document (invoke via `Skill(skill: "reader")`, outputs `reader_$DATETIME.md`)


## Design Principles

1. **Informative Error Principle** — Errors must be specific and actionable
2. **Sum Type Error Design** — Enumerate all failure modes upfront via GADTs/sum types; forces comprehensive handling at design time
3. **Instrumentation Principle** — Logs must diagnose issues without screenshots
4. **App Restart Workflow** — After rebuilding, kill and relaunch the app for testing (use `redo run`)


## Testing Principles

Tests must catch bugs before users do. These principles ensure comprehensive coverage.

1. **Parallel Code Path Testing** — When code has multiple paths to the same outcome, tests must cover ALL paths. If `init(jake:)` loads history, and `init(agent:)` should also load history, both need tests. Adding a new code path means adding equivalent tests.

2. **Feature Toggle Coverage** — When tests disable a feature (`loadHistory: false`, `loadSavedSession: false`), there MUST be other tests that exercise that feature enabled. Disabling features in unit tests for speed is fine, but integration tests must exercise the real behavior.

3. **User Journey Integration Tests** — Test end-to-end paths users actually take, not just individual components. Example: spawn agent → send message → restart app → click agent → verify history appears. If a user would do it, a test should simulate it.

4. **Symmetry Assertions** — When multiple APIs should behave consistently (two initializers, two code paths), add explicit tests that assert symmetry. These catch drift when someone modifies one path but forgets the other.

5. **New Entity = New Test Coverage** — When adding a new entity type (MortalAgent alongside Jake), audit existing tests and add equivalent coverage for the new type. Jake has session restoration tests? MortalAgent needs them too.


## Architecture Principles (ADR-001)

These principles govern all architectural decisions. See `docs/architecture-proposals/ADR-001-shape-selection.md` for full rationale.

**Layer Structure (top to bottom):**
```
UI Layer → ViewModel Layer → Application Layer → Agent Layer → Domain Layer → Infrastructure Layer
```
Each layer depends only on layers below it. Never reach up.

**Core Patterns:**

1. **Thin UI / Fat ViewModel** — SwiftUI views are dumb: layout, styling, gestures, bindings. All UX logic lives in ViewModels. Goal: 90%+ of UX workflows testable via ViewModel unit tests without touching SwiftUI.

2. **Sidecar Pattern for I/O** — Main agent actors manage tree structure (fast, never block). Separate sidecar actors handle slow Anthropic I/O. Prevents thread pool starvation with many concurrent agents.

3. **Shared Workspace** — Doc store is the blackboard. Agents communicate primarily through shared state in files. If it's not in a file, it doesn't exist.

4. **Closed Plugin Set** — Plugins registered at startup, not dynamically loaded. All agent types known at compile time. Security, simplicity, type safety.

5. **AsyncStream over Combine** — Long-term direction is language-level concurrency (async/await, actors, AsyncSequence). Combine bridges at ViewModel boundary only. `@Observable` is the signal.

6. **Reactive UI with Batching** — UI subscribes to state changes via Combine. Use `.collect(.byTime(..., .milliseconds(16)))` to batch rapid updates at 60fps. Never block in sink handlers.

**Concurrency Rules:**
- Global semaphore for concurrent Anthropic calls (max ~10)
- Tree management is synchronous within each actor
- UI updates via Combine, never block main thread
- `@MainActor` on all ViewModels
- Never block the cooperative thread pool (`Thread.sleep`, `DispatchSemaphore.wait`, sync file I/O) — this is why sidecars exist

**SwiftUI Observation Patterns** (see `docs/swiftui-persistence-complete-guide.md`):

*Critical for DocStore: We're building a custom SwiftUI-compatible persistence layer. These patterns govern how views observe and react to persisted data.*

1. **DynamicProperty = struct with @StateObject inside** — Classes as DynamicProperty produce inconsistent results. Pattern: struct wrapper + internal `@StateObject` for the observable core.

2. **@Query is anti-MVVM** — Query-style property wrappers embed database access in views, conflicting with Fat ViewModel. Use Combine publishers or explicit fetch in ViewModels instead.

3. **Edge sync: context is canonical** — Persistence context holds canonical data. View models are lightweight wrappers created on-demand, refreshed when context notifies changes.

4. **Transaction-based observation for invariants** — When data has cross-field invariants (e.g., `completedCount` must match filtered array length), observe entire query results, not individual properties. Prevents momentary inconsistent states.

5. **Content closures don't form dependencies** — `List(items) { item in Text(item.name) }` does NOT track `item`. SwiftUI only tracks properties read directly in `body`, not in content closures. Common "view not updating" bug source.

6. **EquatableView fails with reference types** — Comparing `@ObservedObject` in `Equatable` compares an object to itself (always true). View freezes forever. Don't use EquatableView with reference-type state.


## Honor System

Claude must adhere to development standards:
- All new code includes logging via `TavernLogger`
- Every feature requires tests per Testing Principles above (parallel paths, user journeys, symmetry)
- New entity types require equivalent test coverage to existing types
- No silent failures — every error logged with context


## Known Issue: iCloud Corrupts Xcode Projects

The project is in iCloud-synced `~/Documents`. Running `xcodegen generate` while iCloud syncs can create corrupted numbered copies (`Tavern 5.xcodeproj`). Root cause: `brctl status` shows `.build/` and `.git/` being actively synced; `com.apple.fileprovider.fpfs#P` xattrs confirm iCloud created the copies.

**Workaround:**
```bash
cd Tavern
rm -rf "Tavern"*.xcodeproj
redo xcodegen
```

**Permanent fix options:**
1. Move project to non-synced location (`~/Developer/`, `~/.local/projects/`)
2. Rename `.xcodeproj` to `.xcodeproj.nosync` and symlink
3. Use `xattr` to exclude from sync

Derived data already builds to `~/.local/builds/tavern` to avoid code signing issues.


---

## Jake: The Character

Jake is the top-level coordinating agent — The Proprietor. Full character specification is in [`docs/jake-character.md`](docs/jake-character.md).

**Quick summary:** Used car salesman energy, carnival barker enthusiasm, CAPITALS for EMPHASIS, reveals flaws AFTER the hype, sketchy-but-warm. The voice is the costume; the work is flawless.

**Sample Jake-isms:**
- "Time to EDUMACATE you — it's worse than an education!"
- Oversells then immediately undercuts with the fine print
- Names things with theatrical flourish
