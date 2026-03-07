---
id: p0051
slug: session-classification-automation-design
title: "Session classification automation — design vs transcription vs implementation"
phase: 1-design
gate: pending
priority: 3
source-bead: jake-l6g
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Session classification automation — design vs transcription vs implementation

## Brief
> Migrated from bead jake-l6g (task, priority 3). Stub — needs design before implementation.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **STUB** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to research and develop this stub.

## Stub
DISCUSSION STARTING POINT — not a final task. Discuss with user before promoting to real work. Create decision logic to automatically classify Claude sessions into categories: (a) design sessions with [U]/[C]/[T] exchanges that need transcripts, (b) transcription/meta sessions doing process work, (c) implementation sessions where commits suffice. Could use message frequency analysis, keyword detection, or other heuristics. Sources: transcript_2026-02-02 (Part 3, Transcription vs Design Sessions). Key questions: Is this a standalone tool or part of the audit system? What accuracy is acceptable? ML-based or heuristic? Does this feed into the formal spec pipeline? How does it handle sessions that span multiple categories?

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
