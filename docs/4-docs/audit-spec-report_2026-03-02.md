# PRD-to-Spec Audit Report

**Generated:** 2026-03-02
**PRD Version:** 1.2 (2026-01-21)
**Index Version:** 2026-02-16
**Provenance Report:** spec-status-report_2026-03-02.md


---


## 1. PRD Coverage

Every PRD section mapped to its spec module(s), per the 000-index.md coverage matrix.

| PRD Section | Title | Spec Module | Status |
|-------------|-------|-------------|--------|
| §1 | Executive Summary | (context) | -- |
| §2 | Invariants (Hard-Enforced) | 002-invariants | complete |
| §3 | Problem Statement / Goals | (context) | -- |
| §4.1 | Agent Types | 004-agents | complete |
| §4.2 | Agent States | 004-agents | complete |
| §4.3 | Task Modes | 004-agents | complete |
| §4.4 | Operating Modes | 007-operating-modes | complete |
| §4.5 | The Document Store | 010-doc-store | complete |
| §4.6 | Sandbox Primitives | 011-sandbox | complete |
| §4.7 | Deterministic Shell | 008-deterministic-shell | complete |
| §5.1 | The Core Loop | 013-user-experience | complete |
| §5.2 | Attention Model | 007-operating-modes | complete |
| §5.3 | Bubbling | 009-communication | complete |
| §5.4 | UI Principles | 013-user-experience | complete |
| §5.5 | Question Triage | 009-communication | complete |
| §6.1 | Tech Stack | 003-system-architecture | complete |
| §6.2 | Agent Spawn Configuration | 005-spawning | complete |
| §6.3 | Work Queues | 005-spawning | complete |
| §6.4 | Preflight Checks | 011-sandbox | complete |
| §6.5 | Merge Queue | 012-workflows | complete |
| §6.6 | Hygiene | 010-doc-store | complete |
| §7 | Agent Naming | 005-spawning | complete |
| §8 | Progressive Unlocks | 013-user-experience | complete |
| §8.1 | Concept | 013-user-experience | complete |
| §8.2 | Open Questions | 013-user-experience | complete |
| §9 | Metrics | 015-observability | complete |
| §9.1 | Starter Templates | 012-workflows | complete |
| §9.2 | Meta Process | 015-observability | complete |
| §9.3 | Discovery Sharing | 015-observability, 009-communication | complete |
| §10 | Workflows | 012-workflows | complete |
| §11 | Gang of Experts | 012-workflows | complete |
| §12 | Fish or Cut Bait | 006-lifecycle | complete |
| §13 | Rewind and Branch | 006-lifecycle | complete |
| §14 | Open Items / TBD | (context) | -- |
| §15 | Day 1 Questions | (context) | -- |
| §16 | Violation Monitoring | 015-observability | complete |
| §17 | Testability Requirements | 016-quality | complete |
| §18 | V1 Scope | 017-v1-scope | complete |
| §19 | Development Standards | 016-quality | complete |
| §19.1 | Logging Standards | 016-quality | complete |
| §19.2 | Testing Standards | 016-quality | complete |
| §19.3 | Stress Testing Standards | 016-quality | complete |
| §19.4 | Completeness and Correctness | 018-spec-fidelity | complete |
| §20 | Success Criteria | 017-v1-scope | complete |
| §21 | Performance Requirements | 016-quality | complete |

**Totals:** 45 PRD sections. 41 covered by spec. 4 context-only (§1, §3, §14, §15). 0 gaps.


---


## 2. Spec Module Health

Compares index-claimed requirement counts against actual counts in each spec file.

| Module | Prefix | Index Claims | Actual Active | Actual Dropped | Total Headings | Impl% | Test% | Match? |
|--------|--------|-------------|---------------|----------------|----------------|-------|-------|--------|
| 002-invariants | REQ-INV | 9 | 9 | 0 | 9 | 44% | 33% | YES |
| 003-system-architecture | REQ-ARCH | 10 | 9 | 1 | 10 | 78% | 33% | YES |
| 004-agents | REQ-AGT | 10 | 10 | 0 | 10 | 70% | 70% | YES |
| 005-spawning | REQ-SPN | 10 | 10 | 0 | 10 | 90% | 90% | YES |
| 006-lifecycle | REQ-LCM | 7 | 7 | 0 | 7 | 29% | 14% | YES |
| 007-operating-modes | REQ-OPM | 6 | 6 | 0 | 6 | 83% | 33% | YES |
| 008-deterministic-shell | REQ-DET | 8 | 6 | 2 | 8 | 100% | 33% | YES |
| 009-communication | REQ-COM | 8 | 8 | 0 | 8 | 13% | 13% | YES |
| 010-doc-store | REQ-DOC | 8 | 5 | 3 | 8 | 60% | 60% | YES |
| 011-sandbox | REQ-SBX | 8 | 8 | 0 | 8 | 0% | 0% | YES |
| 012-workflows | REQ-WRK | 8 | 7 | 3 | 10 | 0% | 0% | NO |
| 013-user-experience | REQ-UX | 11 | 11 | 1 | 12 | 73% | 9% | YES |
| 014-view-architecture | REQ-VIW | 11 | 11 | 0 | 11 | 36% | 0% | YES |
| 015-observability | REQ-OBS | 9 | 9 | 2 | 11 | 56% | 22% | YES |
| 016-quality | REQ-QA | 17 | 17 | 1 | 18 | 53% | 35% | YES |
| 017-v1-scope | REQ-V1 | 17 | 17 | 0 | 17 | 47% | 41% | YES |
| 018-spec-fidelity | REQ-FID | 7 | 7 | 0 | 7 | 43% | 43% | YES |
| 019-states-modes | REQ-STM | 7 | 7 | 0 | 7 | 0% | 0% | YES |
| 020-servitor-trees | REQ-TRE | 6 | 6 | 0 | 6 | 0% | 0% | YES |
| 021-capability-delegation | REQ-CAP | 6 | 6 | 0 | 6 | 0% | 0% | YES |
| 022-chat-discussions | REQ-CDS | 5 | 5 | 0 | 5 | 0% | 0% | YES |

