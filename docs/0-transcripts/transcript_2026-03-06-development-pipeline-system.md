# Development Pipeline System — Design & Implementation

**Date:** 2026-03-06
**Sessions:** 1 (2 context continuations)
**Scope:** Design and implement a development pipeline system for tracking work from stub through design, breakdown, execution, and verification. Migrate all 91 open beads. Rename "document pipeline" to "reification chain."
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
