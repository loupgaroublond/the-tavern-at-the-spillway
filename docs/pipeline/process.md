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
- Design discussions (directly with agents, not mediated by orchestrator)
- Verification result review
- Merge path decisions (direct to main vs. review branch)

### Orchestrator (Claude — Chief of Staff)

Does:
- Create pipeline docs, update dashboard
- Route human attention ("Switch to agent [name] for pipeline p{id}")
- Manage worker pool (assign beads to free agents)
- Manage merge ordering and tell agents their queue position at both merge levels
- Track pipeline states, advance through gates
- Collect simple questions from multiple agents, present in batch
- Remind workers to do self-review before scope check

Does NOT:
- Make design decisions about the app
- Review code for correctness
- Run tests or verification
- Mediate technical discussions (routes to agents instead)

### Workers (Agent Team — Rank and File)

- Grab available work from a queue
- Get assigned to a pipeline for the duration of their work period
- Work in per-bead worktrees (during execution)
- Released back to pool when work is done
- Optional specialization (e.g., UI worker with `ui-views.md` loaded)


## 3. Pipeline Lifecycle

Every pipeline moves through four phases:

```
Phase 1: Design ──→ Phase 2: Breakdown ──→ Phase 3: Execution ──→ Phase 4: Verification
         │                    │                      │                       │
      Gate 1              Gate 2                  Gate 3 +              Layers 1-5
   Human Approval      Human Summary           Scope Check           Human Review
      (full)            (summary)              (per-bead)            (per-pipeline)
```

A pipeline in Phase 1 may loop — design agents research, propose, discuss with the human, and iterate until the stub is ready for breakdown. Phase 2 may also loop, punting items back to Phase 1 for more design. Phase 3 is linear per-bead. Phase 4 runs on the complete pipeline branch.


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

**On approval:** The breakdown agent creates beads with compiled context. The orchestrator creates the pipeline branch.

### Gate 3: Self-Review (Per-Bead, Agent)

**Enforcer:** Execution agent (self)

**Criteria:**
- `redo Tavern/test` passes
- For each acceptance criterion: implemented (Yes/No)
- For each code standard in distilled instructions: followed (Yes/No)
- For each claimed requirement: provenance marker present (Yes/No)
- Unsure items listed explicitly

The worker fixes any gaps it identifies, then messages the orchestrator. The orchestrator reminds the worker to complete self-review before advancing to scope check.

### Scope Check (Per-Bead, Separate Agent)

**Enforcer:** Scope check agent (separate from the worker)

**Criteria:**
- Diff matches the work item scope — no scope creep
- All expected files changed
- No unexpected files changed
- Changes address acceptance criteria
- No obvious red flags

The work agent sits idle during scope check, maintaining context for bounce-back. If issues found, the orchestrator bounces the feedback to the idle worker immediately. If clean, the per-bead branch merges into the pipeline branch.

### Verification (Per-Pipeline, Five Layers)

**Enforcer:** Pooled verification agents (one per layer)

Runs after ALL beads have merged into the pipeline branch. See Section 9 for full layer specifications.

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
  └── pipeline/p0000-jukebox          (pipeline branch)
        ├── p0000-wi001               (per-bead worktree)
        ├── p0000-wi002               (per-bead worktree)
        └── p0000-wi003               (per-bead worktree)
