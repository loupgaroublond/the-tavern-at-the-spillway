# Swarm Audit Report — 2026-02-08

## Scope

A multi-agent team executed 78 beads and closed them in a single session. This audit verifies completeness and quality using 9 independent review agents examining the codebase from different angles.

**Audit methodology:**
- 3 bead completeness auditors (epics 1-3, 7-9, standalone beads)
- 1 spec-filling bead auditor (16 spec modules)
- 4 code reviewers (Views, Commands+Permissions, Core business logic, Test suite)
- Manual verification of test framework mismatch (Swift Testing vs XCTest)

---

## Executive Summary

| Category | Result |
|----------|--------|
| Closed beads | 78 |
| Verified complete | 73 |
| Verified partial | 2 (`/hooks`, `/mcp` — view-only, beads claimed edit capability) |
| Duplicates | 2 (7g6, w3u — same work as Epic 2) |
| Test artifact | 1 (ate — intentional test bead) |
| Spec modules filled | 16/16 (155 requirements) |
| Grade 1+2 tests | 526 passing (Swift Testing) |
| Architecture grade | A |
| Code quality grade | A- |
| Test coverage grade | A |

**Bottom line:** The swarm delivered real, substantial work. The implementation is architecturally sound, well-tested, and follows project conventions. Two beads were closed prematurely (partial work), and there are several medium-priority code issues to address.

---

## Part 1: Bead Completeness — Full Inventory

### 9 Epics

| Epic | ID | Beads | Verdict |
|------|----|-------|---------|
| 1: Message Rendering Overhaul | hq1 | 687, cyi, wue, vpp | 4/4 COMPLETE |
| 2: Streaming Responses | jhm | 0cy, fjb, b43 | 3/3 COMPLETE |
| 3: Input Enhancement | cgv | vu3, jsd | 2/2 COMPLETE |
| 4: Permissions Subsystem | m3o | 67c, bwy, no9 | 3/3 COMPLETE |
| 5: Slash Commands + Core | cxg | 462, 7nl, zjp, byq, hkg | 5/5 COMPLETE |
| 6: Custom Slash Commands | l2q | 9p3, 7g5 | 2/2 COMPLETE |
| 7: Management UIs | 2ah | 2yy, e2p, 2mo | 1/3 COMPLETE, **2/3 PARTIAL** |
| 8: Side Pane | 6ts | 9y6, kvn, o52 | 3/3 COMPLETE |
| 9: Chat UX Polish | vpv | (4 sub-features) | 4/4 COMPLETE |

### 35 Implementation Beads (Epic Children)

All verified against source code. Details below only for issues found.

**PARTIAL — e2p: `/hooks — view and edit lifecycle hooks`**

- Reads `.claude/hooks.json` and displays hook configuration
- **Missing:** No editing capability whatsoever. Users cannot add, remove, modify, enable, or disable hooks through the UI
- The bead title says "view and edit" — only "view" was implemented
- HooksCommand.swift is a read-only file parser (84 lines)
- Tests (in ManagementCommandTests.swift) only cover view behavior

**PARTIAL — 2mo: `/mcp — MCP server status, add/remove/reconnect`**

- Reads `.claude/mcp.json` and displays configured MCP servers
- Always shows built-in Tavern MCP server
- **Missing:** No add/remove/reconnect functionality. Status indicator is hardcoded placeholder ("unknown")
- The bead title says "add/remove/reconnect" — none of those were implemented
- MCPCommand.swift is a read-only file parser (93 lines)
- Tests only cover view behavior

### 23 Standalone Implementation Beads

