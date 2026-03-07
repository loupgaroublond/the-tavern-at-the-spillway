---
id: p0033
slug: icloud-personal-state-storage-sync-prefe
title: "iCloud personal state storage — sync preferences across machines"
phase: 1-design
gate: pending
priority: 4
source-bead: jake-5ft
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# iCloud personal state storage — sync preferences across machines

## Brief
> Migrated from bead jake-5ft (feature, priority 4). Stub — needs design before implementation.

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

Personal state (session IDs, window positions, persisted agent list) currently in UserDefaults. Could sync via iCloud for cross-machine continuity.

Sources: project-status.md Document-Based Architecture Remaining, reader section 7 (Session Storage Layers - layer 3).

Key questions: What state is worth syncing? iCloud KV store vs CloudKit? Conflict resolution? Does this conflict with the known iCloud corruption issue with Xcode projects?

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
