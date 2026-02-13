# Project Status Summary

**Generated:** 2026-02-12
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

- **2026-02-09** — Multi-type file audit: 90 Swift files audited, 15 with multiple top-level types, 3 split (AgentMessenger → 3 files, CommitmentVerifier → 4 files, TavernApp → 5 files). Anti-pattern identified: protocol + production impl + mock impl + data types in single file. iCloud duplicate cleanup.

- **2026-02-10** — Property-based spec reframing: all 16 spec modules rewritten to lead with properties ("whenever X, then Y") instead of procedural workflows. Four-gap framework: (1) promote testable assertions to primary framing, (2) convert flowcharts to property tables, (3) separate "what must hold" from "how to implement", (4) distinguish illustrative examples from prescriptive specs.

- **2026-02-12** — Spec enumeration with stable content addressing: files renamed to §000–§017, `§DOC.SECTION.SUBSECTION` addressing scheme for cross-references. 27 cross-reference opportunities identified, 12 major duplicated concepts assigned canonical homes. Append-only numbering ensures permanent addresses.


---


## Features


### 1. Jake (The Proprietor)

**Implemented:**

- Jake agent class with ClodKit SDK integration

- System prompt establishing role and personality (restored authentic voice with apostrophes)

- Can receive messages and respond

- Session persistence across app restarts (UserDefaults)

- Session history rehydration from Claude's JSONL files

- Jake character specification (voice, vocabulary, politics)

- Per-project session storage (Jake maintains `_projectPath`)

- Character document extracted to `docs/0-transcripts/jake-character.md`

- MCP tools for agent spawning (`summon_servitor`, `dismiss_servitor`)

- Streaming responses via `AgentMessenger` protocol

- Plain text responses (JSON wrapper removed after MCP migration)


**Remaining:**

- Proactive suggestions to zoom into other agents


---


### 2. Agent Spawning & Registry

**Implemented:**

- `Agent` protocol with common interface (uses `any Agent` existentials, no type erasure)

- `AgentRegistry` for tracking active agents (thread-safe via DispatchQueue)

- `Servitor` class with optional assignment, state tracking (idle/working/waiting/done)

- `Servitor` methods: `addCommitment()`, `markWaiting()`, `markDone()`

- `Servitor` detects both "DONE" and "COMPLETED" signals

- `Servitor` detects "WAITING" signal for pause state

- `ServitorSpawner` coordinating registry and name generator with messenger factory injection

