---
id: p0030
slug: preflight-checks-spawn-time-verification
title: "Preflight checks — spawn-time verification before agents start"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-wdk
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Preflight checks — spawn-time verification before agents start

## Brief
> Migrated from bead jake-wdk (feature, priority 2). Stub — needs design before implementation.

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

Every agent gets spawn-time verification: sandbox configured, access to required resources, no permissions prompts expected, external accounts authenticated. Failure = agent does not start, parent notified with reason. No degraded mode — pass/fail.

Sources: reader section 6 (Preflight Checks), PRD section 6.4 (Preflight Checks).

Key questions: What checks are needed for v1 (no sandbox yet)? How are required resources specified? What does a failed preflight look like in the UI? Retry mechanism?

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
