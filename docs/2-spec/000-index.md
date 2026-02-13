# 000 — Formal Specification Index

**Status:** complete
**Last Updated:** 2026-02-08

## Purpose

Traceability matrix mapping every PRD section to its spec module(s). Every requirement in the PRD must be covered by at least one spec module.

## PRD Coverage Matrix

| PRD Section | Title | Doc # | Spec Module(s) | Status |
|-------------|-------|-------|----------------|--------|
| §1 | Executive Summary | — | (context — informs all) | — |
| §2 | Invariants (Hard-Enforced) | 002 | 002-invariants.md | complete |
| §3 | Problem Statement / Goals | — | (context — informs all) | — |
| §4.1 | Agent Types | 004 | 004-agents.md | complete |
| §4.2 | Agent States | 004 | 004-agents.md | complete |
| §4.3 | Task Modes | 004 | 004-agents.md | complete |
| §4.4 | Operating Modes | 007 | 007-operating-modes.md | complete |
| §4.5 | The Document Store | 010 | 010-doc-store.md | complete |
| §4.6 | Sandbox Primitives | 011 | 011-sandbox.md | complete |
| §4.7 | Deterministic Shell | 008 | 008-deterministic-shell.md | complete |
| §5.1 | The Core Loop | 013 | 013-user-experience.md | complete |
| §5.2 | Attention Model | 007 | 007-operating-modes.md | complete |
| §5.3 | Bubbling | 009 | 009-communication.md | complete |
| §5.4 | UI Principles | 013 | 013-user-experience.md | complete |
| §5.5 | Question Triage | 009 | 009-communication.md | complete |
| §6.1 | Tech Stack | 003 | 003-system-architecture.md | complete |
| §6.2 | Agent Spawn Configuration | 005 | 005-spawning.md | complete |
| §6.3 | Work Queues | 005 | 005-spawning.md | complete |
| §6.4 | Preflight Checks | 011 | 011-sandbox.md | complete |
| §6.5 | Merge Queue | 012 | 012-workflows.md | complete |
| §6.6 | Hygiene | 010 | 010-doc-store.md | complete |
| §7 | Agent Naming | 005 | 005-spawning.md | complete |
| §8 | Progressive Unlocks | 013 | 013-user-experience.md | complete |
| §8.1 | Concept | 013 | 013-user-experience.md | complete |
| §8.2 | Open Questions | 013 | 013-user-experience.md | complete |
| §9 | Metrics | 015 | 015-observability.md | complete |
| §9.1 | Starter Templates | 012 | 012-workflows.md | complete |
| §9.2 | Meta Process | 015 | 015-observability.md | complete |
| §9.3 | Discovery Sharing | 015, 009 | 015-observability.md, 009-communication.md | complete |
| §10 | Workflows | 012 | 012-workflows.md | complete |
| §11 | Gang of Experts | 012 | 012-workflows.md | complete |
| §12 | Fish or Cut Bait | 006 | 006-lifecycle.md | complete |
| §13 | Rewind and Branch | 006 | 006-lifecycle.md | complete |
| §14 | Open Items / TBD | — | (context — informs all) | — |
| §15 | Day 1 Questions | — | (context — informs all) | — |
| §16 | Violation Monitoring | 015 | 015-observability.md | complete |
| §17 | Testability Requirements | 016 | 016-quality.md | complete |
| §18 | V1 Scope | 017 | 017-v1-scope.md | complete |
| §19 | Development Standards | 016 | 016-quality.md | complete |
| §19.1 | Logging Standards | 016 | 016-quality.md | complete |
| §19.2 | Testing Standards | 016 | 016-quality.md | complete |
| §19.3 | Stress Testing Standards | 016 | 016-quality.md | complete |
| §20 | Success Criteria | 017 | 017-v1-scope.md | complete |
| §21 | Performance Requirements | 016 | 016-quality.md | complete |

## Coverage Summary

- **Total PRD sections:** 44
- **Covered by spec:** 40
- **Context-only (no spec needed):** 4 (§1, §3, §14, §15)
- **Gaps:** none

## Module Status Overview

| Doc # | Module | Prefix | Status | Requirements Count |
|-------|--------|--------|--------|-------------------|
| 002 | 002-invariants.md | REQ-INV | complete | 8 |
| 003 | 003-system-architecture.md | REQ-ARCH | complete | 10 |
| 004 | 004-agents.md | REQ-AGT | complete | 10 |
| 005 | 005-spawning.md | REQ-SPN | complete | 10 |
| 006 | 006-lifecycle.md | REQ-LCM | complete | 7 |
| 007 | 007-operating-modes.md | REQ-OPM | complete | 6 |
| 008 | 008-deterministic-shell.md | REQ-DET | complete | 8 |
| 009 | 009-communication.md | REQ-COM | complete | 8 |
| 010 | 010-doc-store.md | REQ-DOC | complete | 8 |
| 011 | 011-sandbox.md | REQ-SBX | complete | 8 |
| 012 | 012-workflows.md | REQ-WRK | complete | 8 |
| 013 | 013-user-experience.md | REQ-UX | complete | 11 |
| 014 | 014-view-architecture.md | REQ-VIW | complete | 9 |
| 015 | 015-observability.md | REQ-OBS | complete | 11 |
| 016 | 016-quality.md | REQ-QA | complete | 16 |
| 017 | 017-v1-scope.md | REQ-V1 | complete | 17 |

**Total requirements:** 155

## Verification Rules

1. Every PRD section (except context sections) must appear in at least one spec module
2. Every spec module must list its upstream PRD references
3. Requirements use the format REQ-PREFIX-NNN
4. Status progression: skeleton -> partial -> complete -> verified
