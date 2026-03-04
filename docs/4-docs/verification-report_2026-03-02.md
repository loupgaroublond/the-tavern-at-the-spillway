# Verification Report — 2026-03-02

**Generated:** 2026-03-03T08:20Z
**Duration:** ~25 minutes (Steps 5-8 only; Steps 1-4 completed in prior session)

## Executive Summary

| Section | Status | Detail |
|---------|--------|--------|
| Build Health | PASS | 0 warnings |
| Test Health | PASS | 639/639 passed, 0 failed |
| Code Coverage | INFO | 38% overall (5653/14868 lines) |
| Spec Conformance | INFO | 30 conformant, 74 partial, 27 non-conformant, 50 not assessed |
| Pipeline Traceability | WARN | 91% PRD covered, 1 count discrepancy, 6 stale refs, 6 orphaned provenance markers |
| Provenance Coverage | INFO | 45% overall (81/181 implemented or tested) |
| Beads | INFO | 82 total, 82 open, 0 critical (P0) |
| Structural Rules | WARN | 4/8 pass, 4 violations |
| Architecture | PASS | 0 violations |
| SDK Feature Parity | FAIL | 53 verified, 9 partial, 0 false, 16 untracked gaps |
| Informational | — | 6 TODOs, 14 unwired declarations, 1 large file (550 lines), deps current |


## Section 1: Build Health

**Status: PASS**

BUILD SUCCEEDED with 0 warnings.


## Section 2: Test Health

**Status: PASS**

| Metric | Count |
|--------|-------|
| Total tests | 639 |
| Suites | 59 |
| Passed | 639 |
| Failed | 0 |
| Skipped | 0 |

All Grade 1+2 tests pass. No failures.


## Section 3: Code Coverage

**Status: INFO — 38% overall (5653/14868 lines)**

| Target | Covered | Total | % |
|--------|---------|-------|---|
| Tavern (app) | 0 | 981 | 0% |
| TavernCore | 4876 | 8059 | 60.5% |
| TavernKit | 164 | 204 | 80.4% |
| Tiles | 613 | 5624 | 10.9% |
| **Overall** | **5653** | **14868** | **38%** |

