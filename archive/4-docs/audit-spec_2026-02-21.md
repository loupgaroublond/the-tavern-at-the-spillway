# Spec Audit — PRD-to-Spec Coverage Verification

**Date:** 2026-02-21
**Auditor:** Claude Opus 4.6
**Scope:** Full pipeline — PRD → Spec → Code → Tests


## PRD Coverage

| PRD Section | Title | Spec Module | Index Status | Verified |
|-------------|-------|-------------|--------------|----------|
| §1 | Executive Summary | (context) | — | — |
| §2 | Invariants (Hard-Enforced) | 002-invariants | complete | ✓ |
| §3 | Problem Statement / Goals | (context) | — | — |
| §4.1 | Agent Types | 004-agents | complete | ✓ |
| §4.2 | Agent States | 004-agents | complete | ✓ |
| §4.3 | Task Modes | 004-agents | complete | ✓ |
| §4.4 | Operating Modes | 007-operating-modes | complete | ✓ |
| §4.5 | The Document Store | 010-doc-store | complete | ✓ |
| §4.6 | Sandbox Primitives | 011-sandbox | complete | ✓ |
| §4.7 | Deterministic Shell | 008-deterministic-shell | complete | ✓ |
| §5.1 | The Core Loop | 013-user-experience | complete | ✓ |
| §5.2 | Attention Model | 007-operating-modes | complete | ✓ |
| §5.3 | Bubbling | 009-communication | complete | ✓ |
| §5.4 | UI Principles | 013-user-experience | complete | ✓ |
| §5.5 | Question Triage | 009-communication | complete | ✓ |
| §6.1 | Tech Stack | 003-system-architecture | complete | ✓ |
| §6.2 | Agent Spawn Configuration | 005-spawning | complete | ✓ |
| §6.3 | Work Queues | 005-spawning | complete | ✓ |
| §6.4 | Preflight Checks | 011-sandbox | complete | ✓ |
| §6.5 | Merge Queue | 012-workflows | complete | ✓ |
| §6.6 | Hygiene | 010-doc-store | complete | ✓ |
| §7 | Agent Naming | 005-spawning | complete | ✓ |
| §8 | Progressive Unlocks | 013-user-experience | complete | ✓ |
| §8.1 | Concept | 013-user-experience | complete | ✓ |
| §8.2 | Open Questions | 013-user-experience | complete | ✓ |
| §9 | Metrics | 015-observability | complete | ✓ |
| §9.1 | Starter Templates | 012-workflows | complete | ✓ |
| §9.2 | Meta Process | 015-observability | complete | ✓ |
| §9.3 | Discovery Sharing | 015, 009 | complete | ✓ |
| §10 | Workflows | 012-workflows | complete | ✓ |
| §11 | Gang of Experts | 012-workflows | complete | ✓ |
| §12 | Fish or Cut Bait | 006-lifecycle | complete | ✓ |
| §13 | Rewind and Branch | 006-lifecycle | complete | ✓ |
| §14 | Open Items / TBD | (context) | — | — |
| §15 | Day 1 Questions | (context) | — | — |
| §16 | Violation Monitoring | 015-observability | complete | ✓ |
| §17 | Testability Requirements | 016-quality | complete | ✓ |
| §18 | V1 Scope | 017-v1-scope | complete | ✓ |
| §19 | Development Standards | 016-quality | complete | ✓ |
| §19.1 | Logging Standards | 016-quality | complete | ✓ |
| §19.2 | Testing Standards | 016-quality | complete | ✓ |
| §19.3 | Stress Testing Standards | 016-quality | complete | ✓ |
| §19.4 | Completeness Standards | 018-spec-fidelity | complete | ✓ |
| §20 | Success Criteria | 017-v1-scope | complete | ✓ |
| §21 | Performance Requirements | 016-quality | complete | ✓ |

**Result:** 41/41 covered PRD sections verified. 4 context-only sections. No gaps.


## Spec Module Health

