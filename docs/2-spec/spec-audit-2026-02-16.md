# Spec Audit — PRD-to-Spec Coverage Verification

*Run: 2026-02-16*

---

## PRD Coverage

| PRD Section | Title | Spec Module | Index Status | Verified |
|-------------|-------|-------------|--------------|----------|
| §1 | Executive Summary | (context) | — | — |
| §2 | Invariants | 002-invariants.md | complete | ✓ |
| §3 | Problem Statement / Goals | (context) | — | — |
| §4.1 | Agent Types | 004-agents.md | complete | ✓ |
| §4.2 | Agent States | 004-agents.md | complete | ✓ |
| §4.3 | Task Modes | 004-agents.md | complete | ✓ |
| §4.4 | Operating Modes | 007-operating-modes.md | complete | ✓ |
| §4.5 | The Document Store | 010-doc-store.md | complete | ✓ |
| §4.6 | Sandbox Primitives | 011-sandbox.md | complete | ✓ |
| §4.7 | Deterministic Shell | 008-deterministic-shell.md | complete | ✓ |
| §5.1 | The Core Loop | 013-user-experience.md | complete | ✓ |
| §5.2 | Attention Model | 007-operating-modes.md | complete | ✓ |
| §5.3 | Bubbling | 009-communication.md | complete | ✓ |
| §5.4 | UI Principles | 013-user-experience.md | complete | ✓ |
| §5.5 | Question Triage | 009-communication.md | complete | ✓ |
| §6.1 | Tech Stack | 003-system-architecture.md | complete | ✓ |
| §6.2 | Agent Spawn Configuration | 005-spawning.md | complete | ✓ |
| §6.3 | Work Queues | 005-spawning.md | complete | ✓ |
| §6.4 | Preflight Checks | 011-sandbox.md | complete | ✓ |
| §6.5 | Merge Queue | 012-workflows.md | complete | ✓ |
| §6.6 | Hygiene | 010-doc-store.md | complete | ✓ |
| §7 | Agent Naming | 005-spawning.md | complete | ✓ |
| §8 | Progressive Unlocks | 013-user-experience.md | complete | ✓ |
| §8.1 | Concept | 013-user-experience.md | complete | ✓ |
| §8.2 | Open Questions | 013-user-experience.md | complete | ✓ |
| §9 | Metrics | 015-observability.md | complete | ✓ |
| §9.1 | Starter Templates | 012-workflows.md | complete | ✓ |
| §9.2 | Meta Process | 015-observability.md | complete | ✓ |
| §9.3 | Discovery Sharing | 015, 009 | complete | ✓ |
| §10 | Workflows | 012-workflows.md | complete | ✓ |
| §11 | Gang of Experts | 012-workflows.md | complete | ✓ |
| §12 | Fish or Cut Bait | 006-lifecycle.md | complete | ✓ |
| §13 | Rewind and Branch | 006-lifecycle.md | complete | ✓ |
| §14 | Open Items / TBD | (context) | — | — |
| §15 | Day 1 Questions | (context) | — | — |
| §16 | Violation Monitoring | 015-observability.md | complete | ✓ |
| §17 | Testability Requirements | 016-quality.md | complete | ✓ |
| §18 | V1 Scope | 017-v1-scope.md | complete | ✓ |
| §19 | Development Standards | 016-quality.md | complete | ✓ |
| §19.1 | Logging Standards | 016-quality.md | complete | ✓ |
| §19.2 | Testing Standards | 016-quality.md | complete | ✓ |
| §19.3 | Stress Testing Standards | 016-quality.md | complete | ✓ |
| §19.4 | Completeness Standards | 018-spec-fidelity.md | complete | ✓ |
| §20 | Success Criteria | 017-v1-scope.md | complete | ✓ |
| §21 | Performance Requirements | 016-quality.md | complete | ✓ |

**45 PRD sections — 41 covered by spec, 4 context-only. Zero gaps.**

---

## Spec Module Health

