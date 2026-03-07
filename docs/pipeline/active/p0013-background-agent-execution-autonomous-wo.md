---
id: p0013
slug: background-agent-execution-autonomous-wo
title: "Background agent execution — autonomous work without user focus"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-2bc
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Background agent execution — autonomous work without user focus

## Brief
> Migrated from bead jake-2bc (feature, priority 2). Stub — needs design before implementation.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **STUB** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to research and develop this stub.

## Stub
DISCUSSION STARTING POINT — not a final task. Discuss with user before promoting to real work. Agents should be able to work autonomously in the background while the user focuses elsewhere. Currently agents only respond to direct messages. Background execution enables the full multi-agent vision where many agents work in parallel. Related beads: sidecar pattern (vfx) provides the I/O architecture, perseverance mode (pbt) covers retry/lifecycle, but neither explicitly covers the user-facing concept of agents working while you do other things. Sources: CLAUDE.md Not Implemented, PRD section on agent lifecycle, reader section 3. Key questions: What triggers background work? Task queue? Parent agent delegation? How does the user know background work is happening? Notification when done? How does this interact with token budgets (yte)?

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