| Module | Prefix | Claimed | Actual | Match? | Active | Impl'd | Tested | Code% | Test% |
|--------|--------|---------|--------|--------|--------|--------|--------|-------|-------|
| 002-invariants | REQ-INV | 9 | 9 | ✓ | 9 | 4 | 3 | 44% | 33% |
| 003-system-architecture | REQ-ARCH | 10 | 10 | ✓ | 9 | 7 | 2 | 78% | 22% |
| 004-agents | REQ-AGT | 10 | 10 | ✓ | 10 | 7 | 7 | 70% | 70% |
| 005-spawning | REQ-SPN | 10 | 10 | ✓ | 10 | 9 | 9 | 90% | 90% |
| 006-lifecycle | REQ-LCM | 7 | 7 | ✓ | 7 | 2 | 1 | 29% | 14% |
| 007-operating-modes | REQ-OPM | 6 | 6 | ✓ | 6 | 5 | 3 | 83% | 50% |
| 008-deterministic-shell | REQ-DET | 8 | 8 | ✓ | 6 | 6 | 2 | 100% | 33% |
| 009-communication | REQ-COM | 8 | 8 | ✓ | 8 | 1 | 1 | 13% | 13% |
| 010-doc-store | REQ-DOC | 8 | 8 | ✓ | 5 | 3 | 3 | 60% | 60% |
| 011-sandbox | REQ-SBX | 8 | 8 | ✓ | 8 | 0 | 0 | 0% | 0% |
| 012-workflows | REQ-WRK | 8 | 8 | ✓ | 5 | 0 | 0 | 0% | 0% |
| 013-user-experience | REQ-UX | 11 | 11 | ✓ | 10 | 8 | 2 | 80% | 20% |
| 014-view-architecture | REQ-VIW | 11 | 11 | ✓ | 11 | 4 | 0 | 36% | 0% |
| 015-observability | REQ-OBS | 9 | 11 | ✗ (+2) | 9 | 5 | 2 | 56% | 22% |
| 016-quality | REQ-QA | 17 | 18 | ✗ (+1) | 17 | 1 | 0 | 6% | 0% |
| 017-v1-scope | REQ-V1 | 17 | 17 | ✓ | 17 | 6 | 0 | 35% | 0% |
| 018-spec-fidelity | REQ-FID | 7 | 7 | ✓ | 7 | 0 | 0 | 0% | 0% |
| 019-states-modes | REQ-STM | 7 | 7 | ✓ | 7 | 0 | 0 | 0% | 0% |
| 020-servitor-trees | REQ-TRE | 6 | 6 | ✓ | 6 | 0 | 0 | 0% | 0% |
| 021-capability-delegation | REQ-CAP | 6 | 6 | ✓ | 6 | 0 | 0 | 0% | 0% |
| 022-chat-discussions | REQ-CDS | 5 | 5 | ✓ | 5 | 0 | 0 | 0% | 0% |
| 023-keyboard-shortcuts | REQ-KEY | 0 | 0 | ✓ | 0 | — | — | — | — |
| 024-accessibility | REQ-ACC | 0 | 0 | ✓ | 0 | — | — | — | — |
| 025-search | REQ-SRC | 0 | 0 | ✓ | 0 | — | — | — | — |


## Gap Analysis

### Index Discrepancies

- **015-observability:** Index claims 9, file has 11 (9 active + 2 dropped). Missing from count: REQ-OBS-007 (dropped), REQ-OBS-010 (dropped). Index appears to exclude dropped requirements for this module only.

- **016-quality:** Index claims 17, file has 18 (17 active + 1 dropped). Missing from count: REQ-QA-015 (dropped). Same inconsistency.

- **Index total:** Claims 188, actual total across all files is 191 (178 active + 13 dropped). Off by 3 due to the above.

### Downstream Reference Issues

- **004-agents** references `Tavern/Sources/TavernCore/Agents/` — directory is actually `Servitors/` (stale after Agent→Servitor rename)

- **005-spawning** references `ServitorSpawner.swift` — file is actually `MortalSpawner.swift` (stale after rename)