```

**Pipeline branches** are created when a pipeline enters Phase 3 (after Gate 2 approval). They branch from main and accumulate all bead work for the pipeline.

**Per-bead worktrees** branch from the pipeline branch. Each worker gets their own worktree. Workers modify code AND the pipeline doc in their worktree.

**Merge flow:**
1. Per-bead branch → pipeline branch (after scope check)
2. Pipeline branch → main or review branch (after verification + human review)

### Proactive Rebasing

Applies at BOTH merge levels:

1. **Bead to pipeline branch:** Workers rebase their per-bead branches onto the pipeline branch as other beads merge in.

2. **Pipeline branch to main (or review branch):** Pipeline branches rebase onto main as other pipelines merge.

The orchestrator tells agents their queue position and which branches are ahead at both levels. Agents proactively rebase to stay current, reducing merge friction.

### Merge Into Pipeline Branch

After scope check passes:
1. Per-bead branch rebases onto pipeline branch HEAD
2. Worker runs `redo Tavern/test` on the rebased branch
3. If clean, fast-forward merge into pipeline branch
4. Worker released back to pool

Since tests on a rebased branch should match tests on the target after merge, multiple workers can test in parallel — testing is not a merge bottleneck.

### Merge to Main

After verification passes and human reviews:
- **Direct to main:** Pipeline branch rebases to main HEAD, runs `redo Tavern/test`, fast-forward merges
- **Review branch:** Orchestrator assembles aggregate diff from multiple pipelines, human reviews code, then merges

The orchestrator manages merge ordering across pipelines.


## 6. Worker Pool

Workers grab available work from a queue. They do not belong to a specific pipeline — they get assigned for the duration of a work period, then released back to the pool.

**Pool size:** 5-10 total agents running at any time, adjustable as we learn.

### Worker Types

Every worker has a **type** that determines what phase of work it performs:

| Type | Phase | What It Does |
|------|-------|-------------|
| `design` | 1 | Researches stubs, develops design proposals, drafts alternatives |
| `breakdown` | 2 | Decomposes designs into self-contained work items |
| `work` | 3 | Implements code in per-bead worktrees |
| `scope-check` | 3 | Reviews diffs for scope creep (separate from the work agent) |
| `verify-1` | 4 | Traceability audit |
| `verify-2` | 4 | Invariant review |
| `verify-3` | 4 | Architecture conformance |
| `verify-4` | 4 | Blast radius check |
| `verify-5` | 4 | Gap scan |

Worker type is fixed for the lifetime of the agent. A `work` agent does not become a `scope-check` agent.

### Specialization

Orthogonal to type. A specialization is a domain area of the app (e.g., UI, servitor lifecycle, infrastructure). Specialized workers load domain-specific instruction supplements (`ui-views.md`, `agent-core.md`, etc.) in addition to `core.md`.

Specialization is optional and applies mainly to `design`, `breakdown`, and `work` types. The orchestrator considers specialization when assigning work — a UI-specialized worker gets UI beads when available.

**One active team at a time:** This is a Claude Code platform limitation, not a design choice. Many agents come and go, but only one team is active in the orchestrator's session at any given moment.


## 7. Work Breakdown

The breakdown agent (Phase 2) decomposes the pipeline into self-contained work items.

### Decomposition Depth

The agent examines each chunk: "Can one agent implement and test this in one worktree?" If not, go deeper. This recurses:
- Large feature becomes work items
- Work item becomes sub-items with dependencies
- Beads can be hierarchical (parent-child via `bd`)

At each level: punt back to Phase 1 for more design, or go deeper on decomposition? Go deeper when design is clear but scope is too large.

### The Breakdown Plan

The breakdown agent creates a **complete plan first** in the pipeline doc's Work Breakdown Plan section. This plan includes:

- Every work item with full detail
- Markers showing where to create beads
- Context-source specifications per work item (see below)
- Dependencies and ordering
- Parallelism opportunities

Only after the plan is written and approved (Gate 2) does the agent create beads — without re-reading source docs. The agent already made the control-plane decisions about what to include.

### Context-Source Specifications

For each work item, the breakdown agent specifies what documentation to compile into the bead:

```yaml
context-sources:
  instructions: [core, agent-core]
  specs: [REQ-AGT-004, REQ-LCM-001, REQ-LCM-002]
  adrs: [ADR-001 section-3.2, ADR-003 section-2]
  code: [Jake.swift:1-50, MortalSpawner.swift:init]
  design-statements: [from pipeline Design Statements, items 2-3]
