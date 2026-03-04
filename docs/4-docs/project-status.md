# Project Status Summary

**Generated:** 2026-03-02
**Source:** Synthesis of all seed-design transcripts


## Timeline

- **2026-01-18** — Project inception: Jake's voice and character established (Spillway Principle, joke management lifecycle, name translation layer), TAP.CLAUDE.md for homebrew tap, cast of characters with diverse ethnic names, README with comedy pacing principles, git repository initialized

- **2026-01-19 09:06** — Process establishment, notation system for transcripts

- **2026-01-19 10:26** — Problem statement defined (14 pain points), open questions captured

- **2026-01-19 10:40-12:00** — Grand Idea user flow, agent hierarchy, operating modes, created 711 cogitation verbs and naming themes

- **2026-01-19 14:50** — Created `/conceive` slash command, naming rationale ("discovery" rejected as too passive, "conceive" captures generative design through dialogue)

- **2026-01-20 23:15** — XcodeGen setup, project root discovery discussion, LOC script

- **2026-01-21 08:00** — Architecture docs, SDK bug discovered (JSON array parsing), 4 design principles established

- **2026-01-21 15:00** — Handoff docs created, performance requirements added, build path moved to `~/.local/builds/tavern`

- **2026-01-21 16:20** — Instrumentation & stress testing implementation, TavernLogger, progressive unlocks concept

- **2026-01-21 21:13** — Perception-bounded performance principle defined (isolation, responsiveness over speed, perception boundaries, scale independence), stress testing requirements

- **2026-01-21 23:45** — Dynamic view architecture discussion (composable tiles, multiple windows)

- **2026-01-22 00:15** — Document-based architecture, project-as-document, storage layers defined

- **2026-01-22 07:30** — View architecture deep dive: Erlang-style arbitrary depth hierarchies, composable views, agent-participatory layouts, template vs concrete views, MainActor persistence decision

- **2026-01-22 14:30** — SDK fork with JSON fix, content blocks infrastructure, agent spawn UI, session persistence

- **2026-01-22 16:00** — Redo build system, handoff consolidation into CLAUDE.md

- **2026-01-22 17:00** — Jake's character development (politics, Jewish identity)

- **2026-01-22 21:00** — Session history rehydration, content block parsing (tool use/result)

- **2026-01-22 (session rehydration)** — Full session history rehydration implementation: path encoding bugs, content block preservation, integration tests, debug logging visibility

- **2026-01-23** — Headless debugging philosophy established: autonomous testing principle, end-to-end tests over stubs, instrumentation over observation

- **2026-01-24 (architecture exploration)** — Parallel agent spawning methodology for architecture exploration: 49 proposals across 16 shapes, synthesis report with compatibility matrix

- **2026-01-24 (shape selection)** — Architecture decision: Shared Workspace (E) + Supervisor Tree (D) + Reactive Streams (A) + Plugin (I) + Layer (C) + Sidecar (L); ADR-001 created

- **2026-01-24 (async primitives)** — Async primitive strategy: AsyncStream long-term, Combine at SDK boundary, bridge at ViewModel layer

- **2026-01-24 (window restoration)** — Multi-window architecture, per-project sessions, app icon (orange squircle JT), window restoration debugging, GUI instrumentation guide created

- **2026-01-25 01:08** — Agent registry architecture review: 1:1 relationship analysis (TavernProject → TavernCoordinator → AgentSpawner → AgentRegistry), justification for separation (name uniqueness, thread safety, type erasure, facade for multiple consumers), architecture docs found significantly outdated

- **2026-01-25** — Transcript audit methodology: parallel agent verification, one-transcript-per-agent rule, `/audit-transcripts` command created

- **2026-01-27** — Agent spawn simplification (two-mode: user vs Jake), agent persistence, session history fix for mortal agents, testing principles established (5 principles), log helper scripts, macOS 26+ platform policy

- **2026-01-28** — Jake spawn agent tool: `JakeToolHandler` protocol with `JSONActionHandler` implementation, continuation loop for tool execution feedback, wiring through `TavernCoordinator` to `ServitorSpawner`, 28 new tests (mock-based)

- **2026-02-01** — SDK migration from local ClaudeCodeSDK fork to ClodeMonster/NativeClaudeCodeSDK: static function API (`ClaudeCode.query`), `QueryOptions` replacing split config types, session storage forensics (corrupt session recovery), JSON-in-JSON issue for Jake's history display

- **2026-02-02 01:00** — SDK migration design: established that session history reading (`ClaudeNativeSessionStorage`) is Tavern-specific, not SDK functionality. Moved to TavernCore/Persistence. ClodeMonster correctly implements official SDK spec without session history. API transformation: protocol-based → namespace-based (`ClaudeCode.query()`)

- **2026-02-02** — Comprehensive transcript audit system: parallel rewind analyzer agents verify coverage across date ranges, discovered 2 missing transcripts (agent-registry-architecture Jan 25, jake-spawn-tool Jan 28), verified 30 sessions covering all existing transcripts