```
Sources/ (38% — 5653/14868)
├── TavernCore/ (60.5% — 4876/8059)
│   ├── Chat/
│   │   ├── ChatViewModel.swift                          212/493  (43%)
│   │   └── FileMentionAutocomplete.swift                121/132  (91.67%)
│   ├── Commands/
│   │   ├── CommandContext.swift                          24/24   (100%)
│   │   ├── CommandFormatting.swift                       14/14   (100%)
│   │   ├── CompactCommand.swift                          24/24   (100%)
│   │   ├── ContextCommand.swift                          57/61   (93.44%)
│   │   ├── CostCommand.swift                             55/61   (90.16%)
│   │   ├── CustomCommand.swift                           49/49   (100%)
│   │   ├── CustomCommandLoader.swift                    107/114  (93.86%)
│   │   ├── HelpCommand.swift                             29/29   (100%)
│   │   ├── HooksCommand.swift                            58/70   (82.86%)
│   │   ├── MCPCommand.swift                              67/80   (83.75%)
│   │   ├── ModelCommand.swift                            50/50   (100%)
│   │   ├── ServitorsCommand.swift                        38/38   (100%)
│   │   ├── SlashCommand.swift                             0/1    (0%)
│   │   ├── SlashCommandAutocomplete.swift                37/39   (94.87%)
│   │   ├── SlashCommandDispatcher.swift                  67/71   (94.37%)
│   │   ├── SlashCommandParser.swift                      38/40   (95%)
│   │   ├── StatsCommand.swift                            69/76   (90.79%)
│   │   ├── StatusCommand.swift                           47/54   (87.04%)
│   │   └── ThinkingCommand.swift                         56/57   (98.25%)
│   ├── Commitments/
│   │   ├── AssertionRunner.swift                         10/10   (100%)
│   │   ├── Commitment.swift                              38/38   (100%)
│   │   ├── CommitmentList.swift                         154/160  (96.25%)
│   │   ├── CommitmentVerifier.swift                      76/78   (97.44%)
│   │   └── ShellAssertionRunner.swift                   206/214  (96.26%)
│   ├── Coordination/
│   │   └── TavernCoordinator.swift                      180/284  (63.38%)
│   ├── DocStore/
│   │   ├── DocStore.swift                               202/210  (96.19%)
│   │   ├── Document.swift                                97/105  (92.38%)
│   │   ├── ServitorNode.swift                           220/226  (97.35%)
│   │   └── ServitorPersistence.swift                     72/82   (87.8%)
│   ├── Errors/
│   │   └── TavernErrorMessages.swift                     53/298  (17.79%)
│   ├── Logging/
│   │   └── TavernLogger.swift                            11/12   (91.67%)
│   ├── MCP/
│   │   └── TavernMCPServer.swift                         74/129  (57.36%)
│   ├── Naming/
│   │   ├── NameGenerator.swift                          140/142  (98.59%)
│   │   └── NamingTheme.swift                             10/10   (100%)
│   ├── Permissions/
│   │   ├── PermissionManager.swift                       92/100  (92%)
│   │   ├── PermissionRule.swift                          21/21   (100%)
│   │   ├── PermissionSettingsViewModel.swift             52/52   (100%)
│   │   └── PermissionStore.swift                         87/89   (97.75%)
│   ├── Persistence/
│   │   ├── ClaudeNativeSessionStorage.swift               0/282  (0%)
│   │   ├── ClaudeSessionModels.swift                      0/209  (0%)
│   │   └── SessionStore.swift                            88/167  (52.69%)
│   ├── Project/
│   │   ├── ProjectManager.swift                           0/88   (0%)
│   │   └── TavernProject.swift                            0/196  (0%)
│   ├── Providers/
│   │   ├── ClodSessionManager.swift                       0/144  (0%)
│   │   ├── CommandRegistry.swift                          0/33   (0%)
│   │   ├── DocumentStore.swift                            0/32   (0%)
│   │   ├── PermissionSettingsProvider.swift               0/40   (0%)
│   │   └── UnixDirectoryDriver.swift                      0/12   (0%)
│   ├── Resources/
│   │   ├── FileTreeScanner.swift                         58/63   (92.06%)
│   │   ├── FileTypeIcon.swift                            41/50   (82%)
│   │   └── ResourcePanelViewModel.swift                 105/125  (84%)
│   ├── Servitors/
│   │   ├── Jake.swift                                   293/298  (98.32%)
│   │   ├── Mortal.swift                                 404/442  (91.4%)
│   │   ├── MortalSpawner.swift                          101/137  (73.72%)
│   │   └── ServitorRegistry.swift                        78/78   (100%)
│   ├── Sessions/
│   │   └── ClodSession.swift                              0/214  (0%)
│   ├── SidePane/
│   │   ├── BackgroundTaskViewModel.swift                  93/103  (90.29%)
│   │   └── TodoListViewModel.swift                        76/77   (98.7%)
│   ├── Testing/
│   │   ├── LiveMessenger.swift                             7/845  (0.83%)
│   │   ├── MockAssertionRunner.swift                      64/64   (100%)
│   │   ├── MockClaudeCode.swift                           45/48   (93.75%)
│   │   ├── MockMessenger.swift                           179/180  (99.44%)
│   │   ├── MockServitor.swift                            155/212  (73.11%)
│   │   └── TestFixtures.swift                            10/10   (100%)
│   └── UI/
│       ├── ServitorListItem.swift                         18/18   (100%)
│       └── ServitorListViewModel.swift                    47/55   (85.45%)
├── TavernKit/ (80.4% — 164/204)
│   ├── ApprovalTypes.swift                               11/21   (52.38%)
│   ├── ChatMessage.swift                                 11/33   (33.33%)
│   ├── FileMentionSuggestion.swift                        5/6    (83.33%)
│   ├── FileTreeNode.swift                                 9/9    (100%)
│   ├── PermissionMode.swift                              23/23   (100%)
│   ├── PermissionProvider.swift                           6/6    (100%)
│   ├── ServitorListItem.swift                            24/25   (96%)
│   ├── SidePaneTab.swift                                  7/8    (87.5%)
│   ├── StreamTypes.swift                                 31/36   (86.11%)
│   ├── TavernError.swift                                 18/18   (100%)
│   ├── TavernTask.swift                                  13/13   (100%)
│   └── TodoItem.swift                                     6/6    (100%)
├── Tiles/ (10.9% — 613/5624)
│   ├── ApprovalTile/
│   │   ├── ApprovalResponder.swift                        0/6    (0%)
│   │   ├── PlanApprovalTile.swift                         0/17   (0%)
│   │   ├── PlanApprovalTileView.swift                     0/219  (0%)
│   │   ├── ToolApprovalTile.swift                         0/14   (0%)
│   │   └── ToolApprovalTileView.swift                     0/194  (0%)
│   ├── ChatTile/
│   │   ├── ChatResponder.swift                             5/5   (100%)
│   │   ├── ChatTile.swift                               270/310  (87.1%)
│   │   ├── ChatTileView.swift                             0/940  (0%)
│   │   ├── CodeBlockView.swift                            7/130  (5.38%)
│   │   ├── CollapsibleBlockView.swift                    15/208  (7.21%)
│   │   ├── DiffView.swift                                 3/131  (2.29%)
│   │   ├── MessageRowView.swift                           0/342  (0%)
│   │   └── MultiLineTextInput.swift                      57/185  (30.81%)
│   ├── PermissionSettingsTile/
│   │   ├── PermissionSettingsResponder.swift               3/3   (100%)
│   │   ├── PermissionSettingsTile.swift                   40/43  (93.02%)
│   │   └── PermissionSettingsTileView.swift                0/441 (0%)
│   ├── ResourcePanelTile/
│   │   ├── BackgroundTasksContent.swift                    0/342 (0%)
│   │   ├── FileContentContent.swift                        0/148 (0%)
│   │   ├── FileTreeContent.swift                           0/110 (0%)
│   │   ├── FileTypeIcon.swift                              0/31  (0%)
│   │   ├── LineNumberedText.swift                          3/110 (2.73%)
│   │   ├── ResourcePanelResponder.swift                    3/3   (100%)
│   │   ├── ResourcePanelTile.swift                       148/163 (90.8%)
│   │   ├── ResourcePanelTileView.swift                     0/88  (0%)
│   │   └── TodoListContent.swift                           0/252 (0%)
│   ├── ServitorListTile/
│   │   ├── ServitorListResponder.swift                     0/6   (0%)
│   │   ├── ServitorListTile.swift                          0/57  (0%)
│   │   └── ServitorListTileView.swift                      0/508 (0%)
│   └── TavernBoardTile/
│       ├── DetailSurface.swift                             0/31  (0%)
│       ├── Facets.swift                                    0/10  (0%)
│       ├── ModalSurface.swift                              0/12  (0%)
│       ├── SidePaneSurface.swift                           0/10  (0%)
│       ├── SidebarSurface.swift                            0/6   (0%)
│       ├── Sockets/
│       │   ├── ApprovalSocket.swift                        0/45  (0%)
│       │   ├── ChatSocketPool.swift                       59/71  (83.1%)
│       │   ├── PermissionSettingsSocket.swift              0/30  (0%)
│       │   ├── ResourcePanelSocket.swift                   0/14  (0%)
│       │   └── ServitorListSocket.swift                    0/63  (0%)
│       ├── WindowBoard.swift                               0/151 (0%)
│       └── WindowBoardView.swift                           0/175 (0%)
└── Tavern/ (app target) (0% — 0/981)
    ├── TavernApp.swift                                     0/176 (0%)
    ├── TavernAppDelegate.swift                             0/70  (0%)
    ├── Views/ProjectView.swift                             0/236 (0%)
    ├── Views/WelcomeView.swift                             0/319 (0%)
    └── WindowOpeningService.swift                          0/180 (0%)
```


