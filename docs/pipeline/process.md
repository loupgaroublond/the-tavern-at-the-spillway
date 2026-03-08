# Development Pipeline Process

This document defines how work moves through the Tavern development system, from stub to shipped code. It is the operating model for the orchestrator, all agents, and the human VP.

## 1. Core Concepts

**Pipeline documents** are first-class, ephemeral work orders. Each piece of work gets a pipeline document that tracks its progress from stub through completion. Pipeline docs live in `docs/pipeline/active/` and move to `docs/pipeline/archive/` when done. They are not part of the permanent system of record (PRD, specs, ADRs, code, tests).

**Gates** are rigid checkpoints between phases. The activities between gates are flexible — different work requires different approaches — but at each gate, specific conditions must be true before work proceeds. Gates are never skipped.

**Stubs** are the entry point. A stub is any idea, gap, or need that has entered the system but is not yet ready for implementation. Stubs vary in length and definition. The pipeline handles all of them — from a single sentence to a paragraph with context.

**Beads** are the execution unit. During Phase 3, work items become beads (via `bd`) with compiled context. Each bead is self-contained: an agent can pick it up cold and implement it without needing to coordinate with other in-progress work.

**Distilled instructions** are pre-generated, token-efficient instruction sets that agents load at the start of their work. They contain the rules, invariants, and patterns relevant to a specific domain. See Section 11.


## 2. Roles

### Human (VP)

- Gate 1 and Gate 2 approval
- Design discussions (directly with pipeline agents, not mediated by orchestrator)
- Verification result review
- Merge path decisions (direct to main vs. review branch)

### Orchestrator (Claude — Chief of Staff)

Does:
- Create pipeline docs and pipeline worktrees, update dashboard
- Spawn and manage the persistent agent team (never tear it down)
- Assign specific beads to specific workers and verifiers (explicit assignment, not self-selection)
- Route human attention ("Switch to agent [name] for pipeline p{id}")
- Manage merge ordering and tell agents their queue position at both merge levels
- Track pipeline states, advance through gates
- Collect questions from agents, present in batch or route for longer consultation
- Handle verification failures: reopen verification beads, create fix beads, reassign

Does NOT:
- Make design decisions about the app
- Review code for correctness
- Run tests or verification
- Mediate technical discussions (routes to agents instead)

### Pipeline Agents (Long-Lived, One Per Pipeline)

Each active pipeline gets a dedicated **pipeline agent** that persists for the pipeline's entire lifetime. The pipeline agent:

- Owns Phase 1 (design): researches, proposes, discusses with the human
- Owns Phase 2 (breakdown): decomposes into work items, creates ALL beads (work + verification)
- After Phase 4 verification: performs the final FF rebase and test cycle to merge to main
- Accumulates context about its pipeline over time — design history, decisions, breakdown rationale
- Works in the pipeline's dedicated worktree from creation

When a pipeline agent needs human input for design, it signals the orchestrator. The orchestrator routes the human to the agent for direct conversation.

### Workers and Verifiers (Short-Lived, One Per Bead)

The orchestrator creates a **fresh agent for each bead** and terminates it when the bead closes. Workers and verifiers are not specialized and do not persist across beads.

**Workers** implement code. One worker per work bead, working in a per-bead worktree branched from the pipeline worktree.

**Verifiers** review completed work on the pipeline worktree. One verifier per verification bead:

| Type | Layer | What It Does |
|------|:-----:|-------------|
| `scope-check` | 0 | Reviews diffs for scope creep |
| `verify-1` | 1 | Traceability audit |
| `verify-2` | 2 | Invariant review |
| `verify-3` | 3 | Architecture conformance |
| `verify-4` | 4 | Blast radius check |
| `verify-5` | 5 | Gap scan |

When verification fails and the orchestrator reopens all verification beads, fresh agents handle both the fix work and the re-verification. No stale context carries over.

### Communication

All agents — pipeline, worker, and verifier — can signal the orchestrator with questions for the human:

- **Quick questions:** The orchestrator batches and presents them
- **Longer consultation:** The orchestrator routes the human to the agent directly

Agents are encouraged to ask questions rather than guess. An extra round trip is always cheaper than rework.


