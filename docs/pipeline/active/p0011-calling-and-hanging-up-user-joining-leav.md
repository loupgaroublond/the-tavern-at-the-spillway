---
id: p0011
slug: calling-and-hanging-up-user-joining-leav
title: "Calling and hanging up — user joining/leaving agent sessions"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-0xr
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Calling and hanging up — user joining/leaving agent sessions

## Brief
> Migrated from bead jake-0xr (feature, priority 2). Stub — needs design before implementation.

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

When user zooms into an agent, system injects a calling message. When user zooms out, agent receives hanging up message and knows not to pause for interaction. This toggles between chat mode (active conversation) and perseverance mode (background).

Sources: reader section 4 (Zooming In and Out), PRD section 5.2 (Calling and Hanging Up), reader open question ?6.

Key questions: What does the injected message look like? Is it a tool call or a text message? Does the agent acknowledge? What happens if user calls while agent is mid-response?

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