## Section 4: Spec Conformance

**Status: INFO** (from `attestation-report_2026-03-02.md`)

### Verdict Distribution

| Verdict | Count | % |
|---------|-------|---|
| CONFORMANT | 30 | 16.6% |
| PARTIAL | 74 | 40.9% |
| NON-CONFORMANT | 27 | 14.9% |
| NOT ASSESSED | 50 | 27.6% |
| **Total** | **181** | |

### Top 10 Gaps

1. **REQ-AGT-006** — Task Modes (5 modes unimplemented)
2. **REQ-LCM-001** — Fish-or-Cut-Bait Triggers (no trigger detection)
3. **REQ-LCM-002** — Token Budget Enforcement (no token budget)
4. **REQ-LCM-003** — Spin Detection (no spin detection)
5. **REQ-OPM-001** — Perseverance Mode (no background loop)
6. **REQ-OPM-003** — User Joining/Leaving (no system messages)
7. **REQ-STM-002** — Three Orthogonal Boolean Properties (absent)
8. **REQ-STM-003** — Backgrounding Property (absent)
9. **REQ-STM-004** — Perseverance Property (absent)
10. **REQ-CAP-001** — Separation from Summon (no typed handle)


## Section 5: Pipeline Traceability

**Status: WARN** (from `audit-spec-report_2026-03-02.md`)