## 3. Pipeline Lifecycle

Every pipeline moves through four phases:

```
Phase 1: Design ──→ Phase 2: Breakdown ──→ Phase 3: Execution ──→ Phase 4: Verification
         │                    │                      │                       │
      Gate 1              Gate 2                  Gate 3              Layer 0 / Layers 1-5
   Human Approval      Human Summary           Self-Review          (per-bead / per-pipeline)
      (full)            (summary)              (per-bead)            Human Review
```

A pipeline in Phase 1 may loop — the pipeline agent researches, proposes, discusses with the human, and iterates until the stub is ready for breakdown. Phase 2 may also loop, punting items back to Phase 1 for more design. Phase 3 is linear per-bead (workers implement, self-review, merge). Phase 4 verification: scope checks (layer 0) run per-bead as work merges; layers 1-5 run per-pipeline after all scope checks pass.


## 4. Gate Specifications

### Gate 1: Ready for Breakdown (Human Approval — Full)

**Enforcer:** Human

**Criteria:**
- The pipeline doc contains enough context that a different agent could pick it up cold and understand what needs to be built and why
- Design Log captures research findings, discussions, and decisions
- Agent Context lists relevant specs, ADRs, code references, and instruction sets
- Design Statements extract key decisions for handoff to Phase 2
- Open questions are resolved or explicitly deferred
- Human has reviewed the entire pipeline doc and explicitly approves

### Gate 2: Ready for Execution (Human Approval — Summary)

**Enforcer:** Human

**Criteria:**
- All work items are decomposed to a size one agent can implement and test in one worktree
- Each item has clear scope, requirements, ADR constraints, acceptance criteria, and context-source specifications
- Dependencies between items are identified and ordered
- Parallelism opportunities are identified
- Human has reviewed the summary (titles, scopes, ordering, complexity estimates) and explicitly approves
- Human does NOT review compiled documentation bundles — those are for execution agents only

**On approval:** The pipeline agent creates all beads (work + N scope-check + 5 verification) with compiled context and dependency chain. Each work bead gets a paired scope-check bead.

### Gate 3: Self-Review (Per-Bead, Orchestrator-Mediated)

**Enforcer:** Orchestrator (mediates between worker and review)

**Flow:**
1. Worker signals the orchestrator that the task is done
2. Orchestrator sends the worker a self-review prompt
3. Worker performs the self-review (checklist below) and reports results
4. Orchestrator evaluates the review — if gaps remain, sends the worker back to fix them
5. When the orchestrator is satisfied, the worker sits idle while scope check runs
6. After scope check passes, the worker merges into the pipeline branch

**Self-review criteria:**
- `redo Tavern/test` passes
- For each acceptance criterion: implemented (Yes/No)
- For each code standard in distilled instructions: followed (Yes/No)
- For each claimed requirement: provenance marker present (Yes/No)
- Unsure items listed explicitly

The orchestrator does NOT run tests or review code — it checks that the self-review is thorough and complete. Verification catches what self-review misses.

### Scope Check (Per-Bead, Layer 0)

**Enforcer:** Scope check verifier (fresh agent per scope-check bead, assigned by orchestrator)

**Criteria:**
- Diff matches the work item scope — no scope creep
- All expected files changed
- No unexpected files changed
- Changes address acceptance criteria
- No obvious red flags

Each work bead has a paired scope-check bead (layer 0). After self-review passes, the orchestrator creates a fresh scope-check verifier to review the worker's diff *before* it merges. The worker sits idle during scope check (maintains context for bounce-back). If the scope check fails, the orchestrator bounces the worker to fix issues. If it passes, the worker merges into the pipeline branch.

### Verification (Per-Pipeline, Layers 1-5)

**Enforcer:** Fresh verification agents (one per layer, assigned by orchestrator)

Runs after scope check passes. Each layer is a bead. See Section 9 for full layer specifications and the failure/rerun flow.

### Post-Verification: Human Review

**Enforcer:** Human

