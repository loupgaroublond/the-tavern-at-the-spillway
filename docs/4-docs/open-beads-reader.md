# Open Beads Reader

> Generated 2026-02-09 — 49 open beads across 4 priority tiers

## How to Read This

Beads fall into two readiness categories:

- **Concrete** — Scoped work items ready to pick up
- **Discussion Starter** — Raw material mined from transcripts, needs a `/conceive` session before becoming real work

Each bead includes its full description, source references, and open questions. Use this document to survey the landscape and decide what to work on next.

---

## Table of Contents

- [P1 — High Priority](#p1--high-priority)
- [P2 — Medium Priority](#p2--medium-priority)
  - [Concrete Work Items](#concrete-work-items)
  - [Agent System](#agent-system)
  - [UI and Views](#ui-and-views)
  - [Architecture](#architecture)
  - [Doc Store and Persistence](#doc-store-and-persistence)
  - [Process and Tooling](#process-and-tooling)
  - [Metrics](#metrics)
  - [Triage](#triage)
- [P3 — Low Priority](#p3--low-priority)
  - [Agents](#agents-1)
  - [Architecture](#architecture-1)
  - [UI and UX](#ui-and-ux)
  - [Observability and Safety](#observability-and-safety)
  - [Infrastructure](#infrastructure)
- [P4 — Backlog](#p4--backlog)
- [Summary Statistics](#summary-statistics)

---

# P1 — High Priority

## `vpn` — Fill formal spec modules from PRD and reader

**Type:** epic | **Labels:** pipeline, spec | **Created:** 2026-02-07

Populate all spec module skeletons in `docs/2-spec/` with concrete, traceable requirements derived from the PRD and reader. This epic stays open indefinitely — new modules may be added as the design evolves. Every child bead of this epic MUST contain a copy of the fill instructions below so it can be worked independently.

**Fill Instructions (copy into every child bead):**

Take a skeleton spec module and populate it with concrete requirements:

1. **Read upstream sources** — Read the PRD sections listed in the module's Upstream References. Read the corresponding reader sections. Read any transcripts referenced.

2. **Extract requirements** — For each concrete behavior, constraint, or capability described in the PRD, create a requirement entry:
   - Use the module's REQ prefix (e.g. REQ-AGT-NNN)
   - Number sequentially starting from 001
   - Fill in Source (PRD section), Priority (must-have/should-have/deferred based on PRD language and v1 scope), and Status (specified)
   - Write a clear, testable description — someone should be able to write a test from the requirement alone

3. **Fill behavior section** — Add state diagrams (Mermaid), interaction sequences, or behavioral descriptions where the requirements involve state transitions or multi-step flows.

4. **Populate open questions** — Pull relevant items from PRD §14 (Open Items) and §15 (Day 1 Questions). Add any ambiguities discovered during extraction.

5. **Identify coverage gaps** — Note areas where the PRD is silent but the module clearly needs specification. These become questions for /conceive sessions.

6. **Update downstream references** — Verify code and test directory paths are accurate for implemented features.

7. **Update status** — Change module status from 'skeleton' to 'partial' (or 'complete' if fully specified).

8. **Update index** — Update the module's status and requirement count in `docs/2-spec/000-index.md`.

---

# P2 — Medium Priority

## Concrete Work Items

### `0py` — Optimize resource panel UX and UI

**Labels:** resource-panel, ui, ux | **Created:** 2026-02-07

The resource panel v1 is functional but needs UX/UI polish. Areas to evaluate: visual hierarchy, spacing, colors, file tree row hover states, selection affordances, scroll behavior, panel resize handles, header styling, file content view typography, and overall integration with the rest of the Tavern UI. The current implementation is bare-bones — it works but does not feel refined.


### `hnb` — File tree does not refresh when new files appear on disk

**Labels:** resource-panel, ux | **Created:** 2026-02-07

The resource panel file tree only loads the directory contents on initial load and on expand/collapse. If files are created or deleted externally (e.g., by an agent, git checkout, or the user in Finder), the tree does not update to reflect the changes. Need file watching (FSEvents or DispatchSource) to detect on-disk changes and refresh the affected subtree.


### `f99` — Create /spec-status command — live dashboard of spec module status

**Labels:** pipeline, spec, tooling | **Created:** 2026-02-07

Build a slash command that computes a live dashboard from the actual spec files (not manually maintained). For each of the 18 numbered modules (§000–§017): reads the file, extracts status, counts requirements by status (specified/implemented/tested/verified), and summarizes. Output is a table showing module → status → requirement counts → implementation coverage. Basically §0 (000-index.md) but computed live rather than manually maintained.


### `e4p` — Create /trace command — follow a requirement through the pipeline

**Labels:** pipeline, spec, tooling | **Created:** 2026-02-07

Build a slash command that takes a requirement ID (e.g. REQ-AGT-003) or § address (e.g. §4.2.3) and traces it through every pipeline stage. Shows: PRD source section → spec text → ADR (if any) → code files → test files → status at each stage. Quick way to answer "is this requirement fully implemented and tested?" Reads the spec module to find the requirement, extracts its Source field for PRD linkage, checks downstream references for code/test paths, and reports completeness.


### `9uc` — Create /audit-spec command — PRD-to-Spec coverage verification

**Labels:** pipeline, spec, tooling | **Created:** 2026-02-07

Build a slash command that walks the PRD section by section, checks that `2-spec/000-index.md` maps each one to a module, then reads each module to verify requirements actually exist (not just placeholders). Reports coverage gaps and status. Cross-checks downstream references — e.g. if a spec module says code lives in Agents/, verify that directory exists and has tests. Output: coverage report showing PRD sections → spec modules → requirement count → status. Modeled after /audit-transcripts but for the spec pipeline stage.


---

## Agent System

### `2bc` — Background agent execution — autonomous work without user focus

**Labels:** agents, core, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Agents should be able to work autonomously in the background while the user focuses elsewhere. Currently agents only respond to direct messages. Background execution enables the full multi-agent vision where many agents work in parallel.

**Related beads:** sidecar pattern (`vfx`) provides the I/O architecture, perseverance mode (`pbt`) covers retry/lifecycle, but neither explicitly covers the user-facing concept of agents working while you do other things.

**Sources:** CLAUDE.md Not Implemented, PRD section on agent lifecycle, reader section 3.

**Open questions:**
- What triggers background work? Task queue? Parent agent delegation?
- How does the user know background work is happening? Notification when done?
- How does this interact with token budgets (`yte`)?


### `0xr` — Calling and hanging up — user joining/leaving agent sessions

**Labels:** agents, tavern, ui | **Created:** 2026-02-07 | **Status:** Discussion Starter

When user zooms into an agent, system injects a "calling" message. When user zooms out, agent receives "hanging up" message and knows not to pause for interaction. This toggles between chat mode (active conversation) and perseverance mode (background).

**Sources:** reader section 4 (Zooming In and Out), PRD section 5.2 (Calling and Hanging Up), reader open question ?6.

**Open questions:**
- What does the injected message look like? Is it a tool call or a text message?
- Does the agent acknowledge?
- What happens if user calls while agent is mid-response?


### `84c` — Inter-agent communication — bubbling, lateral messaging, direct-to-user

**Labels:** agents, communication, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Agents need to communicate: upward (child to parent to user), laterally (siblings collaborating), and directly to user (with oversight). Currently no inter-agent messaging exists.

**Sources:** reader section 3 (Bubbling), reader section 9 (Agent Communication, Message Protocol), reader open question ?5 (Bubbling Up Process), PRD section 5.3 (Bubbling), notes_issues-to-plan-for item 1 (Context handoff).

**Open questions:**
- Does child ask parent who decides to escalate? Can messages skip levels?
- Is there prioritization?
- How does lateral collaboration work concretely?
- What is stored in doc store vs ephemeral?


### `thv` — Hierarchical agent trees — agents spawning children

**Labels:** agents, architecture, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Currently agents are flat (Jake spawns mortal agents). Design calls for Erlang-style arbitrary depth trees: mortal agents spawning children, children spawning grandchildren, etc. Tree management is synchronous within each actor.

**Sources:** reader section 3 (Mortal Agents, task modes), reader section 5 (Agent Hierarchy diagram), PRD section 4.1 (Agent Types), transcript_2026-01-21-2345 (Erlang-style depth), transcript_2026-01-25-0108 (Component Ownership Chain).

**Open questions:**
- What does child agent spawning look like concretely? Same tool handler as Jake?
- How does tree management interact with the sidecar pattern?
- What about tree visualization in the UI?


### `pbt` — Perseverance mode and agent lifecycle states

**Labels:** agents, lifecycle, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

When agents stop, the system should auto-prompt them to continue (perseverance mode). Agents must explicitly use a tool to get user attention. Need full lifecycle state machine: Working, Waiting for Input, Waiting for Wakeup, Done, Failed/Reaped.

**Sources:** PRD section 4.2 (Agent States), PRD section 4.4 (Operating Modes), reader section 3 (Perseverance Mode vs Chat Mode), reader open question ?6 (Perseverance Prompts and Agent Lifecycle), project-status.md Agent Spawning Remaining.

**Open questions:**
- What is a perseverance prompt exactly?
- What triggers transitions?
- How does this interact with token budgets?
- What is the wakeup mechanism?


### `wdk` — Preflight checks — spawn-time verification before agents start

**Labels:** agents, safety, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Every agent gets spawn-time verification: sandbox configured, access to required resources, no permissions prompts expected, external accounts authenticated. Failure = agent does not start, parent notified with reason. No degraded mode — pass/fail.

**Sources:** reader section 6 (Preflight Checks), PRD section 6.4 (Preflight Checks).

**Open questions:**
- What checks are needed for v1 (no sandbox yet)?
- How are required resources specified?
- What does a failed preflight look like in the UI?
- Retry mechanism?


---

## UI and Views

### `an7` — Component-based chat views — thinking, tools, text as separate renderers

**Labels:** chat, tavern, ui | **Created:** 2026-02-07 | **Status:** Discussion Starter

Render different message content types (thinking blocks, tool_use blocks, text responses) as separate SwiftUI components within the chat view. Distinct from tile layout (`coj`) which is about window-level arrangement — this is about rendering within a single chat.

**Sources:** reader_2026-02-05 Section 9 UI Concepts (component-based chat views TBD), MessageType enum already exists in codebase.

**Open questions:**
- What does each content block type look like visually? Collapsible thinking blocks? Tool use as inline cards?
- How does this interact with streaming?
- Does the existing MessageType enum cover all needed cases?


### `coj` — Composable tile view system — tiles, layout mutation, view modes

**Labels:** tavern, ui, views | **Created:** 2026-02-07 | **Status:** Discussion Starter

The view layer should be a composable surface reshaped by both user AND agents. Tiles within windows, view modes (like Finder list/icon/column views), multiple views of same agent, dead agent bodies (tiles persist for review), saved layouts (templates vs snapshots).

**Sources:** reader section 8 (Dynamic View Architecture), transcript_2026-01-21-2345, transcript_2026-01-22-0730-view-architecture, project-status.md Dynamic View Architecture Remaining.

**Open questions:**
- What tile primitives exist? How does split/merge work?
- What SwiftUI layout patterns?
- How do agents propose vs mutate layouts (two permission levels)?
- What does tree folding look like?


### `hu4` — Notification and attention routing — badges, priority, question triage

**Labels:** agents, tavern, ui | **Created:** 2026-02-07 | **Status:** Discussion Starter

Agents need attention indicators: notification badges, priority routing (which agent needs user attention NOW), question triage (quick vs deep). Parent agents choose notification approach for children (popup vs periodic summary).

**Sources:** PRD section 5.5 (Question Triage), reader section 3 (Bubbling), project-status.md Chat and UI Remaining (Notification badges), notes_issues-to-plan-for item 4 (Priority/attention routing).

**Open questions:**
- How are questions classified as quick vs deep?
- What determines priority?
- How does Jake surface which agent to zoom into?
- Badge count vs badge type?


### `my4` — Resource panel / file viewer — IDE-lite right-side panel

**Labels:** tavern, ui, v1.5 | **Created:** 2026-02-07 | **Status:** Discussion Starter

Right-side panel showing file tree, file contents, and diffs alongside chat. Goal: make Tavern usable as a standalone dev environment at v1.5 without needing a separate IDE.

**Sources:** resource-viewer session (Feb 6).

**Open questions:**
- What file types need rendering? Syntax highlighting approach?
- How do agent file changes surface in the panel?
- Read-only or editable?
- How does this interact with the doc store / shared workspace pattern?


---

## Architecture

### `vfx` — Sidecar pattern — separate I/O actors per agent

**Labels:** architecture, concurrency, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Each agent needs two actor components: main actor (tree structure, never blocks) and sidecar actor (slow Anthropic I/O). Prevents thread pool starvation with concurrent agents. Global semaphore limits concurrent API calls (~10).

**Sources:** reader section 9 (Sidecar Pattern), ADR-001 shape L (Sidecar), transcript_2026-01-24-shape-selection, Architecture Principles in CLAUDE.md (Concurrency Rules).

**Open questions:**
- How does the sidecar actor relate to Swift concurrency (actors)?
- What is the semaphore implementation?
- How does cancellation work across main/sidecar?
- Is the sidecar per-agent or shared?


---

## Doc Store and Persistence

### `egf` — Doc store continuous sync — agents live-syncing state to files

**Labels:** docstore, persistence, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Doc store CRUD exists but agents don't continuously sync state to their files. Need live sync so doc store remains the single source of truth (PRD invariant 5: if it's not in a file, it doesn't exist).

**Sources:** project-status.md Doc Store Remaining, PRD section 4.5 (Doc Store), reader section 7 (Document Store).

**Open questions:**
- What triggers a sync — every state change, or batched?
- How does this interact with the persistence context pattern?
- What about write conflicts from concurrent agents?
- SwiftUI observation patterns for doc store changes?


---

## Process and Tooling

### `azy` — Formal spec pipeline — incremental document propagation

**Labels:** process, tavern, tooling | **Created:** 2026-02-07 | **Status:** Discussion Starter

Build a formal specification pipeline: transcripts → PRD → specs → ADRs → code → tests → docs. Each downstream artifact derives from upstream, with incremental updates when upstream changes and completeness verification at each stage.

**Sources:** formal-spec session (Feb 6).

**Open questions:**
- What tooling drives the pipeline? Manual slash commands or automated?
- How is completeness verified?
- How do we track which upstream changes have propagated?
- Is this a dev-time tool or part of the Tavern app itself?


---

## Metrics

### `yte` — Token budget and cost visibility — per-agent budgets and spend tracking

**Labels:** agents, metrics, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Track token spend across agents, set budgets, know which tasks are expensive vs cheap. Token budget exceeded is a fish-or-cut-bait trigger. Parent specifies token budget at spawn time.

**Sources:** PRD section 6.2 (Agent Spawn Configuration - token budget), PRD section 12 (Fish or Cut Bait - budget exceeded), notes_issues-to-plan-for item 3 (Cost visibility).

**Open questions:**
- How does ClodKit SDK expose token usage?
- Budget per agent or per tree?
- What happens at budget limit — hard stop or warning?
- How does cost roll up to parent?


---

## Triage

### `azu` — Tavern Feature Backlog — Mined from Transcripts & Sessions

**Labels:** backlog, tavern, triage | **Created:** 2026-02-07

Comprehensive backlog mined from all 29 seed-design transcripts, session logs, PRD, implementation plan, project status, open questions, and code TODOs. EVERY ITEM IN THIS EPIC IS A STARTING POINT FOR DISCUSSION WITH THE USER — not a final, clearly defined task. Each bead captures the raw material and source references. Discuss with the user before promoting any item to a real work item.

**Design:** Items extracted from: reader_2026-02-05.md (synthesized transcripts), prd_2026-01-19.md, v1-implementation-plan.md, project-status.md, notes_issues-to-plan-for_2026-01-19-1031.md, code TODOs, handoff-apostrophe-bug.md. Grouped by functional area.

---

# P3 — Low Priority

## Agents

### `kaq` — Model selection per agent — Haiku for drones, Sonnet for coordinators, Opus for architects

**Labels:** agents, sdk, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Parent specifies model when spawning child. Cheap models for cheap tasks (drones), capable models for complex work. Currently all agents use whatever the SDK defaults to.

**Sources:** PRD section 6.2 (Agent Spawn Configuration - model selection).

**Open questions:**
- How does ClodKit SDK support model selection?
- Does model affect token budget?
- Can model be changed mid-session?
- What are the cost tradeoffs?


### `bly` — Fish-or-cut-bait — kill and restart triggers for agents

**Labels:** agents, lifecycle, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Triggers to kill and restart rather than continue: token budget exceeded, changeset is totally wrong, agent spinning, whole gang going down wrong path. Reap and restart cleanly.

**Sources:** PRD section 12 (Fish or Cut Bait), PRD section 4.2 (Failed/Reaped state).

**Open questions:**
- Who decides to fish-or-cut-bait — parent, Jake, or user?
- Automatic detection of spinning?
- What does restart look like — same assignment fresh context?
- How does this relate to agent hierarchy (reap subtree vs individual)?


### `8wt` — Drones and monitor daemons — lightweight agent types

**Labels:** agents, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Drones: Meeseeks-style single-task agents. One task then terminate. Cheap models, cheap to fail. Monitor Daemons: background agents that work for Jake, monitoring health/progress/spending.

**Sources:** PRD section 4.1 (Agent Types table), PRD section 6.6 (Hygiene), reader section 3.

**Open questions:**
- What model for drones (Haiku)?
- What triggers drone creation?
- What do monitor daemons actually monitor?
- How do drones differ from Task subagents?
- Cost model for drones?


### `iln` — Gang of experts — specialized prompt templates for agent roles

**Labels:** agents, prompts, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Specialized prompts applied to agents (not persistent entities): Reviewer, Tester, Architect, etc. Pull in the reviewer = spawn agent with reviewer instructions. User can customize.

**Sources:** PRD section 11 (Gang of Experts).

**Open questions:**
- What expert roles to start with?
- How are prompts composed (system prompt + expert prompt + assignment)?
- Can experts be combined?
- Where are expert templates stored (.tavern/ vs bundled)?


---

## Architecture

### `c8s` — Workflow engine — state machine templates and composable workflows

**Labels:** architecture, tavern, workflow | **Created:** 2026-02-07 | **Status:** Discussion Starter

Workflow = state machine. Engine helps agents work step by step. Starter templates: Rule of 5 (five agent passes over single output), Verification Layers (progressive gates: lint, structure, architecture, performance). User can modify. Agents can propose new templates.

**Sources:** PRD sections 10 (Workflows), reader section 7 (Workflow Engine), reader open question ?2 (Deterministic Shell Meaning).

**Open questions:**
- What is the workflow DSL/format?
- How do workflows compose?
- What is the state machine representation?
- How do verification layers gate progression?
- Template storage location?


### `igh` — Sandbox and changeset system — overlay filesystem, isolation, platforms

**Labels:** architecture, sandbox, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Five sandbox primitives: Changeset (overlay filesystem), Platform (Mac/container/cloud), Isolation (VM/container/OS sandbox), Outputs (network control), Software (OS choice). Source control is orthogonal to isolation. Changesets work across multiple repos.

**Sources:** reader section 6 (Sandbox and Isolation), PRD section 4.6, reader ?8 (partially resolved), project-status.md Sandbox and Changesets (nothing implemented yet).

**Open questions:**
- Which primitive to implement first?
- How does overlay filesystem work on macOS (APFS snapshots? FUSE?)?
- Changeset review workflow?
- How do changesets compose across agents?


### `15i` — Plugin system — closed set of agent types and spawners

**Labels:** architecture, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Plugins registered at startup, not dynamically loaded. All agent types known at compile time. This provides security, simplicity, and type safety. Need a registration mechanism for agent types and their spawners.

**Sources:** ADR-001 shape I (Plugin), reader section 5 Architecture Notes, CLAUDE.md Architecture Principles (Closed Plugin Set), project-status.md Architecture Remaining.

**Open questions:**
- What agent types exist beyond Jake and MortalAgent?
- How does registration work? Is this a protocol + registry pattern?
- How do Gang of Experts fit in?


### `o0w` — .tavern/ in-project shareable configuration

**Labels:** config, persistence, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Projects should have a .tavern/ directory for shareable config: templates, agent definitions, workflow configs. This is version-controllable and separate from personal state (UserDefaults/iCloud).

**Sources:** reader section 7 (Session Storage Layers - layer 2), project-status.md Document-Based Architecture Remaining, PRD section 4.5.

**Open questions:**
- What goes in .tavern/ vs UserDefaults?
- Config file format (YAML, JSON, TOML)?
- Agent definition format?
- Template structure?
- Should this be gitignored or committed?


---

## UI and UX

### `7ou` — User consent for new chats — concrete consent UX

**Labels:** tavern, ui, ux | **Created:** 2026-02-07 | **Status:** Discussion Starter

PRD invariant 4: User attention is sacred. Never force new content on user without consent. What does "100% clear they're OK with it" mean concretely? User preference settings? Contextual inference? Per-agent consent?

**Sources:** reader open question ?7 (User Consent for New Chats), PRD invariant 4.

**Open questions:**
- Settings panel for notification preferences?
- Auto-accept from Jake but confirm from others?
- Context-dependent (during active session vs background)?
- How does this interact with bubbling?


### `gz4` — Agent reasoning visibility — why did it do that?

**Labels:** observability, tavern, ui | **Created:** 2026-02-07 | **Status:** Discussion Starter

Visibility into agent reasoning, not just outputs. Understanding the chain of decisions when an agent goes off the rails. Postmortems are hard without this.

**Sources:** notes_issues-to-plan-for items 2 and 9 (Debugging failed runs, Why did it do that), PRD section 5.4 (Stream separation).

**Open questions:**
- Is this just the thinking blocks rendered in UI? Or a separate reasoning trace?
- How does this work across agent hierarchies?
- Decision tree visualization?
- Post-hoc analysis vs real-time?


### `ogs` — Context cards — quick context for jumping into agent conversations

**Labels:** tavern, ui | **Created:** 2026-02-07 | **Status:** Discussion Starter

Quick context cards for jumping into agent conversations: agent name, current assignment, status right now. Lets user switch contexts without reading full chat history.

**Sources:** reader section 8 (Context Cards), PRD section 5.2.

**Open questions:**
- What exactly is shown? Just name/assignment/status or more?
- Is it a hover card, a sidebar panel, or inline in the agent list?
- Does it include recent messages summary?


---

## Observability and Safety

### `2ni` — Violation monitoring — configurable per-agent rules and enforcement

**Labels:** agents, safety, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Dynamic violation list configurable per-project or per-agent. Examples: modifying files outside designated directories, exceeding token budgets, spawning more than N children, accessing network when disallowed, running commands on blocklist. When detected: log, notify parent/user, optionally pause/reap/warn.

**Sources:** PRD section 16 (Violation Monitoring).

**Open questions:**
- How are rules specified (config file, code, both)?
- Real-time monitoring or post-hoc?
- What is the enforcement mechanism — hooks, sandbox, or agent-level checks?
- Agents cannot modify their own violation rules — how is this enforced?


### `clt` — Metrics and telemetry — token time, utilization, saturation, amplification

**Labels:** metrics, observability, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Time categories: token time (waiting for LLM), tool time (execution), wall clock (total), throttle time (excluded). Agent metrics: utilization, saturation, wait time. Human metrics: wait time, context switching load. Primary measure: amplification (saturated agents running concurrently).

**Sources:** PRD section 9 (Metrics).

**Open questions:**
- Where are metrics stored?
- Real-time dashboard or post-hoc analysis?
- How does amplification factor display in UI?
- Per-session or per-project metrics?
- Baselines and alerting?


---

## Infrastructure

### `l6g` — Session classification automation — design vs transcription vs implementation

**Labels:** process, tavern, tooling | **Created:** 2026-02-07 | **Status:** Discussion Starter

Create decision logic to automatically classify Claude sessions into categories: (a) design sessions with [U]/[C]/[T] exchanges that need transcripts, (b) transcription/meta sessions doing process work, (c) implementation sessions where commits suffice. Could use message frequency analysis, keyword detection, or other heuristics.

**Sources:** transcript_2026-02-02 (Part 3, Transcription vs Design Sessions).

**Open questions:**
- Is this a standalone tool or part of the audit system?
- What accuracy is acceptable?
- ML-based or heuristic?
- Does this feed into the formal spec pipeline?
- How does it handle sessions that span multiple categories?


### `7dg` — Programmatic GUI testing — XCTest UI and log-based verification

**Labels:** infrastructure, tavern, testing | **Created:** 2026-02-07 | **Status:** Discussion Starter

Need programmatic GUI testing infrastructure. Headless testing philosophy: tests run without human interaction, end-to-end over stubs, testing strategy IS debugging strategy. Also need log-based automated verification and performance regression baselines.

**Sources:** transcript_2026-01-23-headless-testing, project-status.md Build and Testing Remaining, PRD section 17 (Testability Requirements).

**Open questions:**
- XCTest UI vs alternative?
- How to headlessly test SwiftUI views?
- Baseline methodology?
- Integration with redo build system?


### `0o6` — Inter-agent message storage — messaging infrastructure in doc store

**Labels:** communication, docstore, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Doc store serves as messaging system (with supporting daemons). Need message storage, routing, delivery confirmation. Messages between agents stored in doc store files.

**Sources:** reader section 7 (Document Store as messaging system), project-status.md Doc Store Remaining (Inter-agent message storage), reader section 9 (Communication Patterns).

**Open questions:**
- Message format (markdown? structured data?)?
- One file per message or conversation log?
- How does delivery confirmation work?
- Ordering guarantees?
- TTL for messages?


### `9f9` — Work queues — drone dispatch and queue mechanics in doc store

**Labels:** agents, docstore, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Work queues live in the document store. When items appear, drones fire immediately. Agents attach at spawn or mid-task. Need: queue creation, item addition, drone dispatch, empty-queue instructions (idle, hibernate, terminate).

**Sources:** reader section 7 (Document Store as work queues), reader open question ?19 (Work Queues), PRD section 6.3 (Work Queues), project-status.md Doc Store Remaining.

**Open questions:**
- Full specification of queue mechanics?
- Priorities and dependencies within queues?
- File format for queue items?
- How does drone dispatch work — filesystem watcher or polling?


---

# P4 — Backlog

### `cvk` — /mcp — add server management (add/remove/reconnect)

**Labels:** management, mcp, ui | **Created:** 2026-02-07

The /mcp command currently only displays MCP server configuration (read-only) with hardcoded status placeholders. Add ability to: query real runtime connection status, add new MCP servers, remove existing servers, and trigger reconnection. MCPCommand.swift needs substantial expansion.


### `drq` — /hooks — add editing capability for lifecycle hooks

**Labels:** hooks, management, ui | **Created:** 2026-02-07

The /hooks command currently only displays hook configuration (read-only). Add ability to add, remove, enable/disable, and edit hook commands through the UI. Requires interactive editing interface or inline editing controls in HooksCommand.swift.


### `5ft` — iCloud personal state storage — sync preferences across machines

**Labels:** persistence, tavern, ux | **Created:** 2026-02-07 | **Status:** Discussion Starter

Personal state (session IDs, window positions, persisted agent list) currently in UserDefaults. Could sync via iCloud for cross-machine continuity.

**Sources:** project-status.md Document-Based Architecture Remaining, reader section 7 (Session Storage Layers - layer 3).

**Open questions:**
- What state is worth syncing?
- iCloud KV store vs CloudKit?
- Conflict resolution?
- Does this conflict with the known iCloud corruption issue with Xcode projects?


### `0fi` — Hygiene daemons — cleanup of dead agents, stale overlays, orphaned resources

**Labels:** agents, lifecycle, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Daemons handle cleanup: dead agents, old changesets, stale overlays, orphaned workflows/documents/resources. Initially manual cleanup, sophisticated reaping later.

**Sources:** PRD section 6.6 (Hygiene), reader section 8 (Dead Agents Leave Bodies).

**Open questions:**
- What triggers cleanup — periodic or event-driven?
- What is the retention policy for dead agents?
- How long do bodies persist?
- Is this a monitor daemon or separate system?


### `nt2` — Rollback mechanism — undoing agent work cleanly

**Labels:** safety, tavern, workflow | **Created:** 2026-02-07 | **Status:** Discussion Starter

Undoing agent work that looked fine but wasn't. Git helps but isn't always clean. Especially important when agents work on actual files (pre-changeset).

**Sources:** notes_issues-to-plan-for item 8 (Rollback).

**Open questions:**
- Git-based rollback vs custom undo?
- Per-agent commits?
- How does this interact with changesets when they exist?
- Rollback across multiple agents that collaborated?


### `28x` — Saved layouts — named templates and concrete snapshots

**Labels:** persistence, tavern, ui | **Created:** 2026-02-07 | **Status:** Discussion Starter

Two types of saved layouts: abstract templates (structure without specific agents) and concrete snapshots (specific agents, specific state). Session restore is automatic; saved layouts are intentional.

**Sources:** reader section 8 (Persistence), project-status.md Dynamic View Architecture Remaining, transcript_2026-01-21-2345.

**Open questions:**
- Storage format?
- Template vs snapshot distinction in practice?
- How does a template get populated with real agents?
- Can layouts be shared via .tavern/?


### `0ps` — Discovery sharing — agents noticing and reporting oddities

**Labels:** agents, communication, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

Agents (even drones) prompted to notice oddities and share them via messaging while continuing main task. Cannot enforce via deterministic hook — relies on prompt engineering encouraging curiosity and social behavior.

**Sources:** PRD section 9.3 (Discovery Sharing).

**Open questions:**
- What message format for discoveries?
- Where are they stored — doc store, separate log?
- How does user review discoveries?
- Priority of discoveries vs main task?


### `6up` — Self-improvement — measurement, workflow evolution, meta process

**Labels:** meta, observability, tavern | **Created:** 2026-02-07 | **Status:** Discussion Starter

No self-improvement exists currently. Options range from better logging to ML-based prompt optimization to evolutionary workflow design. Meta process: decision layer for selecting which workflows/tools to use for a given task.

**Sources:** reader open question ?3 (Self Improvement Definition), PRD section 9.2 (Meta Process), notes_issues-to-plan-for item 5 (No self-improvement).

**Open questions:**
- What does self-improvement mean concretely for v1?
- Performance tracking and manual adjustment?
- Automated A/B testing of prompts?
- Learning from successful vs failed agent runs?


### `ejj` — Merge queue — coordinated changeset merging

**Labels:** changesets, tavern, workflow | **Created:** 2026-02-07 | **Status:** Discussion Starter

Agents queue up their changesets, see what's ahead, refine against predictable target, serialized merges, fewer conflicts.

**Sources:** PRD section 6.5 (Merge Queue), PRD v1 Deferred list.

**Open questions:**
- How does this work without git worktrees (changesets are overlay-based)?
- What is the merge strategy?
- Conflict resolution — automatic or agent-assisted?
- Priority ordering in the queue?


### `vpt` — Rewind and branch — checkpoint, fork, and replay capability

**Labels:** agents, tavern, workflow | **Created:** 2026-02-07 | **Status:** Discussion Starter

Checkpoint agent state, tweak prompt, fork new timeline. Works at both agent level and changeset level. Enables experimentation without losing prior work.

**Sources:** PRD section 13 (Rewind and Branch), PRD v1 Deferred list.

**Open questions:**
- What is checkpointed — session state, doc store state, or both?
- How does forking work with Claude sessions (new session with context summary)?
- UI for browsing timelines?
- Storage cost of checkpoints?


### `whf` — Progressive unlocks — engagement-based content revelation

**Labels:** engagement, tavern, ui | **Created:** 2026-02-07 | **Status:** Discussion Starter

Track message count. As count grows, unlock: more cogitating verbs, new naming themes, expanded Jake vocabulary, easter eggs. Subtle hints only — Jake doesn't announce unlocks, just starts using new words.

**Sources:** PRD section 8 (Progressive Unlocks), transcript_2026-01-21-1620 (progressive unlocks concept).

**Open questions:**
- Per-project or global count?
- Linear or milestone-based?
- Where stored (doc store, UserDefaults)?
- Reset behavior? Can users prestige?
- What are the first unlock tiers?


---

# Summary Statistics

| Priority | Total | Concrete | Discussion Starters |
|----------|-------|----------|---------------------|
| P1       | 1     | 1        | 0                   |
| P2       | 20    | 5        | 15                  |
| P3       | 17    | 0        | 17                  |
| P4       | 11    | 2        | 9                   |
| **Total**| **49**| **8**    | **41**              |

**By functional area:**

| Area | Count |
|------|-------|
| Agent system (lifecycle, spawning, hierarchy, communication) | 13 |
| UI / Views (chat, tiles, layouts, notifications) | 10 |
| Architecture (sidecar, sandbox, plugins, workflows) | 6 |
| Pipeline / Spec tooling | 5 |
| Doc store / Persistence | 5 |
| Metrics / Observability | 3 |
| Management commands | 2 |
| Process / Tooling | 2 |
| Triage / Backlog | 2 |
| Resource panel | 1 |
