---
id: p0039
slug: sandbox-and-changeset-system-overlay-fil
title: "Sandbox and changeset system — overlay filesystem, isolation, platforms"
phase: 1-design
gate: pending
priority: 3
source-bead: jake-igh
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Sandbox and changeset system — overlay filesystem, isolation, platforms

## Brief
> Migrated from bead jake-igh (feature, priority 3). Stub — needs design before implementation.

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

Five sandbox primitives: Changeset (overlay filesystem), Platform (Mac/container/cloud), Isolation (VM/container/OS sandbox), Outputs (network control), Software (OS choice). Source control is orthogonal to isolation. Changesets work across multiple repos.

Sources: reader section 6 (Sandbox and Isolation), PRD section 4.6, reader ?8 (partially resolved), project-status.md Sandbox and Changesets (nothing implemented yet).

Key questions: Which primitive to implement first? How does overlay filesystem work on macOS (APFS snapshots? FUSE?)? Changeset review workflow? How do changesets compose across agents?

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