- **2026-02-02 16:50** — Servitor naming: MortalAgent renamed to Servitor (code), Jake calls them "The Regulars" (voice). MCP tool design (`summon_servitor`/`dismiss_servitor`) replacing JSON envelope hack. Phase 1 scope: minimal viable dispatcher (summon + dismiss only), defer message forwarding, resummon, capability distribution

- **2026-02-05** — Worktree-aware audit discovery: `list-project-dirs.sh` and `list-sessions.sh` scripts for cross-worktree session deduplication, updated `/audit-transcripts` command

- **2026-02-05/06** — Backlog mining: systematic extraction from all transcripts, PRD, session archives, code TODOs into beads issue tracker. Created epic `azu` with 40 child beads across 4 priority tiers (P1: 5, P2: 10, P3: 16, P4: 9)

- **2026-02-06** — Jake JSON response format removed: eliminated `parseJakeMessage()` and structured JSON wrapper now that MCP tools handle agent spawning natively. Jake's text responses treated same as any other agent.

- **2026-02-06** — Resource panel exploration: initial design session identifying 3 layout approaches (NavigationSplitView 3-column, HSplitView, Inspector panel). Session ended before decisions made.

- **2026-02-07 (formal spec)** — Document pipeline reorganization: `docs/` restructured into numbered pipeline stages (0-transcripts → 1-prd → 2-spec → 3-adr → 4-docs). Created formal specification skeleton with 16 modules, traceability matrix in `index.md`, `pipeline.md` overview

- **2026-02-07 (resource panel ideation)** — Resource panel design decisions via `/ideate`: HSplitView layout, per-window scope, toolbar toggle, VSplitView internal split (file tree + file content), v1 scope defined (lazy file tree, read-only viewer, binary/size detection, filtering)

- **2026-02-07 (resource panel impl)** — Resource panel implementation: 4 TavernCore files + 4 view files + 3 test suites. Wrong-worktree deployment discovered and corrected. ClodKit SDK migration (`ClaudeCodeSDK` → `ClodKit`, `ClaudeCode.query` → `Clod.query`). 200 tests passing.

- **2026-02-07 (v1 parity plan)** — V1 chat parity planning: full CLI feature inventory, user-selected scope for v1, chunked into 9 parallelizable epics (message rendering, streaming, input enhancement, permissions, slash commands, custom commands, management UIs, side pane, chat UX polish), dependency graph for parallel execution

- **2026-02-08 (autonomous testing)** — Autonomous testing infrastructure: graded testing system (Grades 1-5), MockAgent + MockMessenger protocol extraction (`AgentMessenger`), `LiveMessenger` production implementation, ViewInspector wiring tests (ADR-004), XCUITest setup with launch arguments (ADR-005), 85+ new tests established

- **2026-02-08 (swarm prompt)** — Team coordinator prompt adaptation from ClodKit project: worktree-based parallel development, bead assignment, merge coordination, model selection guidance. Created `SWARM.md` with plan mode, Grade 3 merge gates, Grade 4 hold, self-destruct

- **2026-02-08 (swarm execution)** — First swarm: 8 parallel worktrees, 76 beads across 10 epics, 3 phases. Phase 0 triage (3 beads on main), Phase 1 foundation (4 agents: specs, rendering, commands, permissions), Phase 2 extensions (3 agents: custom commands, core infra, streaming). All merged to main, 526 Grade 1+2 tests passing.

- **2026-02-08/09 (gap remediation)** — Second swarm: 12 gaps from post-v1-parity audit remediated via 8 parallel worktrees (34 beads). `PermissionManager` wired to SDK, streaming race conditions fixed, `AnyAgent` type-erasure replaced with existentials, blocking `waitUntilExit` fixed, 14 views instrumented, Grade 5 stress tests (8 files), `CommandFormattingUtils` extracted, sidecar pattern removed from docs. 574 Grade 1+2 + 32 Grade 3 tests passing.

- **2026-02-09 (CLAUDE.md revamp)** — Major CLAUDE.md overhaul: added 6 new sections (Non-Negotiable Invariants, Servitor Types, Key Patterns, Session Persistence Model, Documentation Pipeline, Slash Commands). Expanded testing section with grade system. Restored Jake's contractions after ClodKit apostrophe bug fix upstream. Established "agent briefing" principle: CLAUDE.md is the document agents read at session start.

- **2026-02-09** — Multi-type file audit: 90 Swift files audited, 15 with multiple top-level types, 3 split (AgentMessenger → 3 files, CommitmentVerifier → 4 files, TavernApp → 5 files). Anti-pattern identified: protocol + production impl + mock impl + data types in single file. iCloud duplicate cleanup.

