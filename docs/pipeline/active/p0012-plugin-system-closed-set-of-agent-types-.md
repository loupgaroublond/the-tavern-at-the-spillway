---
id: p0012
slug: plugin-system-closed-set-of-agent-types-
title: "Plugin system — closed set of agent types and spawners"
phase: 1-design
gate: pending
priority: 3
source-bead: jake-15i
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Plugin system — closed set of agent types and spawners

## Brief
> Migrated from bead jake-15i (feature, priority 3). Stub — needs design before implementation.

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

Plugins registered at startup, not dynamically loaded. All agent types known at compile time. This provides security, simplicity, and type safety. Need a registration mechanism for agent types and their spawners.

Sources: ADR-001 shape I (Plugin), reader section 5 Architecture Notes, CLAUDE.md Architecture Principles (Closed Plugin Set), project-status.md Architecture Remaining.

Key questions: What agent types exist beyond Jake and MortalAgent? How does registration work? Is this a protocol + registry pattern? How do Gang of Experts fit in?

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