### PRD Coverage

| Metric | Value |
|--------|-------|
| PRD sections | 45 total |
| Covered by spec | 41 (91%) |
| Context-only (no reqs) | 4 |

### Spec Modules

| Metric | Value |
|--------|-------|
| Active modules | 21 |
| Stub modules | 3 |
| Active requirements | 181 |

### Transition Rates

| Transition | Rate |
|------------|------|
| PRD → Spec | 91% (41/45 sections) |
| Spec → Code | 45% (81/181) |
| Spec → Tests | 28% (50/181) |
| Code → Tests | 62% (50/81) |

### Implementation Status Breakdown

| Status | Count | % |
|--------|-------|---|
| Specified only | 100 | 55% |
| Implemented (code, no tests) | 31 | 17% |
| Tested (code + tests) | 50 | 28% |
| **Overall coverage** | **81/181** | **45%** |

### Discrepancies and Issues

- **Index discrepancy:** 1 — module 012 claims 8 requirements, has 10 (includes 3 dropped)
- **Stale downstream refs:** 6 modules reference `Agents/` instead of `Servitors/`
- **Orphaned provenance markers:** 6 dropped requirements with lingering `// MARK: - Provenance:` markers in source


## Section 6: Provenance Coverage

**Status: INFO — 45% overall (81/181 requirements implemented or tested)**

| Module | Prefix | Total | Specified | Implemented | Tested | Coverage% |
|--------|--------|-------|-----------|-------------|--------|-----------|
| 002-invariants | REQ-INV | 9 | 5 | 1 | 3 | 44% |
| 003-system-architecture | REQ-ARCH | 9 | 2 | 4 | 3 | 78% |
| 004-agents | REQ-AGT | 10 | 2 | 5 | 3 | 80% |
| 005-spawning | REQ-SPN | 10 | 2 | 2 | 6 | 80% |
| 006-lifecycle | REQ-LCM | 7 | 7 | 0 | 0 | 0% |
| 007-operating-modes | REQ-OPM | 6 | 1 | 3 | 2 | 83% |
| 008-deterministic-shell | REQ-DET | 6 | 1 | 2 | 3 | 83% |
| 009-communication | REQ-COM | 8 | 7 | 0 | 1 | 13% |
| 010-doc-store | REQ-DOC | 5 | 3 | 0 | 2 | 40% |
| 011-sandbox | REQ-SBX | 8 | 8 | 0 | 0 | 0% |
| 012-workflows | REQ-WRK | 7 | 7 | 0 | 0 | 0% |
| 013-user-experience | REQ-UX | 11 | 3 | 7 | 1 | 73% |
| 014-view-architecture | REQ-VIW | 11 | 7 | 4 | 0 | 36% |
| 015-observability | REQ-OBS | 9 | 4 | 3 | 2 | 56% |
| 016-quality | REQ-QA | 17 | 3 | 6 | 8 | 82% |
| 017-v1-scope | REQ-V1 | 17 | 7 | 3 | 7 | 59% |
| 018-spec-fidelity | REQ-FID | 7 | 3 | 0 | 4 | 57% |
| 019-states-modes | REQ-STM | 7 | 7 | 0 | 0 | 0% |
| 020-servitor-trees | REQ-TRE | 6 | 6 | 0 | 0 | 0% |
| 021-capability-delegation | REQ-CAP | 6 | 6 | 0 | 0 | 0% |
| 022-chat-discussions | REQ-CDS | 5 | 5 | 0 | 0 | 0% |
| **TOTAL** | | **181** | **100** | **31** | **50** | **45%** |