- **2026-02-10** — Property-based spec reframing: all 16 spec modules rewritten to lead with properties ("whenever X, then Y") instead of procedural workflows. Four-gap framework: (1) promote testable assertions to primary framing, (2) convert flowcharts to property tables, (3) separate "what must hold" from "how to implement", (4) distinguish illustrative examples from prescriptive specs.

- **2026-02-12** — Spec enumeration with stable content addressing: files renamed to §000–§017, `§DOC.SECTION.SUBSECTION` addressing scheme for cross-references. 27 cross-reference opportunities identified, 12 major duplicated concepts assigned canonical homes. Append-only numbering ensures permanent addresses.

- **2026-02-13** — Preview requirements and crash fix: investigated NavigationSplitView preview crash (macOS SwiftUI NSOutlineView bug), added `#Preview` blocks to all 18 views, created ADR-006 requiring previews on every SwiftUI view file. Standard preview project URL: `/tmp/tavern-preview`. Updated CLAUDE.md Honor System.

- **2026-02-14 (provenance tracking)** — Provenance tracking system: created PRD §19.4 ("Completeness and Correctness Standards"), spec module §018 (spec fidelity, 7 requirements REQ-FID-001 through REQ-FID-007), ADR-007 (provenance MARK comments for code, `.tags()` for tests, bidirectional traceability). Closed `vpn` epic (16/16 complete). Self-verification principle: development process subject to same rigor as the system itself.

- **2026-02-14 (redo skill)** — Redo build system operationalized: created `/redo` skill with full `.do` file table, dependencies, and patterns. Added build dependency graph to CLAUDE.md. Established frequency-based placement principle: 95% info in CLAUDE.md, specialized context in skills, tutorials for humans.

- **2026-02-14 (session mode control)** — Per-agent session mode control designed: each servitor gets independent permission mode (Plan/Normal/Auto-Edit/YOLO). UI placement in input bar area. ExitPlanMode approval flow through `canUseTool` callback. Mode mapping between Tavern and ClodKit enums. Stub beads created for model selection, thinking tokens, and full session control panel.

- **2026-02-14 (Xcode preview automation)** — Developed Xcode preview automation loop (Grade 4 pattern): Cmd+Option+P triggers preview resume, DiagnosticReports `.ips` files detect crashes automatically. Discovered NSOutlineView preview invariant: any SwiftUI property wrapper in preview views triggers crash during NSOutlineView initial layout. Fix: pure static inline views with no property wrappers in `#Preview` blocks.

- **2026-02-15** — Test performance: Grade 1+2 wallclock time cut from 13 minutes to 1.5 seconds. Three independent bugs fixed: (1) SDK live tests in wrong grade target (moved to Grade 3), (2) redo-log Unicode crash on Swift Testing symbols, (3) test runner hang from `loadCustomCommands()`/`restoreServitors()` keeping CFRunLoop alive. Added `restoreState` parameter to `TavernCoordinator.init`.

- **2026-02-16 (attestation concept)** — Designed `/attest` command for semantic conformance analysis. Fills the gap between traceability (structural links exist) and conformance (code satisfies requirements). Three-phase process: mechanical gathering → semantic analysis (per-property verdicts) → verdict synthesis (CONFORMANT/PARTIAL/NON-CONFORMANT). Three invocation modes: single requirement, prefix, or module number.

- **2026-02-16 (spec review)** — Batched Q&A across all 16 spec modules. Terminology decisions: "agent" → "servitor", "spawn" → "summon", "outputs" → "connectors", view "modes" → "representations". Architecture drops: closed plugin set, three storage layers, Jake's tool handler protocol, continuation loop, expert prompts, workflow metrics, Combine minimized. Seven new spec modules decided (§019–§025): States & Modes, Servitor Trees, Capability Delegation, Chat Discussions & Sessions, Keyboard Shortcuts, Accessibility, Search. Failure boundaries concept (Erlang-style supervision). Capability delegation as async with handle. Done vs Complete distinction. Distribution: source code only.

- **2026-02-16 (audit-spec pipeline)** — Extended `/audit-spec` with top-to-bottom PRD pipeline flow reporting: per-PRD-section downstream coverage table with implementation and test percentages. Established spec convention: strikethrough for dropped requirements (content preserved for history, rationale visible inline). Documented in `000-index.md` §5.

- **2026-02-21** — Servitor taxonomy finalized and Grade 4 XCUITest fix. Definitive rename: `Agent` protocol → `Servitor`, `Servitor` class → `Mortal`, `ServitorSpawner` → `MortalSpawner`, `AgentRegistry` → `ServitorRegistry`, `AgentMessenger` → `ServitorMessenger`, `AgentListViewModel` → `ServitorListViewModel`. Grade 4 tests fixed: 4/8 failing from duplicate windows. Root cause: SwiftUI window persistence (separate from macOS Saved Application State). Fix: `.firstMatch` pattern for multi-window tolerance. `-ApplePersistenceIgnoreState YES` breaks SwiftUI entirely on macOS 26.

