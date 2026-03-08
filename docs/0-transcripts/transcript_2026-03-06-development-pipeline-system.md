# Development Pipeline System — Design & Implementation

**Date:** 2026-03-06
**Sessions:** 1 (4 context continuations)
**Scope:** Design and implement a development pipeline system for tracking work from stub through design, breakdown, execution, and verification. Migrate all 91 open beads. Rename "document pipeline" to "reification chain." Revise agent model after failed orchestration attempt.
**Follows:** `transcript_2026-03-05-udd-consolidation.md`

---

## Context

91 open beads (7 epic, 62 feature, 17 task, 5 bug), most effectively stubs needing design before implementation. The project needed a system to track work from stub through shipped code, coordinate an agent workforce, and distinguish itself from the existing document flow (transcripts → PRD → specs → ADRs → code → tests → docs).

---

## Pipeline System Design (Session 1, Pre-Compaction)

*[T] The bulk of the design happened in a long /ideate session that was later captured in a detailed plan file. The plan covers 14 sections: directory structure, pipeline document format, numbering/migration, roles/team model, branching model, phase details (design, breakdown, execution, verification), orchestrator operating model, dashboard, distilled instructions, process spec outline, and implementation steps.*

Key design decisions established during ideation:

- **Roles:** Human = VP (decisions). Claude = orchestrator/chief of staff (coordination only). Agent team members = rank-and-file workers.
- **4-phase lifecycle:** Design → Breakdown → Execution → Verification, with rigid gates between phases.
- **Pipeline documents:** YAML-frontmatter markdown files that serve three audiences at once — brief for human status, in-depth for human review, tracking data for agents/orchestrator.
- **5-layer verification:** Traceability audit, invariant review, architecture conformance, blast radius check, gap scan.
- **Multi-level branching:** per-bead worktrees → pipeline branch → main.
- **Distilled instructions:** Pre-generated, token-efficient instruction sets (core.md + 5 domain supplements) so agents don't burn tokens re-reading full specs.
- **Context compilation:** A script that bundles specs, ADR sections, code excerpts, and design statements into self-contained bead context documents.

The plan was captured at `/Users/yankee/.claude/plans/partitioned-foraging-aho.md` (766 lines, 14 sections).

---

## Implementation (Session 1 continued, Pre-Compaction)

All 5 implementation steps completed in sequence:

**Step A (Foundation):** Created `docs/pipeline/{active,archive,instructions}`, `scripts/pipeline/`. Wrote `docs/pipeline/process.md` (571 lines, 14 sections).

**Step B (Distilled Instructions):** 5 research agents read all spec modules and ADRs in parallel. Generated `core.md` (209 lines) + 5 supplements: `agent-core.md`, `ui-views.md`, `communication.md`, `infrastructure.md`, `testing-quality.md`.

**Step C (Scripts):** `scripts/pipeline/dashboard.sh` (YAML frontmatter parser, JSON/markdown output) and `scripts/pipeline/compile-bead-context.sh` (context bundle compiler).

**Step D (Bead Migration):** Exported all 91 open beads, generated pipeline docs (p0000-p0099), handled epic-child relationships with blocked-by lists. Closed all beads with "Migrated to pipeline pNNNN" reasons. Fixed edge cases: 9 closed beads appearing in epic dependents removed, p0000 slug cleaned up from truncated auto-generation.

**Step E (Orchestrator Infrastructure):** Created `/pipeline-dashboard` slash command. Updated MEMORY.md.

All 6 validation checks passed: 0 open beads, 91 valid pipeline docs, dashboard JSON valid, instruction files complete, p0000 exists, compile script executable.

---

## Naming Discussion — "Reification" (Session 2, Post-Compaction)

[U] "what's a word we can use to disambiguate the pipeline process for development, from the word 'pipeline' we use to mean the flow of design, from ideation to tests and everything in between?"

[C] Offered metaphor-based options (Forge, Mill, Track) and then non-metaphor options (Docket, Dispatch, Maturation). Framed the distinction: the doc pipeline describes the state of the project (how knowledge flows from ideas to artifacts), while the development pipeline describes the state of work on the project.

[U] "give me more, those are either two folksey or contain too much semantic overlap"

[U] "oh, no, i want to rename the document flow, and keep this as the pipeline. i'm likening that document flow to a search through a latent space, where we 'find' code, tests, and stage 4 documents"

[C] "That's a much more interesting problem. The document flow is a progressive materialization — you start with fuzzy ideas in transcripts and progressively resolve them into concrete artifacts." Offered: Derivation, Resolution, Projection, Descent, Convergence, **Reification**, Trajectory, Reduction.

[U] "Reification, cause fuck the haters who don't like it"

### Changes Made

- Renamed `docs/pipeline.md` → `docs/reification.md`
- Title and content updated to "Reification Chain" with framing: "progressive materialization of abstract ideas into concrete artifacts"
- CLAUDE.md section "Documentation Pipeline" → "Reification Chain"
- Pipeline doc p0004 stub updated
- MEMORY.md terminology section added
- Historical files (transcripts, readers, reports) left untouched

