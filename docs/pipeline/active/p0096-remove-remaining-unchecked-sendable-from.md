---
id: p0096
slug: remove-remaining-unchecked-sendable-from
title: "Remove remaining @unchecked Sendable from codebase"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-0m1n
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Remove remaining @unchecked Sendable from codebase

## Brief
> Migrated from bead jake-0m1n (task, priority 2). Stub — needs design before implementation.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **STUB** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to research and develop this stub.

## Stub
19 @unchecked Sendable uses remain after UDD consolidation. Categories:
- Servitor layer (Jake, Mortal, MortalSpawner, ServitorRegistry): protect mutable state with DispatchQueues. These are the hardest — evaluate whether they should become @MainActor or actors.
- Session layer (ClodSession, ClodSessionManager): mutable state + Task captures. Evaluate actor conversion.
- Commitment layer (CommitmentList, CommitmentVerifier, ShellAssertionRunner): DispatchQueue-protected mutable state.
- Permission layer (PermissionManager, PermissionStore): DispatchQueue-protected mutable state.
- Naming (NameGenerator): DispatchQueue-protected indices.
- Testing (MockServitor, MockMessenger, MockAssertionRunner, LiveMessenger's UnsafeSendableBox): test doubles with mutable state.

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