**Impl%** = (implemented + tested) / active. **Test%** = tested / active. Both from spec-status-report_2026-03-02.md.


---


## 3. Gap Analysis


### 3.1 Critical Gaps

No unmapped PRD sections. All 41 substantive PRD sections have at least one spec module.


### 3.2 Index Discrepancies

- **Module 012 (Workflows):** Index claims 8 requirements. File has 10 total headings (7 active + 3 dropped). Two requirements (REQ-WRK-009 Workflow Engine, REQ-WRK-010 Workflow Recovery) were added after the index was last updated. Index should read 10 total (7 active + 3 dropped).


### 3.3 Downstream Reference Issues

Several spec modules reference directories or filenames that are stale:

- **Modules 004, 006, 007, 019, 020, 021** reference `Tavern/Sources/TavernCore/Agents/` for files like `Jake.swift`, `Servitor.swift`, `ServitorSpawner.swift`. The actual location is `Tavern/Sources/TavernCore/Servitors/`. The `Agents/` directory exists but is **empty**.

- **Modules 004, 005** reference `ServitorSpawner.swift`. The actual filename is `MortalSpawner.swift`.

- **Module 019** references `Servitor.swift, Jake.swift` in `Agents/`. These files live in `Servitors/`.

- **Module 020** references `ServitorSpawner.swift` in `Agents/`. Actual file: `Servitors/MortalSpawner.swift`.

- **Module 021** references `Agents/` and `MCP/`. `MCP/` is correct. `Agents/` should be `Servitors/`.

All code and test directories physically exist. No missing directories. The issues are exclusively stale path references in the spec downstream sections.


### 3.4 Unmapped PRD Sections

None. Four sections (§1, §3, §14, §15) are correctly marked as context-only.


### 3.5 Orphaned Provenance

From spec-status-report_2026-03-02.md, the following dropped requirements still have code/test provenance markers in the codebase:

- **REQ-ARCH-006** (Closed Plugin Set) -- code: MortalSpawner.swift, test: ServitorRegistryTests.swift

