# Transcript: Preview Requirements and Crash Fix

**Date:** 2026-02-13 / 2026-02-14
**Sessions:** Plan creation + execution
**Topic:** Xcode preview crashes, universal preview coverage, ADR-006

---

[U] Some of the Xcode previews are crashing, logs are in the usual places. Also, let's get previews onto all the view files, and then, document this somewhere as a requirement to be enforced for the project — starting to sound like an ADR maybe.

[C] Investigated the crash logs. The `ProjectContentView` preview triggers a `fatalError` in SwiftUI's internal `OutlineListCoordinator` at `TableViewListCore_Mac2.swift:5170`. This is a macOS SwiftUI bug — `NavigationSplitView` with sidebar-style lists crashes during preview rendering when the outline view tries to diff rows. The `WelcomeView` preview works fine (confirmed "Completed: Initialized" in diagnostics).

[T] *The crash is specific to `NavigationSplitView` composing an `NSOutlineView`-backed sidebar list. The individual components (`AgentListView`, `ChatView`) preview fine on their own — it's only the composition inside `NavigationSplitView` that triggers it.*

[C] Preview coverage: 4 of 18 views have previews. Proposed a plan with four parts:

1. **Fix the crash** — Replace `NavigationSplitView` in the preview with `HSplitView`, showing sidebar and detail side-by-side
2. **Add `#Preview` blocks to all 14 missing views** — Each self-contained, using `/tmp/tavern-preview` as the standard project URL
3. **Write ADR-006** — Document the preview requirement formally
4. **Update CLAUDE.md Honor System** — Add the rule so Claude enforces it going forward

[U] *(Approved plan, executed via `do @plan`)*

___

[S] **Preview Requirements (ADR-006)**

Every SwiftUI view file must include at least one `#Preview` block. Previews must be self-contained — no dependency on running services, saved sessions, or real filesystem state. The standard preview project URL is `/tmp/tavern-preview`.

**NavigationSplitView workaround:** macOS SwiftUI has a known crash bug in `OutlineListCoordinator` during preview rendering. The fix is to preview component parts separately rather than composing them inside `NavigationSplitView`. Use `HSplitView` for side-by-side layout in previews.

**Implementation note:** The plan assumed `PermissionManager()` had a no-arg init, but it actually requires `PermissionManager(store: PermissionStore())`. Adjusted during implementation.

**Verification:** Build succeeded. All Grade 1+2 tests passed (pre-existing failures in permission enforcement and SDK integration tests confirmed via baseline comparison).