---

## Worker Types vs Specializations (Session 2, Post-Compaction)

[U] "also, let's clarify the worker pool will have workers of type design, breakdown, work, scope-check, or verify-1 through verify-5. if they specialize on a specific area of the app, that's a specialization"

[C] Updated Section 6 of `process.md`. Worker **types** are the 9 fixed roles:

| Type | Phase |
|------|-------|
| `design` | 1 |
| `breakdown` | 2 |
| `work` | 3 |
| `scope-check` | 3 |
| `verify-1` through `verify-5` | 4 |

**Specialization** is orthogonal — which domain of the app the worker knows (UI, servitors, infrastructure, etc.), expressed by which instruction supplements they load alongside `core.md`. Type is fixed for the agent's lifetime. Specialization applies mainly to design, breakdown, and work types.

---

## Orchestrator Slash Command (Session 2, Post-Compaction)

[U] "when i load a new claude session, how do i trigger claude to get started on this?"

[C] "A slash command. Something like `/orchestrate` that you invoke when you want the session to act as the pipeline orchestrator. This stays out of CLAUDE.md (which loads every session, even ones that aren't doing pipeline work) and is explicit — you're telling Claude 'this session is an orchestrator session.'"

[U] "heck yeah"

Created `.claude/commands/orchestrate.md` — defines the orchestrator role, worker type table, session start protocol (run dashboard, check agent messages, present situation, wait for direction), and ongoing operations reference.

---

## SLOC Counter Update

Updated `scripts/loc.sh` to count:
- Pipeline docs (`docs/pipeline/`) — 6,422 lines across 98 files
- Shell scripts (`scripts/*.sh`) — 984 lines across 9 files

Previously these were invisible in the project line count.

---

## Artifacts Created/Modified

| File | Action |
|------|--------|
| `docs/pipeline/process.md` | Created (571 lines) |
| `docs/pipeline/instructions/core.md` | Created (209 lines) |
| `docs/pipeline/instructions/agent-core.md` | Created (163 lines) |
| `docs/pipeline/instructions/ui-views.md` | Created (145 lines) |
| `docs/pipeline/instructions/communication.md` | Created (105 lines) |
| `docs/pipeline/instructions/infrastructure.md` | Created (142 lines) |
| `docs/pipeline/instructions/testing-quality.md` | Created (182 lines) |
| `docs/pipeline/active/p0000-p0099` | Created (91 pipeline docs) |
| `docs/pipeline/dashboard.md` | Generated |
| `scripts/pipeline/dashboard.sh` | Created |
| `scripts/pipeline/compile-bead-context.sh` | Created |
| `.claude/commands/pipeline-dashboard.md` | Created |
| `.claude/commands/orchestrate.md` | Created |
| `docs/pipeline.md` → `docs/reification.md` | Renamed + updated |
| `CLAUDE.md` | Updated (reification rename + project structure) |
| `scripts/loc.sh` | Updated (pipeline + shell script counting) |

---

## Orchestration Failure — Agent Model Revision (Session 3, Post-Compaction)

*[T] The user ran `/orchestrate` and the orchestrator failed: it spawned design agents as subagents (fire-and-forget), they ran autonomously without human input, got terminated, and the design discussion — the most valuable part — never happened. This triggered a fundamental rethink of the agent model.*

[U] "we need to fix the orchestration rules, i ran this, claude failed to put anyone in a worktree. then claude ran design agents, terminated them, and i never had a discussion. i have some thoughts about a fundamental shift, but first, what are your thoughts?"

[C] Diagnosed the problem as a role model mismatch: the process spec envisions persistent agents that sit idle and hold context, but subagents are fire-and-forget. Proposed that the orchestrator should be a "mode" rather than a role, with Claude working directly in the main session for interactive phases and subagents only for parallelizable non-interactive work.

[U] "no, it's agent teams, not subagents"

[C] "You're right, that changes things. With agent teams, the members are persistent — the human can switch to them and have a real conversation. So the platform supports the model."

### The Two-Tier Agent Model

[U] "i am thinking to make the pipeline have a 'pipeline' agent, who is responsible for design, breakdown, and then performing the final FF rebase and testing cycle. then we have one open pipeline agent per pipeline, for the lifetime of the pipeline. the orchestrator must never tear down the team, even if there are no agents running, but there usually will be. then, we have a pool of workers, and pools of the verification agents available, at least one of each type. these general purpose agents are also able to let the orchestrator know they have questions for me, and either have the orchestrator present them, or ask for a longer consultation. we should encourage agents to ask questions in general, too. explain this idea back to me so i know you got it"

[C] Reflected back: pipeline agents are long-lived (one per pipeline, owns design + breakdown + final merge), worker and verification pools are shared and general-purpose, any agent can signal for human input (quick questions batched, longer consultation routed directly), team is permanent and never torn down.