Modules with 0% coverage (7 total, all recently added): REQ-LCM, REQ-SBX, REQ-WRK, REQ-STM, REQ-TRE, REQ-CAP, REQ-CDS — these represent newly specified scope not yet implemented.


## Section 7: Beads Audit

**Status: INFO**

| Metric | Value |
|--------|-------|
| Total beads | 82 |
| Open | 82 |
| In progress | 0 |
| Closed | 0 |

### Priority Distribution

| Priority | Count |
|----------|-------|
| P0 (critical) | 0 |
| P1 (high) | 5 |
| P2 (medium) | 40 |
| P3 (low) | 24 |
| P4 (backlog) | 13 |

**P0 Critical Beads:** None. No critical issues blocking work.


## Section 8: Structural Rules

**Status: WARN — 4/8 pass, 4 violations**

| Check | Status | Detail |
|-------|--------|--------|
| 8a. Test timeouts | WARN | 7 suites without `.timeLimit` |
| 8b. Preview blocks | PASS | All 23 view files have `#Preview` blocks |
| 8c. Logging | WARN | 12/70 TavernCore files have Logger (many are models/protocols that don't need it) |
| 8d. Provenance markers | WARN | 67/~100 source files have provenance (expected — provenance is additive) |
| 8e. @MainActor ViewModels | WARN | 2/6 VMs missing `@MainActor` |
| 8f. ServitorMessenger DI | PASS | Both Jake and Mortal accept `ServitorMessenger` via constructor injection |
| 8g. No blocking calls | PASS | 0 `Thread.sleep`, 0 `DispatchSemaphore.wait` in Sources (excluding Testing) |
| 8h. Layer violations | PASS | 0 violations: no TavernCore imports in Tiles, no upward imports |

### 8a. Test Suites Without `.timeLimit`

7 suites missing `.timeLimit(...)`:

- `TodoListViewModelTests`
- `ResourcePanelViewModelTests`
- `ChatViewModelTests`
- `BackgroundTaskViewModelTests`
- `PermissionSettingsViewModelTests`
- `TavernCoordinatorTests`
- `ChatViewModelCommandTests`

### 8e. ViewModels Missing `@MainActor`

2 of 6 ViewModels are missing `@MainActor`:

- `BackgroundTaskViewModel`
- `TodoListViewModel`


## Section 9: Architecture

**Status: PASS — 0 violations**

`Package.swift` defines a clean layered target graph:

- **TavernKit** — no dependencies (pure types/protocols, foundation layer)
- **Leaf tiles** (`ApprovalTile`, `PermissionSettingsTile`, `ServitorListTile`, `ResourcePanelTile`, `ChatTile`) — depend only on TavernKit
- **TavernBoardTile** — composes all leaf tiles + TavernKit
- **TavernCore** — depends on TavernKit + ClodKit
- **Tavern (app)** — depends on TavernCore + TavernKit + TavernBoardTile

No architecture violations. All layers are clean and dependency direction is respected throughout.


## Section 10: Informational

### 10a. TODO/FIXME/HACK Audit

**6 code TODOs, 0 FIXMEs, 0 HACKs**

| File | Line | Comment |
|------|------|---------|
| `TavernCore/Sessions/ClodSession.swift` | 7 | `TODO: ClodSession consolidates session logic currently duplicated in Jake and Mortal` |
| `TavernCore/Sessions/ClodSession.swift` | 159 | `TODO: Re-enable after ClodKit SDK update with robust resume handling` |
| `TavernCore/Servitors/Mortal.swift` | 165 | `TODO: Re-enable after ClodKit SDK update with robust resume handling` |
| `TavernCore/Servitors/Mortal.swift` | 208 | `TODO: Re-enable after ClodKit SDK update with robust resume handling` |
| `TavernCore/Servitors/Jake.swift` | 169 | `TODO: Re-enable after ClodKit SDK update with robust resume handling` |
| `TavernCore/Servitors/Jake.swift` | 225 | `TODO: Re-enable after ClodKit SDK update with robust resume handling` |

2 unique themes: session consolidation (1 TODO), ClodKit resume handling (5 TODOs across 3 files).

### 10b. Unwired Code Analysis (heuristic)

**All findings are heuristic. False positives expected for protocol witnesses, type-inferred dot syntax, and test-only instantiation patterns.**

**Unwired Types:**

| Declaration | File | Classification | Reason |
|---|---|---|---|
| `UnixDirectoryDriver` | Providers/UnixDirectoryDriver.swift | Development gap | Implements `ProjectProvider` but never instantiated in production |
| `DirectoryProjectHandle` | Providers/UnixDirectoryDriver.swift | Development gap | Only instantiated inside unwired `UnixDirectoryDriver` |
| `ProjectProvider` (protocol) | TavernKit/ProjectProvider.swift | Development gap | Only conformer is unwired `UnixDirectoryDriver` |
| `ProjectHandle` (protocol) | TavernKit/ProjectProvider.swift | Development gap | Part of unwired `ProjectProvider` island |
| `FileTypeIcon` (TavernCore) | Resources/FileTypeIcon.swift | Obsolete duplicate | Tiles module has its own copy; TavernCore version unused by UI |

**Unwired Functions:**

| Declaration | File | Classification | Reason |
|---|---|---|---|
| `ClaudeNativeSessionStorage.getAllSessions()` | Persistence/ClaudeNativeSessionStorage.swift | Development gap | Declared public, never called |
| `ClaudeNativeSessionStorage.listProjects()` | Persistence/ClaudeNativeSessionStorage.swift | Development gap | Only called from unwired `getAllSessions()` |
| `TavernCoordinator.reloadCustomCommands()` | Coordination/TavernCoordinator.swift | Development gap | File-watcher hook never built |
| `TavernCoordinator.refresh()` | Coordination/TavernCoordinator.swift | Development gap | No external caller |
| `TavernCoordinator.dismissServitor(id:)` | Coordination/TavernCoordinator.swift | Obsolete | Dead alias for `closeServitor(id:)` |
| `Mortal.updateChatDescription(_:)` | Servitors/Mortal.swift | Obsolete | Bypassed by direct property access in `ClodSessionManager` |
| `ClodSessionManager.resetAllSessions()` | Providers/ClodSessionManager.swift | Development gap | Debug reset, no UI trigger |
| `CommitmentVerifier.verify(_:in:)` | Commitments/CommitmentVerifier.swift | Premature API | Single-commitment form, production uses `verifyAll()` |
| `CommitmentVerifier.retryFailed(in:)` | Commitments/CommitmentVerifier.swift | Development gap | Retry mechanism tested but no production caller |

**Unwired Classes (fully built, fully tested, not connected to runtime):**

| Declaration | File | Classification | Reason |
|---|---|---|---|
| `ServitorPersistence` | DocStore/ServitorPersistence.swift | Development gap | All methods tested but class never instantiated in production |
| `DocStore` | DocStore/DocStore.swift | Development gap | Only consumed by unwired `ServitorPersistence` |

**Summary:** 10 development gaps, 2 obsolete, 1 premature API, 1 duplicate

**Notable:** The `DocStore`/`ServitorPersistence` island is the biggest gap — two fully-tested layers representing the "doc store is source of truth" invariant, but not connected to the runtime. `TavernCoordinator` uses `SessionStore` (UserDefaults) instead.

### 10c. Dependency Freshness

| Dependency | Current | Latest | Status |
|------------|---------|--------|--------|
| ClodKit | local path | — | local dev |
| ViewInspector | 0.10.3 | 0.10.3 | current |

All dependencies are current. ClodKit is on a local development path (expected during active development).

### 10d. File Complexity

**Large files (>500 lines):**

| File | Lines |
|------|-------|
| `TavernCore/Chat/ChatViewModel.swift` | 550 |

1 file at the complexity threshold. No files exceed 1000 lines.

**Highest function counts (top 8):**

| File | Functions |
|------|-----------|
| `TavernCore/Persistence/SessionStore.swift` | 19 |
| `Tiles/TavernBoardTile/WindowBoard.swift` | 15 |
| `TavernCore/Providers/ClodSessionManager.swift` | 14 |
| `Tiles/TavernBoardTile/TavernNavigator.swift` | 13 |
| `Tiles/ResourcePanelTile/ResourcePanelTile.swift` | 13 |
| `TavernCore/Persistence/ClaudeNativeSessionStorage.swift` | 13 |
| `TavernCore/Coordination/TavernCoordinator.swift` | 13 |
| `TavernCore/Commitments/CommitmentList.swift` | 13 |


## Section 11: SDK Feature Parity

**Source:** ADR-010 feature matrix (127 total capabilities)

| Matrix Status | Count | Verified | Partial | False/Stale | Confirmed | Untracked |
|---------------|-------|----------|---------|-------------|-----------|-----------|
| Implemented   | 62    | 53       | 9       | 0           | —         | —         |
| Gap           | 16    | —        | —       | —           | 0         | 16        |
| Deferred      | 36    | —        | —       | —           | 36        | 0         |
| Broken        | 1     | —        | —       | —           | 1         | 0         |
| N/A           | 12    | —        | —       | —           | 12        | —         |

**Pass criteria:** Zero FALSE implementations. Zero UNTRACKED violations.
**Result: FAIL** — 16 Gap rows are UNTRACKED (no individual bead per ADR-010 Rule 2).

**Partial implementations (9):**
- `ClaudeQuery.interrupt()` — wired but only tested via mock
- `options.persistSession` — used implicitly, no test asserts the flag
- `options.environment` (CLAUDECODE) — set in production, no test coverage
- `PermissionMode.dontAsk` — mapped but no end-to-end assertion to ClodKit options
- `cacheReadInputTokens`, `cacheCreationInputTokens`, `durationMs`, `stopReason`, `numTurns` — parsed and unit-tested but not displayed in UI

**Untracked gaps (16):** All Gap rows lack individual bd beads. ADR-010 Rule 2 requires one bead per Gap. Closest approximations are design/PRD beads (`jake-vn54`, `jake-yte`, `jake-lt2s`) scoped to UI features, not SDK gap resolution.

**Broken (1):** `options.resume` — confirmed broken. Code commented out in `ClodSession.swift:158-162` with explicit TODO. No bead specifically tracks session resume fix.

**Full detail:** `docs/4-docs/sdk-parity-report_2026-03-02.md`


## Action Items

Ranked by priority:

1. **CRITICAL** — None. Build passes, all 639 tests pass.

2. **HIGH** — 16 untracked SDK Gap violations (ADR-010 Rule 2 requires a bead per Gap); 27 non-conformant requirements concentrated in lifecycle (REQ-LCM), states-modes (REQ-STM), and capability-delegation (REQ-CAP); 24 must-have requirements across 4 unstarted modules (019-022) with 0% implementation coverage.

3. **MEDIUM** — 9 partial SDK implementations needing test coverage; 7 test suites without `.timeLimit`; 2 ViewModels missing `@MainActor`; 6 stale downstream refs in spec modules (`Agents/` → `Servitors/`); 6 orphaned provenance markers on dropped requirements.

4. **LOW** — 6 code TODOs (2 unique themes: session consolidation, ClodKit resume handling — all intentional, awaiting upstream SDK update); ChatViewModel at 550 lines approaching complexity threshold.
