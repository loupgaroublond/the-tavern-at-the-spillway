---
id: p0021
slug: hierarchical-agent-trees-agents-spawning
title: "Hierarchical agent trees — agents spawning children"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-thv
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Hierarchical agent trees — agents spawning children

## Brief
> Migrated from bead jake-thv (feature, priority 2). Stub — needs design before implementation.

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

Currently agents are flat (Jake spawns mortal agents). Design calls for Erlang-style arbitrary depth trees: mortal agents spawning children, children spawning grandchildren, etc. Tree management is synchronous within each actor.

Sources: reader section 3 (Mortal Agents, task modes), reader section 5 (Agent Hierarchy diagram), PRD section 4.1 (Agent Types), transcript_2026-01-21-2345 (Erlang-style depth), transcript_2026-01-25-0108 (Component Ownership Chain).

Key questions: What does child agent spawning look like concretely? Same tool handler as Jake? How does tree management interact with the sidecar pattern? What about tree visualization in the UI?

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
