# Formal Specification Index

**Status:** skeleton
**Last Updated:** 2026-02-07

## Purpose

Traceability matrix mapping every PRD section to its spec module(s). Every requirement in the PRD must be covered by at least one spec module.

## PRD Coverage Matrix

| PRD Section | Title | Spec Module(s) | Status |
|-------------|-------|----------------|--------|
| §1 | Executive Summary | (context — informs all) | — |
| §2 | Invariants (Hard-Enforced) | invariants.md | skeleton |
| §3 | Problem Statement / Goals | (context — informs all) | — |
| §4.1 | Agent Types | agents.md | skeleton |
| §4.2 | Agent States | agents.md | skeleton |
| §4.3 | Task Modes | agents.md | skeleton |
| §4.4 | Operating Modes | operating-modes.md | skeleton |
| §4.5 | The Document Store | doc-store.md | skeleton |
| §4.6 | Sandbox Primitives | sandbox.md | skeleton |
| §4.7 | Deterministic Shell | deterministic-shell.md | skeleton |
| §5.1 | The Core Loop | user-experience.md | skeleton |
| §5.2 | Attention Model | operating-modes.md | skeleton |
| §5.3 | Bubbling | communication.md | skeleton |
| §5.4 | UI Principles | user-experience.md | skeleton |
| §5.5 | Question Triage | communication.md | skeleton |
| §6.1 | Tech Stack | system-architecture.md | skeleton |
| §6.2 | Agent Spawn Configuration | spawning.md | skeleton |
| §6.3 | Work Queues | spawning.md | skeleton |
| §6.4 | Preflight Checks | sandbox.md | skeleton |
| §6.5 | Merge Queue | workflows.md | skeleton |
| §6.6 | Hygiene | doc-store.md | skeleton |
| §7 | Agent Naming | spawning.md | skeleton |
| §8 | Progressive Unlocks | user-experience.md | skeleton |
| §8.1 | Concept | user-experience.md | skeleton |
| §8.2 | Open Questions | user-experience.md | skeleton |
| §9 | Metrics | observability.md | skeleton |
| §9.1 | Starter Templates | observability.md | skeleton |
| §9.2 | Meta Process | observability.md | skeleton |
| §9.3 | Discovery Sharing | observability.md | skeleton |
| §10 | Workflows | workflows.md | skeleton |
| §11 | Gang of Experts | workflows.md | skeleton |
| §12 | Fish or Cut Bait | lifecycle.md | skeleton |
| §13 | Rewind and Branch | lifecycle.md | skeleton |
| §14 | Open Items / TBD | (context — informs all) | — |
| §15 | Day 1 Questions | (context — informs all) | — |
| §16 | Violation Monitoring | observability.md | skeleton |
| §17 | Testability Requirements | quality.md | skeleton |
| §18 | V1 Scope | v1-scope.md | skeleton |
| §19 | Development Standards | quality.md | skeleton |
| §19.1 | Logging Standards | quality.md | skeleton |
| §19.2 | Testing Standards | quality.md | skeleton |
| §19.3 | Stress Testing Standards | quality.md | skeleton |
| §20 | Success Criteria | v1-scope.md | skeleton |
| §21 | Performance Requirements | quality.md | skeleton |

## Coverage Summary

- **Total PRD sections:** 40
- **Covered by spec:** 36
- **Context-only (no spec needed):** 4 (§1, §3, §14, §15)
- **Gaps:** none

## Module Status Overview

| Module | Prefix | Status | Requirements Count |
|--------|--------|--------|-------------------|
| invariants.md | REQ-INV | skeleton | 0 |
| agents.md | REQ-AGT | skeleton | 0 |
| operating-modes.md | REQ-OPM | skeleton | 0 |
| doc-store.md | REQ-DOC | skeleton | 0 |
| sandbox.md | REQ-SBX | skeleton | 0 |
| deterministic-shell.md | REQ-DET | skeleton | 0 |
| communication.md | REQ-COM | skeleton | 0 |
| spawning.md | REQ-SPN | skeleton | 0 |
| user-experience.md | REQ-UX | skeleton | 0 |
| view-architecture.md | REQ-VIW | skeleton | 0 |
| system-architecture.md | REQ-ARCH | skeleton | 0 |
| workflows.md | REQ-WRK | skeleton | 0 |
| lifecycle.md | REQ-LCM | skeleton | 0 |
| observability.md | REQ-OBS | skeleton | 0 |
| quality.md | REQ-QA | skeleton | 0 |
| v1-scope.md | REQ-V1 | skeleton | 0 |

## Verification Rules

1. Every PRD section (except context sections) must appear in at least one spec module
2. Every spec module must list its upstream PRD references
3. Requirements use the format REQ-PREFIX-NNN
4. Status progression: skeleton → partial → complete → verified
