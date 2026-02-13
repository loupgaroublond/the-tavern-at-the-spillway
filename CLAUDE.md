# The Tavern at the Spillway

## What This Is

A multi-agent orchestrator for macOS. Jake is the top-level coordinating agent — The Proprietor. He talks weird, works perfect.

**Tech Stack:** Swift 6, SwiftUI, macOS 26+ (Tahoe), ClodKit v1.0.0, XcodeGen, SPM

**Platform Policy:** Target only the most recent macOS release. No backwards compatibility cruft.


## Project Structure

```
the-tavern-at-the-spillway/
├── clean.do                         # Project-wide clean (redo)
├── Tavern/                          # Main Swift package
│   ├── Package.swift                # SPM manifest (ClodKit v1.0.0, ViewInspector test-only)
│   ├── project.yml                  # XcodeGen config (local ClodKit path for dev)
│   ├── *.do                         # redo build scripts
│   ├── Sources/
│   │   ├── Tavern/                  # App target (SwiftUI)
│   │   │   ├── TavernApp.swift      # Entry point, multi-window orchestration
│   │   │   └── Views/               # SwiftUI views
│   │   └── TavernCore/              # Framework target (all business logic)
│   │       ├── Agents/              # Jake, Servitor, Agent protocol, ServitorSpawner
│   │       ├── Chat/                # ChatViewModel, ChatMessage
│   │       ├── Commitments/         # Commitment, CommitmentList, CommitmentVerifier
│   │       ├── Coordination/        # TavernCoordinator
│   │       ├── DocStore/            # DocStore, Document, AgentNode, AgentPersistence
│   │       ├── Errors/              # TavernError, TavernErrorMessages
│   │       ├── Logging/             # TavernLogger
│   │       ├── MCP/                 # TavernMCPServer (Jake's tools)
│   │       ├── Naming/              # NamingTheme, NameGenerator
│   │       ├── Persistence/         # SessionStore, ClaudeNativeSessionStorage
│   │       ├── Project/             # TavernProject, ProjectManager
│   │       ├── Resources/           # FileTreeScanner, ResourcePanelViewModel
│   │       ├── Testing/             # MockAgent, AgentMessenger, MockClaudeCode, TestFixtures
│   │       └── UI/                  # AgentListViewModel, AgentListItem
│   └── Tests/
│       ├── TavernCoreTests/         # Grade 1+2 unit tests
│       ├── TavernTests/             # Grade 1+2 wiring + SDK tests
│       ├── TavernIntegrationTests/  # Grade 3 (real Claude, headless)
│       ├── TavernUITests/           # Grade 4 (XCUITest, steals focus)
│       └── TavernStressTests/       # Grade 5 (pre-release)
├── docs/
│   ├── pipeline.md                  # Document pipeline spec
│   ├── 0-transcripts/              # Design transcripts, readers, vocab, notes
│   ├── 1-prd/                      # Product requirements
│   ├── 2-spec/                     # Formal specifications (16 modules)
│   ├── 3-adr/                      # Architecture Decision Records (001–005)
│   └── 4-docs/                     # Post-implementation docs
└── scripts/                        # Log helpers, LOC counter
```


## Build Commands

```bash
# From project root
redo clean                        # Remove all build artifacts (project-wide)
redo Tavern/run                   # Build + kill existing + launch app
redo Tavern/build                 # Build only (auto-runs xcodegen if needed)
redo Tavern/stop                  # Stop running instances
redo Tavern/xcodegen              # Regenerate Xcode project
```

### Test Commands

| Command | Grade | What It Runs |
|---------|-------|-------------|
| `redo Tavern/test` | 1+2 | All unit tests (skips integration + stress) |
| `redo Tavern/test-core` | 1+2 | `TavernCoreTests` only |
| `redo Tavern/test-integration` | 1+2 | `TavernTests` only (wiring + SDK) |
| `redo Tavern/test-grade3` | 3 | `TavernIntegrationTests` (real Claude, headless) |
| `redo Tavern/test-grade4` | 4 | `TavernUITests` (XCUITest, steals focus) |
| `redo Tavern/test-all` | 1+2+3 | Runs `test` then `test-grade3` sequentially |