- **Sources/TavernCore/Shell/** — referenced by no module currently, but directory does not exist (not relevant)

### Orphaned Provenance (code/test markers pointing to dropped requirements)

6 dropped requirement IDs still have code provenance markers:

| Dropped REQ | File(s) | Notes |
|-------------|---------|-------|
| REQ-ARCH-006 | MortalSpawner.swift | Also has test tag in ServitorRegistryTests |
| REQ-DET-006 | TavernMCPServer.swift | Tool handler protocol — absorbed into MCP pattern |
| REQ-DOC-004 | ClaudeNativeSessionStorage.swift, SessionStore.swift | Three storage layers — code exists, req dropped |
| REQ-DOC-005 | ClaudeNativeSessionStorage.swift, Jake.swift | Session lifecycle — code exists, req dropped |
| REQ-DOC-008 | SessionStore.swift | Path encoding — code exists, req dropped |
| REQ-OBS-007 | TavernLogger.swift | Logging categories — code exists, req dropped |

These are not errors per se — the code predates the requirement drops and still implements the functionality. The provenance markers are vestigial.

### Unmapped PRD Sections

None. All non-context PRD sections are mapped to spec modules.

### Critical Gaps — Modules with 0% Code Provenance (Active Requirements Only)

| Module | Active Reqs | Status |
|--------|-------------|--------|
| 011-sandbox | 8 | **Explicitly deferred** for v1 (PRD §18) |
| 012-workflows | 5 | **Explicitly deferred** for v1 (merge queue, templates) |
| 018-spec-fidelity | 7 | **Meta/process** — describes provenance standards, not code features |
| 019-states-modes | 7 | **Arguably provenance-able** — state machine is implemented in Mortal/Jake |
| 020-servitor-trees | 6 | **Arguably provenance-able** — tree structure exists in MortalSpawner |
| 021-capability-delegation | 6 | **Partially deferred** — capability model not yet built |
| 022-chat-discussions | 5 | **Arguably provenance-able** — ChatViewModel implements this |


## PRD Pipeline Flow (Top-to-Bottom)

### Per-PRD-Section Downstream Coverage

| PRD Section(s) | Spec Module | Active Reqs | Impl'd | Tested | Code% | Test% |
|----------------|-------------|-------------|--------|--------|-------|-------|
| §2 Invariants | 002-invariants | 9 | 4 | 3 | 44% | 33% |
| §6.1 Tech Stack | 003-system-architecture | 9 | 7 | 2 | 78% | 22% |
| §4.1–4.3 Agent Types/States/Modes | 004-agents | 10 | 7 | 7 | 70% | 70% |
| §6.2–6.3, §7 Spawn/Queues/Naming | 005-spawning | 10 | 9 | 9 | 90% | 90% |
| §12–13 Fish or Cut Bait, Rewind | 006-lifecycle | 7 | 2 | 1 | 29% | 14% |
| §4.4, §5.2 Operating/Attention | 007-operating-modes | 6 | 5 | 3 | 83% | 50% |
| §4.7 Deterministic Shell | 008-deterministic-shell | 6 | 6 | 2 | 100% | 33% |
| §5.3, §5.5 Bubbling/Triage | 009-communication | 8 | 1 | 1 | 13% | 13% |
| §4.5, §6.6 Doc Store/Hygiene | 010-doc-store | 5 | 3 | 3 | 60% | 60% |
| §4.6, §6.4 Sandbox/Preflight | 011-sandbox | 8 | 0 | 0 | 0% | 0% |
| §6.5, §10–11 Workflows/Experts/Merge | 012-workflows | 5 | 0 | 0 | 0% | 0% |
| §5.1, §5.4, §8 Core Loop/UI/Unlocks | 013-user-experience | 10 | 8 | 2 | 80% | 20% |
| (derived) View Architecture | 014-view-architecture | 11 | 4 | 0 | 36% | 0% |
| §9, §16 Metrics/Violations/Logging | 015-observability | 9 | 5 | 2 | 56% | 22% |
| §17, §19, §21 Quality/Standards/Perf | 016-quality | 17 | 1 | 0 | 6% | 0% |
| §18, §20 V1 Scope/Success | 017-v1-scope | 17 | 6 | 0 | 35% | 0% |
| §19.4 Completeness Standards | 018-spec-fidelity | 7 | 0 | 0 | 0% | 0% |
| (derived) States & Modes | 019-states-modes | 7 | 0 | 0 | 0% | 0% |
| (derived) Servitor Trees | 020-servitor-trees | 6 | 0 | 0 | 0% | 0% |
| (derived) Capability Delegation | 021-capability-delegation | 6 | 0 | 0 | 0% | 0% |
| (derived) Chat Discussions | 022-chat-discussions | 5 | 0 | 0 | 0% | 0% |

### Aggregate Pipeline Flow

```
PRD  ━━━  45 sections
       │ 100% covered (41 spec'd + 4 context-only)
       ▼
Spec ━━━  178 active requirements across 21 modules (+3 stubs)
       │ 38.2% have code provenance
       ▼
Code ━━━  68 requirements traced to source files
       │ 51.5% of implemented reqs have test tags
       ▼
Tests ━━  35 requirements traced to test files
```

| Layer Transition | Rate |
|-----------------|------|
| PRD → Spec | 100% (41/41) |
| Spec → Code | 38.2% (68/178) |
| Spec → Tests | 19.7% (35/178) |
| Code → Tests | 51.5% (35/68) |

### Unimplemented Breakdown

Of the 110 active requirements without code provenance:

- **Explicitly deferred (v1):** ~13 requirements (011-sandbox: 8, 012-workflows: 5) — not expected to have code

- **Meta/process (no code artifact):** ~24 requirements (018-spec-fidelity: 7, 016-quality: 16 of 17 untouched) — describe standards and processes, not features

- **Arguably provenance-able:** ~18 requirements (019-states-modes: 7, 020-servitor-trees: 6, 022-chat-discussions: 5) — code exists but lacks provenance markers

- **Genuinely unimplemented:** ~55 requirements across remaining modules — features that need building (009-communication: 7, 006-lifecycle: 5, 014-view-architecture: 7, 017-v1-scope: 11, 021-capability-delegation: 6, plus scattered singles)

### Test Coverage Gaps (Highest Leverage for Adding Tests)

| Module | Code% | Test% | Gap | Notes |
|--------|-------|-------|-----|-------|
| 014-view-architecture | 36% | 0% | 36pp | 4 reqs implemented, 0 tested |
| 008-deterministic-shell | 100% | 33% | 67pp | Fully implemented, undertested |
| 013-user-experience | 80% | 20% | 60pp | 8 impl'd, only 2 tested |
| 003-system-architecture | 78% | 22% | 56pp | 7 impl'd, only 2 tested |
| 007-operating-modes | 83% | 50% | 33pp | 5 impl'd, 3 tested |
| 017-v1-scope | 35% | 0% | 35pp | 6 scope reqs tagged in code, 0 tested |
| 015-observability | 56% | 22% | 33pp | 5 impl'd, 2 tested |


## Summary

- **PRD sections:** 45 total, 41 covered, 4 context-only
- **Spec modules:** 24 total (21 complete, 3 stubs), all present
- **Total requirements:** 191 in files (178 active, 13 dropped)
- **Implementation coverage:** 68/178 active (38.2%)
- **Test coverage:** 35/178 active (19.7%)
- **Code→Test rate:** 35/68 implemented (51.5%)
- **Index accuracy:** 22/24 modules match claimed counts (015, 016 undercount by 2 and 1 respectively; index total 188 vs actual 191)
- **Downstream references:** 1 stale directory name (Agents/ → Servitors/), 1 stale file name (ServitorSpawner → MortalSpawner)
- **Deferred (no code expected):** ~13 requirements (sandbox + workflows)
- **Meta/process (no code artifact):** ~24 requirements (quality standards + fidelity)
- **Arguably provenance-able:** ~18 requirements (existing code, missing markers)
- **Orphaned provenance:** 6 code markers + 1 test marker pointing to dropped requirements
- **Unmapped PRD sections:** 0
