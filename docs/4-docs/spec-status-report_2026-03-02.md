# Spec Status Dashboard

**Generated:** 2026-03-02

**Active requirements:** 181 | **Dropped:** 13 | **Overall coverage:** 45%

**Status definitions:**
- **specified** — requirement exists in spec, no code yet
- **implemented** — code exists, no tests yet
- **tested** — code exists and tests verify it

**Coverage formula:** `(implemented + tested) / active × 100`

---

## Module 002 — Invariants (REQ-INV)

**Active:** 9 | **Dropped:** 0 | **Coverage:** 44% (1 implemented, 3 tested, 5 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-INV-001 | Test Suite Gate | must-have | specified | — | — |
| REQ-INV-002 | Universal Testability | must-have | specified | — | — |
| REQ-INV-004 | Sacred User Attention | must-have | specified | — | — |
| REQ-INV-008 | Original File Protection | must-have | specified | — | — |
| REQ-INV-009 | Sandbox Boundary Impossibility | must-have | specified | — | — |
| REQ-INV-006 | Invariant Immutability | must-have | implemented | TavernMCPServer.swift | — |
| REQ-INV-003 | Independent Commitment Verification | must-have | tested | ShellAssertionRunner.swift, AssertionRunner.swift, CommitmentVerifier.swift | CommitmentTests.swift |
| REQ-INV-005 | Doc Store as Source of Truth | must-have | tested | DocStore.swift, ServitorPersistence.swift, SessionStore.swift | DocStoreTests.swift |
| REQ-INV-007 | Visible Failures | must-have | tested | TavernError.swift, TavernLogger.swift, TavernErrorMessages.swift | TavernErrorMessagesTests.swift |


## Module 003 — System Architecture (REQ-ARCH)

**Active:** 9 | **Dropped:** 1 | **Coverage:** 78% (4 implemented, 3 tested, 2 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-ARCH-001 | Tech Stack | must-have | specified | — | — |
| REQ-ARCH-010 | No Sandbox Entitlement | must-have | specified | — | — |
| REQ-ARCH-002 | Six-Layer Structure | must-have | implemented | TavernCoordinator.swift | — |
| REQ-ARCH-005 | Component Ownership Hierarchy | must-have | implemented | ProjectManager.swift, TavernProject.swift, TavernCoordinator.swift | — |
| REQ-ARCH-007 | Concurrency Model | must-have | implemented | Jake.swift | — |
| REQ-ARCH-008 | Async Primitive Strategy | must-have | implemented | WindowBoard.swift, ClodSessionManager.swift, ChatViewModel.swift | — |
| REQ-ARCH-003 | Thin UI / Fat ViewModel | must-have | tested | ResourcePanelTile.swift, WindowBoardView.swift, WindowBoard.swift, Facets.swift, TavernNavigator.swift, SidebarSurface.swift, DetailSurface.swift, SidePaneSurface.swift, ClodSessionManager.swift, UnixDirectoryDriver.swift, ChatViewModel.swift, ChatSocketPool.swift, ServitorListSocket.swift, ResourcePanelSocket.swift | ChatViewModelTests.swift, ChatSocketPoolTests.swift, ChatTileTests.swift |
| REQ-ARCH-004 | Architecture Shapes | must-have | tested | ServitorState.swift, WindowBoard.swift, Facets.swift, TavernNavigator.swift, DocStore.swift, Servitor.swift, ClodSessionManager.swift, MortalSpawner.swift, ChatViewModel.swift, ChatSocketPool.swift | ChatSocketPoolTests.swift |
| REQ-ARCH-009 | Dependency Injection for Testability | must-have | tested | ServitorMessenger.swift, MockServitor.swift, ClodSession.swift | JakeTests.swift, MortalTests.swift |

**Dropped:** ~~REQ-ARCH-006~~ (Closed Plugin Set)


## Module 004 — Agents (REQ-AGT)

**Active:** 10 | **Dropped:** 0 | **Coverage:** 70% (0 implemented, 7 tested, 3 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-AGT-003 | Drone Agents | deferred | specified | — | — |
| REQ-AGT-004 | Monitor Daemons | deferred | specified | — | — |
| REQ-AGT-006 | Task Modes | must-have | specified | — | — |
| REQ-AGT-001 | Jake Daemon Agent | must-have | tested | Jake.swift | JakeTests.swift |
| REQ-AGT-002 | Mortal Agents (Servitors) | must-have | tested | Mortal.swift | MortalTests.swift |
| REQ-AGT-005 | Agent State Machine | must-have | tested | ServitorState.swift, Servitor.swift, Mortal.swift | MortalTests.swift |
| REQ-AGT-007 | Servitor Trees vs Claude-Internal Agents | must-have | tested | TavernCoordinator.swift, MortalSpawner.swift | MortalSpawnerTests.swift |
| REQ-AGT-008 | Async/Non-Blocking I/O Pattern | must-have | tested | Jake.swift | JakeTests.swift |
| REQ-AGT-009 | Done Signal Detection | must-have | tested | Mortal.swift | MortalTests.swift |
| REQ-AGT-010 | Agent Protocol | must-have | tested | ServitorState.swift, Servitor.swift | ChatViewModelTests.swift |


## Module 005 — Spawning (REQ-SPN)

**Active:** 10 | **Dropped:** 0 | **Coverage:** 90% (0 implemented, 9 tested, 1 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-SPN-008 | Work Queues | deferred | specified | — | — |
| REQ-SPN-001 | Summon Configuration Parameters | must-have | tested | MortalSpawner.swift | MortalSpawnerTests.swift |
| REQ-SPN-002 | User-Summon Mode | must-have | tested | MortalSpawner.swift | MortalSpawnerTests.swift |
| REQ-SPN-003 | Jake-Summon Mode | must-have | tested | TavernMCPServer.swift, MortalSpawner.swift | MortalSpawnerTests.swift |
| REQ-SPN-004 | Naming Theme Assignment | should-have | tested | NamingTheme.swift | NamingTests.swift |
| REQ-SPN-005 | Global Name Uniqueness | must-have | tested | ServitorRegistry.swift, NameGenerator.swift | NamingTests.swift, ServitorRegistryTests.swift |
| REQ-SPN-006 | Tier Depletion | should-have | tested | NameGenerator.swift | NamingTests.swift |
| REQ-SPN-007 | Easter Egg Names | should-have | tested | NamingTheme.swift | NamingTests.swift |
| REQ-SPN-009 | Chat Description | must-have | tested | Mortal.swift | MortalTests.swift |
| REQ-SPN-010 | Auto-Generated Names | must-have | tested | NameGenerator.swift, TavernMCPServer.swift, MortalSpawner.swift | MortalSpawnerTests.swift |


## Module 006 — Lifecycle (REQ-LCM)

**Active:** 7 | **Dropped:** 0 | **Coverage:** 29% (1 implemented, 1 tested, 5 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-LCM-001 | Fish-or-Cut-Bait Triggers | must-have | specified | — | — |
| REQ-LCM-002 | Token Budget Enforcement | must-have | specified | — | — |
| REQ-LCM-003 | Spin Detection | should-have | specified | — | — |
| REQ-LCM-005 | Rewind Capability | deferred | specified | — | — |
| REQ-LCM-006 | Branch Capability | deferred | specified | — | — |
| REQ-LCM-007 | Agent Expiration and Hibernation | should-have | implemented | Jake.swift, Mortal.swift | — |
| REQ-LCM-004 | Dead Agent Artifacts | must-have | tested | ServitorPersistence.swift, ServitorListViewModel.swift | ServitorPersistenceTests.swift |


## Module 007 — Operating Modes (REQ-OPM)

**Active:** 6 | **Dropped:** 0 | **Coverage:** 83% (3 implemented, 2 tested, 1 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-OPM-006 | Cogitation Display | should-have | specified | — | — |
| REQ-OPM-003 | User Joining/Leaving | must-have | implemented | PermissionSettingsTile.swift, PermissionSettingsProvider.swift, ChatViewModel.swift | — |
| REQ-OPM-004 | Attention Model | must-have | implemented | ServitorListTile.swift, ServitorListTileView.swift, ServitorListViewModel.swift | — |
| REQ-OPM-005 | Two-Mode Servitor Summoning | must-have | implemented | MortalSpawner.swift, Mortal.swift | — |
| REQ-OPM-001 | Perseverance Mode | must-have | tested | ModalSurface.swift, PermissionSettingsProvider.swift, ApprovalSocket.swift, ChatViewModel.swift | ChatViewModelTests.swift |
| REQ-OPM-002 | Chat Mode | must-have | tested | ModalSurface.swift, PermissionSettingsProvider.swift, ApprovalSocket.swift, ChatViewModel.swift | ChatViewModelTests.swift |


## Module 008 — Deterministic Shell (REQ-DET)

**Active:** 6 | **Dropped:** 2 | **Coverage:** 100% (4 implemented, 2 tested, 0 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-DET-001 | Prompt Composition | must-have | implemented | Jake.swift, Mortal.swift | — |
| REQ-DET-002 | Passthrough Display | must-have | implemented | ClaudeNativeSessionStorage.swift | — |
| REQ-DET-003 | Structured Outputs via Tools | must-have | implemented | TavernMCPServer.swift | — |
| REQ-DET-008 | MCP Tool Interface | must-have | implemented | TavernMCPServer.swift | — |
| REQ-DET-004 | Commitment Verification | must-have | tested | Mortal.swift, CommitmentVerifier.swift | CommitmentTests.swift, MortalTests.swift |
| REQ-DET-005 | Commitment Storage | must-have | tested | Commitment.swift, CommitmentList.swift | CommitmentTests.swift |

**Dropped:** ~~REQ-DET-006~~ (Jake's Tool Handler Protocol), ~~REQ-DET-007~~ (Continuation Loop)


## Module 009 — Communication (REQ-COM)

**Active:** 8 | **Dropped:** 0 | **Coverage:** 13% (0 implemented, 1 tested, 7 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-COM-001 | Upward Bubbling | must-have | specified | — | — |
| REQ-COM-002 | Lateral Communication | should-have | specified | — | — |
| REQ-COM-003 | Direct-to-User Communication | should-have | specified | — | — |
| REQ-COM-004 | Question Classification | must-have | specified | — | — |
| REQ-COM-005 | Parent-Controlled Notification Mode | should-have | specified | — | — |
| REQ-COM-006 | Message Protocol Expectations | must-have | specified | — | — |
| REQ-COM-007 | Discovery Sharing | should-have | specified | — | — |
| REQ-COM-008 | Jake as Communication Hub | must-have | tested | CommandRegistry.swift, TavernCoordinator.swift, Jake.swift | TavernCoordinatorTests.swift, JakeTests.swift |


## Module 010 — Doc Store (REQ-DOC)

**Active:** 5 | **Dropped:** 3 | **Coverage:** 60% (0 implemented, 3 tested, 2 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-DOC-006 | Authoritative Display | should-have | specified | — | — |
| REQ-DOC-007 | Hygiene — Dead Agent Cleanup | must-have | specified | — | — |
| REQ-DOC-001 | Filesystem Identity | must-have | tested | DocStore.swift, Document.swift, DocumentStore.swift | DocStoreTests.swift |
| REQ-DOC-002 | Source of Truth | must-have | tested | DocStore.swift, DocumentStore.swift | DocStoreTests.swift, ServitorPersistenceTests.swift |
| REQ-DOC-003 | Multi-Purpose Storage | must-have | tested | DocStore.swift, Document.swift | DocStoreTests.swift |

**Dropped:** ~~REQ-DOC-004~~ (Three Storage Layers), ~~REQ-DOC-005~~ (Session Lifecycle), ~~REQ-DOC-008~~ (Path Encoding)


## Module 011 — Sandbox (REQ-SBX)

**Active:** 8 | **Dropped:** 0 | **Coverage:** 0% (0 implemented, 0 tested, 8 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-SBX-001 | Five Sandbox Primitives | must-have | specified | — | — |
| REQ-SBX-002 | Changeset as Diff | deferred | specified | — | — |
| REQ-SBX-003 | Source Control Orthogonality | must-have | specified | — | — |
| REQ-SBX-004 | Preflight Checks | must-have | specified | — | — |
| REQ-SBX-005 | Preflight Fail-Fast | must-have | specified | — | — |
| REQ-SBX-006 | Platform Configuration | deferred | specified | — | — |
| REQ-SBX-007 | Isolation Levels | deferred | specified | — | — |
| REQ-SBX-008 | Connector Control | deferred | specified | — | — |


## Module 012 — Workflows (REQ-WRK)

**Active:** 7 | **Dropped:** 3 | **Coverage:** 0% (0 implemented, 0 tested, 7 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-WRK-001 | Workflow as State Machine | deferred | specified | — | — |
| REQ-WRK-004 | User-Modifiable Templates | deferred | specified | — | — |
| REQ-WRK-006 | Merge Queue | deferred | specified | — | — |
| REQ-WRK-007 | Spec Engine | deferred | specified | — | — |
| REQ-WRK-008 | Workflow Composability | deferred | specified | — | — |
| REQ-WRK-009 | Workflow Engine | deferred | specified | — | — |
| REQ-WRK-010 | Workflow Recovery | deferred | specified | — | — |

**Dropped:** ~~REQ-WRK-002~~ (Rule of Five Template), ~~REQ-WRK-003~~ (Verification Layers Template), ~~REQ-WRK-005~~ (Gang of Experts)

**Note:** Index claims 8 requirements but file has 10 total headings (7 active + 3 dropped). REQ-WRK-009 and REQ-WRK-010 were likely added after the index was last updated.


## Module 013 — User Experience (REQ-UX)

**Active:** 11 | **Dropped:** 1 | **Coverage:** 73% (7 implemented, 1 tested, 3 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-UX-004 | No Unsolicited Content | must-have | specified | — | — |
| REQ-UX-010 | Progressive Unlock Concept | should-have | specified | — | — |
| REQ-UX-012 | Three-Choice Consent Pattern | should-have | specified | — | — |
| REQ-UX-001 | Fresh Project Entry | must-have | implemented | ProjectView.swift, WindowBoardView.swift | — |
| REQ-UX-003 | Agent Discovery | must-have | implemented | ServitorListTile.swift, ServitorListTileView.swift | — |
| REQ-UX-005 | Stream Separation | should-have | implemented | MessageRowView.swift | — |
| REQ-UX-006 | Content Block Rendering | must-have | implemented | MessageRowView.swift | — |
| REQ-UX-007 | Project-as-Document | must-have | implemented | TavernApp.swift, WindowOpeningService.swift, ProjectManager.swift | — |
| REQ-UX-008 | Multi-Window Support | must-have | implemented | TavernApp.swift, WelcomeView.swift | — |
| REQ-UX-009 | Chat Controls | must-have | implemented | ChatTileView.swift, ChatTile.swift | — |
| REQ-UX-002 | Task-as-Chat | must-have | tested | ServitorListTile.swift, ServitorListTileView.swift, ChatTileView.swift, ChatTile.swift, SidebarSurface.swift, DetailSurface.swift | ChatTileTests.swift |

**Dropped:** ~~REQ-UX-011~~ (Progressive Unlock Open Questions)


## Module 014 — View Architecture (REQ-VIW)

**Active:** 11 | **Dropped:** 0 | **Coverage:** 36% (4 implemented, 0 tested, 7 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-VIW-002 | View Representations | should-have | specified | — | — |
| REQ-VIW-006 | Layout Persistence | should-have | specified | — | — |
| REQ-VIW-007 | Agent Layout Suggestions | deferred | specified | — | — |
| REQ-VIW-008 | Agent Layout Mutations | deferred | specified | — | — |
| REQ-VIW-009 | Context Cards | deferred | specified | — | — |
| REQ-VIW-010 | Drag and Drop | should-have | specified | — | — |
| REQ-VIW-011 | Animation Properties | should-have | specified | — | — |
| REQ-VIW-001 | Composable View Surface | should-have | implemented | MessageRowView.swift | — |
| REQ-VIW-003 | Granular View Primitives | should-have | implemented | MessageRowView.swift | — |
| REQ-VIW-004 | Agent Hierarchy View Independence | should-have | implemented | ServitorListTileView.swift | — |
| REQ-VIW-005 | Dead Agent Bodies | must-have | implemented | ServitorListViewModel.swift | — |


## Module 015 — Observability (REQ-OBS)

**Active:** 9 | **Dropped:** 2 | **Coverage:** 56% (3 implemented, 2 tested, 4 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-OBS-001 | Time Category Metrics | must-have | specified | — | — |
| REQ-OBS-002 | Agent Utilization Metrics | must-have | specified | — | — |
| REQ-OBS-003 | Human Metrics | should-have | specified | — | — |
| REQ-OBS-004 | Amplification Factor | must-have | specified | — | — |
| REQ-OBS-008 | Logging Modes | must-have | implemented | TavernLogger.swift | — |
| REQ-OBS-009 | Debug Build Agent Capabilities | must-have | implemented | TavernLogger.swift | — |
| REQ-OBS-011 | Discovery Sharing | should-have | implemented | Jake.swift, Mortal.swift | — |
| REQ-OBS-005 | Boundary Attempt Reporting | must-have | tested | PermissionManager.swift, PermissionRule.swift | PermissionEnforcementTests.swift, PermissionManagerTests.swift |
| REQ-OBS-006 | Violation Rule Immutability | must-have | tested | PermissionStore.swift | PermissionEnforcementTests.swift |

**Dropped:** ~~REQ-OBS-007~~ (Logging Categories), ~~REQ-OBS-010~~ (Meta Process)


## Module 016 — Quality (REQ-QA)

**Active:** 17 | **Dropped:** 1 | **Coverage:** 53% (3 implemented, 6 tested, 8 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-QA-004 | Fast Test Execution | must-have | specified | — | — |
| REQ-QA-007 | Parallel Code Path Testing | must-have | specified | — | — |
| REQ-QA-008 | Feature Toggle Coverage | must-have | specified | — | — |
| REQ-QA-010 | Symmetry Assertions | must-have | specified | — | — |
| REQ-QA-011 | New Entity = New Coverage | must-have | specified | — | — |
| REQ-QA-016 | Cancellation Design | should-have | specified | — | — |
| REQ-QA-017 | Full Coverage and Clean Builds | must-have | specified | — | — |
| REQ-QA-018 | Grade 2.9 — Local LLM Testing | should-have | specified | — | — |
| REQ-QA-001 | Automated Tests from Day Zero | must-have | implemented | TestFixtures.swift | — |
| REQ-QA-002 | Regression Detection | must-have | implemented | MockClaudeCode.swift, ServitorMessenger.swift, MockServitor.swift, ClodSession.swift, MockMessenger.swift | — |
| REQ-QA-013 | Logging Standards | must-have | implemented | TavernLogger.swift | — |
| REQ-QA-003 | Reproducible Test Environment | must-have | tested | MockAssertionRunner.swift, TestFixtures.swift | SDKDiagnosticTests.swift |
| REQ-QA-005 | External Dependency Stubs | must-have | tested | MockClaudeCode.swift, MockAssertionRunner.swift, ServitorMessenger.swift, LiveMessenger.swift, MockServitor.swift, MockMessenger.swift, ClodSession.swift | JakeTests.swift |
| REQ-QA-006 | Stress Testing | must-have | tested | — | SidePaneStressTests.swift, PermissionStressTests.swift, FileTreeStressTests.swift, MortalSpawnerStressTests.swift, ConcurrencyStressTests.swift, StreamingStressTests.swift, CommandDispatchStressTests.swift, SessionHistoryStressTests.swift |
| REQ-QA-009 | User Journey Integration Tests | must-have | tested | — | JakeIntegrationTests.swift, SDKLiveIntegrationTests.swift, MortalIntegrationTests.swift |
| REQ-QA-012 | Testing Grade System | must-have | tested | — | JakeIntegrationTests.swift, SDKLiveIntegrationTests.swift, SDKDiagnosticTests.swift, MortalIntegrationTests.swift |
| REQ-QA-014 | Perception-Bounded Performance | must-have | tested | — | PermissionStressTests.swift, FileTreeStressTests.swift, ConcurrencyStressTests.swift, StreamingStressTests.swift, SessionHistoryStressTests.swift |

**Dropped:** ~~REQ-QA-015~~ (RAM Budget)


## Module 017 — V1 Scope (REQ-V1)

**Active:** 17 | **Dropped:** 0 | **Coverage:** 47% (1 implemented, 7 tested, 9 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-V1-007 | Session Persistence | must-have | specified | — | — |
| REQ-V1-008 | Drone Agents | deferred | specified | — | — |
| REQ-V1-009 | Background Mode | deferred | specified | — | — |
| REQ-V1-010 | Sandbox | deferred | specified | — | — |
| REQ-V1-011 | Rewind | deferred | specified | — | — |
| REQ-V1-012 | Merge Queue | deferred | specified | — | — |
| REQ-V1-013 | Starter Templates | deferred | specified | — | — |
| REQ-V1-014 | Code Review | deferred | specified | — | — |
| REQ-V1-015 | Metrics Dashboard | deferred | specified | — | — |
| REQ-V1-003 | Servitor Sidebar | must-have | implemented | ServitorListTileView.swift, ChatViewModel.swift | — |
| REQ-V1-001 | Jake Responds in Character | must-have | tested | ProjectView.swift, WelcomeView.swift, Jake.swift | JakeTests.swift, JakeIntegrationTests.swift |
| REQ-V1-002 | MCP Tool Spawning Works | must-have | tested | TavernMCPServer.swift, Jake.swift | MortalSpawnerTests.swift, MortalIntegrationTests.swift |
| REQ-V1-004 | Spawned Servitor Receives Assignment | must-have | tested | MortalSpawner.swift | MortalSpawnerTests.swift |
| REQ-V1-005 | Servitor Done Flow | must-have | tested | Mortal.swift | MortalTests.swift, MortalIntegrationTests.swift |
| REQ-V1-006 | Mock Verification Pipeline | must-have | tested | CommitmentVerifier.swift | CommitmentTests.swift |
| REQ-V1-016 | Integration Tests Pass | must-have | tested | — | JakeIntegrationTests.swift, MortalIntegrationTests.swift |
| REQ-V1-017 | Naming Themes | should-have | tested | NamingTheme.swift, NameGenerator.swift | NamingTests.swift |


## Module 018 — Spec Fidelity (REQ-FID)

**Active:** 7 | **Dropped:** 0 | **Coverage:** 43% (0 implemented, 3 tested, 4 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-FID-001 | Completeness Verification | must-have | specified | — | — |
| REQ-FID-004 | Bidirectional Reference | must-have | specified | — | — |
| REQ-FID-005 | Status Derivation | must-have | specified | — | — |
| REQ-FID-006 | Coverage Verification | must-have | specified | — | — |
| REQ-FID-002 | Code Provenance Comments | must-have | tested | — | Tags.swift (TavernCoreTests, TavernTests, TavernStressTests, TavernIntegrationTests) |
| REQ-FID-003 | Test Provenance Tags | must-have | tested | — | Tags.swift (TavernCoreTests, TavernTests, TavernStressTests, TavernIntegrationTests) |
| REQ-FID-007 | Comment Format Specification | must-have | tested | — | Tags.swift (TavernCoreTests, TavernTests, TavernStressTests, TavernIntegrationTests) |


## Module 019 — States Modes (REQ-STM)

**Active:** 7 | **Dropped:** 0 | **Coverage:** 0% (0 implemented, 0 tested, 7 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-STM-001 | Canonical State Machine | must-have | specified | — | — |
| REQ-STM-002 | Three Orthogonal Boolean Properties | must-have | specified | — | — |
| REQ-STM-003 | Backgrounding Property | must-have | specified | — | — |
| REQ-STM-004 | Perseverance Property | must-have | specified | — | — |
| REQ-STM-005 | User Presence Property | must-have | specified | — | — |
| REQ-STM-006 | Configurable Inactivity Timeout | must-have | specified | — | — |
| REQ-STM-007 | State-Mode Interaction Rules | must-have | specified | — | — |


## Module 020 — Servitor Trees (REQ-TRE)

**Active:** 6 | **Dropped:** 0 | **Coverage:** 0% (0 implemented, 0 tested, 6 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-TRE-001 | Tree Structure | must-have | specified | — | — |
| REQ-TRE-002 | Operating Modes at Tree Positions | must-have | specified | — | — |
| REQ-TRE-003 | Failure Boundaries | must-have | specified | — | — |
| REQ-TRE-004 | Gang Termination via Capability | must-have | specified | — | — |
| REQ-TRE-005 | Token Budget Inheritance | must-have | specified | — | — |
| REQ-TRE-006 | Cross-Tree Communication | must-have | specified | — | — |


## Module 021 — Capability Delegation (REQ-CAP)

**Active:** 6 | **Dropped:** 0 | **Coverage:** 0% (0 implemented, 0 tested, 6 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-CAP-001 | Separation from Summon | must-have | specified | — | — |
| REQ-CAP-002 | Capability Handle Flow | must-have | specified | — | — |
| REQ-CAP-003 | Capability Types | must-have | specified | — | — |
| REQ-CAP-004 | Delegation Chains | must-have | specified | — | — |
| REQ-CAP-005 | Deterministic Shell Enforcement | must-have | specified | — | — |
| REQ-CAP-006 | Agents Cannot Modify Own Capabilities | must-have | specified | — | — |


## Module 022 — Chat Discussions (REQ-CDS)

**Active:** 5 | **Dropped:** 0 | **Coverage:** 0% (0 implemented, 0 tested, 5 specified)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-CDS-001 | Chat Discussion | must-have | specified | — | — |
| REQ-CDS-002 | Underlying Sessions | must-have | specified | — | — |
| REQ-CDS-003 | Session Resumption | must-have | specified | — | — |
| REQ-CDS-004 | Session Recreation | must-have | specified | — | — |
| REQ-CDS-005 | Contiguous Experience | must-have | specified | — | — |


---

## Summary

| Module | Prefix | Total | Specified | Implemented | Tested | Coverage% |
|--------|--------|-------|-----------|-------------|--------|-----------|
| 011-sandbox | REQ-SBX | 8 | 8 | 0 | 0 | 0% |
| 012-workflows | REQ-WRK | 7 | 7 | 0 | 0 | 0% |
| 019-states-modes | REQ-STM | 7 | 7 | 0 | 0 | 0% |
| 020-servitor-trees | REQ-TRE | 6 | 6 | 0 | 0 | 0% |
| 021-capability-delegation | REQ-CAP | 6 | 6 | 0 | 0 | 0% |
| 022-chat-discussions | REQ-CDS | 5 | 5 | 0 | 0 | 0% |
| 009-communication | REQ-COM | 8 | 7 | 0 | 1 | 13% |
| 006-lifecycle | REQ-LCM | 7 | 5 | 1 | 1 | 29% |
| 014-view-architecture | REQ-VIW | 11 | 7 | 4 | 0 | 36% |
| 018-spec-fidelity | REQ-FID | 7 | 4 | 0 | 3 | 43% |
| 002-invariants | REQ-INV | 9 | 5 | 1 | 3 | 44% |
| 017-v1-scope | REQ-V1 | 17 | 9 | 1 | 7 | 47% |
| 016-quality | REQ-QA | 17 | 8 | 3 | 6 | 53% |
| 015-observability | REQ-OBS | 9 | 4 | 3 | 2 | 56% |
| 010-doc-store | REQ-DOC | 5 | 2 | 0 | 3 | 60% |
| 004-agents | REQ-AGT | 10 | 3 | 0 | 7 | 70% |
| 013-user-experience | REQ-UX | 11 | 3 | 7 | 1 | 73% |
| 003-system-architecture | REQ-ARCH | 9 | 2 | 4 | 3 | 78% |
| 007-operating-modes | REQ-OPM | 6 | 1 | 3 | 2 | 83% |
| 005-spawning | REQ-SPN | 10 | 1 | 0 | 9 | 90% |
| 008-deterministic-shell | REQ-DET | 6 | 0 | 4 | 2 | 100% |
| **TOTAL** | | **181** | **100** | **31** | **50** | **45%** |

All counts are active requirements only (13 dropped requirements excluded).


---

## Anomalies

### Orphaned Provenance (dropped requirements with code/test markers still present)

- **REQ-ARCH-006** (dropped): code in MortalSpawner.swift, test in ServitorRegistryTests.swift

- **REQ-DET-006** (dropped): code in TavernMCPServer.swift

- **REQ-DOC-004** (dropped): code in ClaudeNativeSessionStorage.swift, SessionStore.swift

- **REQ-DOC-005** (dropped): code in ClaudeNativeSessionStorage.swift, Jake.swift

- **REQ-DOC-008** (dropped): code in SessionStore.swift

- **REQ-OBS-007** (dropped): code in TavernLogger.swift

### Index Discrepancy

- **Module 012** (workflows): index claims 8 requirements but file has 10 total headings (7 active + 3 dropped). REQ-WRK-009 and REQ-WRK-010 were likely added after the index was last updated.

### Must-Have Gaps (must-have requirements still at `specified` status)

Many must-have requirements remain at specified status. This is expected for features not yet implemented. Key must-have gaps by area:

- **Invariants:** REQ-INV-001 (Test Suite Gate), REQ-INV-002 (Universal Testability), REQ-INV-004 (Sacred User Attention), REQ-INV-008 (Original File Protection), REQ-INV-009 (Sandbox Boundary)

- **Architecture:** REQ-ARCH-001 (Tech Stack), REQ-ARCH-010 (No Sandbox Entitlement)

- **Agents:** REQ-AGT-006 (Task Modes)

- **Lifecycle:** REQ-LCM-001 (Fish-or-Cut-Bait), REQ-LCM-002 (Token Budget)

- **Communication:** REQ-COM-001 (Upward Bubbling), REQ-COM-004 (Question Classification), REQ-COM-006 (Message Protocol)

- **Doc Store:** REQ-DOC-007 (Dead Agent Cleanup)

- **Sandbox:** REQ-SBX-001 through SBX-005 (sandbox primitives — architecture deferred for most)

- **User Experience:** REQ-UX-004 (No Unsolicited Content)

- **Quality:** REQ-QA-004 (Fast Tests), REQ-QA-007 (Parallel Paths), REQ-QA-008 (Feature Toggle), REQ-QA-010 (Symmetry), REQ-QA-011 (New Entity Coverage), REQ-QA-017 (Full Coverage)

- **V1 Scope:** REQ-V1-007 (Session Persistence)

- **States/Modes:** REQ-STM-001 through STM-007 (entire module)

- **Servitor Trees:** REQ-TRE-001 through TRE-006 (entire module)

- **Capability Delegation:** REQ-CAP-001 through CAP-006 (entire module)

- **Chat Discussions:** REQ-CDS-001 through CDS-005 (entire module)

### Deferred-but-Implemented

(none found)