```

The compile script (`scripts/pipeline/compile-bead-context.sh`) reads these references and produces a single compiled context document per bead. Execution agents burn tokens reading docs once — when they read the bead.

### Design Statement Flow

Design agents (Phase 1) produce Design Statements in the pipeline doc. The breakdown agent reads these and decides which to inject into each bead. The compile script includes them. Nobody re-researches what was already figured out.


## 8. Execution

### Per-Bead Worktrees

Each worker gets a worktree branched from the pipeline branch. They implement the work item, modify the pipeline doc if needed, and commit in their per-bead branch.

### Self-Review (Gate 3)

When done, the worker reviews its own instructions piece by piece:
- For each acceptance criterion: implemented? Yes/No
- For each code standard: followed? Yes/No
- For each claimed requirement: provenance marker? Yes/No
- Unsure items listed

The worker fixes any gaps it identifies, then messages the orchestrator. The orchestrator does NOT run checks — verification catches what self-review misses.

### Scope Check

After self-review, a **separate scope check agent** does a quick pass:
- Does the diff match the work item scope?
- Scope creep? Missing files? Obvious omissions?

The work agent sits idle during scope check (maintains context for bounce-back). If issues found, the orchestrator bounces to the idle worker immediately. If clean, per-bead branch merges into the pipeline branch.

This is the only verification that happens per-bead. Full verification (Layers 1-5) is per-pipeline.


## 9. Verification

Verification runs on the **pipeline branch** after all beads have merged into it. This is per-pipeline, not per-bead.

Five layers, each run by a separate agent with comprehensive instructions (400-900 lines per layer — every rule, invariant, and check baked into the prompt). Agents do NOT run slash commands.

Verification agents are pooled — when idle, they pick up the next job for their layer. They keep context on their layer's methodology, making them efficient across pipelines.

### Verification Flow

```
Pipeline branch complete (all beads merged)
    |
    v
Layer 1: Traceability Audit  \
Layer 2: Invariant Review      |-- can run in parallel
Layer 3: Architecture Conformance /
    |
    v (when 1-3 complete)
Layer 4: Blast Radius Check
    |
    v
Layer 5: Gap Scan
    |
    v
Results recorded in pipeline doc --> human reviews
```

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

### Post-Verification

If all layers pass, human decides merge path (direct to main or review branch).

If layers fail:
- **Violated invariants:** New beads created, workers fix, re-merge into pipeline branch, verification re-runs
- **Unclear verdicts:** Human reviews and decides
- **Gaps found:** New pipeline stubs created

### Archiving

After merge:
1. Orchestrator closes child beads
2. Pipeline doc moved to `archive/`
3. Never written again
4. Dashboard updated


## 10. Merge to Main

The orchestrator manages merge ordering across pipelines. Proactive rebasing at both levels keeps branches current and reduces merge friction.

**Direct merge:** Pipeline branch rebases to main HEAD, runs `redo Tavern/test`, fast-forward merges.

**Review branch:** Orchestrator assembles aggregate diff from multiple pipelines, human reviews code, then merges.

The human decides which path each pipeline takes.


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

1. **Script** (`scripts/pipeline/dashboard.sh`): Parse YAML frontmatter from all active pipeline docs. Compute phase counts, blocked-by chains, time-in-phase.

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
pipeline-branch: null
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
| `pipeline-branch` | string | Git branch name (null until Phase 3) |
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

6. **Context is compiled, not re-researched.** Design agents produce Design Statements. Breakdown agents produce context-source specifications. The compile script bundles them. Execution agents read once.

7. **The orchestrator coordinates, never decides.** Technical decisions belong to agents and the human. The orchestrator routes attention, manages queues, and tracks state.

8. **Background churn is always running.** Workers grab work, scope checks run, beads merge — regardless of human presence.

9. **Proactive rebasing at all levels.** Agents stay current with their merge targets. The orchestrator tells them their queue position and which branches are ahead.

10. **One team active, many agents in flight.** The Claude Code platform limits us to one active team, but agents come and go continuously. The pool is the design unit, not the team.