| ID | Title | Verdict | Notes |
|----|-------|---------|-------|
| gfg | Jake system prompt broken | COMPLETE | Apostrophes restored, character voice intact |
| dd4 | Real commitment verification | COMPLETE | ShellAssertionRunner with Process, timeout, DI. 34 tests |
| p70 | Jake autonomous spawning via tool handler | COMPLETE | MCP tools (summon/dismiss) fully wired |
| cli | Agent sidebar status | COMPLETE | Color-coded circles, pulsing animation, accessibility |
| gkp | Per-tool progress indicator | COMPLETE | Tool name + elapsed time during execution |
| cu8 | Running cost/token display | COMPLETE | Header shows formatted token counts |
| fh0 | Custom commands in autocomplete | COMPLETE | Loaded and registered alongside built-ins |
| kwo | Subdirectory namespacing | COMPLETE | `/` to `:` conversion, recursive scanning |
| vvz | Max thinking tokens control | COMPLETE | /thinking command with off/default/numeric |
| 6eg | /stats — usage visualization | COMPLETE | Token bars, cost, rate, web search count |
| p37 | /context — visualization | COMPLETE | Context window bar, token breakdown |
| 9fq | /status — version/model/session | COMPLETE | Minor: "account" and "connectivity" not shown |
| xnp | Permission rules display/editing UI | COMPLETE | Mode picker, rule list, add/remove controls |
| afx | Don't Ask mode | COMPLETE | Auto-deny unmatched tools, enum + UI + logic |
| 2e0 | Streaming indicator | COMPLETE | Two-phase: cogitating then streaming |
| 2pt | Copy button on code blocks | COMPLETE | Hover-triggered, checkmark feedback |
| 24m | Error block styling polish | COMPLETE | Red avatar, warning icon, collapsible |
| pt3 | Web search result rendering | COMPLETE | Cyan/globe, collapsible block |
| zka | Inline diff rendering | COMPLETE | Auto-detect unified diff, color-coded lines |
| uai | Scroll-to-bottom button | COMPLETE | FAB, auto-hide when at bottom |
| 60c | Timestamps on messages | COMPLETE | Smart relative formatting |
| 6ap | Resource panel / file viewer | COMPLETE | Three-tab side pane, file tree + content viewer |
| ate | Test dep | N/A | Test artifact, intentionally closed |

### 2 Duplicate Beads

| ID | Title | Notes |
|----|-------|-------|
| 7g6 | Streaming responses | Duplicate of Epic 2 work, same implementation |
| w3u | Streaming responses | Duplicate of Epic 2 work, same implementation |

### 3 SDK/Legacy Beads

| ID | Title | Verdict |
|----|-------|---------|
| dec | ClodKit SDK migration | COMPLETE — ClodKit v1.0.0 integrated, all references updated |
| iy1 | Apostrophe bug | COMPLETE — Resolved by ClodKit migration, Jake prompt restored |
| 96m | SDK testing strategy | COMPLETE — AgentMessenger protocol with MockMessenger/LiveMessenger |

### 16 Spec-Filling Beads

| ID | Module | Reqs | Status |
|----|--------|------|--------|
| 72v | invariants.md (REQ-INV) | 8 | FILLED |
| phg | agents.md (REQ-AGT) | 10 | FILLED |
| yfc | operating-modes.md (REQ-OPM) | 6 | FILLED |
| lz6 | doc-store.md (REQ-DOC) | 8 | FILLED |
| 3p9 | deterministic-shell.md (REQ-DET) | 8 | FILLED |
| 3q0 | communication.md (REQ-COM) | 8 | FILLED |
| gyx | spawning.md (REQ-SPN) | 10 | FILLED |
| 4ij | user-experience.md (REQ-UX) | 11 | FILLED |
| pl9 | system-architecture.md (REQ-ARCH) | 10 | FILLED |
| gzq | observability.md (REQ-OBS) | 11 | FILLED |
| 1cb | quality.md (REQ-QA) | 16 | FILLED |
| 9gd | v1-scope.md (REQ-V1) | 17 | FILLED |
| ulh | lifecycle.md (REQ-LCM) | 7 | FILLED |
| 4lh | workflows.md (REQ-WRK) | 8 | FILLED |
| vij | view-architecture.md (REQ-VIW) | 9 | FILLED |
| kxw | sandbox.md (REQ-SBX) | 8 | FILLED |

