# Gap Analysis — 2026-03-01

**Source:** `verification-report_2026-03-01.md`
**Scope:** All actionable gaps from Sections 1–10, prioritized and structured for parallel remediation.

---

## Overview

The verification report identified gaps across 6 categories. This analysis distills them into discrete, parallelizable work streams.

| Stream | Gap Count | Priority | Parallel? |
|--------|-----------|----------|-----------|
| A. Structural Rules | 4 violations | Medium | Yes — all independent |
| B. Unwired Code | 17 declarations | Medium | Yes — grouped by subsystem |
| C. Dependency Freshness | 1 outdated | High | Yes — independent |
| D. Provenance Backfill | 7 modules at 0% | Medium | Yes — per module |
| E. Code Hygiene | 2 TODOs, 1 large file | Low | Yes — independent |
| F. Spec Conformance (NON-CONFORMANT) | 18 requirements | High | Partially — design needed first |

Build health, test health, architecture, and pipeline traceability all PASS — no action needed.

---

## Stream A: Structural Rules (4 violations)

### A1. Test Timeout — 1 violation

`TavernTests/TavernTests.swift:4` — `@Suite("Tavern App Tests")` missing `.timeLimit(.minutes(1))`.

**Fix:** Add `.timeLimit(.minutes(1))` to the `@Suite` attribute. One-line change.

### A2. Preview Blocks — 12 missing

12 view files in `Tiles/` have `struct ... : View` but no `#Preview`. Per ADR-006, every SwiftUI view file must include at least one `#Preview` block.

| File | View |
|------|------|
| ChatTileView.swift | ChatTileView |
| WindowBoardView.swift | WindowBoardView |
| ModalSurface.swift | ModalSurface |
| DetailSurface.swift | DetailSurface |
| SidebarSurface.swift | SidebarSurface |
| SidePaneSurface.swift | SidePaneSurface |
| PermissionSettingsTileView.swift | PermissionSettingsTileView |
| ResourcePanelTileView.swift | ResourcePanelTileView |
| FileContentContent.swift | FileContentContent |
| TodoListContent.swift | TodoListContent |
| BackgroundTasksContent.swift | BackgroundTasksContent |
| FileTreeContent.swift | FileTreeContent |

**Approach:** Each preview needs mock data. Group by tile to share mock setup.

### A3. Logging — 53 files missing Logger

53 of 63 non-testing TavernCore files lack explicit `Logger` instances. Many use `TavernLogger.category.method()` centrally. The verification report notes this may or may not satisfy the instrumentation principle.

**Decision needed:** Is `TavernLogger.category.*` sufficient, or does each file need its own `Logger`? If the former, this is a non-issue. If the latter, this is incremental backfill per normal development (add Logger when touching a file).

**Recommendation:** Defer to incremental backfill. Not worth a dedicated bead — honor system per CLAUDE.md.

### A4. Provenance Markers

Covered in Stream D below.

---

## Stream B: Unwired Code (17 declarations)

All 17 are development gaps — code exists, wiring is missing. Grouped by subsystem for parallel work:

### B1. Error Display Path
- `TavernErrorMessages` (enum, 239 lines) — needs UI error display integration

### B2. Session Management
- `ClodSession` (class, 170+ lines) — needs connection to `ClodSessionManager`
- `ClaudeNativeSessionStorage.getMostRecentSession(for:)` — needs session resume flow
- `SessionStore.getServitor(id:)` — needs session restore flow
- `SessionStore.clearAllSessions()` — needs UI trigger
- `SessionStore.clearServitorList()` — needs UI trigger

### B3. Command Dispatch
- `SlashCommandParser.parse(_:)` / `ParseResult` — needs wiring into command dispatch (only `partialCommand()` used for autocomplete currently)

### B4. Chat/Autocomplete
- `FileMentionAutocomplete.selectedSuggestion()` — needs ChatTile integration
- `Mortal.updateChatDescription(_:)` — needs UI/coordinator call site

### B5. Project/Window
- `WindowOpeningService.raiseAllWindowsForProject(url:)` — needs project switching flow
- `UnixDirectoryDriver` / `DirectoryProjectHandle` — needs project opening flow

