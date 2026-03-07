# Transcript: Remediation Review

**Date:** 2026-03-04
**Context:** Reviewing all gaps from the 2026-03-02 verification/attestation/audit reports. Walking through each item in depth, one by one, getting user approval before committing to any change. Plan file at `~/.claude/plans/mighty-spinning-bumblebee.md` has the raw inventory.

**Gap inventory source documents:**
- `docs/4-docs/verification-report_2026-03-02.md`
- `docs/4-docs/attestation-report_2026-03-02.md`
- `docs/4-docs/audit-spec-report_2026-03-02.md`
- `docs/4-docs/spec-status-report_2026-03-02.md`
- `docs/4-docs/sdk-parity-report_2026-03-02.md`

---

## Item 1: Orphaned Provenance Markers (6 dropped reqs with lingering code markers)

*[T] Six requirements were dropped from the spec, but their `// MARK: - Provenance: REQ-XXX-NNN` comments still exist in source files. These are misleading — they reference requirements that no longer exist. The question is: remove them outright, or update them to point at whatever active requirement superseded the dropped one?*

**The 6 orphans:**

1. **REQ-ARCH-006** (Closed Plugin Set) — markers in `MortalSpawner.swift`, test in `ServitorRegistryTests.swift`
2. **REQ-DET-006** (Jake's Tool Handler Protocol) — marker in `TavernMCPServer.swift`
3. **REQ-DOC-004** (Three Storage Layers) — markers in `ClaudeNativeSessionStorage.swift`, `SessionStore.swift`
4. **REQ-DOC-005** (Session Lifecycle) — markers in `ClaudeNativeSessionStorage.swift`, `Jake.swift`
5. **REQ-DOC-008** (Path Encoding) — marker in `SessionStore.swift`
6. **REQ-OBS-007** (Logging Categories) — marker in `TavernLogger.swift`

**[U]** The closed plugin requirement (ARCH-006) is moribund and needs to be dropped entirely from wherever it's referenced — not remapped, dropped. The rest can all be removed too.

*[T] User is clear: all 6 orphaned markers get removed, not remapped. Additionally, REQ-ARCH-006 itself (the "closed plugin set" concept from Shape I in ARCH-004) should be dropped as a concept — the system shouldn't be locked into a closed set of agent types. This means:*
- *Remove REQ-ARCH-006 from all MARK comments*
- *Remove the `.tags(.reqARCH006)` test tag*
- *Check if Shape I (Plugin) in REQ-ARCH-004 needs updating to reflect this*
- *Remove REQ-DET-006, DOC-004, DOC-005, DOC-008, OBS-007 from all MARK comments*
- *Add REQ-DOC-001 to ServitorStore/ServitorRecord where appropriate (replacing the removed DOC-004/DOC-008)*

**Decision: Remove all 6 orphaned markers. REQ-ARCH-006 (closed plugin set) is moribund — drop entirely, don't remap.**

**[U]** Shape I is rejected, it's meaningless, just cut it and tweak the rest of the doc to suit.

*[T] Shape I (Plugin — "closed set of agent types and spawners") in REQ-ARCH-004 is rejected as a concept. The system shouldn't constrain itself to a closed set. Remove Shape I from the seven architecture shapes in 003-system-architecture.md, making it six shapes. Adjust wording throughout.*

**Decision: Remove Shape I (Plugin) from REQ-ARCH-004. Architecture Shapes drops from seven to six.**

---

## Item 2: Stale Downstream Refs in Spec Modules

**[C]** Seven spec files have `Agents/` where they should say `Servitors/`, and three of those also say `ServitorSpawner.swift` instead of `MortalSpawner.swift`. The empty `Agents/` directory also still exists. This one feels straightforward — find-and-replace in the downstream reference sections of all 7 spec files, delete the empty directory. Any reason not to just do that?

**[U]** Just log that as another task.

**Decision: Log stale downstream refs as a task. Seven spec files need `Agents/` to `Servitors/` and `ServitorSpawner.swift` to `MortalSpawner.swift` renames, plus delete empty `Agents/` directory.**

---

## Item 1c: Module 012 Index Discrepancy

**[C]** The index claims 8 requirements for module 012 but the file has 10 headings (7 active + 3 dropped). REQ-WRK-009 and REQ-WRK-010 were added after the index was last updated.

**[U]** Explain a little more?

**[C]** The `000-index.md` file has a table that tracks every spec module — how many requirements each one has. For module 012 (workflows), the index says:

```
| 012 | 012-workflows.md | REQ-WRK | complete | 8 |
```

But the actual `012-workflows.md` file has **10** requirement headings:
- 7 active: WRK-001, 004, 006, 007, 008, 009, 010
- 3 dropped: ~~WRK-002~~, ~~WRK-003~~, ~~WRK-005~~

It looks like WRK-009 (Workflow Engine) and WRK-010 (Workflow Recovery) were added to the spec after the index was last touched. The index count of "8" was correct at the time — the original 8 were WRK-001 through WRK-008, then 002, 003, 005 got dropped and 009, 010 got added.

The fix is just updating the index row to say `10` instead of `8`. Or — do you want the index to track active vs total separately?

**[U]** Track both, update the index, move on.

**Decision: Update 000-index.md for module 012 count from 8 to 10. Update index format to track active vs total separately (apply to all modules, not just 012).**

---

## Item 1d: `.timeLimit` on Test Suites

**[C]** Seven test suites are missing `.timeLimit(.minutes(2))`:

- `TodoListViewModelTests`
- `ResourcePanelViewModelTests`
- `ChatViewModelTests`
- `BackgroundTaskViewModelTests`
- `PermissionSettingsViewModelTests`
- `TavernCoordinatorTests`
- `ChatViewModelCommandTests`

All other test suites in the project have `.timeLimit(.minutes(N))`. These 7 just got missed.

**[U]** Log and move on.

**Decision: Add `.timeLimit(.minutes(2))` to all 7 test suites. Mechanical fix.**

---

## Item 1e: @MainActor on ViewModels

**[C]** Already resolved by the Observable migration. Skipping.

**Decision: Skip — already resolved.**

---

## Item 1f: Dead Code Cleanup

**[C]** The verification report flagged dead/unwired code. There are really three categories:

**Category A: TavernCoordinator itself**

The whole class was dead — not instantiated anywhere in production. WindowBoard replaced it entirely per ADR-008. But it still had 31 Grade 1+2 tests and 5 Grade 3 integration tests, all passing. It was even migrated to `@Observable` in a recent commit — actively maintained dead code.

**Category B: Small dead methods/files (safe to delete)**

| Item | What | Lines |
|------|------|-------|
| `TavernCoordinator.dismissServitor(id:)` | Alias that calls `closeServitor` | 3 lines |
| `TavernCoordinator.reloadCustomCommands()` | Never called, file-watcher never built | 7 lines |
| `TavernCoordinator.refresh()` | Wrapper never called | 5 lines |
| `Mortal.updateChatDescription(_:)` | Public property is set directly instead | 4 lines |
| `FileTypeIcon` (TavernCore) | Duplicate — ResourcePanelTile has its own copy, this one is only tested, never used in production | file + test file |
| `ClaudeNativeSessionStorage.getAllSessions()` | Convenience method, zero callers | 12 lines |
| `ClaudeNativeSessionStorage.listProjects()` | Convenience method, zero callers | 24 lines |

If TavernCoordinator itself gets deleted, the first three go with it automatically.

**Category C: Keep (not really dead)**

| Item | Why Keep |
|------|----------|
| `CommitmentVerifier.verify(_:in:)` | Actually called by `verifyAll()` internally |
| `CommitmentVerifier.retryFailed(in:)` | Public API for future retry workflow, tested |
| `DocStore` / `ServitorPersistence` | Fully tested design scaffold for the "doc store is source of truth" invariant — not wired to runtime yet but represents future work |

**[U]** Write your questions down, just in case. I can't find TavernCoordinator anymore, is it gone? Group B can be deleted. Category C leave in place.

**[C]** Gone — TavernCoordinator and its tests have already been deleted. The research agents were working from a slightly stale view. That simplifies Category B — the three TavernCoordinator methods go with it.

So the remaining Category B deletions are:
- `Mortal.updateChatDescription(_:)` — 4 lines
- `FileTypeIcon` in TavernCore + its test file — 2 files
- `ClaudeNativeSessionStorage.getAllSessions()` — 12 lines
- `ClaudeNativeSessionStorage.listProjects()` — 24 lines

**Decision: TavernCoordinator already gone (Category A resolved). Category B: delete `Mortal.updateChatDescription`, `FileTypeIcon` duplicate, and two `ClaudeNativeSessionStorage` convenience methods. Category C: leave in place (design scaffold for future work).**

---

## New Feature: Debug Log Window

**[U]** When running in debug mode, which redo should do by default, the app should display a debug log window that scrolls by every log message and event for my insights into what's going on.

*[T] New feature request — not from the gap reports, but from the user directly. A dedicated window in debug builds that shows a live scrolling feed of all TavernLogger output and system events. This replaces the need to run `log stream` in a terminal or open Console.app. The app already has TavernLogger with 7 categories (agents, chat, coordination, claude, resources, permissions, commands) — this window would be a live consumer of those logs.*

*Open questions for design discussion:*
- *Window lifecycle: auto-open on debug launch? Togglable via menu item?*
- *Filtering: per-category toggles? Log level filter?*
- *Format: structured (columns for timestamp/category/level/message) or raw text scroll?*
- *Performance: buffering strategy to avoid UI lag from high-volume logging?*
- *Is this a tile in the existing tileboard, a separate window, or a panel?*
- *Search: live text search/filter within the log?*

**Status: Logged to plan, design questions recorded for future discussion.**

---

## SDK Gap Beads — Overview

**[U]** The beads are essentially stubs until we talk them out, give me the list of things, let's see which ones we want to fill out for work, vs leave stubbed for later.

**[C]** Here are the 20 untracked SDK gaps, grouped by theme:

**Model & Thinking Control (8 gaps)**
1. `options.model` — no model picker, always uses default
2. `options.fallbackModel` — no fallback model config
3. `options.maxThinkingTokens` — no thinking token limit
4. `options.thinking` (ThinkingConfig) — no adaptive/enabled/disabled toggle
5. `options.effort` — no effort level picker
6. `ClaudeQuery.setModel()` — can't change model mid-stream
7. `ClaudeQuery.setMaxThinkingTokens()` — can't change thinking tokens mid-stream
8. `ClaudeQuery.supportedModels()` — can't enumerate available models

**Budget (1 gap)**
9. `options.maxBudgetUsd` — no per-query budget cap

**File Rewind (2 gaps)**
10. `ClaudeQuery.rewindFiles(to:)` — can't rewind file changes to a message
11. `ClaudeQuery.rewindFilesTyped(to:dryRun:)` — typed version with dry-run

**MCP Management (4 gaps)**
12. `ClaudeQuery.mcpStatus()` — can't query MCP server status
13. `ClaudeQuery.reconnectMcpServer(name:)` — can't reconnect a server
14. `ClaudeQuery.toggleMcpServer(name:enabled:)` — can't enable/disable a server
15. `ClaudeQuery.mcpServerStatus()` — can't get per-server status

**Session Info (2 gaps)**
16. `ClaudeQuery.accountInfo()` — can't display account tier/limits
17. `ClaudeQuery.initializationResult()` — can't inspect session init info

**Hooks & Elicitation (2 gaps)**
18. `onNotification` hook — CLI notifications not surfaced in UI
19. `options.onElicitation` + request/result types — MCP server elicitation not handled

**Usage (1 gap)**
20. Per-model usage breakdown (`modelUsage` dictionary) — not parsed

**[U]** File rewind is stubbed. Every other one needs to be filled out. In your plan, write out everything for them, then, run "open" on the file, and tell me where to start reading.

**Decision: File rewind (2 items) stubbed for later. All other 18 gaps need filled-out implementation plans.**

---

## SDK Gap Beads — Design Discussion

**[U]** For model/thinking/effort (2a) and budget (2b): we need defaults. Do this at user level for now — create a provider and source for macOS UserDefaults. We dropped UserDefaults when we fixed servitor persistence, but we need to bring it back cleanly for this purpose. These defaults are applied to a servitor at servitor creation and persisted (in the servitor's `.tavern/` record).

**[U]** MCP configuration is per servitor, and again we can have some defaults. Jake's are always prewired to use a fixed set of MCP, though leave the option open for users to add more MCP servers to Jake. For now, MCP server config can actually just be JSON embedded in a code block in the markdown document for the servitor, matching the Claude Code schema. The default is always empty, with all the settings features to add default MCP servers and so on disabled and stubbed. They must be visible in the UI though.

**[U]** Account info is singleton — pulled from the Jake session. Session info is obviously per session.

*[T] Key design decisions captured:*

*1. **UserDefaults revival (clean)**: A new, clean UserDefaults-backed provider specifically for user-level defaults (model, thinking, effort, budget). This is NOT the old SessionStore pattern — it's a new "user preferences" layer. Defaults are stamped onto a servitor at creation time and then persisted in the servitor's `.tavern/` record. After creation, the servitor's config is independent of the defaults.*

*2. **Two-layer config pattern**: UserDefaults (user-level defaults) → ServitorStore (per-servitor persisted config). Defaults only apply at creation time — changing a default doesn't retroactively change existing servitors.*

*3. **MCP config in markdown**: Servitor's `.tavern/servitors/<name>/servitor.md` already has YAML frontmatter. MCP config goes as a JSON code block in the markdown body, matching Claude Code's `mcpServers` schema. This keeps it human-readable and editable.*

*4. **Jake's MCP is special**: Jake always has the tavern MCP server (summon/dismiss). Users can add more, but can't remove the built-in ones. Other servitors start with empty MCP config by default.*

*5. **Account info is singleton**: One `accountInfo()` call from Jake's session, shared across the whole app. Not per-servitor. Makes sense — account tier/limits don't change per servitor.*

*6. **MCP management UI is visible but stubbed**: The UI surfaces show MCP server status, but the "add default servers" management features are disabled/stubbed for now. Users see what's configured but can't manage defaults yet.*

**[C]** The two-layer pattern is clean. UserDefaults for "what a new servitor should look like by default" stamped into ServitorStore at creation time, persisted per-servitor from then on. This avoids the old mess where UserDefaults was doing double duty as both preferences AND persistence. Clear separation of concerns.

MCP config as a JSON code block in servitor.md is clever. It's human-readable, version-controllable, and doesn't require a new file format. One question — the servitor.md already has YAML frontmatter for structured data (name, id, sessionId, sessionMode). Why JSON in a code block rather than extending the YAML? Is it because you want to match the Claude Code MCP schema exactly and YAML/JSON translation is a headache?

Account info as singleton from Jake makes sense. Jake is the daemon — he's always running, always has a session. Pull it once, cache it, share it. No need to query it per-servitor.

The "visible but stubbed" approach for MCP management UI is pragmatic. Users can see what's configured, the architecture supports future management features, but we don't build the settings/defaults flow until we need it.

Three questions before updating the plan:

1. **Changing defaults after creation** — strictly creation-time only, or should there be a "reset to defaults" option on an existing servitor?

2. **Jake's fixed MCP set** — just `tavern` today, or do you anticipate more built-in MCP servers? This affects whether the "fixed set" is a single hardcoded server or a configurable list that happens to start with one entry.

3. **One JSON block per servitor doc** — or could a servitor doc accumulate multiple code blocks for different purposes (MCP config, future structured config)?

**[U]** 1) yes, 2) configurable, 3) one JSON block per MCP config for a servitor. We probably will have multiple code blocks, but for now, stay scoped to MCP.

