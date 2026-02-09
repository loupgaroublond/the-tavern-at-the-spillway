# Formal Specification Index

**Status:** complete
**Last Updated:** 2026-02-08

## Purpose

Traceability matrix mapping every PRD section to its spec module(s). Every requirement in the PRD must be covered by at least one spec module.

## PRD Coverage Matrix

| PRD Section | Title | Spec Module(s) | Status |
|-------------|-------|----------------|--------|
| §1 | Executive Summary | (context -- informs all) | -- |
| §2 | Invariants (Hard-Enforced) | invariants.md | complete |
| §3 | Problem Statement / Goals | (context -- informs all) | -- |
| §4.1 | Agent Types | agents.md | complete |
| §4.2 | Agent States | agents.md | complete |
| §4.3 | Task Modes | agents.md | complete |
| §4.4 | Operating Modes | operating-modes.md | complete |
| §4.5 | The Document Store | doc-store.md | complete |
| §4.6 | Sandbox Primitives | sandbox.md | complete |
| §4.7 | Deterministic Shell | deterministic-shell.md | complete |
| §5.1 | The Core Loop | user-experience.md | complete |
| §5.2 | Attention Model | operating-modes.md | complete |
| §5.3 | Bubbling | communication.md | complete |
| §5.4 | UI Principles | user-experience.md | complete |
| §5.5 | Question Triage | communication.md | complete |
| §6.1 | Tech Stack | system-architecture.md | complete |
| §6.2 | Agent Spawn Configuration | spawning.md | complete |
| §6.3 | Work Queues | spawning.md | complete |
| §6.4 | Preflight Checks | sandbox.md | complete |
| §6.5 | Merge Queue | workflows.md | complete |
| §6.6 | Hygiene | doc-store.md | complete |
| §7 | Agent Naming | spawning.md | complete |
| §8 | Progressive Unlocks | user-experience.md | complete |
| §8.1 | Concept | user-experience.md | complete |
| §8.2 | Open Questions | user-experience.md | complete |
| §9 | Metrics | observability.md | complete |
| §9.1 | Starter Templates | workflows.md | complete |
| §9.2 | Meta Process | observability.md | complete |
| §9.3 | Discovery Sharing | observability.md, communication.md | complete |
| §10 | Workflows | workflows.md | complete |
| §11 | Gang of Experts | workflows.md | complete |
| §12 | Fish or Cut Bait | lifecycle.md | complete |
| §13 | Rewind and Branch | lifecycle.md | complete |
| §14 | Open Items / TBD | (context -- informs all) | -- |
| §15 | Day 1 Questions | (context -- informs all) | -- |
| §16 | Violation Monitoring | observability.md | complete |
| §17 | Testability Requirements | quality.md | complete |
| §18 | V1 Scope | v1-scope.md | complete |
| §19 | Development Standards | quality.md | complete |
| §19.1 | Logging Standards | quality.md | complete |
| §19.2 | Testing Standards | quality.md | complete |
| §19.3 | Stress Testing Standards | quality.md | complete |
| §20 | Success Criteria | v1-scope.md | complete |
| §21 | Performance Requirements | quality.md | complete |

## Coverage Summary

- **Total PRD sections:** 44
- **Covered by spec:** 40
- **Context-only (no spec needed):** 4 (§1, §3, §14, §15)
- **Gaps:** none

## Module Status Overview

| Module | Prefix | Status | Requirements Count |
|--------|--------|--------|-------------------|
| invariants.md | REQ-INV | complete | 8 |
| agents.md | REQ-AGT | complete | 10 |
| operating-modes.md | REQ-OPM | complete | 6 |
| doc-store.md | REQ-DOC | complete | 8 |
| deterministic-shell.md | REQ-DET | complete | 8 |
| communication.md | REQ-COM | complete | 8 |
| spawning.md | REQ-SPN | complete | 10 |
| user-experience.md | REQ-UX | complete | 11 |
| observability.md | REQ-OBS | complete | 11 |
| quality.md | REQ-QA | complete | 16 |
| v1-scope.md | REQ-V1 | complete | 17 |
| system-architecture.md | REQ-ARCH | complete | 10 |
| lifecycle.md | REQ-LCM | complete | 7 |
| workflows.md | REQ-WRK | complete | 8 |
| view-architecture.md | REQ-VIW | complete | 9 |
| sandbox.md | REQ-SBX | complete | 8 |

**Total requirements:** 155

## Verification Rules

1. Every PRD section (except context sections) must appear in at least one spec module
2. Every spec module must list its upstream PRD references
3. Requirements use the format REQ-PREFIX-NNN
4. Status progression: skeleton -> partial -> complete -> verified