- **REQ-DET-006** (Jake's Tool Handler Protocol) -- code: TavernMCPServer.swift

- **REQ-DOC-004** (Three Storage Layers) -- code: ClaudeNativeSessionStorage.swift, SessionStore.swift

- **REQ-DOC-005** (Session Lifecycle) -- code: ClaudeNativeSessionStorage.swift, Jake.swift

- **REQ-DOC-008** (Path Encoding) -- code: SessionStore.swift

- **REQ-OBS-007** (Logging Categories) -- code: TavernLogger.swift

These provenance markers should be updated to reference the active requirements that superseded them, or removed if the code itself should be refactored.


---


## 4. PRD Pipeline Flow


### 4.1 Per-PRD-Section Pipeline

Each PRD section traced through spec to implementation status. Status derived from the spec-status-report provenance data.

| PRD Section | Title | Spec Module | Active Reqs | Specified | Implemented | Tested |
|-------------|-------|-------------|-------------|-----------|-------------|--------|
| §2 | Invariants | 002 | 9 | 5 | 1 | 3 |
| §4.1-4.3 | Agent Types/States/Modes | 004 | 10 | 3 | 0 | 7 |
| §4.4, §5.2 | Operating Modes, Attention | 007 | 6 | 1 | 3 | 2 |
| §4.5, §6.6 | Doc Store, Hygiene | 010 | 5 | 2 | 0 | 3 |
| §4.6, §6.4 | Sandbox, Preflight | 011 | 8 | 8 | 0 | 0 |
| §4.7 | Deterministic Shell | 008 | 6 | 0 | 4 | 2 |
| §5.1, §5.4, §8.x | UX, Unlocks | 013 | 11 | 3 | 7 | 1 |
| §5.3, §5.5 | Bubbling, Questions | 009 | 8 | 7 | 0 | 1 |
| §6.1 | Tech Stack | 003 | 9 | 2 | 4 | 3 |
| §6.2-6.3, §7 | Spawning, Queues, Naming | 005 | 10 | 1 | 0 | 9 |
| §6.5, §9.1, §10, §11 | Workflows, Templates, Experts, Merge | 012 | 7 | 7 | 0 | 0 |
| §9, §9.2-9.3, §16 | Metrics, Meta, Violations | 015 | 9 | 4 | 3 | 2 |
| §12, §13 | Fish/Cut Bait, Rewind | 006 | 7 | 5 | 1 | 1 |
| §17, §19.x, §21 | Quality, Standards, Performance | 016 | 17 | 8 | 3 | 6 |
| §18, §20 | V1 Scope, Success Criteria | 017 | 17 | 9 | 1 | 7 |
| §19.4 | Spec Fidelity | 018 | 7 | 4 | 0 | 3 |
| (derived) | View Architecture | 014 | 11 | 7 | 4 | 0 |
| (derived) | States & Modes | 019 | 7 | 7 | 0 | 0 |
| (derived) | Servitor Trees | 020 | 6 | 6 | 0 | 0 |
| (derived) | Capability Delegation | 021 | 6 | 6 | 0 | 0 |
| (derived) | Chat Discussions | 022 | 5 | 5 | 0 | 0 |


### 4.2 Aggregate Pipeline Flow

```
PRD (45 sections)
  │
  ├─ 4 context-only (no spec needed)
  │
  └─ 41 substantive sections
       │
       ▼
  Spec (21 modules, 181 active requirements, 13 dropped)
       │
       ├─ 100 specified only (55%)    ── no code yet
       │
       ├─  31 implemented (17%)       ── code exists, no tests
       │
       └─  50 tested (28%)            ── code + tests
```


### 4.3 Transition Rates

| Transition | Count | Rate |
|------------|-------|------|
| PRD section → Spec requirement | 45 → 181 (active) | 4.0 reqs per PRD section |
| Specified → Implemented or Tested | 81 / 181 | 45% |
| Implemented → Tested | 50 / 81 | 62% |
| Specified → Still specified | 100 / 181 | 55% |

**Key observation:** The spec-to-code transition is the primary bottleneck. 55% of requirements have no implementation. Of those that do have code, 62% also have tests -- a healthy ratio.


### 4.4 Unimplemented Breakdown

Modules with 0% coverage (all requirements at specified-only):

| Module | Active Reqs | Priority Mix | Notes |
|--------|-------------|-------------|-------|
| 011-sandbox | 8 | 2 must-have, 4 deferred, 2 must-have(arch) | Entire module deferred for v1 |
| 012-workflows | 7 | All deferred | Entire module deferred for v1 |
| 019-states-modes | 7 | All must-have | Canonical state machine -- blocks other work |
| 020-servitor-trees | 6 | All must-have | Tree hierarchy -- blocks multi-level orchestration |
| 021-capability-delegation | 6 | All must-have | Capability system -- blocks permission enforcement |
| 022-chat-discussions | 5 | All must-have | Session management -- blocks session resumption |

Of these, 011 and 012 are intentionally deferred. Modules 019-022 represent **24 must-have requirements** with no implementation.


### 4.5 Test Coverage Gaps

Modules with implementation but 0% test coverage:

| Module | Active | Implemented | Tested | Gap |
|--------|--------|-------------|--------|-----|
| 014-view-architecture | 11 | 4 | 0 | 4 implemented reqs with no tests |

Modules with low test-to-implementation ratio (test% < impl%/2):

| Module | Impl% | Test% | Ratio |
|--------|-------|-------|-------|
| 013-user-experience | 73% | 9% | 0.12 |
| 007-operating-modes | 83% | 33% | 0.40 |
| 015-observability | 56% | 22% | 0.39 |


---


## 5. Summary Statistics

| Metric | Value |
|--------|-------|
| **PRD sections** | 45 |
| **Covered by spec** | 41 (91%) |
| **Context-only** | 4 (9%) |
| **Unmapped PRD gaps** | 0 |
| **Spec modules** | 21 active + 3 stubs |
| **Active requirements** | 181 |
| **Dropped requirements** | 13 |
| **Specified only** | 100 (55%) |
| **Implemented (code, no tests)** | 31 (17%) |
| **Tested (code + tests)** | 50 (28%) |
| **Overall coverage** | 45% |
| **Index discrepancies** | 1 (module 012) |
| **Stale downstream refs** | 6 modules reference `Agents/` instead of `Servitors/` |
| **Orphaned provenance** | 6 dropped reqs with lingering markers |
| **Modules at 0% coverage** | 6 (2 intentionally deferred, 4 not yet started) |
| **Must-have reqs unimplemented** | ~60 |
| **Pinned design decisions** | 17 |
