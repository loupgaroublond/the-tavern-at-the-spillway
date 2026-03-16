---
id: p0104
slug: servitor-tree-hierarchy
title: "Servitor tree hierarchy: parent-child relationships and capability delegation"
phase: design
gate: pending
priority: 1
source-bead: null
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-08
updated: 2026-03-08
assigned-agent: null
merges: [p0091, p0092]
---

# Servitor Tree Hierarchy: Parent-Child Relationships and Capability Delegation

## Brief
> Merged from p0091 (Servitor Trees / REQ-TRE) and p0092 (Capability Delegation / REQ-CAP). Consolidates parent-child tree structure and capability delegation into a single design pipeline.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **Pending** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to develop unified design covering both servitor trees and capability delegation.

## Merge History

**p0091 — Module 020: Servitor Trees (REQ-TRE)** (source bead: jake-ud7m)
- 6 reqs, 0% coverage, all must-have
- Parent-child tree structure, Erlang-style failure boundaries, gang termination, token budget inheritance
- Depends on module 019 (states) and module 021 (capabilities)
- Major structural addition to ServitorRegistry/MortalSpawner
- Status at merge: STUB, no design work done

**p0092 — Module 021: Capability Delegation (REQ-CAP)** (source bead: jake-llxb)
- **WARNING: p0092 was burned for contradicting requirements.** Any design content from p0092 must be critically evaluated against the PRD and p0068 (capability delegation PRD backfill), which is the authority on capability delegation requirements.
- 6 reqs, 0% coverage, all must-have
- Async summon with handle, separate delegate command, delegation chains, shell enforcement, agents cannot modify own capabilities
- Described as "foundation for module 020"
- Status at merge: STUB, no design work done

## Scope

### From REQ-TRE (Servitor Trees)
- Parent-child tree structure for servitors
- Erlang-style failure boundaries (supervisor trees)
- Gang termination (parent dies, children die)
- Token budget inheritance through the tree

### From REQ-CAP (Capability Delegation) — requires critical review
- Async summon with handle return
- Separate `delegate` command (distinct from summon)
- Delegation chains (A delegates to B, B delegates to C)
- Shell-level enforcement of capabilities
- Agents cannot modify their own capabilities

**Authority note:** For capability delegation requirements, defer to the PRD and p0068 (capability delegation PRD backfill), not to the original p0092 stub content. p0092 was burned because its framing contradicted requirements.

## Design Log

## Design Statements

## Work Breakdown Plan

## Verification Results

## Agent Context
### Relevant Specs
- §020 Servitor Trees (REQ-TRE) — 6 requirements
- §021 Capability Delegation (REQ-CAP) — 6 requirements
- p0068 — Capability delegation PRD backfill (authority on cap-del requirements)

### Relevant ADRs

### Key Code
- `Sources/TavernCore/Servitors/MortalSpawner.swift` — current spawning logic
- `Sources/TavernCore/Servitors/Mortal.swift` — mortal servitor implementation
- `Sources/TavernCore/Servitors/Jake.swift` — proprietor (top of current hierarchy)

### Distilled Instructions

## Child Beads

## Generated Stubs