- **2026-02-28** — Tileboard architecture design session: comprehensive redesign using hybrid navigation reference architecture. SPM-enforced tile isolation, responder closures, socket pattern, provider protocols for DI. Three-level hierarchy: TavernApp (reifier) → TavernProject (document-level board) → WindowBoard (window-level board, née TavernCoordinator). Providers ARE the domain objects (no wrapper layer). @Observable migration from ObservableObject. ClodSession designed as stateful per-servitor translation layer replacing stateless ServitorMessenger. Jake/Mortal duplication map: most code is session lifecycle boilerplate, not domain logic. Nine architecture trees documented (ownership, view hierarchy, SPM graph, data flow, lifecycle, threading, provider scoping, filesystem layout, migration mapping). Core* rename to ADR-008.

- **2026-03-01 (rich streaming gap analysis)** — SDK gap analysis: compared local ClodKit development copy against Tavern consumption patterns, found 17 gaps. Critical discovery: streaming pipeline has two modes — default gives cumulative snapshots, partial messages (`includePartialMessages: true`) gives incremental `content_block_start/delta/stop` events. Produced 10 detailed implementation plans (A–J). Established build strategy: feature branch + local path dependency for working against unpublished SDK APIs.

- **2026-03-01 (rich streaming implementation)** — Implemented Plan A (Rich Streaming Pipeline) on `feature/rich-streaming` branch across 16 files. `StreamEvent` widened from 5 to 12 cases with `ToolUseInfo`, `ToolResultInfo`, `CompletionInfo`, `RateLimitInfo`. Full `ServitorMessenger.queryStreaming()` rewrite using content block state machine. Created ADR-010 (SDK Feature Parity): living matrix tracking ~120 SDK capabilities with statuses (62 implemented, 16 gaps, 36 deferred). SDK currency rules: version bump = feature audit.

- **2026-03-01 (ClodKit lifecycle)** — Designed ClodKit deinit chain for orphaned subprocess cleanup: `ProcessTransport.deinit` → `process.terminate()`, `ClaudeSession.deinit` → `transport.close()`, `ClaudeQuery.deinit` → `Task { await session.close() }`. Established compiler-first safety principle: prefer designs where incorrect code fails at compile time, not code review. Grade 3 testing safety: three-layer defense (environment stripping, permissionMode = .plan, ClodKit deinits). Opened GitHub issue on ClodKit.

- **2026-03-01 (TavernKit consolidation)** — Eliminated Core* indirection: CoreModels + CoreProviders merged into single `TavernKit` module (the compiler-enforced public interface surface). CoreUI dissolved — views moved to owning tiles. 12 modules reduced to 9. "Importing up" vs "peering in" distinction: tiles can import other tiles' public APIs (importing up), but must never access TavernCore concrete implementations (peering in). Fixed infinite recursion bug (WindowBoard → ServitorListTile → responder → WindowBoard). Established "sockets lift up" principle: board communicates with tiles only through sockets in both directions. Added explicit test timeouts to all 116 test functions.

- **2026-03-01 (tileboard addendum)** — Code comment style standard: comments explain "why", not "what". ViewModel elimination: deleted all 6 ViewModel classes (ChatViewModel, ServitorListViewModel, ResourcePanelViewModel, BackgroundTaskViewModel, TodoListViewModel, PermissionSettingsViewModel) and TavernCoordinator. Tiles replace ViewModels as UX domain models. Zero ViewModel references remain.

- **2026-03-01 (verification suite)** — Created unified verification suite (ADR-009) and `/verify` slash command: single-command complete project gap analysis across 10 sections (build health, test health, code coverage, spec conformance, pipeline traceability, provenance, beads state, structural rules, architecture, informational). Dead code reframed as "unwired components" — development gaps, not obsolete code. Agent motivation philosophy: crew accountability framing. Hierarchical code coverage reporting. Removed arbitrary thresholds. `bd -n 0` mandatory for all beads queries.

- **2026-03-01/02 (tiles own all state)** — Live debugging: fixed stale session resume (`ControlProtocolError.timeout`) by disabling resume temporarily. Fixed disappearing messages on servitor switch — root cause: `ChatTileView.task` calling `loadSessionHistory()` on cached tiles, overwriting messages on every SwiftUI view recreation. Fix: moved history load to `ChatSocketPool.tile(for:)` creation site. Established Core Pattern #1: "Tiles Own All State" — views must NEVER trigger state initialization on tiles. Added ChatTile and ChatSocketPool test suites.

- **2026-03-02** — Cleanup orchestrator design: two maintenance commands. `/update-status` (light cycle): audit-transcripts → reader → spec-reader → status. `/update-verifications` (heavy cycle): spec-status → audit-spec → attest-report → verify. Team-based serial orchestration with error gating. Platform constraint discovered: teammates cannot spawn sub-agents (Agent tool is main-context only). `spec-status` and `audit-spec` modified to write reports to disk. `/verify` stripped of attest step (explicit in orchestrator instead).


---


## Features