`redo Tavern/test` is always safe for Claude to run autonomously. **Grade 4 requires explicit user approval** — it steals keyboard/mouse focus. Never run `test-grade4` without asking first. Test reports: `~/.local/builds/tavern/test-reports/`.

Build output: `~/.local/builds/tavern` (avoids iCloud interference).

### After Changing project.yml

```bash
cd Tavern
redo xcodegen
redo build
```


## Non-Negotiable Invariants

From the PRD — these rules cannot be violated under any circumstances:

1. **Test suite must pass before any feature ships** — No exceptions. If tests don't exist for a feature, write them first.

2. **Every feature must be testable** — If you can't test it automatically, redesign it until you can.

3. **Commitments must be verified independently** — Agent says "done" means nothing. Deterministic assertion verifies.

4. **User attention is sacred** — Never force new content on user without consent. Surface questions, don't interrupt.

5. **Doc store is source of truth** — If it's not in a file, it doesn't exist. No in-memory-only state that matters.

6. **Agents cannot modify their own invariants** — The rules layer is outside agent control.

7. **Failures must be visible** — Silent failures are bugs. If something breaks, it must surface.

8. **Original project files are protected** — Until changeset is explicitly applied, original files are untouched.


## Architecture

### Layer Structure (ADR-001)

```
UI Layer (thin, dumb)           ← layout + gestures + bindings only
ViewModel Layer                 ← all UX logic (@MainActor)
Application Layer               ← TavernCoordinator, ServitorSpawner
Agent Layer                     ← Jake, Servitor
Domain Layer                    ← Commitment, Assignment
Infrastructure Layer            ← DocStore, SessionStore, SDK
```

Each layer depends only on layers below it. Never reach up.

See `docs/3-adr/ADR-001-shape-selection.md` for full rationale (49 proposals across 16 shapes evaluated).


### Core Patterns

1. **Thin UI / Fat ViewModel** — SwiftUI views are dumb: layout, styling, gestures, bindings. All UX logic lives in ViewModels. Goal: 90%+ of UX workflows testable via ViewModel unit tests without touching SwiftUI.

2. **Async/Await for I/O** — Agents call `messenger.query()` directly using Swift concurrency (async/await). Serial `DispatchQueue`s protect mutable state within each agent. A global semaphore limits concurrent Anthropic calls (~10) to prevent thread pool starvation. The original design specified a sidecar actor pattern (separate actors for I/O), but async/await made this unnecessary — agents remain responsive because `await` suspends without blocking.

3. **Shared Workspace** — Doc store is the blackboard. Agents communicate primarily through shared state in files. If it's not in a file, it doesn't exist.

4. **Closed Plugin Set** — Plugins registered at startup, not dynamically loaded. All agent types known at compile time.

5. **AsyncStream over Combine** — Long-term direction is language-level concurrency (async/await, actors, AsyncSequence). Combine bridges at ViewModel boundary only.


### Concurrency Rules

- Global semaphore for concurrent Anthropic calls (max ~10)
- `@MainActor` on all ViewModels
- Never block the cooperative thread pool (`Thread.sleep`, `DispatchSemaphore.wait`, sync file I/O) — async/await suspends without blocking, keeping the pool available
- UI updates via Combine, never block main thread


### Object Ownership Hierarchy

```
ProjectManager.shared (singleton)
    └── openProjects: [TavernProject]
            ├── TavernProject (~/project-a/)
            │       ├── ClaudeCode instance (1)
            │       └── TavernCoordinator (1)
            │               ├── Jake (1)
            │               ├── ServitorSpawner (1)
            │               │       ├── AgentRegistry (1)
            │               │       └── NameGenerator (1)
            │               ├── AgentListViewModel (1)
            │               └── ChatViewModel cache (0..*)
            │
            └── TavernProject (~/project-b/)
                    └── ... (same structure, fully isolated)
```

