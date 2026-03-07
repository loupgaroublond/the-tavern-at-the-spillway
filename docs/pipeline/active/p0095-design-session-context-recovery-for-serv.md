---
id: p0095
slug: design-session-context-recovery-for-serv
title: "Design session context recovery for servitor session transitions"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-o9a1
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Design session context recovery for servitor session transitions

## Brief
> Migrated from bead jake-o9a1 (feature, priority 2). Stub — needs design before implementation.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **STUB** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to research and develop this stub.

## Stub
STUB — When a servitor's Claude session expires and a new session must be created, the new session starts with no context. Design and implement context injection so Claude can resume where it left off.

Three candidate approaches identified during design discussion:

1. Custom compaction — Run Haiku on conversation history, produce summary, inject into new session. Show compaction output to user. Gives control over what's preserved.

2. Message replay — Use SDK to feed logged messages into new session so it has the same context window. Faithful but potentially expensive, may hit context limits.

3. Personhood card — Persistent document attached to servitor describing current state, work history, decisions. Servitor carries it across sessions like an identity. Most useful for drones/daemons.

These are not mutually exclusive — different servitor types may use different strategies. Design should consider which approach fits which servitor lifecycle (mortal vs daemon vs drone).

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
