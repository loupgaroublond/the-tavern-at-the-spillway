---
id: p0043
slug: sidecar-pattern-separate-i-o-actors-per-
title: "Sidecar pattern — separate I/O actors per agent"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-vfx
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Sidecar pattern — separate I/O actors per agent

## Brief
> Migrated from bead jake-vfx (feature, priority 2). Stub — needs design before implementation.

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

Each agent needs two actor components: main actor (tree structure, never blocks) and sidecar actor (slow Anthropic I/O). Prevents thread pool starvation with concurrent agents. Global semaphore limits concurrent API calls (~10).

Sources: reader section 9 (Sidecar Pattern), ADR-001 shape L (Sidecar), transcript_2026-01-24-shape-selection, Architecture Principles in CLAUDE.md (Concurrency Rules).

Key questions: How does the sidecar actor relate to Swift concurrency (actors)? What is the semaphore implementation? How does cancellation work across main/sidecar? Is the sidecar per-agent or shared?

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