[U] "you forgot the 0th type of verification agent, the scope checkers. also, let's add we can have specialized workers and verifiers on specific areas of the code, as appropriate, and then route work and verification steps to those, as appropriate"

*[T] This added scope-check as layer 0 and introduced optional specialization for workers/verifiers.*

### Revision: Ephemeral Workers, Not Pools

[U] "actually, let's revise this, worker, verifier agents are not specialized, and they are short lived, as the orchestrator creates one for each bead, and then terminates them when the gate has been passed. when a verification step fails, and the orchestrator reopens all the verification beads, ideally both the fixes and the verifications are all performed with fresh agents."

*[T] Significant reversal — from pooled/specialized workers to fresh-per-bead ephemeral workers. Clean context per bead is more important than accumulated specialization.*

[U] "yeah, so we have the orchestrator also responsible for assigning specific beads to specific workers and verifiers, to be clear. this is in opposition to a model where the workers and verifiers select the next item from a queue."

### Worktrees at Pipeline Start + Verification as Beads

[U] "wait, the worktree thing, let's also have each pipeline get a full worktree at the start. beads for the execution or verifiers to look at something must indicate which worktree they apply to. during breakdown, the pipeline agent must always create beads for the verification steps too. use dependencies to block steps 4 and 5 of verification, until ready. 1, 2, 3 are blocked on the 0th, etc.... the verifier can close that bead once it's passed that gate, or notify the orchestrator that it failed, and then the orchestrator a) opens up all six beads, b) creates a new work bead, c) blocks the 0th on the work bead, and d) notifies an executor to pick it up"

### Corrections During Implementation

[U] "you're done already?"

*[T] Claude had declared done but left multiple inconsistencies. Sweep found: Section 3 diagram stale, Gate 3 text stale, Section 5 merge flow wrong, duplicate merge sections, stale "Design agents"/"Breakdown agents" terminology, missing MEMORY.md update.*

[U] "for pipeline agents, isn't the FF rebase after a different phase than 3?"

*[T] Claude had written "Post-Phase 3" for the FF rebase. Corrected to Post-Phase 4 — it happens after verification passes.*

[U] "verification happens per pipeline, not per bead"

*[T] Section 3 diagram said "(bead-based)" for verification. Fixed to "(per-pipeline)" — the beads are a tracking mechanism, not the unit of scope.*

### Per-Bead Scope Check (Layer 0)

[U] "layer 0 is per bead, sorry, i forgot to clarify that."

[C] Proposed the dependency model:
```
Work bead A ──→ Scope-check A  ┐
Work bead B ──→ Scope-check B  ├──→ Layers 1,2,3 ──→ Layers 4,5
Work bead C ──→ Scope-check C  ┘
```

[U] "yeah, this was actually part of the original design, and you basically got it perfectly"

---

## Gate 3 Self-Review Flow (Session 4, Post-Compaction)

[U] "when we get to gate 3, the self review, here's how it works, the agent says its done with the task, the orchestrator gives the agent a message to do the review, the agent performs the self review, and then the orchestrator checks it, and tells the agent whether it needs to keep working, or wait for the scope review"

*[T] Established that self-review is orchestrator-mediated: worker signals done → orchestrator sends review prompt → worker performs review → orchestrator evaluates → sends back if gaps remain → when satisfied, worker sits idle for scope check.*

### Scope Check Before Merge

[U] "layer 0 scope check has to run before the agent gets to merge its work into the bead branch, 8 and 9 have that wrong"

*[T] The scope check was incorrectly placed after merge. Final execution flow: self-review → scope check (on per-bead worktree) → merge into pipeline branch. Worker sits idle during scope check for immediate bounce-back if issues found.*

### TeamCreate Emphasis

[U] "the instructions must emphasize using TeamCreate"

*[T] Added "Team Setup — CRITICAL" section to orchestrate.md: `TeamCreate(team_name: "tavern-pipeline")` on first session, concrete `Agent(team_name:...)` calls for spawning, `TaskCreate`/`TaskUpdate` for coordination, `SendMessage(type: "shutdown_request")` for shutdown. Also updated process.md Section 6.*

[U] "are these team agents?"

[C] "Yes — they're spawned via `Agent(team_name: "tavern-pipeline", name: "...")` which makes them team members under the team created by `TeamCreate`."

[U] "just clarifying to be sure"

---

## Artifacts Modified (Sessions 3-4)

| File | Action |
|------|--------|
| `docs/pipeline/process.md` | Major revision: Sections 2-9, 13-14 rewritten for two-tier agent model, per-bead scope check, orchestrator-mediated self-review, TeamCreate integration |
| `.claude/commands/orchestrate.md` | Rewritten: team setup, agent naming conventions, TeamCreate workflow, per-bead scope check flow |
| `scripts/pipeline/dashboard.sh` | Updated: worktree-aware (reads pipeline docs from worktree when available) |
| `docs/reification.md` | Renamed from `docs/pipeline.md`, content updated |
| `MEMORY.md` (auto-memory) | Updated: agent model, terminology, per-bead scope check |
