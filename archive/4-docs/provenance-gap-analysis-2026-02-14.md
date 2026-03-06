# Provenance Gap Analysis

**Generated:** 2026-02-14
**Tool:** `/spec-status`, `/audit-spec`
**Baseline:** First run — zero provenance markers in codebase

## Executive Summary

The specification pipeline is structurally complete and accurate. All 45 PRD sections map to spec modules (or are correctly marked context-only), all 17 spec modules exist with accurate requirement counts, and all referenced downstream directories are present. The gap is entirely in provenance: no `// MARK: - Provenance:` comments exist in source code, and no `.tags()` entries exist in tests.

**162 requirements specified. 0 implemented (by provenance). 0 tested (by provenance).**

This is expected — ADR-007 was just committed. Provenance markers are added incrementally as code is touched.

## Pipeline Health

| Metric | Value | Status |
|--------|-------|--------|
| PRD sections | 45 total, 41 covered, 4 context-only | Clean |
| Spec modules | 17/17 present | Clean |
| Index accuracy | 17/17 match claimed counts | Clean |
| Downstream directories | All verified | Clean |
| Orphaned provenance | None | Clean |
| Requirements | 162 total | — |
| Implemented (provenance) | 0/162 (0%) | Gap |
| Tested (provenance) | 0/162 (0%) | Gap |

## Priority Breakdown

| Priority | Count | Notes |
|----------|-------|-------|
| must-have | 98 | Core V1 functionality |
| should-have | 27 | Important but not blocking |
| deferred | 37 | Post-V1 scope |

## Recommended Backfill Prioritization

Provenance backfill should follow the incremental strategy from spec 018: add markers when touching a file. For proactive backfill, prioritize modules where working code already exists.

### Tier 1 — Highest Value (code exists, heavily tested)

These modules have working implementations and existing tests. Adding provenance markers is pure bookkeeping — no new code needed.

1. **004-agents (REQ-AGT)** — 10 requirements, 8 must-have
   - Jake.swift, Servitor.swift, ServitorSpawner.swift all exist
   - Agent protocol, state machine, done detection, two-level orchestration — all implemented
   - Tests exist in TavernCoreTests and TavernTests

2. **005-spawning (REQ-SPN)** — 10 requirements, 6 must-have
   - ServitorSpawner.swift, Naming/ directory all exist
   - Spawn configuration, user/jake spawn modes, name generation — all implemented

3. **008-deterministic-shell (REQ-DET)** — 8 requirements, 8 must-have
   - Commitments/, MCP/TavernMCPServer.swift exist
   - Commitment verification, MCP tools, tool handler — all implemented

4. **010-doc-store (REQ-DOC)** — 8 requirements, 7 must-have
   - DocStore/, Persistence/ directories exist
   - Session storage, path encoding — implemented

5. **013-user-experience (REQ-UX)** — 11 requirements, 8 must-have
   - TavernApp.swift, Views/, UI/ all exist
   - Multi-window, agent sidebar, chat, content blocks — implemented

### Tier 2 — Structural (architecture, cross-cutting)

These are architectural requirements embodied in code structure rather than specific files. Provenance markers go in the most representative files.

6. **003-system-architecture (REQ-ARCH)** — 10 requirements, 10 must-have
   - Layer structure, ownership hierarchy, concurrency model — embodied in project structure
   - Mark Package.swift, key entry points

7. **002-invariants (REQ-INV)** — 8 requirements, 8 must-have
   - Cross-cutting — mark enforcement points (test configs, error handlers)

8. **015-observability (REQ-OBS)** — 11 requirements, 8 must-have
   - TavernLogger, TavernError — exist and are used throughout

9. **016-quality (REQ-QA)** — 16 requirements, 15 must-have
   - Process requirements — mark test infrastructure files, grade system configs

### Tier 3 — Partial Implementation

10. **007-operating-modes (REQ-OPM)** — 6 requirements, 5 must-have
    - Chat mode exists, perseverance mode partially implemented

11. **006-lifecycle (REQ-LCM)** — 7 requirements, 3 must-have
    - Partial — agent lifecycle basics exist, fish-or-cut-bait not yet

12. **009-communication (REQ-COM)** — 8 requirements, 4 must-have
    - Basic chat exists, bubbling/lateral communication not yet

13. **017-v1-scope (REQ-V1)** — 17 requirements, 8 must-have
    - Meta-requirements referencing other modules — mark after those are marked

14. **014-view-architecture (REQ-VIW)** — 9 requirements, 1 must-have
    - Views/ exists but advanced features not built

### Tier 4 — Deferred (no implementation expected)

15. **011-sandbox (REQ-SBX)** — 4 of 8 deferred, 4 must-have not yet implemented
16. **012-workflows (REQ-WRK)** — all 8 deferred
17. **018-spec-fidelity (REQ-FID)** — 7 must-have, tooling just built (this report)

## Index Discrepancies

None. All 17 modules match their claimed requirement counts exactly.

## Downstream Reference Issues

None. All referenced directories exist. Modules 011 and 012 correctly note "not yet implemented" for their downstream code.

## Tooling Available

Three slash commands now provide live pipeline visibility:

- `/spec-status` — Full dashboard with per-module tables and coverage percentages
- `/trace REQ-XXX-NNN` — Single requirement traceability chain (PRD → spec → code → tests)
- `/audit-spec` — Complete PRD-to-spec coverage verification with gap analysis

Re-run after adding provenance markers to track progress.