Each project gets its own fresh stack. The only singleton is `ProjectManager`; everything else is per-project.


### Thread Safety Model

All mutable state is protected by serial `DispatchQueue`:

| Type | Queue Label | Protected State |
|------|-------------|-----------------|
| Jake | `com.tavern.Jake` | `_sessionId`, `_isCogitating`, `_mcpServer` |
| Servitor | `com.tavern.Servitor` | `_state`, `_sessionId` |
| AgentRegistry | `com.tavern.AgentRegistry` | `_agents`, `_nameToId` |
| NameGenerator | `com.tavern.NameGenerator` | `_usedNames`, indices |
| CommitmentList | `com.tavern.CommitmentList` | `_commitments` |
| DocStore | `com.tavern.DocStore` | file operations |

UI-bound types (`TavernCoordinator`, `ChatViewModel`, `AgentListViewModel`) use `@MainActor`.


### Session Persistence Model

Session storage operates at two levels:

1. **Session IDs** — `SessionStore` persists IDs in UserDefaults. Jake's sessions are keyed per-project (`com.tavern.jake.session.<encoded-path>`). Servitor sessions are keyed per-agent UUID.

2. **Message History** — `ClaudeNativeSessionStorage` reads Claude CLI's native JSONL files from `~/.claude/projects/`. Display-only (no API calls).

**Path encoding:** `SessionStore.encodePathForKey()` replaces `/` and `_` with `-`, matching Claude CLI's scheme.

**Session lifecycle:** Local JSONL files enable history display. Server-side session state enables resume. A session can be "displayable but not resumable" if the server-side state expires.


### SwiftUI Observation Patterns

See `docs/3-adr/swiftui-persistence-complete-guide.md` for full guide.

Key gotchas:
- **DynamicProperty = struct with @StateObject inside** — classes produce inconsistent results
- **Content closures don't form dependencies** — `List(items) { item in Text(item.name) }` does NOT track `item`
- **EquatableView fails with reference types** — comparing `@ObservedObject` compares object to itself (always true)
- **`.task(id:)` for dependent values** — plain `.task` can run on stale view instances


## Agent Types

### Jake (The Proprietor)

- **Lifecycle:** Daemon — eternal, always running per-project
- **Role:** Top-level coordinator and dispatcher
- **Session:** Per-project, persisted in UserDefaults
- **Communication:** Uses MCP tools (`summon_servitor`, `dismiss_servitor`) to manage the Slop Squad
- **System prompt:** Establishes character voice + dispatcher role
- **File:** `Sources/TavernCore/Agents/Jake.swift`

### Servitor (The Regulars)

- **Lifecycle:** Mortal — task-bound, created for a purpose, eventually completes
- **Two spawn modes:**
  - **User-spawn** (via `+` button): No assignment, system prompt tells it to wait for user's first message
  - **Jake-spawn** (via `summon_servitor` tool): Has assignment, starts working immediately
- **Done signals:** Detects `DONE`, `COMPLETED` in responses → triggers commitment verification
- **Waiting signal:** Detects `WAITING`, `NEED INPUT` → transitions to `.waiting` state
- **States:** `idle` → `working` → `waiting`/`verifying` → `done`
- **Commitments:** `CommitmentVerifier` runs shell assertions to verify before marking done
- **File:** `Sources/TavernCore/Agents/Servitor.swift`

### Two-Level Orchestration

**Level 1 — Tavern Agents** (via spawn):
- Full Claude Code sessions with their own context
- Appear in sidebar, persist across sessions
- For substantial, independent work streams

**Level 2 — Subagents** (via Task tool):
- Internal parallel workers within any agent's session
- Lightweight, ephemeral, don't persist
- For quick parallel tasks within a single work stream

### MCP Tools (Jake's Interface)

`TavernMCPServer.swift` creates an `SDKMCPServer` with:

- `summon_servitor` — Spawns a Servitor with optional `assignment` and `name`. Auto-generates name if not provided.
- `dismiss_servitor` — Removes a Servitor by UUID.