**Total: 155 requirements across 16 modules.** All specs include testable requirement text, Mermaid behavior diagrams, open questions sections, and coverage gap identification. Index.md traceability matrix is accurate.

---

## Part 2: Code Quality Gap Analysis

### GAP-01: Permissions Not Wired to Tool Execution (HIGH)

**What's missing:** The permissions subsystem (PermissionManager, PermissionStore, PermissionMode, PermissionRule, ToolApprovalRequest — 59 tests, clean architecture) exists but is **not connected to anything**. No code outside the `Permissions/` directory references `PermissionManager`. When an agent executes a tool, no permission check occurs.

**Evidence:** Grep for `PermissionManager` outside Permissions/ returns zero matches. `ChatViewModel` does not reference permissions. `Jake.swift` and `Servitor.swift` do not check permissions.

**Impact:** The security boundary described in Epic 4 exists as code but provides zero protection. Tools execute unconditionally regardless of permission mode or rules.

**Recommendation:** Wire `PermissionManager.evaluateTool()` into the SDK's `canUseTool` callback in `LiveMessenger`.

---

### GAP-02: View Instrumentation Violations (MEDIUM)

**What's missing:** The project mandates 5 instrumentation requirements for SwiftUI views (body evaluation, conditional branches, lifecycle events, task execution, state changes). Several views violate this.

**Non-compliant views (missing ALL instrumentation):**

| View | Lines | Impact |
|------|-------|--------|
| AgentListView.swift | 314 | Cannot diagnose sidebar issues from logs |
| FileContentView.swift | 75 | Cannot diagnose file viewer issues |
| FileTreeView.swift | 64 | Cannot diagnose tree navigation issues |
| LineNumberedText.swift | 42 | Low impact (simple view) |
| MultiLineTextInput.swift | 208 | Logger defined on line 22 but **never used anywhere** |

**Partially compliant views (have body logging, missing lifecycle + state change logging):**

Most other views have body evaluation logging but lack `.onAppear`/`.onDisappear` logging and `.onChange` state tracking. Only TavernApp.swift and ToolApprovalView.swift are close to full compliance.

**None of the 16 views are fully compliant** with all 5 instrumentation requirements.

---

### GAP-03: Streaming Cancellation Race Condition (MEDIUM)

**Location:** Jake.swift:256, Servitor.swift:254

**What's wrong:** The cancel closure calls `innerCancel()` outside the serial queue, then sets `_isCogitating = false` inside the queue. Meanwhile, the stream's `.completed` handler also sets `_isCogitating = false` inside the queue. Both writes are to the same value so there's no data corruption, but:
- It violates the documented invariant that all `_isCogitating` access goes through the queue
- The ordering of `innerCancel()` vs queue operations is non-deterministic

**Impact:** Low in practice (both paths write `false`). Principle violation rather than functional bug.

---

### GAP-04: CommitmentVerifier Blocks Thread Pool (MEDIUM)

**Location:** CommitmentVerifier.swift:116 (`process.waitUntilExit()`)

**What's wrong:** `waitUntilExit()` blocks a cooperative thread pool thread. The project documents "never block the cooperative thread pool" as a core concurrency rule. With many concurrent commitment verifications, this could exhaust the pool.

**Recommendation:** Use `Process.terminationHandler` callback instead.

---

### GAP-05: Debug File Logging in Production Code (MEDIUM)

**Location:** ChatViewModel.swift (~line 161-177)

**What's wrong:** Session history loading writes to `/tmp/tavern_chat_debug.log`. This is:
- Left in production code (should be `#if DEBUG` guarded)
- Blocking file I/O on the main thread
- Grows unbounded (no rotation)

---

### GAP-06: Main Thread JSONL Parsing (MEDIUM)

**Location:** ChatViewModel.loadSessionHistory() (line 142+), ClaudeNativeSessionStorage.swift:165

**What's wrong:** JSONL parsing for session history happens on the main thread. For large sessions (hundreds of messages), this blocks the UI during app launch.