**Criteria:**
- All five verification layers have passed
- Human reviews results (summary or in-depth, human's choice)
- Human decides merge path: direct to main or review branch


## 5. Branching Model

Multi-level branching for parallel execution:

```
main
  └── pipeline/p0000-jukebox          (pipeline worktree, created at pipeline start)
        ├── p0000-wi001               (per-bead worktree, Phase 3)
        ├── p0000-wi002               (per-bead worktree, Phase 3)
        └── p0000-wi003               (per-bead worktree, Phase 3)
```

**Pipeline worktrees** are created when a pipeline is created — not when it enters Phase 3. The pipeline agent works in this worktree from the start (design, breakdown, everything). The worktree persists for the pipeline's entire lifetime.

**Per-bead worktrees** branch from the pipeline branch during Phase 3. Each worker gets their own worktree for isolation during parallel execution.

**All beads reference their worktree.** Work beads and scope-check beads specify the per-bead worktree. Layers 1-5 verification beads specify the pipeline worktree (they examine the fully merged result).

**Merge flow:**
1. Per-bead branch → pipeline branch (after self-review + scope check)
2. Pipeline branch → main or review branch (after verification + human review)

### Proactive Rebasing

Applies at BOTH merge levels:

1. **Bead to pipeline branch:** Workers rebase their per-bead branches onto the pipeline branch as other beads merge in.

2. **Pipeline branch to main (or review branch):** Pipeline branches rebase onto main as other pipelines merge.

The orchestrator tells agents their queue position and which branches are ahead at both levels. Agents proactively rebase to stay current, reducing merge friction.

### Merge Into Pipeline Branch

After self-review and scope check pass, the worker merges into the pipeline branch (see Section 8 for details). The orchestrator closes the work bead and terminates the worker. Multiple workers can test in parallel since tests on a rebased branch match tests on the target after merge.

### Merge to Main

After verification passes and human reviews, the **pipeline agent** performs the final merge:
- **Direct to main:** Pipeline branch rebases to main HEAD, runs `redo Tavern/test`, fast-forward merges
- **Review branch:** Orchestrator assembles aggregate diff from multiple pipelines, human reviews code, then merges

The orchestrator manages merge ordering across pipelines.


## 6. Agent Model

Two tiers of agents, managed as a single persistent team via `TeamCreate`.

The orchestrator **must** use `TeamCreate(team_name: "tavern-pipeline")` to create the team on first session. All agents are spawned with `team_name: "tavern-pipeline"` so they join the team and coordinate via the shared task list (`TaskCreate`, `TaskUpdate`, `TaskList`). Agents are shut down via `SendMessage(type: "shutdown_request")`.

### Tier 1: Pipeline Agents (Long-Lived)

One per active pipeline, persists for the pipeline's entire lifetime. Spawned by the orchestrator via `Agent(team_name: "tavern-pipeline", name: "pNNNN-pipeline")` when a pipeline starts, shut down when it archives.

**Responsibilities:**
- Phase 1: Design (research, propose, discuss with human)
- Phase 2: Breakdown (decompose, create ALL beads — work + scope-checks + 5 verification)
- Post-Phase 4: Final FF rebase and test cycle to merge to main
- Post-Phase 4: Archive after human approves merge

The pipeline agent accumulates context over the pipeline's life. It knows the design history, decisions, breakdown rationale, and which beads are in flight. It is the authority on its pipeline.

### Tier 2: Workers and Verifiers (Short-Lived)

The orchestrator spawns a **fresh agent for each bead** (via `Agent(team_name: "tavern-pipeline", name: "pNNNN-wiNNN-worker")` or `name: "pNNNN-verify-N"`) and shuts it down when the bead closes. Workers and verifiers do not persist across beads and are not specialized.

- **Workers:** One per work bead. Work in per-bead worktrees branched from the pipeline worktree.
- **Verifiers:** One per verification bead. Examine the pipeline worktree.

When verification fails and all verification beads reopen, fresh agents handle both the fix and the re-verification. No stale context carries over.

### Team Lifecycle

The team is **permanent**. The orchestrator never tears it down, even if no agents are currently active (though there usually will be). Pipeline agents persist for their pipeline's lifetime. Workers and verifiers come and go as beads are created and closed.

**Agent count:** 5-10 total agents running at any time, adjustable as we learn. This includes pipeline agents + active workers/verifiers.


## 7. Work Breakdown

The **pipeline agent** (Phase 2) decomposes the pipeline into self-contained work items and creates ALL beads — both work beads and verification beads.

### Decomposition Depth

The pipeline agent examines each chunk: "Can one agent implement and test this in one worktree?" If not, go deeper. This recurses:
- Large feature becomes work items
- Work item becomes sub-items with dependencies
- Beads can be hierarchical (parent-child via `bd`)

At each level: punt back to Phase 1 for more design, or go deeper on decomposition? Go deeper when design is clear but scope is too large.

### The Breakdown Plan

The pipeline agent creates a **complete plan first** in the pipeline doc's Work Breakdown Plan section. This plan includes:

- Every work item with full detail
- Markers showing where to create beads
- Context-source specifications per work item (see below)
- Dependencies and ordering
- Parallelism opportunities
- Verification beads with their dependency chain (see below)

Only after the plan is written and approved (Gate 2) does the pipeline agent create beads — without re-reading source docs. The agent already made the control-plane decisions about what to include.

### Verification Beads

The pipeline agent **always** creates verification beads alongside the work beads: one scope-check bead per work bead (N total) plus 5 per-pipeline verification beads. The dependency chain:

```
Work bead A ──→ Scope-check A  ┐
Work bead B ──→ Scope-check B  ├──→ Layer 1: verify-1  ┐
Work bead C ──→ Scope-check C  ┘    Layer 2: verify-2  ├──→ Layer 4: verify-4  ┐
                                     Layer 3: verify-3  ┘    Layer 5: verify-5  ┘
```

- Each work bead gets a **paired scope-check bead** (layer 0) blocked on it
- Layers 1, 2, 3 are blocked on **all** scope-check beads
- Layers 4, 5 are blocked on layers 1, 2, 3

Scope-check beads reference the per-bead worktree (they review the worker's diff *before* merge). Layers 1-5 reference the pipeline worktree (they examine the fully merged result).

When a verifier passes its layer, it closes the bead. When a verifier fails, it notifies the orchestrator. See Section 9 for the failure flow.

### Context-Source Specifications

For each work item, the pipeline agent specifies what documentation to compile into the bead:

```yaml
context-sources:
  instructions: [core, agent-core]
  specs: [REQ-AGT-004, REQ-LCM-001, REQ-LCM-002]
  adrs: [ADR-001 section-3.2, ADR-003 section-2]
  code: [Jake.swift:1-50, MortalSpawner.swift:init]
  design-statements: [from pipeline Design Statements, items 2-3]
  worktree: pipeline/p0000-jukebox
```

The compile script (`scripts/pipeline/compile-bead-context.sh`) reads these references and produces a single compiled context document per bead. Execution agents burn tokens reading docs once — when they read the bead.

### Design Statement Flow

The pipeline agent (Phase 1) produces Design Statements in the pipeline doc. During breakdown (Phase 2), the same agent reads these and decides which to inject into each bead. The compile script includes them. Nobody re-researches what was already figured out.


## 8. Execution

### Per-Bead Worktrees

The orchestrator creates a fresh worker agent for each work bead and assigns it. Each worker gets a worktree branched from the pipeline branch. They implement the work item, modify the pipeline doc if needed, and commit in their per-bead branch.

### Self-Review (Gate 3)

When the worker signals it is done, the orchestrator sends it a self-review prompt. The worker reviews its own instructions piece by piece:
- For each acceptance criterion: implemented? Yes/No
- For each code standard: followed? Yes/No
- For each claimed requirement: provenance marker? Yes/No
- Unsure items listed

The worker reports results to the orchestrator. If the orchestrator identifies gaps in the review, it sends the worker back to fix them. This loop continues until the orchestrator is satisfied the review is thorough. The orchestrator does NOT review code for correctness — it checks completeness of the self-review. Verification catches what self-review misses.

### Scope Check (Per-Bead, Layer 0)

After self-review passes, the orchestrator creates a fresh scope-check verifier to review the worker's diff against the work item scope. The **worker sits idle** during scope check — it maintains context for immediate bounce-back if issues are found.

- **Pass:** The scope-check bead closes, the verifier is terminated, and the worker proceeds to merge.
- **Fail:** The orchestrator bounces the worker with specific feedback. The worker fixes, re-does self-review, and scope check runs again.

### Merge Into Pipeline Branch

After scope check passes, the worker merges its work:
1. Per-bead branch rebases onto pipeline branch HEAD
2. Worker runs `redo Tavern/test` on the rebased branch
3. If clean, fast-forward merge into pipeline branch
4. Worker messages the orchestrator; orchestrator closes the work bead and terminates the worker

When ALL work beads and their scope-check beads are closed, layers 1-3 become unblocked.


## 9. Verification

Scope checks (layer 0) run per-bead *before* merge (see Section 8). Layers 1-5 run per-pipeline on the **pipeline worktree** after all work has merged. Each verification layer is a bead with dependencies (see Section 7). The orchestrator creates a fresh verifier agent for each layer 1-5 bead and terminates it when the bead closes.

Verification agents receive comprehensive instructions (400-900 lines per layer — every rule, invariant, and check baked into the prompt). Agents do NOT run slash commands.

### Verification Flow (Bead Dependencies)

```
Work bead A ──→ Self-review ──→ Scope-check A ──→ Merge A  ┐
Work bead B ──→ Self-review ──→ Scope-check B ──→ Merge B  ├──→ Layers 1,2,3 ──→ Layers 4,5
Work bead C ──→ Self-review ──→ Scope-check C ──→ Merge C  ┘
                (per-bead, before merge)                         (per-pipeline, after all merged)
                                                                      │
                                                                      v
                                                                 Results ──→ human reviews
```

Layers 1-3 become unblocked when ALL work beads and scope-check beads are closed (all work merged). Layers 4-5 become unblocked when layers 1-3 close.

### Layer 1: Traceability Audit

Graph completeness check. Does NOT assess correctness — only that claimed links exist.

Checks:
- Every requirement claimed by the pipeline's work items has code with `// MARK: - Provenance: REQ-XXX-NNN`
- Every provenance-marked code file has test files with `.tags(.reqXXXNNN)` or matching provenance markers
- No requirements in the work plan lack corresponding code or test annotations

Output: Traceability matrix (requirement to code to tests to complete/incomplete).

### Layer 2: Invariant Review

Genuine code review. Does the code actually satisfy the spec properties?

For each spec invariant relevant to this pipeline's scope:
- Read the property statement from the spec module
- Read the actual implementation code
- Verdict: **Holds** (cite evidence), **Violated** (explain), or **Unclear** (explain ambiguity)

Violated verdicts block completion. Unclear verdicts escalate to human.

### Layer 3: Architecture Conformance

Comprehensive check against ALL architecture requirements. Catches what the compiler doesn't enforce.

**Semantic review:** Module placement, abstraction appropriateness, DRY violations, ADR pattern conformance.

**Structural rules:** Test timeouts, `#Preview` blocks, logger setup, provenance markers, `@MainActor` on ViewModels, ServitorMessenger DI, no blocking calls, no layer violations, no `@unchecked Sendable`.

### Layer 4: Blast Radius Check

What else depends on what was changed? Does it still work?

- Identify all changed types, protocols, and interfaces from the pipeline diff
- Find all files/modules that depend on changed code
- For each affected module: verify its spec invariants still hold
- Run tests for affected modules, not just the module that was changed
- If changes affect SDK layer, flag for Grade 3 tests

### Layer 5: Gap Scan

Zoom out from the specific work and assess what was revealed.

- Requirements in PRD or specs that should have been addressed but weren't?
- New invariants that should exist but don't?
- Design questions revealed by implementation?
- Follow-up items needed for completeness?
- Spec modules that need updating based on what was built?

Gaps become new pipeline stubs at Phase 1.

### Pass Flow

When a verifier passes its layer, it closes the bead. The orchestrator terminates the verifier. Downstream verification beads become unblocked.

When ALL verification beads (N scope-checks + 5 layers) are closed, the pipeline is ready for human review.

### Failure Flow

When a verifier finds a problem, it notifies the orchestrator with specific findings. The orchestrator then:

1. **Reopens all verification beads** (N scope-checks + 5 layers — even those already passed, since the fix may invalidate prior results)
2. **Creates a new work bead** for the fix, referencing the verifier's findings
3. **Creates a new scope-check bead** paired with the fix work bead
4. **Blocks layers 1-3 on the new scope-check bead** (the dependency chain cascades: layers 4-5 blocked on 1-3)
5. **Creates a fresh worker** for the fix bead

After the fix merges into the pipeline branch, the entire verification chain reruns with fresh agents. No stale context carries over from the prior attempt.

### Post-Verification: Human Review

If all layers pass, human decides merge path (direct to main or review branch).

Unclear verdicts from Layer 2 escalate to human before the pipeline can pass.

### Archiving

After merge:
1. Pipeline agent closes all child beads
2. Pipeline doc moved to `archive/`
3. Pipeline worktree cleaned up
4. Pipeline agent terminated
5. Dashboard updated


## 10. Merge to Main

The **pipeline agent** performs the final merge. The orchestrator manages merge ordering across pipelines and tells pipeline agents their queue position.

**Direct merge:** Pipeline agent rebases the pipeline branch to main HEAD, runs `redo Tavern/test`, fast-forward merges.

**Review branch:** Orchestrator assembles aggregate diff from multiple pipelines, human reviews code, then merges.

The human decides which path each pipeline takes. Proactive rebasing at both levels keeps branches current and reduces merge friction.


## 11. Distilled Instructions

Agents load distilled instruction sets at the start of their work. These are pre-generated, token-efficient extracts from the full specs and ADRs.

### Structure

**`core.md` (~250 lines)** — loaded by all agents. Sources: 002-invariants, 003-system-architecture, 017-v1-scope, CLAUDE.md Honor System, ADR-007.

Contents:
- Non-negotiable invariants (8 rules)
- Layer model and dependency direction
- Concurrency: `@MainActor`, no blocking, Sendable hierarchy
- Observable: `@Observable` only, banned patterns
- Tile architecture: tiles own state, one per module
- Code standards: provenance, tags, logging, previews, errors
- Testing standards: grades, parallel paths, toggles, new entity coverage
- V1 scope: ships vs. deferred

**Supplements (~100-200 lines each)** — loaded based on work domain:

| Supplement | Sources | When Loaded |
|-----------|---------|-------------|
| `agent-core.md` | 004-008, ADR-003, ADR-011 | Servitor, spawning, lifecycle, state machine work |
| `ui-views.md` | 013-014, ADR-004/006/008 | View, tile, and UX work |
| `communication.md` | 009, 022, ADR-008 | Messaging, bubbling, chat work |
| `infrastructure.md` | 010-012, ADR-011 | Doc store, sandbox, workflow work |
| `testing-quality.md` | 015-018, ADR-002/005/009/010 | Test infrastructure, quality, verification work |

### Maintenance

When specs or ADRs change, affected instruction sets must be regenerated from their sources. Regeneration is wired into `/update-status` (affected sets) and `/update-verifications` (all sets + validate).


## 12. Dashboard

### Two-Layer Generation

1. **Script** (`scripts/pipeline/dashboard.sh`): Parse YAML frontmatter from all active pipeline docs. **Worktree-aware** — for each pipeline with a worktree, reads the worktree version of the pipeline doc (which may be more current than the main branch copy). Computes phase counts, blocked-by chains, time-in-phase.

2. **Orchestrator**: Read pipeline docs for context. Fill in "what's needed" descriptions, progress details, human-readable summaries.

### Slash Command

`/pipeline-dashboard` runs the dashboard script, reads active pipeline docs for context, writes `docs/pipeline/dashboard.md`, and displays a summary in conversation.

The orchestrator can use `/loop 5m /pipeline-dashboard` during active work periods. During low activity, manual updates at natural breakpoints.

### Format

```
# Pipeline Dashboard
_Updated: {timestamp}_

## Summary
| Phase | Count |
|-------|------:|
| Design | N |
| Breakdown | N |
| Execution | N |
| Verification | N |
| **Active** | **N** |
| Archived | N |

## Needs Your Attention
| Pipeline | Phase | Priority | What's Needed |
|----------|-------|:--------:|---------------|

## Running
| Pipeline | Phase | Priority | Progress |
|----------|-------|:--------:|----------|

## Queued
| Pipeline | Priority | Waiting On |
|----------|:--------:|------------|

## Recently Archived
| Pipeline | Completed | Items | Duration |
|----------|-----------|:-----:|----------|
```


## 13. Pipeline Document Structure

Each pipeline document uses YAML frontmatter for script-parseable state and a markdown body for humans and agents.

### Frontmatter

```yaml
---
id: p0000
slug: jukebox
title: The Jukebox — Background Process Framework
phase: 1-design
gate: pending
priority: 2
source-bead: jake-815
child-beads: []
blocked-by: []
pipeline-branch: pipeline/p0000-jukebox
worktree-path: /path/to/worktree/p0000-jukebox
created: 2026-03-06
updated: 2026-03-06
assigned-agent: null
---
```

**Field definitions:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Pipeline ID (`p0000`-`p9999`) |
| `slug` | string | URL-safe short name |
| `title` | string | Human-readable title |
| `phase` | enum | `1-design`, `2-breakdown`, `3-execution`, `4-verification`, `archived` |
| `gate` | enum | `pending`, `passed`, `blocked` |
| `priority` | int | 0 (critical) through 4 (backlog) |
| `source-bead` | string | Original bead ID this pipeline was migrated from (null if new) |
| `child-beads` | list | Bead IDs created during breakdown |
| `blocked-by` | list | Pipeline IDs that must complete first |
| `pipeline-branch` | string | Git branch name (created at pipeline start) |
| `worktree-path` | string | Path to pipeline worktree (created at pipeline start) |
| `created` | date | Creation date |
| `updated` | date | Last update date |
| `assigned-agent` | string | Currently assigned agent name (null if unassigned) |

### Body Template

```markdown
# {title}

## Brief
> 1-2 sentences, always current.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **IN PROGRESS** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** {what needs to happen next}

## Stub
{Original stub text, verbatim}

## Design Log
{Chronological: research, discussions, decisions, transcript refs}

## Design Statements
{Key decisions/constraints extracted from Design Log, handed off to Phase 2}

## Work Breakdown Plan
{Phase 2 output: full decomposition with bead markers and context-source specs}

## Verification Results
{Phase 4: layer-by-layer findings}

## Agent Context
### Relevant Specs
### Relevant ADRs
### Key Code
### Distilled Instructions

## Child Beads

## Generated Stubs
```

### Epics

Epic beads become stubbed pipeline docs, blocked on their children. When all child pipelines complete, the epic pipeline gets reviewed as a whole — is the epic truly done, or is there more to do? This review may generate new stubs.


## 14. Process Principles

1. **Activities are flexible, gates are rigid.** Do whatever is needed to get work to the next gate. At the gate, specific things must be true.

2. **Pipeline documents are ephemeral.** They track work in progress. The permanent system of record is the PRD, specs, ADRs, code, and tests with their traceability chain.

3. **Stubs are cheap.** Any idea, gap, or question can become a stub. The pipeline handles filtering and refinement.

4. **Verification is layered.** Each layer catches a different class of problem. Skipping layers accumulates debt.

5. **Gaps generate stubs.** Verification is not just quality control — it is a source of new work. This is how the pipeline feeds itself.

6. **Context is compiled, not re-researched.** The pipeline agent produces Design Statements (Phase 1) and context-source specifications (Phase 2). The compile script bundles them. Workers read once.

7. **The orchestrator coordinates, never decides.** Technical decisions belong to agents and the human. The orchestrator routes attention, manages queues, and tracks state.

8. **Background churn is always running.** Workers grab work, scope checks run, beads merge — regardless of human presence.

9. **Proactive rebasing at all levels.** Agents stay current with their merge targets. The orchestrator tells them their queue position and which branches are ahead.

10. **The team is permanent, agents are ephemeral.** Pipeline agents persist for the pipeline's lifetime. Workers and verifiers are created fresh per bead and terminated when the bead closes. The team itself is never torn down.
