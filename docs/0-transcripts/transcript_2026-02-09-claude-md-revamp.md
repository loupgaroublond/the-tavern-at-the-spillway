# Transcript: CLAUDE.md Revamp — Making the Briefing Document Complete

**Date:** 2026-02-09
**Sessions:** 3a706177 (planning), 86816d28 (implementation)
**Topic:** Identifying gaps in CLAUDE.md and creating a plan to make it the authoritative agent briefing document


## Context

After the first swarm completed (526 tests, 28 commits, all v1 parity beads closed), the project had grown considerably: 5 ADRs, a formal testing grade system, a PRD with 8 non-negotiable invariants, GUI instrumentation patterns, a session persistence model, and MCP tools for Jake. None of this was in CLAUDE.md. Agents starting fresh sessions had to spelunk through docs/ to find things that should be front-and-center.


## The Design Discussion

[U] claude.md needs a serious glow up. we have a bunch of project specific things now that all agents must regularly be aware of. lots of technical decisions and requirements, as well as patterns for organizing documentation and other parts of things, so go have a look around and your plan should be a list of things in the project you will extract the key information from to put in claude.md

[T] *Launched three parallel exploration agents: one for docs/ (ADRs, specs, PRD, pipeline.md, reader, jake-character.md), one for source code patterns (Package.swift, project.yml, redo scripts, Sources/, Tests/), one for project config and scripts (root files, .beads/, existing CLAUDE.md, slash commands). After synthesis, identified 15 source files with extractable content not yet surfaced in CLAUDE.md.*

[C] Here's a plan organized by source:

**From `docs/1-prd/prd_2026-01-19.md`** — the 8 Non-Negotiable Invariants (test suite passes before ship, every feature testable, commitments verified independently, user attention sacred, doc store is source of truth, agents can't modify own invariants, failures visible, original files protected). These are hard rules every agent must follow. Currently not in CLAUDE.md at all.

**From `docs/3-adr/` — ADRs 002–005** — Testing grade definitions (1–5), which grades `redo test` runs (1+2 only), when Grade 3/4/5 run; MockMessenger/LiveMessenger pattern and AgentMessenger protocol; ViewInspector for view-wiring tests; XCUITest scope, launch arguments, Grade 4 constraints. The testing principles section exists but lacks the grade system and tooling details.

**From `docs/4-docs/gui-instrumentation-guide.md`** — The 5 things to log in SwiftUI views (body evaluation, conditional branches, lifecycle, tasks, state changes). The `.task(id:)` gotcha. The `let _ = Self.logger.debug(...)` pattern. Born from a real debugging nightmare — this is a mandatory coding pattern, not optional guidance.

**From `docs/4-docs/architecture-v1.md`** — The ownership tree (TavernApp → ProjectManager → TavernProject → TavernCoordinator → Jake/Spawner/ChatViewModel). Thread safety model (DispatchQueue per agent, @MainActor on ViewModels). Current CLAUDE.md has a key files table but no ownership hierarchy.

**From `docs/0-transcripts/reader_2026-02-05.md`** — Reference to it as the canonical design synthesis. Open questions index (?1–?19). Two-level orchestration model (Tavern Agents vs Task Subagents). Two-mode spawning. Agents should read the reader before making design decisions.

**From `docs/pipeline.md`** — The stage flow (0-transcripts → 1-prd → 2-spec → 3-adr → code → tests → 4-docs). Rule: documents belong to exactly one stage, stages flow forward only. Agents creating or modifying docs need to know where things go.

**From `Tavern/Sources/TavernCore/Agents/Jake.swift` and `Servitor.swift`** — Jake (daemon, eternal) vs Servitor (mortal, task-bound). Two spawn modes: user-spawn (waits for input) vs Jake-spawn (has assignment, starts immediately). Done-signal detection ("DONE"/"COMPLETED"/"WAITING"). Current CLAUDE.md mentions agents abstractly; the Jake/Servitor distinction and spawn modes are core domain concepts.

**From `Tavern/Sources/TavernCore/Persistence/`** — Dual storage: UserDefaults (session IDs) + Claude's JSONL (message history). Session restoration flow. Path encoding (slashes/underscores → dashes). Per-project for Jake, per-agent for Servitors. Session management is the trickiest part of the codebase and isn't documented in CLAUDE.md at all.

**From `Tavern/Sources/TavernCore/MCP/TavernMCPServer.swift`** — MCP tools available to Jake: `summon_servitor`, `dismiss_servitor`. Callback pattern for UI updates. Agents implementing new Jake tools need to follow this pattern.

**From `Tavern/*.do` files** — Full test command matrix: `test` (G1+2), `test-core` (TavernCoreTests), `test-integration` (TavernTests), `test-grade3` (real Claude), `test-all` (G1+2+3), `test-grade4` (XCUITest). Test reports location: `~/.local/builds/tavern/test-reports/`. Current CLAUDE.md lists some but not all test commands.

**From `.claude/commands/`** — All custom slash commands: `/conceive`, `/reader`, `/status`, `/commit`, `/audit-transcripts`. Currently only `/conceive` and `/reader` are mentioned.

**From `docs/0-transcripts/jake-character.md`** — Vocabulary translation layer: Slop Squad = worker pool, Jukebox = background services, Regular = individual servitor, Cogitating = thinking. The Regulars cast list (Marcos Antonio, María Elena, etc.). Agents reading Jake's output or writing Jake's prompts need the vocabulary.

**From `Tavern/Package.swift` + `Tavern/project.yml`** — ClodKit v1.0.0 (published), ViewInspector (test only). Local ClodKit path in project.yml for development. No sandbox entitlement.

[C] *Proposed structure for the revamped CLAUDE.md:*

1. What This Is (keep, tighten)
2. Project Structure (keep, update tree if needed)
3. Build Commands (expand with full test matrix)
4. Non-Negotiable Invariants (NEW — from PRD)
5. Architecture (merge current ADR-001 section + ownership hierarchy + session model)
6. Agent Types (NEW — Jake vs Servitor, spawn modes, done signals)
7. Key Patterns (NEW — instrumentation, concurrency, dependency injection)
8. Testing (merge current principles + grade system + tooling)
9. Documentation Pipeline (NEW — stage flow, where docs go)
10. Slash Commands (NEW — full list)
11. Debugging (keep + add instrumentation patterns)
12. Known Bugs (keep iCloud only)
13. Jake: The Character (keep + add vocabulary translation)
14. Seed Design Interview Process (keep)
15. Current State (keep, update)
16. Key Files (keep, update)


## Apostrophe Bug Scope Expansion

[U] the apostrophe bug is fixed upstream, so we can tidy that up as well

[T] *Checked Jake.swift lines 53–54: found a warning comment and a system prompt written without contractions as a workaround for the ClodKit shell-escaping bug. The fix means two things: remove the workaround comment, and restore natural contractions to Jake's voice.*

[C] Found the workaround in `Jake.swift`. The plan is updated: treat the apostrophe bug as a cleanup task instead of something to document. Tasks:

- Remove the warning comment at `Jake.swift:53–54`
- Restore natural contractions in Jake's system prompt (e.g. "do not" → "don't", "Do not" → "Don't")
- Remove any apostrophe-related test expectations that only exist to document the bug
- Do NOT add this bug to the new CLAUDE.md — it's resolved

*The plan was saved and approved. Implementation ran in session 86816d28.*


## Implementation Notes

The revamp added 6 new major sections to CLAUDE.md that previously had no coverage:

1. **Non-Negotiable Invariants** — 8 rules from the PRD that every agent must know before touching any code
2. **Servitor Types** — Jake vs Mortal distinction, lifecycle differences, spawn modes, done-signal detection
3. **Key Patterns** — Instrumentation (mandatory), dependency injection (MockMessenger/LiveMessenger), error design
4. **Session Persistence Model** — Dual storage architecture, path encoding, per-project/per-agent keying
5. **Documentation Pipeline** — Stage flow, placement rules, where new documents go
6. **Slash Commands** — Full command inventory with purpose descriptions

The testing section was significantly expanded with the grade system table, when to run each grade, and the testing tooling (ViewInspector, XCUITest).

Grade 4 testing (XCUITest) received explicit emphasis: requires user approval to run because it steals keyboard/mouse focus.


___

## [S] Synthesis

### The "Agent Briefing" Principle

CLAUDE.md serves a specific function: it's the document an agent reads at session start to orient without spelunking. The project had accumulated 15+ decisions and patterns that were documented somewhere in docs/ but not front-and-center. The glow-up was a deliberate act of information architecture — pulling the agent-critical subset of project knowledge into one place.

The criterion for inclusion: *"Would an agent make a mistake if they didn't know this before starting work?"* Invariants (non-negotiable rules), ownership hierarchy (who owns what), testing grades (which command to run), session model (trickiest part of the codebase), instrumentation (mandatory pattern), pipeline placement rules (where to put new docs) — all passed the test.

### Apostrophe Bug: From Workaround to Cleanup

The apostrophe bug (`'` in `--system-prompt` causing 60s timeouts) was documented in the project and baked into Jake's character voice — the system prompt avoided all contractions. When ClodKit v1.0.0 fixed the underlying shell escaping, the cleanup wasn't just technical (remove comment) but also character restoration (give Jake back his voice: CAPITALS for EMPHASIS, contractions, theatrical asides). The fix was an opportunity to restore the full Jake character that had been muted by the workaround.

### CLAUDE.md as Living Architecture

The session established a pattern: as the codebase grows, CLAUDE.md should grow with it. Each major new subsystem (testing infrastructure, session persistence, MCP tools) should surface its "agent-critical" facts into CLAUDE.md, not just live in docs/. The glow-up was a catch-up pass; future subsystems should do this incrementally.