| Module | Prefix | Claimed | Actual | Match? | Impl'd | Tested | Cov% |
|--------|--------|---------|--------|--------|--------|--------|------|
| 002-invariants | REQ-INV | 8 | 8 | ✓ | 4 | 3 | 50% |
| 003-system-architecture | REQ-ARCH | 10 | 10 | ✓ | 8 | 3 | 80% |
| 004-agents | REQ-AGT | 10 | 10 | ✓ | 7 | 6 | 70% |
| 005-spawning | REQ-SPN | 10 | 10 | ✓ | 9 | 9 | 90% |
| 006-lifecycle | REQ-LCM | 7 | 7 | ✓ | 2 | 1 | 29% |
| 007-operating-modes | REQ-OPM | 6 | 6 | ✓ | 5 | 3 | 83% |
| 008-deterministic-shell | REQ-DET | 8 | 8 | ✓ | 7 | 2 | 88% |
| 009-communication | REQ-COM | 8 | 8 | ✓ | 1 | 1 | 13% |
| 010-doc-store | REQ-DOC | 8 | 8 | ✓ | 6 | 3 | 75% |
| 011-sandbox | REQ-SBX | 8 | 8 | ✓ | 0 | 0 | 0% |
| 012-workflows | REQ-WRK | 8 | 8 | ✓ | 0 | 0 | 0% |
| 013-user-experience | REQ-UX | 11 | 11 | ✓ | 8 | 2 | 73% |
| 014-view-architecture | REQ-VIW | 9 | 9 | ✓ | 4 | 0 | 44% |
| 015-observability | REQ-OBS | 11 | 11 | ✓ | 6 | 2 | 55% |
| 016-quality | REQ-QA | 16 | 16 | ✓ | 1 | 0 | 6% |
| 017-v1-scope | REQ-V1 | 17 | 17 | ✓ | 6 | 0 | 35% |
| 018-spec-fidelity | REQ-FID | 7 | 7 | ✓ | 0 | 0 | 0% |

**Cov% = Implemented / Actual.**

---

## Gap Analysis

### Index Discrepancies

None. All 17 modules match claimed counts exactly. ✓

### Downstream Reference Issues

- **011-sandbox:** "Not yet implemented (deferred for v1)" — correct, no directory expected
- **012-workflows:** "Not yet implemented" — correct, no directory expected
- All other claimed directories verified present ✓

### Unmapped PRD Sections

None. ✓

### Orphaned Provenance

None found. ✓

### Requirements Without Code Provenance (88 of 162)

**002-invariants (4 missing):** INV-001 (Test Suite Gate), INV-002 (Universal Testability), INV-004 (Sacred User Attention), INV-008 (Original File Protection)

**003-system-architecture (2 missing):** ARCH-001 (Tech Stack), ARCH-010 (No Sandbox Entitlement)

**004-agents (3 missing):** AGT-003 (Drone Agents), AGT-004 (Monitor Daemons), AGT-006 (Task Modes)

**005-spawning (1 missing):** SPN-008 (Work Queues)

**006-lifecycle (5 missing):** LCM-001 (Fish-or-Cut-Bait Triggers), LCM-002 (Token Budget), LCM-003 (Spin Detection), LCM-005 (Rewind), LCM-006 (Branch)

**007-operating-modes (1 missing):** OPM-006 (Cogitation Display)

**008-deterministic-shell (1 missing):** DET-007 (Continuation Loop)

**009-communication (7 missing):** COM-001 through COM-007 (all except COM-008 Jake as Hub)

**010-doc-store (2 missing):** DOC-006 (Authoritative Display), DOC-007 (Dead Agent Cleanup)

**011-sandbox (8 missing):** All — deferred for v1

**012-workflows (8 missing):** All — not yet implemented

**013-user-experience (3 missing):** UX-004 (No Unsolicited Content), UX-010/011 (Progressive Unlocks)

**014-view-architecture (5 missing):** VIW-002 (View Modes), VIW-006–009 (Layout Persistence, Suggestions, Mutations, Context Cards)

**015-observability (5 missing):** OBS-001–004 (Metrics), OBS-010 (Meta Process)

**016-quality (15 missing):** All except QA-002 (Regression Detection)

**017-v1-scope (11 missing):** V1-007 through V1-017

**018-spec-fidelity (7 missing):** All — meta-spec, no code implementation expected

### Contextual Notes

Many "missing" requirements are expected:

- **Explicitly deferred:** SBX-* (8), V1-008–015 (8), SPN-008, AGT-003/004, LCM-001–003/005/006, WRK-* (8) — ~35 reqs
- **Meta/process (no code artifact):** FID-* (7), most QA-* (process standards), INV-001/002 — ~22 reqs
- **Genuinely unimplemented features:** COM-001–007, VIW-002/006–009, OBS-001–004/010, UX-010/011 — ~20 reqs

---

## PRD Pipeline Flow (Top-to-Bottom)

### Per-PRD-Section Downstream Coverage