### B6. Infrastructure
- `DocStoreError` (enum) — needs proper error handling in callers
- `AssertionTimeoutError` (struct) — needs assertion timeout path
- `CommitmentStatus` (enum) — needs status-based filtering/display
- `TavernLogger.debugInfo(_:)` / `debugLog(_:)` — needs call sites

---

## Stream C: Dependency Freshness

ClodKit v1.0.0 → v1.0.1. Known issue: process lifecycle fix (already tracked as `jake-pf80`).

**Action:** Update `Package.swift` and `project.yml` to v1.0.1. Verify build + tests pass.

---

## Stream D: Provenance Backfill (7 modules at 0%)

These modules have zero code and test provenance markers:

| Module | Prefix | Reqs |
|--------|--------|------|
| 017-v1-scope | REQ-V1 | 17 |
| 018-spec-fidelity | REQ-FID | 7 |
| 019-states-modes | REQ-STM | 7 |
| 020-servitor-trees | REQ-TRE | 6 |
| 021-capability-delegation | REQ-CAP | 6 |
| 022-chat-discussions | REQ-CDS | 5 |
| 016-quality | REQ-QA | 17 |

**Note:** Some of these (STM, CAP, CDS) are also NON-CONFORMANT — no code exists to tag. Provenance backfill only applies where code already exists but lacks markers.

**Actionable now:** REQ-V1, REQ-FID, REQ-QA — these reference existing code/tests that lack markers.

**Blocked on implementation:** REQ-STM, REQ-TRE, REQ-CAP, REQ-CDS — code doesn't exist yet.

---

## Stream E: Code Hygiene

### E1. TODOs (2)
1. `CommandRegistry.swift:37` — wire to FileTreeScanner when ChatTile absorbs FileMentionAutocomplete
2. `SDKDiagnosticTests.swift:54` — add integration tests that actually call Claude

### E2. Large File
- `ChatViewModel.swift` at 548 lines — candidate for decomposition

---

## Stream F: Spec Conformance — NON-CONFORMANT Requirements

18 NON-CONFORMANT requirements need implementation. These are **design-heavy** — most require spec-pin decisions before coding.

| Gap | Requirements | Category | Existing Bead? |
|-----|-------------|----------|----------------|
| States/modes | REQ-STM-002/003/004/005/006 | Backgrounding, perseverance, userPresence, inactivity timeout | No |
| Capability delegation | REQ-CAP-001/002/004/006 | Handle/promise flow, delegation chains | `jake-zdhx` (PRD backfill) |
| Lifecycle: fish-or-cut-bait | REQ-LCM-001 | Trigger implementation | No |
| Lifecycle: token budget | REQ-LCM-002 | Token budget enforcement | `jake-unus` (fine-tuning) |
| Lifecycle: spin detection | REQ-LCM-003 | Spin detection | No |
| Task modes | REQ-AGT-006 | Task mode system | No |

**NOT ASSESSED (top gaps from report):**
- REQ-COM-001 (upward bubbling), REQ-COM-004 (question classification), REQ-COM-006 (typed message protocol) — no implementation
- REQ-INV-001 (CI/CD pipeline) — infrastructure gap

**Recommendation:** Stream F items are too large for this remediation pass. They require design decomposition and should be tracked as future epics. Focus this pass on Streams A–E (mechanical fixes that improve health metrics without design decisions).

---

## Parallelization Strategy

```
Epic: Verification Gap Remediation (2026-03-01)
│
├── [Independent — run in parallel]
│   ├── A1: Test timeout fix (1 file, ~5 min)
│   ├── A2: Preview blocks (12 files, ~30 min per agent)
│   ├── B1-B6: Unwired code groups (6 groups, parallel)
│   ├── C: ClodKit update (Package.swift + project.yml)
│   ├── D: Provenance backfill for REQ-V1, REQ-FID, REQ-QA
│   └── E1: TODO resolution (2 files)
│
└── [Deferred — needs design first]
    └── F: NON-CONFORMANT spec requirements (18 reqs, future epics)
```

**Estimated parallel agents:** 6–8 can work simultaneously across Streams A–E.