**Recommendation:** Move to `Task.detached` for the parsing work.

---

### GAP-07: Token Formatting Duplicated 5x (LOW)

**Location:** CompactCommand.swift:34, ContextCommand.swift:68, CostCommand.swift:58, StatsCommand.swift:75, ThinkingCommand.swift:70

**What's wrong:** Identical `formatTokens()` function copy-pasted into 5 files. Changes require 5 updates.

**Also duplicated:** `makeBar()` in ContextCommand.swift:61 and StatsCommand.swift:68.

---

### GAP-08: AnyAgent Type-Erasure Unnecessary (LOW)

**Location:** Agent.swift:51-83, AgentRegistry.swift:38

**What's wrong:** `AnyAgent` wraps agents via closure-based type erasure, but there are only 2 conformers (Jake, Servitor), both known at compile time. The project uses a "closed plugin set" — no dynamic loading. Modern Swift existentials (`any Agent`) would be simpler.

---

### GAP-09: Sidecar Pattern Documented But Not Implemented (LOW)

**Location:** CLAUDE.md architecture section, ADR-001

**What's wrong:** Architecture docs describe a "Sidecar Pattern for I/O — Main agent actors manage tree structure (fast, never block). Separate sidecar actors handle slow Anthropic I/O." In reality, Jake and Servitor directly call `messenger.query()` from their own queues. No separate sidecar actors exist.

**Recommendation:** Either implement sidecars or update documentation to reflect that async/await replaced the pattern.

---

### GAP-10: Dead Code and Unused Declarations (LOW)

| Item | Location | Issue |
|------|----------|-------|
| Unused DispatchQueue | PermissionManager.swift:18 | Declared, never used |
| `CommandContext.recordUsage()` | CommandContext.swift:40 | Method exists but is never called anywhere |
| `ClaudeSessionProtocol` | ClaudeSessionProtocol.swift | Protocol with single conformer, no testing benefit |

---

### GAP-11: TavernError Sum Type Incomplete (LOW)

**Location:** TavernError.swift

**What's wrong:** Only 2 cases: `.sessionCorrupt` and `.internalError(String)`. The `internalError` catch-all undermines the "sum type error design" principle. Missing specific cases for: agent name collision, commitment timeout, MCP server failure, permission denial.

---

### GAP-12: ChatViewModel State Booleans (LOW)

**Location:** ChatViewModel.swift lines 23-30

**What's wrong:** Multiple booleans track agent state (`isCogitating`, `isStreaming`, `currentToolName != nil`). These create intermediate states (e.g., `isCogitating=true, isStreaming=false`) that can cause UI flicker. A single `enum AgentActivityState { idle, cogitating, streaming, toolRunning(String) }` would be cleaner.

---

## Part 3: Test Coverage Analysis

### Corrected Test Count

The test suite review agent incorrectly reported commands and permissions as having "zero tests" because it searched for XCTest's `func test` pattern. **The codebase uses Swift Testing** (`@Test`, `@Suite`, `#expect`).

**Actual counts:**

| Area | @Test Methods | Framework |
|------|---------------|-----------|
| Commands (9 files) | 126 | Swift Testing |
| Permissions (5 files) | 59 | Swift Testing |
| Streaming | 23 | Swift Testing |
| ChatViewModel | 14 | Swift Testing |
| ChatPolish | 15 | Swift Testing |
| Commitments | 34 | Swift Testing |
| Agents (Jake, Servitor, Spawner) | 57 | Swift Testing |
| AgentRegistry | 10 | Swift Testing |
| Naming | 15 | Swift Testing |
| Side Pane (Todo, BackgroundTask, SidePane) | 46 | Swift Testing |
| File operations (Tree, Autocomplete, Resources, FileType) | 53 | Swift Testing |
| AgentList + Persistence | 33 | Swift Testing |
| Coordinator | 17 | Swift Testing |
| Other (Core, TavernTests) | 8 | Swift Testing |
| DocStore | 21 | Swift Testing |
| **Grade 1+2 Total** | **526** | **All passing** |