### 1. Jake (The Proprietor)

**Implemented:**

- Jake servitor class with ClodKit SDK integration

- System prompt establishing role and personality (restored authentic voice with contractions after ClodKit apostrophe bug fix)

- Can receive messages and respond

- Session persistence across app restarts (UserDefaults)

- Session history rehydration from Claude's JSONL files

- Jake character specification (voice, vocabulary, politics)

- Per-project session storage (Jake maintains `_projectPath`)

- Character document extracted to `docs/0-transcripts/jake-character.md`

- MCP tools for servitor spawning (`summon_servitor`, `dismiss_servitor`)

- Streaming responses via `ServitorMessenger` protocol

- Plain text responses (JSON wrapper removed after MCP migration)

- Rich streaming with content block state machine (thinking, tool use, text deltas, system events)


**Remaining:**

- Proactive suggestions to zoom into other servitors


---


### 2. Servitor Spawning & Registry

**Implemented:**

- `Servitor` protocol with common interface (uses `any Servitor` existentials, no type erasure)

- `ServitorRegistry` for tracking active servitors (thread-safe via DispatchQueue)

- `Mortal` class with optional assignment, state tracking (idle/working/waiting/done)

- `Mortal` methods: `addCommitment()`, `markWaiting()`, `markDone()`

- `Mortal` detects both "DONE" and "COMPLETED" signals

- `Mortal` detects "WAITING" signal for pause state

- `MortalSpawner` coordinating registry and name generator with messenger factory injection

