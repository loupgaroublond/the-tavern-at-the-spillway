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

## New Feature: Debug Log Window

**[U]** When running in debug mode, which redo should do by default, the app should display a debug log window that scrolls by every log message and event for my insights into what's going on.

*[T] New feature request — not from the gap reports, but from the user directly. A dedicated window in debug builds that shows a live scrolling feed of all TavernLogger output and system events. This replaces the need to run `log stream` in a terminal or open Console.app. The app already has TavernLogger with 7 categories (agents, chat, coordination, claude, resources, permissions, commands) — this window would be a live consumer of those logs.*

*Open questions for design discussion:*
- *Window lifecycle: auto-open on debug launch? Togglable via menu item?*
- *Filtering: per-category toggles? Log level filter?*
- *Format: structured (columns for timestamp/category/level/message) or raw text scroll?*
- *Performance: buffering strategy to avoid UI lag from high-volume logging?*
- *Is this a tile in the existing tileboard, a separate window, or a panel?*

**Status: Logged to plan, design discussion pending.**

---

## Item 2: Stale Downstream Refs in Spec Modules

