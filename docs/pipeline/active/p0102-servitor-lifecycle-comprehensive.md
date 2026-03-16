---
id: p0102
slug: servitor-lifecycle-comprehensive
title: "Comprehensive servitor lifecycle: states, modes, transitions, and gaps"
phase: design
gate: pending
priority: 1
source-bead: null
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-08
updated: 2026-03-08
assigned-agent: null
merges: [p0088, p0017, p0090, p0020]
---

# Comprehensive Servitor Lifecycle: States, Modes, Transitions, and Gaps

## Brief
> Merged from p0088 (lifecycle gaps), p0017 (kill/restart triggers), p0090 (states & modes), and p0020 (perseverance mode). Consolidates all servitor lifecycle design work into a single pipeline doc. Punted back to Gate 1 for unified design.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **Pending** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Design agent to produce unified lifecycle design covering all merged concerns.

## Merged Sources

### p0088 — Module 006: Lifecycle Gaps (REQ-LCM)
- **Source bead:** jake-3arz (feature, priority 1)
- **Content:** 5 specified reqs remaining. LCM-001 FOCB triggers (must-have), LCM-002 token budget enforcement (must-have, depends on SDK gap 2b), LCM-003 spin detection (should-have), LCM-005 rewind (deferred), LCM-006 branch (deferred).
- **Status at merge:** Stub, no design work started.

### p0017 — Fish-or-Cut-Bait: Kill and Restart Triggers
- **Source bead:** jake-bly (feature, priority 3)
- **Content:** Discussion starting point. Triggers to kill and restart rather than continue: token budget exceeded, changeset totally wrong, agent spinning, whole gang going down wrong path. Reap and restart cleanly.
- **Sources cited:** PRD section 12 (Fish or Cut Bait), PRD section 4.2 (Failed/Reaped state).
- **Status at merge:** Stub, discussion starting point (not promoted to real work).

### p0090 — Module 019: States & Modes (REQ-STM)
- **Source bead:** jake-xaau (feature, priority 1)
- **Content:** 7 reqs, 0% coverage, all must-have. Three orthogonal booleans (backgrounding, perseverance, user presence) as unified state machine. Foundation for modules 020 and 007. Currently ServitorState is a simple enum, not the three-boolean model.
- **Status at merge:** Stub, no design work started.

### p0020 — Perseverance Mode and Agent Lifecycle States
- **Source bead:** jake-pbt (feature, priority 2)
- **Content:** Discussion starting point. When agents stop, the system should auto-prompt them to continue (perseverance mode). Agents must explicitly use a tool to get user attention. Full lifecycle state machine: Working, Waiting for Input, Waiting for Wakeup, Done, Failed/Reaped.
- **Sources cited:** PRD section 4.2 (Agent States), PRD section 4.4 (Operating Modes), reader section 3 (Perseverance Mode vs Chat Mode), reader open question ?6 (Perseverance Prompts and Agent Lifecycle), project-status.md Agent Spawning Remaining.
- **Status at merge:** Stub, discussion starting point (not promoted to real work).

## Consolidated Design Scope

### Lifecycle State Machine
- **Current state:** ServitorState is a simple enum (`idle`, `working`, `waiting`, `verifying`, `done`).
- **Target state:** Three orthogonal booleans (backgrounding, perseverance, user presence) as a unified state machine (from p0090/REQ-STM).
- **Full state set (from p0020):** Working, Waiting for Input, Waiting for Wakeup, Done, Failed/Reaped.

### Perseverance Mode (from p0020)
- Auto-prompt agents to continue when they stop.
- Agents must explicitly use a tool to get user attention (not just emit text).
- Key questions:
  - What is a perseverance prompt exactly?
  - What triggers transitions between modes?
  - How does perseverance interact with token budgets?
  - What is the wakeup mechanism?

### Fish-or-Cut-Bait Triggers (from p0017, p0088/LCM-001)
- Kill and restart conditions: token budget exceeded, changeset totally wrong, agent spinning, gang going down wrong path.
- Key questions:
  - Who decides to FOCB — parent agent, Jake, or user?
  - How is spinning detected automatically? (LCM-003, should-have)
  - What does restart look like — same assignment, fresh context?
  - How does FOCB relate to agent hierarchy (reap subtree vs individual)?

### Token Budget Enforcement (from p0088/LCM-002)
- Must-have requirement, depends on SDK gap 2b (see p0094).
- Token budget exceeded is a FOCB trigger.

### Deferred Items (from p0088)
- LCM-005: Rewind — deferred.
- LCM-006: Branch — deferred.

## Open Questions (Consolidated)
1. What are the exact transitions in the three-boolean state model? (p0090)
2. What is a perseverance prompt — exact content and trigger? (p0020, reader ?6)
3. Who has FOCB authority — parent, Jake, user, or configurable? (p0017)
4. How does spin detection work — heuristic, token count, repetition? (p0088 LCM-003)
5. How does the lifecycle state machine interact with session persistence? (cross-cutting)
6. Does FOCB reap a subtree or just the individual agent? (p0017)
7. What is the wakeup mechanism for Waiting-for-Wakeup state? (p0020)
8. How does token budget enforcement feed into FOCB triggers? (p0088 LCM-002, p0094)

## Agreements Between Sources

All four sources agree on:
- The current simple enum state model is insufficient.
- Agents need both autonomous (perseverance) and interactive (chat) modes.
- Token budgets should trigger lifecycle transitions (not just warnings).
- The Failed/Reaped state is a necessary terminal state distinct from Done.

## Disagreements Between Sources

No direct contradictions found. The sources are complementary:
- p0090 provides the formal state model (three booleans).
- p0020 provides the UX-level lifecycle (perseverance, wakeup).
- p0017 provides the failure/restart policy (FOCB triggers).
- p0088 provides the spec-level requirements (LCM-001 through LCM-006).

The only tension is priority: p0088 and p0090 are priority 1 (must-have), p0020 is priority 2, p0017 is priority 3. This merged doc inherits priority 1.

## Design Log

## Design Statements

## Work Breakdown Plan

## Verification Results

## Agent Context
### Relevant Specs
- Module 006: Lifecycle Gaps (REQ-LCM) — `docs/2-spec/` (if exists)
- Module 019: States & Modes (REQ-STM) — `docs/2-spec/` (if exists)
### Relevant ADRs
### Relevant PRD Sections
- PRD 4.2: Agent States
- PRD 4.4: Operating Modes
- PRD 12: Fish or Cut Bait
### Key Code
- `Sources/TavernCore/Servitors/Mortal.swift` — current state machine
- `Sources/TavernCore/Servitors/Jake.swift` — daemon lifecycle
- `Sources/TavernCore/Servitors/MortalSpawner.swift` — spawn/dismiss
### Distilled Instructions

## Child Beads

## Generated Stubs
