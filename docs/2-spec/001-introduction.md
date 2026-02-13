# 001 — Introduction

**Status:** complete
**Last Updated:** 2026-02-12

## Purpose

This document defines the conventions used throughout the Tavern specification suite. It is the canonical reference for document numbering, cross-reference syntax, and addressing rules.

## How to Read the Spec

The specification is organized as 18 numbered modules (000–017). Each module covers a single domain. Modules depend only on lower-numbered modules — invariants and architecture come first, scoping comes last.

Start with §2 (Invariants) and §3 (System Architecture) for the foundational rules, then read domain modules in any order. §0 (Index) provides a traceability matrix mapping every PRD section to its spec module(s).

## Document Numbering Convention

Every spec file is prefixed with a three-digit number for lexical sorting:

```
000-index.md
001-introduction.md
002-invariants.md
...
017-v1-scope.md
```

Numbers are permanent. Removed content retires its number — never reassigned. This is the **append-only rule**.

## Cross-Reference Syntax

The `§` prefix distinguishes spec references from other numbering.

**Format:** `§DOC.SECTION.SUBSECTION`

| Example | Meaning |
|---------|---------|
| `§4` | Document 004 (Agents) |
| `§4.2` | Document 004, Section 2 (Requirements) |
| `§4.2.5` | Document 004, Section 2, Requirement 5 (REQ-AGT-005) |
| `§0` | Document 000 (Index) |

**Rules:**

- Leading zeros are dropped in references for readability (`§4`, not `§004`)
- Section numbers match existing `## N.` headings within each document
- Subsection numbers match requirement order (REQ-AGT-001 = §4.2.1, REQ-AGT-005 = §4.2.5)
- The `§` prefix is required — bare numbers like `4.2.5` are ambiguous

## Sub-File Splitting

If a document outgrows a single file, it becomes a directory. Addresses stay the same:

```
004-agents/
  _index.md
  004.2-requirements.md
  004.3-state-machines.md
```

The `_index.md` file replaces the original single file. All `§4.X.Y` references continue to resolve.

## Document Assignment

| Doc # | File | Module | Req Prefix |
|-------|------|--------|------------|
| 000 | `000-index.md` | Traceability matrix | — |
| 001 | `001-introduction.md` | Conventions, addressing, how to read the spec | — |
| 002 | `002-invariants.md` | Hard-enforced invariants | REQ-INV |
| 003 | `003-system-architecture.md` | Tech stack, layers, ownership, concurrency | REQ-ARCH |
| 004 | `004-agents.md` | Agent types, states, orchestration model | REQ-AGT |
| 005 | `005-spawning.md` | Spawn config, naming, work queues | REQ-SPN |
| 006 | `006-lifecycle.md` | Fish-or-cut-bait, token budgets, rewind/branch | REQ-LCM |
| 007 | `007-operating-modes.md` | Perseverance vs chat, attention model | REQ-OPM |
| 008 | `008-deterministic-shell.md` | Prompts, tools, commitments, MCP interface | REQ-DET |
| 009 | `009-communication.md` | Bubbling, lateral comms, question triage | REQ-COM |
| 010 | `010-doc-store.md` | Filesystem identity, storage layers, sessions | REQ-DOC |
| 011 | `011-sandbox.md` | Sandbox primitives, changesets, isolation | REQ-SBX |
| 012 | `012-workflows.md` | State machines, templates, merge queue | REQ-WRK |
| 013 | `013-user-experience.md` | Core loop, UI principles, progressive unlock | REQ-UX |
| 014 | `014-view-architecture.md` | View composition, layout, context cards | REQ-VIW |
| 015 | `015-observability.md` | Metrics, logging, violation monitoring | REQ-OBS |
| 016 | `016-quality.md` | Testing grades, standards, performance | REQ-QA |
| 017 | `017-v1-scope.md` | V1 boundaries, success criteria, deferrals | REQ-V1 |

**Ordering rationale:** Rules → Architecture → Agents (creation → lifecycle → operation → control → communication) → Infrastructure (storage → safety → workflows) → Presentation (UX → views) → Operations (monitoring → testing) → Scoping.