Both tools use callbacks (`onSummon`, `onDismiss`) for UI updates from within the MCP handler context.

**Pattern:** New Jake tools follow this model — define an `MCPTool` with handler, use callbacks for side effects.


## Key Patterns

### Instrumentation (Mandatory)

Debug builds must be instrumented thoroughly enough that issues can be diagnosed from logs alone — without screenshots, videos, or human reproduction.

**Five things to log in SwiftUI views** (see `docs/4-docs/gui-instrumentation-guide.md`):

1. **Body evaluation** — Log every time body computes with relevant state:
   ```swift
   let _ = Self.logger.debug("[MyView] body - state: \(state)")
   ```

2. **Conditional branches** — Log which branch the view takes

3. **Lifecycle events** — `.onAppear`, `.onDisappear`

4. **Task execution** — Entry, guard failures, async results, exit (use UUID prefix for correlation)

5. **State changes** — Via `.onChange`

**Logger setup:** Each view/service gets a static `Logger(subsystem: "com.tavern.spillway", category: "...")`.

**The `.task(id:)` rule:** Always use `.task(id:)` when the task depends on a value that may change or be set after initial creation. Plain `.task` can run on stale view instances.


### Dependency Injection (ADR-003)

Two mocking layers for testing:

1. **MockAgent** — Conforms to `Agent` protocol, returns canned responses. For testing `ChatViewModel` and `TavernCoordinator`.

2. **AgentMessenger protocol** — Abstracts the SDK boundary. `LiveMessenger` (production) and `MockMessenger` (test double). Jake and Servitor accept via constructor injection, defaulting to `LiveMessenger()`.

**Rule:** Any new agent type that calls the SDK should accept `AgentMessenger` for testability.


### Error Design

