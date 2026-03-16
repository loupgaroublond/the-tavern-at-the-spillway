---
id: p0020
slug: perseverance-mode-and-agent-lifecycle-st
title: "Perseverance mode and agent lifecycle states"
phase: merged
gate: n/a
priority: 2
source-bead: jake-pbt
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Perseverance mode and agent lifecycle states

## Brief
> Migrated from bead jake-pbt (feature, priority 2). Stub — needs design before implementation.

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

When agents stop, the system should auto-prompt them to continue (perseverance mode). Agents must explicitly use a tool to get user attention. Need full lifecycle state machine: Working, Waiting for Input, Waiting for Wakeup, Done, Failed/Reaped.

Sources: PRD section 4.2 (Agent States), PRD section 4.4 (Operating Modes), reader section 3 (Perseverance Mode vs Chat Mode), reader open question ?6 (Perseverance Prompts and Agent Lifecycle), project-status.md Agent Spawning Remaining.

Key questions: What is a perseverance prompt exactly? What triggers transitions? How does this interact with token budgets? What is the wakeup mechanism?

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