- Naming theme system (LOTR, Rick & Morty, Santa's Reindeer, etc.)

- Tiered name depletion (less silly → more silly)

- Global name uniqueness

- Two-mode spawn: user-spawn (waits for input) vs Jake-spawn (works immediately)

- Instant spawn via toolbar `+` button (no dialog)

- Servitor list sidebar with state indicators and context menu (edit/close)

- Servitor persistence via UserDefaults (`PersistedAgent` type)

- Servitor restoration on app restart

- Mutable chat description field (visible in sidebar)

- Streaming support for both Jake and Mortal via `sendStreaming()` with cancel closures


**Remaining:**

- Hierarchical spawn trees (servitors spawning children)

- Perseverance mode ("Ralph Wiggum" auto-continue)

- Servitor hibernation/reaping

- Capability delegation (async summon with handle, separate `delegate` command)

- Failure boundaries (Erlang-style supervision within servitor trees)


---


### 3. Chat & UI

**Implemented:**

- `ChatTileView` with message history, input field (replaces old `ChatView`)

- "Cogitating" status with verb from vocab list

- `MessageType` enum (text, toolUse, toolResult, toolError, thinking, webSearch)

- Block-aware message rendering with extracted components (`MessageRowView`, `CollapsibleBlockView`, `CodeBlockView`, `DiffView`)

- Content block parsing from Claude's JSONL

- Servitor list sidebar with selection and context menu

- Multi-chat navigation (switching between servitors)

- `ServitorListTile` managing servitor list and selection state (replaces `ServitorListViewModel`)

- Chat tile caching via `ChatSocketPool` (reused on servitor reselection, tiles own all state)

- Session history loading for mortal servitors

- Rich streaming responses with content block state machine (thinking, text, tool_use deltas, tool results, system events, rate limits)

- Streaming indicator and cancel button

- Multi-line input (Enter = send, Shift+Enter = newline)

- @ file mention autocomplete

- Servitor sidebar status indicators (idle/working/error)

- Running cost/token display with cache token counts

- Per-tool progress indicator with elapsed time

- Scroll-to-bottom button

- Side pane with tabs: background tasks, TODOs, tab switcher

- `#Preview` blocks on all SwiftUI view files (ADR-006)


**Remaining:**

- Typewriter effect

- Thinking/tools as separate panels (not inline)

- Notification badges when servitors need attention

- Ephemeral vs kept-open chat distinction

- Cross-servitor unified views

- Per-agent session mode control UI (Plan/Normal/Auto-Edit/YOLO in input bar)


---


### 4. Document-Based Architecture

**Implemented:**

- Project-as-document model (any directory works)

- `TavernProject` model holding root URL (refactored as document-level board)

- `ProjectManager` for open/recent projects

- Welcome screen with recent projects

- File > Open via NSOpenPanel

- Dock menu with recent projects

- Multi-window support (each project = separate window, N windows per project)

- Per-project session storage

- Window restoration on app restart

- `WindowOpeningService` bridging AppKit to SwiftUI

- `TavernAppDelegate` for Dock menu integration

- Window restoration fixed (`.task(id:)` pattern for dependent values)


**Remaining:**

- `.tavern/` in-project shareable config

- iCloud personal state storage

- Saved layouts (named templates)

- "The Regulars" welcome page


---


### 5. Commitments & Verification

**Implemented:**

- `Commitment` struct (description, assertion, status)

- `CommitmentList` for servitors

- Verifier that runs assertions and updates status (non-blocking via `Process.terminationHandler`)

- Completion flow: servitor says "done" → verification → actual done or continue

- Thread-safe helpers (`LockedFlag`, `LockedRef`) for concurrent verification

- Tests for commitment system

- Done vs Complete distinction: Done = servitor says "done" (request to check), Complete = verified commitment met


**Remaining:**

- Real verification logic (currently mock)

- Commitments stored in doc store file

- Independent subagent verification

- Failure surfacing to user


---


### 6. Doc Store

**Implemented:**

- `DocStore` class wrapping filesystem

- CRUD operations for markdown documents

- Frontmatter parsing

- Servitor nodes with ID, name, assignment, state

- Servitor persistence to files

- Tests for doc store


**Remaining:**

- Servitors syncing state to doc store continuously

- Work queues

- Specs/PRDs storage

- Workflow templates

- Inter-servitor message storage


---


### 7. Tileboard Architecture

**Implemented:**

- SPM-enforced tile isolation: each feature is its own SPM target, leaf tiles cannot import other leaf tiles

- Responder closures for navigation intent (all params required — compiler catches unwired closures)

- Socket pattern: sockets live in TavernBoardTile only, wiring responder closures to navigator methods

- `WindowBoard` (née `TavernCoordinator`) as window-level board with facets

- Three-level hierarchy: TavernApp (reifier) → TavernProject (document-level board) → WindowBoard (window-level board)

- @Observable throughout (migrated from ObservableObject/@Published)

- Provider protocols for dependency injection (tiles depend on protocols, not implementations)

- Six leaf tiles: `ServitorListTile`, `ChatTile`, `ResourcePanelTile`, `ApprovalTile`, `PermissionSettingsTile`, `TavernBoardTile`

- `ChatSocketPool` managing `[ServitorID: ChatTile]` (create on demand, tear down on dismiss)

- `TavernKit` module as compiler-enforced public interface surface (merged CoreModels + CoreProviders)

- CoreUI dissolved — views moved to owning tiles

- "Sockets lift up" principle: board communicates with tiles only through sockets in both directions

- "Tiles Own All State" principle: views are pure renderers, tiles own initialization and state lifecycle

- Resource panel (right-side pane with file tree browser + read-only file viewer)

- Resource panel toggle via toolbar button

- File tree with lazy loading, binary detection, size caps, filtered directories

- All ViewModel classes eliminated (replaced by tiles)

- `TavernCoordinator` eliminated (replaced by `WindowBoard`)


**Remaining:**

- Agent layout mutation tools (with permission)

- Layout suggestion tools

- View modes / representations (unified stream vs split components)

- Multiple views of same servitor

- Dead servitor "bodies" (tiles persist for review)

- Saved layout templates vs concrete snapshots

- Tree folding/collapsing


---


### 8. Sandbox & Changesets

**Implemented:**

- Nothing yet


**Remaining:**

- Overlay filesystem (changeset)

- Platform selection (Mac, container, cloud)

- Isolation levels (VM, container, OS sandbox)

- Network access control

- Servitor can trash everything and restart

- Changeset application to original files


---


### 9. Build & Testing Infrastructure

**Implemented:**

- XcodeGen setup (`project.yml`)

- Redo build system (build, run, test, test-core, test-integration, test-grade3, test-grade4, test-all, stop, clean, xcodegen)

- `/redo` skill with full `.do` file table and dependency graph

- Build dependency graph in CLAUDE.md

- ~250 tests (Grade 1+2: 187, wiring+SDK: 31, Grade 3 integration: 32)

- Grade 4 XCUITest infrastructure with launch arguments (`--ui-testing`, `--project-path`)

- Grade 4 fix: `.firstMatch` pattern for multi-window SwiftUI tolerance

- Grade 5 stress tests (8 test files: concurrency, message accumulation, file tree scanning, permissions, command dispatch, session loading, todo/background bulk operations)

- TavernLogger with categories (agents, chat, coordination, claude, permissions, commands)

- Console.app filtering

- Build output to `~/.local/builds/tavern`

- MockServitor for Tile/Coordinator testing

- `ServitorMessenger` protocol with `MockMessenger` (test double)

- Integration tests for session rehydration

- ViewInspector wiring tests (ADR-004) for SwiftUI view-ViewModel binding verification

- App icon generation via redo (`icon.do`)

- Log helper scripts (`scripts/logs.sh`, `logs-stream.sh`, `logs-category.sh`, `logs-errors.sh`)

- macOS 26+ platform target (no backwards compat)

- View instrumentation tests (verify logging fires in SwiftUI views)

- `#Preview` blocks on all SwiftUI views (ADR-006)

- Xcode preview automation loop (Grade 4 pattern: Cmd+Opt+P + DiagnosticReports crash detection)

- Test performance optimized: 13 min → 1.5 sec (SDK tests moved to Grade 3, redo-log Unicode fix, `restoreState` parameter)

- Explicit test timeouts on all 116 test functions across all targets

- ChatTile and ChatSocketPool test suites (tile-owns-state regression tests)

- Grade 3 testing safety: three-layer defense (env stripping, plan mode, ClodKit deinits)


**Remaining:**

- Log-based automated verification

- Performance regression baselines

- Grade 2.9 local LLM testing (llama-ish + Apple Intelligence)

- Mutation testing (deliberately inject bugs to verify test coverage)

- 100% code coverage target


---


### 10. SDK Integration

**Implemented:**

- ClodKit v1.0.0 (migrated from local fork → ClodeMonster → ClodKit)

- `Clod.query()` static API with `QueryOptions`

- `ServitorMessenger` wrapping SDK calls (batch and streaming modes)

- Rich streaming via `includePartialMessages: true` with content block state machine (feature/rich-streaming branch)

- `StreamEvent` widened to 12 cases: textDelta, thinkingDelta, toolUseStarted, toolUseFinished, toolProgress, toolResult, systemMessage, rateLimitInfo, completedTurn, completed, promptSuggestions, error

- `canUseTool` callback integration for permission enforcement

- Path encoding for session storage

- Content block parsing for tool_use inputs and tool_result error flags

- ADR-010: SDK Feature Parity living matrix (~120 capabilities tracked, 62 implemented, 16 gaps, 36 deferred)

- SDK currency rules: version bump = feature audit (atomic commit with matrix update)

- Session history reading confirmed as Tavern-specific (not SDK functionality)

- ClodSession designed as stateful per-servitor translation layer (absorbs session lifecycle from Jake/Mortal)

- Compiler-first safety principle for isolation boundary design


**Remaining:**

- ClodKit deinit chain (ProcessTransport, ClaudeSession, ClaudeQuery — GitHub issue open)

- ClodSession implementation (designed but not fully implemented)

- Remaining 16 SDK feature gaps (Plans B–J)

- Session resume re-enablement (disabled due to stale session ControlProtocolError)


---


### 11. Permissions Subsystem

**Implemented:**

- `PermissionManager` with mode-based evaluation (bypassPermissions, plan, dontAsk, normal, acceptEdits)

- `PermissionStore` backed by UserDefaults

- Allow/deny rules with wildcard pattern matching

- `ToolApprovalRequest` / `ToolApprovalResponse` types

- `ToolApprovalView` connected to async permission decisions

- "Always allow" rule persistence via approval responses

- Integration with `ServitorMessenger` via `canUseTool` callback

- Mode switching affects subsequent evaluations

- Tests for permission enforcement


**Remaining:**

- Per-agent session mode control (Plan/Normal/Auto-Edit/YOLO per servitor)

- ExitPlanMode approval flow (plan presentation → user review → mode transition)

- Permission rules display/editing UI (`PermissionSettingsTile` exists but needs wiring)

- Per-project permission profiles


---


### 12. Slash Command Infrastructure

**Implemented:**

- `CommandRegistry` with command parsing and dispatch

- `CommandParser` extracting command name and arguments from input

- Core commands: `/compact`, `/cost`, `/model`, `/status`, `/context`, `/stats`

- Max thinking tokens control

- Autocomplete integration for command names

- Custom command discovery from `.claude/commands/*.md`

- Subdirectory namespacing for custom commands

- Argument substitution ($ARGUMENTS)

- `CommandFormattingUtils` shared utility (formatTokens, makeBar)

- Tests for command dispatch and formatting


**Remaining:**

- Management commands with substantial UIs (/agents, /hooks, /mcp)


---


### 13. Progressive Unlocks

**Implemented:**

- PRD section defining concept


**Remaining:**

- Message count tracking

- Threshold system

- Content unlocking (cogitation verbs, naming themes, easter eggs)

- Persistence strategy


---


### 14. Inter-Agent Communication

**Implemented:**

- Nothing yet


**Remaining:**

- Upward bubbling (child → parent → user)

- Lateral messaging (sibling servitors)

- Direct-to-user with oversight

- "Calling" and "hanging up" protocol


---


### 15. Architecture & ADRs

**Implemented:**

- Shape selection complete: Shared Workspace (E) + Supervisor Tree (D) + Reactive Streams (A) + Plugin (I) + Layer (C)

- ADR-001: Architecture shape selection with rationale

- 49 architecture proposals in `docs/3-adr/proposals/`

- Synthesis report with 16 shapes and 122-pair compatibility matrix

- Async primitive strategy: AsyncStream long-term, Combine at boundary

- ADR-002: Testing Grade System (Grades 1-5)

- ADR-003: Dependency Injection (MockServitor + ServitorMessenger two-layer approach)

- ADR-004: ViewInspector for SwiftUI wiring tests

- ADR-005: XCUITest for E2E validation

- ADR-006: Preview requirements (every SwiftUI view file must have `#Preview`)

- ADR-007: Provenance tracking (MARK comments for code, `.tags()` for tests, bidirectional traceability)

- ADR-008: Core* rename (CoreModels + CoreProviders → TavernKit, CoreUI dissolved)

- ADR-009: Unified verification suite (10-section complete gap analysis, `/verify` command)

- ADR-010: SDK Feature Parity (living matrix, SDK currency rules, ~120 capabilities tracked)


**Remaining:**

- Full implementation of selected architecture shapes

- Supervisor tree implementation

- Message bus over shared workspace

- Plugin system for servitor types and spawners


---


### 16. Design Principles

**Documented:**

- **Informative Error Principle** — Errors must be specific and actionable

- **Sum Type Error Design** — Enumerate all failure modes upfront via GADTs/sum types

- **Instrumentation Principle** — Logs must diagnose issues without screenshots

- **Autonomous Testing Principle** — Tests run without human interaction

- **Perception-Bounded Performance** — "Fast" defined by user perception; isolation, responsiveness, scale independence

- **App Restart Workflow** — After rebuilding, kill and relaunch the app

- **Compiler-First Safety** — Prefer designs where incorrect code fails at compile time, not code review. Agents can't reliably catch code review problems; compilers always catch type errors.

- **Tiles Own All State** — Views are pure renderers. Tiles own initialization and state lifecycle. View lifecycle events are for view-local behavior only.

- **Sockets Lift Up** — Board communicates with tiles only through sockets in both directions.

- **Self-Verification Principle** — Development process subject to same rigor as the system itself. Provenance tracking makes requirement → code fidelity machine-verifiable.


**Testing Principles (added 2026-01-27):**

- **Parallel Code Path Testing** — All paths to same outcome need tests

- **Feature Toggle Coverage** — If tests disable a feature, other tests must enable it

- **User Journey Integration Tests** — Test what users actually do end-to-end

- **Symmetry Assertions** — Assert parallel APIs behave consistently (compile-time drift detection)

- **New Entity = New Test Coverage** — New types need equivalent tests to existing types


---


### 17. Formal Specification Pipeline

**Implemented:**

- Document pipeline reorganization: `docs/` restructured into numbered stages (0-transcripts → 1-prd → 2-spec → 3-adr → 4-docs)

- `pipeline.md` defining rules (forward only, traceability, single home per document)

- 25 numbered spec modules (§000–§025) in `docs/2-spec/` with traceability matrix and introduction

- All spec modules filled from transcripts, PRD, and session logs

- Property-based spec methodology: requirements lead with **Properties:** blocks, procedural workflows converted to property tables, state machine diagrams preserved (they ARE properties)

- Stable content addressing (`§DOC.SECTION.SUBSECTION`) with append-only numbering for permanent cross-references

- 27 cross-reference opportunities identified, 12 duplicated concepts assigned canonical homes

- Dropped requirement convention: `~~strikethrough~~` with visible rationale inline (content preserved for history)

- `/spec-status` — provenance coverage dashboard

- `/audit-spec` — PRD-to-spec coverage verification with top-to-bottom pipeline flow reporting

- `/attest` — semantic conformance analysis (single requirement, prefix, or module)

- `/attest-report` — full attestation report across all modules (swarm-orchestrated)

- `/trace` — single requirement traceability through PRD → spec → code → tests

- Provenance tracking: MARK comments for code, `.tags()` for tests (ADR-007)

- `/verify` — unified verification suite combining all checks into single report (ADR-009)

- Spec review: terminology standardized (servitor, summon, connectors, representations), architecture drops documented, 7 new modules (§019–§025)


**Remaining:**

- Deduplication pass: replace restated content with `§` references to canonical homes

- External docs updated with new spec file names

- Incremental verification that downstream elements are complete relative to upstream

- `/spec-reader` compiled active specification reader


---


### 18. Process & Methodology

**Implemented:**

- Seed design interview process with notation ([U], [C], [T], [S])

- `/conceive` command for bootstrapping design sessions

- `/audit-transcripts` command for transcript verification and repair (worktree-aware)

- `/status` command for project status updates

- `/reader` command for reader document synthesis

- `/commit` command for transcribe-and-commit workflow

- Parallel agent spawning for architecture exploration

- Transcript audit methodology (one-transcript-per-agent rule)

- Beads issue tracking for backlog management

- Team-based swarm coordination (multi-worktree parallel development with merge gates)

- `/update-status` — light cleanup cycle orchestrator (audit-transcripts → reader → spec-reader → status)

- `/update-verifications` — heavy verification cycle orchestrator (spec-status → audit-spec → attest-report → verify)

- Error gating principle: structural issues halt execution; "nothing new found" is success

- Agent briefing principle: CLAUDE.md updated incrementally as codebase grows

- Frequency-based placement: 95% info in CLAUDE.md, specialized context in skills, tutorials for humans

- Code comment style: explain "why", not "what"


**Remaining:**

- (Process is ongoing maintenance, not a feature to "complete")
