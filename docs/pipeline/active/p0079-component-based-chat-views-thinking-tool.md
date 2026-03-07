---
id: p0079
slug: component-based-chat-views-thinking-tool
title: "Component-based chat views — thinking, tools, text as separate renderers"
phase: 1-design
gate: pending
priority: 2
source-bead: jake-an7
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Component-based chat views — thinking, tools, text as separate renderers

## Brief
> Migrated from bead jake-an7 (feature, priority 2). Stub — needs design before implementation.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **STUB** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to research and develop this stub.

## Stub
DISCUSSION STARTING POINT — not a final task. Discuss with user before promoting to real work. Render different message content types (thinking blocks, tool_use blocks, text responses) as separate SwiftUI components within the chat view. Distinct from tile layout (coj) which is about window-level arrangement — this is about rendering within a single chat. Sources: reader_2026-02-05 Section 9 UI Concepts (component-based chat views TBD), MessageType enum already exists in codebase. Key questions: What does each content block type look like visually? Collapsible thinking blocks? Tool use as inline cards? How does this interact with streaming (7g6)? Does the existing MessageType enum cover all needed cases?

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
