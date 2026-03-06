# Transcript: ObservableObject Eradication — Completion

**Date:** 2026-03-05
**Context:** Final phase of the ObservableObject → @Observable migration. The decision was made during tileboard architecture (2026-02-28). A first wave migrated 7 files via worktree (commit `7bce7ca`). This session completes the remaining 7 files.

**Prior sessions in this arc:**
- `transcript_2026-02-28-tileboard-architecture.md` — Decision: all tiles use @Observable from day one
- Session `e2bb2452` — User requested audit, worktree created for initial migration
- Commit `7bce7ca` — First wave: FileMentionAutocomplete, CommandContext, SlashCommandAutocomplete, SlashCommandDispatcher, ProjectManager, TavernProject, plus view-side wrappers
- Session `ae1bc179` — Remediation review confirmed first wave resolved flagged violations

---

## The Decision (from tileboard session, 2026-02-28)

**[U]** We never should have been using observable objects. Bigger question is, why do this in a separate step? What's the benefit?

*[T] User is pushing back on a phased approach — if tiles are being rewritten anyway, migrating the old ViewModels separately is wasted work.*

**[C]** Fair point. The argument was "smaller, independently testable diffs." But you're right that if we're decomposing into tiles anyway, every ViewModel file is getting rewritten or deleted. Migrating ObservableObject to @Observable in a file that's about to be replaced by a tile is wasted work. The better approach: migrate to @Observable as part of creating each tile.

**[U]** Let's do observable in one phase, then.

---

## The Audit (session e2bb2452)

**[U]** Can you audit for observable objects? We said we should switch away from that, so let's also make sure this ends up in the verification suite ADR to prevent.

**[C]** Got it — purge ObservableObject/@Published in favor of @Observable. Let me explore the codebase.

*[T] Found 14 ObservableObject classes in TavernCore and the app target. Tiles already use @Observable.*

**[U]** Give me a remediation plan. Do it in a branch in a worktree.

*[T] Created worktree on `worktree-observable-migration` branch. First wave of migration executed there, then merged to main as commit `7bce7ca`.*

---

## Final Eradication (this session, 2026-03-05)

**[U]** We were getting rid of observableobject, there's a stash with some changes, can you verify that we've eradicated everything? If not, see if the stash can help, and otherwise eradicate everything.

*[T] Found the stash at `stash@{0}` on `worktree-observable-migration`. Checked contents — it covers 6 files (FileMentionAutocomplete, CommandContext, SlashCommandAutocomplete, SlashCommandDispatcher, ProjectManager, TavernProject) but those are already migrated on the current branch. The stash is redundant.*

*[T] Found 7 remaining files still using ObservableObject/@Published. None of them are in the stash. 6 are dead code (replaced by Tiles), only ChatViewModel is actively used in production.*

**[C]** The stash files are already migrated on the current branch. The stash is redundant. The remaining 7 files that need migration are:

1. **ChatViewModel** — Active (via Coordinator), only file with `import Combine`
2. **TavernCoordinator** — Dead code (no production callers)
3. **ServitorListViewModel** — Dead code (replaced by ServitorListTile)
4. **ResourcePanelViewModel** — Dead code (tests only, replaced by ResourcePanelTile)
5. **TodoListViewModel** — Dead code (tests only)
6. **BackgroundTaskViewModel** — Dead code (tests only)
7. **PermissionSettingsViewModel** — Dead code (tests only, replaced by PermissionSettingsTile)

*[T] Applied mechanical transformation to all 7: replace `ObservableObject` conformance with `@Observable` macro, remove `@Published`, replace `import Combine` with `import Observation` where applicable.*

### Build Failure: @Observable Init Order

*[T] Build failed on TavernCoordinator: "variable 'self._servitorListViewModel' used before being initialized." The `@Observable` macro generates backing storage (`_servitorListViewModel`), and all stored properties need to be initialized before any property access because the macro synthesizes accessors that touch the observation registrar. The line `chatViewModels[jake.id] = jakeChatViewModel` triggered registrar access before `servitorListViewModel` was set.*

**[C]** Fix: reorder init to initialize `servitorListViewModel` before any property access that would trigger the observation registrar.

*[T] Reordered init: moved `servitorListViewModel` creation before `jakeChatViewModel` creation and the `chatViewModels` dictionary assignment. Build succeeded.*

### Verification

- Zero instances of `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` remain in `Tavern/Sources/`
- Build succeeds
- All Grade 1+2 tests pass
- Stash dropped (was redundant)

---

## Design Insight: @Observable Init Ordering

**Key lesson:** When migrating a class from `ObservableObject` to `@Observable`, the `@Observable` macro synthesizes accessor logic that touches the observation registrar. This means you cannot access *any* property (even via subscript like `dict[key] = value`) until *all* stored properties are initialized. With `ObservableObject`, property order in init didn't matter because `@Published` was just a property wrapper. With `@Observable`, the init order is load-bearing.

**Pattern:** In classes with cross-referencing stored properties, initialize all stored properties first, then do any mutation or cross-wiring as a second step.