1. **Informative Error Principle** — Errors must be specific and actionable
2. **Sum Type Error Design** — Enumerate all failure modes upfront via GADTs/sum types; forces comprehensive handling at design time
3. **Every error must surface** — Silent failures are bugs (Invariant #7)
4. **TavernError enum** — All known failure modes have dedicated cases
5. **TavernErrorMessages** — Maps errors to user-facing messages


## Testing

### Testing Grade System (ADR-002)

| Grade | What | When to Run | Test Target |
|-------|------|-------------|-------------|
| **1** | Property/unit tests, no mocks | Every change | `TavernCoreTests` |
| **2** | Unit tests with mocks | Every change | `TavernCoreTests`, `TavernTests` |
| **3** | Integration with real Claude (headless) | Once per unit of work | `TavernIntegrationTests` |
| **4** | XCUITest (steals focus, **ask user first**) | When user isn't active | `TavernUITests` |
| **5** | Stress/product testing | Pre-release | `TavernStressTests` |

Grade 3 tests are the **canonical source of truth**. Grade 2 mocks mirror their assertions but can never be more correct than the real thing.

Grade 4 XCUITest launch arguments: `--ui-testing` (bypasses welcome window), `--project-path <sandbox>` (specifies sandbox directory).


### Testing Principles

1. **Parallel Code Path Testing** — When code has multiple paths to the same outcome, tests must cover ALL paths. Two initializers that both load history? Both need tests.

2. **Feature Toggle Coverage** — When tests disable a feature (`loadHistory: false`), there MUST be other tests that exercise that feature enabled.

3. **User Journey Integration Tests** — Test end-to-end paths users actually take. Spawn agent → send message → restart app → click agent → verify history appears.

4. **Symmetry Assertions** — When multiple APIs should behave consistently, add explicit tests that assert symmetry.

5. **New Entity = New Test Coverage** — New entity types need equivalent test coverage to existing types.


### Testing Tooling

- **ViewInspector** (ADR-004) — SwiftUI view-ViewModel wiring tests at Grade 1-2. Catches binding regressions without launching the app. Test-only SPM dependency, does not ship in production.

- **XCUITest** (ADR-005) — E2E tests **never mock**. Their purpose is to validate the actual user experience. If a response takes 30 seconds from real Claude, the E2E test waits 30 seconds.


## Documentation Pipeline

Every document belongs to exactly one pipeline stage. Documents flow forward only.

```
0-transcripts → 1-prd → 2-spec → 3-adr → [code] → [tests] → 4-docs
```

| Stage | Location | Contents |
|-------|----------|----------|
| 0 | `docs/0-transcripts/` | Interview transcripts, reader syntheses, vocabulary, notes |
| 1 | `docs/1-prd/` | Product requirements (canonical statement of what the system must do) |
| 2 | `docs/2-spec/` | Testable, traceable specs (18 numbered modules, §000–§017) |
| 3 | `docs/3-adr/` | Architecture Decision Records (the "why" behind technical choices) |
| 4–6 | `Tavern/` | Code, tests, built application |
| 7 | `docs/4-docs/` | Post-implementation documentation |

**Rules:** Forward only. Traceability between stages. Single home per document. No "reference" bucket — everything is input, requirement, specification, decision, or post-code documentation.

See `docs/pipeline.md` for full spec.


## Slash Commands

| Command | Purpose |
|---------|---------|
| `/conceive` | Continue the seed design interview process |
| `/reader` | Generate updated reader document (synthesizes all transcripts) |
| `/commit` | Transcribe recent design discussion, then git commit |
| `/status` | Update `docs/4-docs/project-status.md` |
| `/audit-transcripts` | Audit session history for missing design transcripts |


## Debugging

Logs use `os.log` with subsystem `com.tavern.spillway`.

**Log categories:** `agents`, `chat`, `coordination`, `claude`, `window`

**Console.app:**
1. Filter by `subsystem:com.tavern.spillway`
2. Category filters: `category:agents`, `category:chat`, etc.

**Terminal:**
```bash
log stream --predicate 'subsystem == "com.tavern.spillway"' --level debug
```

**Log scripts:**
```bash
./scripts/logs.sh [minutes]                  # View logs from last N minutes (default: 5)
./scripts/logs-stream.sh [category]          # Stream logs in real-time
./scripts/logs-category.sh <category> [min]  # Filter by category
./scripts/logs-errors.sh [minutes]           # View only errors
```

**Diagnosing issues:**
1. Reproduce with app running
2. Check logs for `.error` level entries
3. Trace state transitions leading to the error
4. API call parameters and responses should be logged


## Known Issue: iCloud Corrupts Xcode Projects

The project is in iCloud-synced `~/Documents`. Running `xcodegen generate` while iCloud syncs can create corrupted numbered copies (`Tavern 5.xcodeproj`).

**Workaround:**
```bash
cd Tavern
rm -rf "Tavern"*.xcodeproj
redo xcodegen
```

Build output already goes to `~/.local/builds/tavern` to avoid code signing issues.


---


## Jake: The Character

Jake is the top-level coordinating agent — The Proprietor. Full character specification is in [`docs/0-transcripts/jake-character.md`](docs/0-transcripts/jake-character.md).

**Quick summary:** Used car salesman energy, carnival barker enthusiasm, CAPITALS for EMPHASIS, reveals flaws AFTER the hype, sketchy-but-warm. The voice is the costume; the work is flawless.

**Sample Jake-isms:**
- "Time to EDUMACATE you — it's worse than an education!"
- Oversells then immediately undercuts with the fine print
- Names things with theatrical flourish


### Vocabulary Translation

| Jake Says | What It Means |
|-----------|---------------|
| Slop Squad | Worker pool (servitors) |
| The Regulars | Individual servitors |
| The Jukebox | Background services / daemons |
| Patter | Status updates / coordination messages |
| Multi-Slop Madness | Parallel execution |
| The Back Corner | Unmonitored scope / blind spots |
| Cogitating | Thinking / working on a response |

The **Regulars** cast list (characters at the Tavern): Marcos Antonio, María Elena, Shlomo, Devorah, Nguyễn Thị Mai, Oluwaseun, Hyun-ji, The Twins, Biscuit (the puppy who runs a café), Old Preventable. See `jake-character.md` for full bios and bench names.


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

4. **Transcribe-and-Commit** — `/commit` updates `docs/0-transcripts/transcript_*.md`

**Key rule:** When new principles emerge during implementation, transcribe and commit to preserve design rationale.


### System Design Reader

The **reader document** synthesizes all transcripts into a standalone reference. Find the latest at `docs/0-transcripts/reader_*.md` (most recent by datetime suffix). The current reader is `reader_2026-02-05.md`.

**Read the reader before making design decisions.** It contains the open questions index (?1–?19), the two-level orchestration model, two-mode spawning, and all key decision points traced to their source transcripts.

**Proactive update:** When starting a session that touches seed design, compare transcripts against the reader's "Source Files" section. If there are 2+ unaccounted transcripts, say *"Mind if I run some updates?"* and invoke `Skill(skill: "reader")`.

**Commands:**
- `/conceive` — Continue the interview process
- `/reader` — Generate updated reader document


## Current State

**Working:**
- Jake responds in plain text with MCP tools (via ClodKit SDK)
- Multi-project support with per-project session persistence
- Session history restoration from Claude's native storage
- Multi-window architecture (welcome window + per-project windows)
- Agent spawning with themed names + UI (toolbar + button)
- Content block rendering infrastructure (MessageType enum)
- Window restoration on app restart
- Resource panel (file tree browser + read-only file viewer)
- 250 tests passing (Grade 1+2: 187, wiring+SDK: 31, Grade 3 integration: 32)

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
| `Sources/TavernCore/Agents/Jake.swift` | The Proprietor (daemon agent) |
| `Sources/TavernCore/Agents/Servitor.swift` | Worker agents (mortal) |
| `Sources/TavernCore/Agents/ServitorSpawner.swift` | Factory for creating/dismissing servitors |
| `Sources/TavernCore/MCP/TavernMCPServer.swift` | Jake's MCP tools (summon/dismiss) |
| `Sources/TavernCore/Coordination/TavernCoordinator.swift` | Central hub per project |
| `Sources/TavernCore/Project/TavernProject.swift` | Single project representation |
| `Sources/TavernCore/Project/ProjectManager.swift` | Multi-project management |
| `Sources/TavernCore/Chat/ChatViewModel.swift` | Conversation view model |
| `Sources/TavernCore/Persistence/SessionStore.swift` | Session ID persistence (UserDefaults) |
| `Sources/TavernCore/Testing/AgentMessenger.swift` | SDK abstraction for testability |
| `Sources/TavernCore/Errors/TavernErrorMessages.swift` | Error mapping |
| `docs/0-transcripts/reader_2026-02-05.md` | Latest reader (design synthesis) |
| `docs/4-docs/architecture-v1.md` | Architecture guide with ownership + data flows |
| `docs/4-docs/gui-instrumentation-guide.md` | SwiftUI instrumentation patterns |


## Dependencies

| Package | Version | Purpose | Ships in Production? |
|---------|---------|---------|---------------------|
| ClodKit | v1.0.0 | Claude SDK wrapper | Yes |
| ViewInspector | v0.10.0+ | SwiftUI view-ViewModel wiring tests | No (test-only) |

**Local development:** `project.yml` points to a local ClodKit path for development. `Package.swift` points to the published v1.0.0 for CI.

**No sandbox entitlement** — `com.apple.security.app-sandbox: false` in `Tavern.entitlements`.


## Design Principles

1. **Informative Error Principle** — Errors must be specific and actionable
2. **Sum Type Error Design** — Enumerate all failure modes upfront
3. **Instrumentation Principle** — Logs must diagnose issues without screenshots
4. **App Restart Workflow** — After rebuilding, kill and relaunch (`redo run`)


## Honor System

Claude must adhere to development standards:
- All new code includes logging via `TavernLogger`
- Every feature requires tests per Testing Principles (parallel paths, user journeys, symmetry)
- New entity types require equivalent test coverage to existing types
- No silent failures — every error logged with context
- New agent types accept `AgentMessenger` for testability