- Naming theme system (LOTR, Rick & Morty, Santa's Reindeer, etc.)

- Tiered name depletion (less silly → more silly)

- Global name uniqueness

- Two-mode spawn: user-spawn (waits for input) vs Jake-spawn (works immediately)

- Instant spawn via toolbar `+` button (no dialog)

- Agent list sidebar with state indicators and context menu (edit/close)

- Agent persistence via UserDefaults (`PersistedAgent` type)

- Agent restoration on app restart

- Mutable chat description field (visible in sidebar)

- Streaming support for both Jake and Servitor via `sendStreaming()` with cancel closures


**Remaining:**

- Hierarchical spawn trees (agents spawning children)

- Perseverance mode ("Ralph Wiggum" auto-continue)

- Agent hibernation/reaping


---


### 3. Chat & UI

**Implemented:**

- `ChatView` with message history, input field

- "Cogitating" status with verb from vocab list

- `MessageType` enum (text, toolUse, toolResult, toolError, thinking, webSearch)

- Block-aware message rendering with extracted components (`MessageRowView`, `CollapsibleBlockView`, `CodeBlockView`, `DiffView`)

- Content block parsing from Claude's JSONL

- Agent list sidebar with selection and context menu

- Multi-chat navigation (switching between agents)

- `AgentListViewModel` managing agent list and selection state

- Chat view model caching (reused on agent reselection)

- UI module bridging SwiftUI views to TavernCore

- Session history loading for mortal agents

- Streaming responses with partial message updates

- Streaming indicator and cancel button

- Multi-line input (Enter = send, Shift+Enter = newline)

- @ file mention autocomplete

- Agent sidebar status indicators (idle/working/error)

- Running cost/token display

- Per-tool progress indicator with elapsed time

- Scroll-to-bottom button

- Side pane with tabs: background tasks, TODOs, tab switcher


**Remaining:**

- Typewriter effect

- Thinking/tools as separate panels (not inline)

- Notification badges when agents need attention

- Ephemeral vs kept-open chat distinction

- Cross-agent unified views


---


### 4. Document-Based Architecture

**Implemented:**

- Project-as-document model (any directory works)

- `TavernProject` model holding root URL

- `ProjectManager` for open/recent projects

- Welcome screen with recent projects

- File > Open via NSOpenPanel

- Dock menu with recent projects

- Multi-window support (each project = separate window)

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

- `CommitmentList` for agents

- Verifier that runs assertions and updates status (non-blocking via `Process.terminationHandler`)

- Completion flow: agent says "done" → verification → actual done or continue

- Thread-safe helpers (`LockedFlag`, `LockedRef`) for concurrent verification

- Tests for commitment system


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

- Agent nodes with ID, name, assignment, state

- Agent persistence to files

- Tests for doc store


**Remaining:**

- Agents syncing state to doc store continuously

- Work queues

- Specs/PRDs storage

- Workflow templates

- Inter-agent message storage


---


### 7. Dynamic View Architecture

**Implemented:**

- Multi-window support with window restoration

- Per-project windows

- Welcome window with recent projects list

- Window state persisted across app restarts

- GUI instrumentation guide (`docs/4-docs/gui-instrumentation-guide.md`)

- Resource panel (right-side pane with file tree browser + read-only file viewer)

- Resource panel toggle via toolbar button

- File tree with lazy loading, binary detection, size caps, filtered directories


**Remaining:**

- Composable tiles within windows

- Agent layout mutation tools (with permission)

- Layout suggestion tools

- View modes (unified stream vs split components)

- Multiple views of same agent

- Dead agent "bodies" (tiles persist for review)

- Saved layout templates vs concrete snapshots

- Tree folding/collapsing

- Template vs concrete view system (from view architecture discussion)

- Component-based chat (thinking blocks, tool logs separate from chat)


---


### 8. Sandbox & Changesets

**Implemented:**

- Nothing yet


**Remaining:**

- Overlay filesystem (changeset)

- Platform selection (Mac, container, cloud)

- Isolation levels (VM, container, OS sandbox)

- Network access control

- Agent can trash everything and restart

- Changeset application to original files


---


### 9. Build & Testing Infrastructure

**Implemented:**

- XcodeGen setup (`project.yml`)

- Redo build system (build, run, test, test-core, test-integration, test-grade3, test-grade4, test-all, stop, clean, xcodegen)

- 574 Grade 1+2 unit tests across TavernCoreTests and TavernTests

- 32 Grade 3 integration tests (real Claude via ClodKit)

- Grade 4 XCUITest infrastructure with launch arguments (`--ui-testing`, `--project-path`)

- Grade 5 stress tests (8 test files: concurrency, message accumulation, file tree scanning, permissions, command dispatch, session loading, todo/background bulk operations)

- TavernLogger with categories (agents, chat, coordination, claude, permissions, commands)

- Console.app filtering

- Build output to `~/.local/builds/tavern`

- MockAgent for ViewModel/Coordinator testing

- `AgentMessenger` protocol with `LiveMessenger` (production) and `MockMessenger` (test double)

- Integration tests for session rehydration

- ViewInspector wiring tests (ADR-004) for SwiftUI view-ViewModel binding verification

- App icon generation via redo (`icon.do`)

- Log helper scripts (`scripts/logs.sh`, `logs-stream.sh`, `logs-category.sh`, `logs-errors.sh`)

- macOS 26+ platform target (no backwards compat)

- View instrumentation tests (verify logging fires in SwiftUI views)


**Remaining:**

- Log-based automated verification

- Performance regression baselines


---


### 10. SDK Integration

**Implemented:**

- ClodKit v1.0.0 (migrated from local fork → ClodeMonster → ClodKit)

- `Clod.query()` static API with `QueryOptions`

- `LiveMessenger` wrapping SDK calls (batch and streaming modes)

- Streaming via `AsyncThrowingStream<StreamEvent, Error>` with cancellation support

- `canUseTool` callback integration for permission enforcement

- Path encoding for session storage

- Content block parsing for tool_use inputs and tool_result error flags


**Remaining:**

- Upstream contributions or fork maintenance


---


### 11. Permissions Subsystem

**Implemented:**

- `PermissionManager` with mode-based evaluation (bypassPermissions, plan, dontAsk, normal, acceptEdits)

- `PermissionStore` backed by UserDefaults

- Allow/deny rules with wildcard pattern matching

- `ToolApprovalRequest` / `ToolApprovalResponse` types

- `ToolApprovalView` connected to async permission decisions

- "Always allow" rule persistence via approval responses

- Integration with `LiveMessenger` via `canUseTool` callback

- Mode switching affects subsequent evaluations

- Tests for permission enforcement


**Remaining:**

- Permission rules display/editing UI

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

- Lateral messaging (sibling agents)

- Direct-to-user with oversight

- "Calling" and "hanging up" protocol


---


### 15. Architecture (ADR-001)

**Implemented:**

- Shape selection complete: Shared Workspace (E) + Supervisor Tree (D) + Reactive Streams (A) + Plugin (I) + Layer (C)

- ADR-001 documenting decision with rationale

- 49 architecture proposals in `docs/3-adr/proposals/`

- Synthesis report with 16 shapes and 122-pair compatibility matrix

- Async primitive strategy: AsyncStream long-term, Combine at boundary

- ADR-002: Testing Grade System (Grades 1-5)

- ADR-003: Dependency Injection (MockAgent + AgentMessenger two-layer approach)

- ADR-004: ViewInspector for SwiftUI wiring tests

- ADR-005: XCUITest for E2E validation


**Remaining:**

- Full implementation of selected architecture shapes

- Supervisor tree implementation

- Message bus over shared workspace

- Plugin system for agent types and spawners


---


### 16. Design Principles

**Documented:**

- **Informative Error Principle** — Errors must be specific and actionable

- **Sum Type Error Design** — Enumerate all failure modes upfront via GADTs/sum types

- **Instrumentation Principle** — Logs must diagnose issues without screenshots

- **Autonomous Testing Principle** — Tests run without human interaction

- **Perception-Bounded Performance** — "Fast" defined by user perception; isolation, responsiveness, scale independence

- **App Restart Workflow** — After rebuilding, kill and relaunch the app


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

- 18 numbered spec modules (§000–§017) in `docs/2-spec/` with traceability matrix and introduction

- All spec modules filled from transcripts, PRD, and session logs

- Property-based spec methodology: requirements lead with **Properties:** blocks, procedural workflows converted to property tables, state machine diagrams preserved (they ARE properties)

- Stable content addressing (`§DOC.SECTION.SUBSECTION`) with append-only numbering for permanent cross-references

- 27 cross-reference opportunities identified, 12 duplicated concepts assigned canonical homes


**Remaining:**

- Deduplication pass: replace restated content with `§` references to canonical homes

- External docs updated with new spec file names

- Incremental verification that downstream elements are complete relative to upstream


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


**Remaining:**

- (Process is ongoing maintenance, not a feature to "complete")