**Additional grades:**

| Grade | Target | Test Count | Framework |
|-------|--------|------------|-----------|
| 3 (Integration, real Claude) | TavernIntegrationTests | 32 | XCTest |
| 4 (XCUITest) | TavernUITests | 8 | XCTest |
| 5 (Stress) | TavernStressTests | 9 | XCTest |

### Test Coverage Gaps

**No untested features in the closed beads.** Every feature area has corresponding tests. The coverage is thorough for business logic and adequate for UI components (which rely on E2E tests per project convention).

**Areas with thinner coverage:**
- View instrumentation testing (no tests verify that logging actually fires)
- MultiLineTextInput (NSViewRepresentable — no unit tests, only E2E)
- Grade 5 stress tests lack performance assertions (verify "doesn't crash" but not "completes within X seconds")

---

## Part 4: What Was Done Well

1. **Massive throughput with consistent quality.** 78 beads, 85+ source files, 526 tests, 155 spec requirements — all in a single swarm session. The code follows established patterns throughout.

2. **Test-first discipline.** Every major feature has corresponding tests. The Swift Testing framework is used idiomatically with `@Suite` grouping, `@Test` descriptions, and `#expect` assertions.

3. **Architecture adherence.** New code follows the documented layer structure, thread safety model, and dependency injection patterns. Commands use the SlashCommand protocol cleanly. Permissions use serial queues correctly.

4. **Spec-filling work is excellent.** All 16 spec modules contain testable requirements with Mermaid diagrams, open questions, and gap identification. The traceability matrix is maintained.

5. **Streaming implementation is the highlight.** AsyncSequence integration, incremental UI updates, cancellation, error handling, and 23 symmetry-aware tests. Production-grade work.

---

## Part 5: Prioritized Action Items

### Tier 1: Correctness Issues

- [ ] **GAP-01**: Wire PermissionManager to tool execution path
- [ ] **GAP-05**: Remove or `#if DEBUG` guard the `/tmp/tavern_chat_debug.log` writing
- [ ] Reopen or create new beads for `/hooks` editing and `/mcp` add/remove/reconnect

### Tier 2: Reliability Issues

- [ ] **GAP-03**: Fix streaming cancellation race (move queue.sync before innerCancel)
- [ ] **GAP-04**: Replace `waitUntilExit()` with `Process.terminationHandler`
- [ ] **GAP-06**: Move JSONL parsing off main thread

### Tier 3: Maintainability

- [ ] **GAP-07**: Extract `formatTokens()` and `makeBar()` to shared utility
- [ ] **GAP-02**: Add instrumentation to 5 non-compliant views
- [ ] **GAP-09**: Update architecture docs to reflect actual concurrency model
- [ ] **GAP-10**: Remove dead code (unused queue, uncalled methods, single-conformer protocol)

### Tier 4: Design Polish

- [ ] **GAP-08**: Replace AnyAgent with `any Agent` existentials
- [ ] **GAP-11**: Add specific TavernError cases
- [ ] **GAP-12**: Replace ChatViewModel boolean state with single enum
- [ ] Clean up duplicate beads (7g6, w3u)

---

## Appendix: Open Beads Remaining

47 beads remain open in the backlog. These represent future work not claimed by the swarm:

- Background agent execution, inter-agent communication, hierarchical agent trees
- Composable tile view system, saved layouts
- Sidecar pattern, doc store continuous sync
- Calling/hanging up, perseverance mode
- Sandbox/changeset system, merge queue, rollback
- Workflow engine, gang of experts, drones/monitors
- Progressive unlocks, context cards, discovery sharing
- And more (see `bd list --status open -n 0` for full list)

---

*Report generated 2026-02-08 by 9 independent audit agents + manual verification.*
*526 Grade 1+2 tests passing. 78 beads audited. 12 gaps identified.*