*Resolved questions:*
- *Changing defaults: strictly creation-time, but offer a "reset to defaults" option on existing servitors*
- *Jake's fixed MCP set: configurable list that starts with `tavern`. Not hardcoded to one server — treat it as a list that can grow.*
- *Code blocks in servitor.md: one JSON code block per MCP config. Anticipate multiple code blocks for different purposes in the future, but scope to MCP for now.*

---

## Continuing After Compaction

*[T] The session was compacted here due to context limits. The conceiving discussion continued in the resumed session with the remaining pending items.*

**[U]** So... update the transcript...

**[U]** No, use a rewind agent.

*[T] The user directed the assistant to launch a rewind agent to reconstruct the missing transcript sections from the session log, rather than writing from memory after compaction.*

**[U]** Let's go on to 3.

*[T] The user moved on to Item 3 (test coverage for implemented code) while the rewind agent worked on transcript reconstruction.*

**[C]** Item 3 is about test coverage gaps for code that already exists — things that are implemented but have zero tests, or are partially tested with significant missing coverage. Presented as three categories:

**Category A — Implemented, Zero Tests:** 15 requirements across UX, view architecture, and observability modules — all view/tile testing (ViewInspector wiring tests for existing views). Mechanical work.

**Category B — Partial SDK implementations needing test coverage:** SDK features wired but not fully tested — CompletionInfo parsing, SessionUsage accumulation, streaming event pipeline.

