# Transcript: Tileboard Addendum — Comment Style + ViewModel Elimination

**Date:** 2026-03-01
**Session:** Same session as tileboard-architecture and tavernkit-consolidation transcripts
**Topics:** Code comment style standard, ViewModel class elimination

---

## Part 23: Comment Style Standard

*[During Phase 3 tile creation, user reviewed the newly created tile source files.]*

[U] The comments do a lot of explaining "what", which was necessary for hybrid example, but not here. Can we clean those out, and stick to comments that explain things that are not immediately obvious in the code?

[C] Cleaned up over-documented comments across all tile modules, removing "what" explanations and keeping only comments that explain non-obvious behavior.

___

[S] *Code comments in the Tavern must explain "why", not "what." The hybrid-nav-example needed verbose "what" comments because it served as a teaching reference. Production Tavern code should only comment things that aren't immediately obvious from reading the code itself.*

---

## Part 24: ViewModel Elimination

*[After the main tileboard commit (f53f5f1, 148 files changed), user reviewed the codebase state.]*

[U] There should not be any class named ViewModel, so yes, let's do some deep analysis to clean up.

[C] Performed comprehensive analysis. Found 6 ViewModel classes still present:

- `ChatViewModel` — superseded by `ChatTile`
- `ServitorListViewModel` — superseded by `ServitorListTile`
- `ResourcePanelViewModel` — superseded by `ResourcePanelTile`
- `BackgroundTaskViewModel` — absorbed into `ResourcePanelTile`
- `TodoListViewModel` — absorbed into `ResourcePanelTile`
- `PermissionSettingsViewModel` — superseded by `PermissionSettingsTile`

Also found `TavernCoordinator` was only kept alive because `TavernProject` used it to create the `SlashCommandDispatcher`. Extracted command registration directly into `TavernProject`, eliminating the coordinator entirely.

Deleted all 6 ViewModel classes, deleted `TavernCoordinator`, rewrote or deleted 10+ test files. Final state: zero references to any ViewModel class in the entire codebase.

___

[S] *The tileboard pattern eliminates the ViewModel concept entirely. Tiles ARE the UX domain model — they own state, expose it to views via @Observable/@Bindable, and communicate via responder closures. The word "ViewModel" implies a passive data adapter between model and view; tiles are active participants that model the user's interaction. No class in the Tavern should carry the ViewModel suffix.*