| PRD Section(s) | Spec Module | Reqs | Impl'd | Tested | Code% | Test% |
|----------------|-------------|------|--------|--------|-------|-------|
| §2 Invariants | 002-invariants | 8 | 4 | 3 | 50% | 38% |
| §6.1 Tech Stack | 003-system-architecture | 10 | 8 | 3 | 80% | 30% |
| §4.1–4.3 Agent Types/States/Modes | 004-agents | 10 | 7 | 6 | 70% | 60% |
| §6.2, §6.3, §7 Spawn/Queues/Naming | 005-spawning | 10 | 9 | 9 | 90% | 90% |
| §12, §13 Fish-or-Cut-Bait/Rewind | 006-lifecycle | 7 | 2 | 1 | 29% | 14% |
| §4.4, §5.2 Operating Modes/Attention | 007-operating-modes | 6 | 5 | 3 | 83% | 50% |
| §4.7 Deterministic Shell | 008-deterministic-shell | 8 | 7 | 2 | 88% | 25% |
| §5.3, §5.5 Bubbling/Question Triage | 009-communication | 8 | 1 | 1 | 13% | 13% |
| §4.5, §6.6 Doc Store/Hygiene | 010-doc-store | 8 | 6 | 3 | 75% | 38% |
| §4.6, §6.4 Sandbox/Preflight | 011-sandbox | 8 | 0 | 0 | 0% | 0% |
| §6.5, §9.1, §10, §11 Workflows/Merge/GoE | 012-workflows | 8 | 0 | 0 | 0% | 0% |
| §5.1, §5.4, §8 Core Loop/UI/Unlocks | 013-user-experience | 11 | 8 | 2 | 73% | 18% |
| *(Reader §8, transcripts)* | 014-view-architecture | 9 | 4 | 0 | 44% | 0% |
| §9, §9.2–3, §16 Metrics/Violations | 015-observability | 11 | 6 | 2 | 55% | 18% |
| §17, §19, §21 Testing/Dev Stds/Perf | 016-quality | 16 | 1 | 0 | 6% | 0% |
| §18, §20 V1 Scope/Success Criteria | 017-v1-scope | 17 | 6 | 0 | 35% | 0% |
| §19.4 Completeness Standards | 018-spec-fidelity | 7 | 0 | 0 | 0% | 0% |

### Aggregate Pipeline Flow

```
PRD  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  45 sections
       │ 100% coverage (41 active + 4 context)
       ▼
Spec ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  162 requirements across 17 modules
       │ 46% have code provenance
       ▼
Code ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  74 requirements traced to source
       │ 47% of implemented reqs have test tags
       ▼
Tests ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ~35 requirements traced to tests
```

| Layer Transition | Rate |
|-----------------|------|
| PRD → Spec | **100%** |
| Spec → Code | **46%** (74/162) |
| Spec → Tests | **22%** (~35/162) |
| Code → Tests | **47%** (~35/74) |

### Unimplemented Requirement Breakdown

| Category | Count | Examples |
|----------|-------|---------|
| **Explicitly deferred** | ~35 | SBX-* (8), WRK-* (8), V1-008–015 (8), LCM-001–003/005/006, AGT-003/004, SPN-008 |
| **Meta/process** (no code artifact) | ~22 | FID-* (7), most QA-* (15), INV-001/002 |
| **Genuinely unimplemented** | ~20 | COM-001–007, VIW-002/006–009, OBS-001–004/010, UX-010/011 |
| **Arguably provenance-able** | ~11 | ARCH-001/010, INV-004/008, OPM-006, DET-007, DOC-006/007, UX-004, V1-007/016/017 |

### Test Coverage Gaps (Weakest Areas)

Modules with high implementation but low test coverage — highest leverage for adding tests:

| Module | Code% | Test% | Gap |
|--------|-------|-------|-----|
| 008-deterministic-shell | 88% | 25% | 63pp |
| 013-user-experience | 73% | 18% | 55pp |
| 015-observability | 55% | 18% | 37pp |
| 003-system-architecture | 80% | 30% | 50pp |
| 010-doc-store | 75% | 38% | 37pp |

---

## Summary

| Metric | Value |
|--------|-------|
| PRD sections | 45 total, 41 covered, 4 context-only |
| Spec modules | 17 total, all present |
| Total requirements | 162 |
| Index accuracy | 17/17 ✓ |
| Downstream references | All verified |
| Code provenance | 74/162 (46%) |
| Test provenance | ~35/162 (~22%) |
| Deferred (no code expected) | ~35 requirements |
| Meta/process (no code artifact) | ~22 requirements |
| **Adjusted code provenance** | **74/105 active reqs (70%)** |
| Orphaned provenance | 0 |
| Unmapped PRD sections | 0 |