**Category C — Architectural requirements with gaps:** Flagged as PARTIAL even though tests exist — more implementation gaps than test gaps.

**[U]** Break it down by test, or small group of very related tests. One bead per work unit.

**[U]** Just document this in the plan, how we'll break it up. You'll create all these beads once we have the full plan fleshed out.

**Decision: Test coverage work to be broken into individual beads, one per test or small group of related tests. Document the breakdown in the plan file first, create beads after the full plan is complete.**

___

**[S] Synthesis: Remediation Review Session**

This session walked through every gap from the 2026-03-02 verification suite, making item-by-item decisions. The key outcomes:

**Housekeeping (approved for execution):**
- All 6 orphaned provenance markers removed (no remapping)
- Shape I (Plugin / closed plugin set) dropped from architecture shapes — concept is moribund
- 7 stale spec refs logged for `Agents/` to `Servitors/` rename
- Module 012 index updated to track both active and total requirement counts
- 7 test suites get `.timeLimit(.minutes(2))`
- Dead code: TavernCoordinator already gone; small dead methods/duplicates approved for deletion; DocStore/ServitorPersistence island reclassified as dead code (delete)

**SDK gap design (new architecture):**
- **Two-layer config pattern**: UserDefaults (user-level defaults) stamped onto ServitorStore (per-servitor persistence) at creation time. "Reset to defaults" option for existing servitors.
- **MCP config in markdown**: JSON code blocks in `servitor.md` matching Claude Code `mcpServers` schema. Human-readable, version-controllable.
- **Jake's MCP set**: Configurable list starting with `tavern`, not hardcoded. Users can add but can't remove built-ins.
- **Account info singleton**: Pulled from Jake's session, shared app-wide.
- **UI philosophy**: Everything visible but management features stubbed for now.
- **File rewind**: Stubbed for later (needs message UUID tracking infrastructure).
- All other 18 SDK gaps get filled-out implementation plans.

**Test coverage (plan documented, beads deferred):**
- Break down into individual beads per test or small related group
- Create beads after full plan is complete

**Unimplemented modules (stub beads, one per module):**
- 019 States-Modes, 020 Servitor Trees, 021 Capability Delegation, 022 Chat Discussions, 006 Lifecycle gaps, 009 Communication
- Dependency chain: 019/021 are foundations → 020 builds on both → 009 builds on 020. 022 blocked on ClodKit session resume. 006 depends on SDK budget tracking.

**Unwired code — RESOLVED:**
- DocStore/ServitorPersistence island reclassified as dead code after user review. No remaining unwired code.

**Debug log window (designed):**
- Sink-based logging library replacing direct os.log. Two sinks: OSLogSink (always) + BufferSink (debug only).
- Infinite buffer, clears on restart, offload to disk if needed.
- NSPanel, menu toggleable, open/closed state in UserDefaults.
- Raw text scroll, per-category toggles, log level filter, text search, pause/resume.
- Entire feature `#if DEBUG` only — compiled out of release builds.
