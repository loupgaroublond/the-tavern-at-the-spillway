---
id: p0017
slug: fish-or-cut-bait-kill-and-restart-trigge
title: "Fish-or-cut-bait — kill and restart triggers for agents"
phase: merged
gate: n/a
priority: 3
source-bead: jake-bly
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Fish-or-cut-bait — kill and restart triggers for agents

## Brief
> Migrated from bead jake-bly (feature, priority 3). Stub — needs design before implementation.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **STUB** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to research and develop this stub.

## Stub
DISCUSSION STARTING POINT — not a final task. Discuss with user before promoting to real work.

Triggers to kill and restart rather than continue: token budget exceeded, changeset is totally wrong, agent spinning, whole gang going down wrong path. Reap and restart cleanly.

Sources: PRD section 12 (Fish or Cut Bait), PRD section 4.2 (Failed/Reaped state).

Key questions: Who decides to fish-or-cut-bait — parent, Jake, or user? Automatic detection of spinning? What does restart look like — same assignment fresh context? How does this relate to agent hierarchy (reap subtree vs individual)?

## Design Log

## Design Statements

## Work Breakdown Plan

## Verification Results

## Agent Context
### Relevant Specs
### Relevant ADRs
### Key Code
### Distilled Instructions

## Child Beads

## Generated Stubs
