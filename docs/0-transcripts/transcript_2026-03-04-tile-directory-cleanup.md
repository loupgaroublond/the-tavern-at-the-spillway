# Transcript: Tile Directory Cleanup

**Date:** 2026-03-04
**Sessions:** 85925660 (navigator extension), 805f6cd2 (tile cleanup)
**Context:** Post tile-migration cleanup — fixing multi-tile directories, a misnamed board module, and empty marker files


## Navigator Extension Extraction (Preceding Session)

**[U]** the windowboard that implements the navigator protocol, the navigator impl needs to be an extension in a separate section of the file. we always break tileboards up that way

*[T] Quick refactor — moved the `TavernNavigator` conformance from inline on the `WindowBoard` class to a separate `extension WindowBoard: TavernNavigator` block at the bottom of the same file. Establishes the pattern that tileboard protocol conformances live in extensions.*


## Tile Directory Cleanup

**[U]** we just did the tile migration, but there are a couple tile dirs that have more than one tile in them. also, there's a tile dir for workboard that's poorly named. thus we have these empty swift file turds we didn't need. let's fix that

*[T] Three issues identified: (1) `ApprovalTile/` contained two distinct tile types — `ToolApprovalTile` and `PlanApprovalTile`. (2) `TavernBoardTile/` was misnamed — it's the root board orchestrator, not a tile. (3) Both directories had empty 4-line "module marker" `.swift` files that existed solely to satisfy SPM's requirement for at least one source file in the module root.*

**[C]** For the TavernBoardTile rename — what should the new module name be? Options: TavernBoard (drop "Tile" suffix since it's an orchestrator) or WindowBoard (match the primary type name).

**[U]** TavernBoard

*[T] "TavernBoard" keeps the project namespace ("Tavern") in the module name while accurately reflecting that it's the board, not a tile. "WindowBoard" would match the class name but lose the namespace prefix.*


### Execution

**[C]** Executed the three changes:

1. **Split `ApprovalTile/` → `ToolApprovalTile/` + `PlanApprovalTile/`** — moved tile + view files into separate directories, split the shared `ApprovalResponder.swift` into per-tile responder files (`ToolApprovalResponder.swift`, `PlanApprovalResponder.swift`), deleted the old directory including the marker file.

2. **Renamed `TavernBoardTile/` → `TavernBoard/`** — renamed directory, deleted the marker `TavernBoardTile.swift`. `WindowBoard.swift` is the real entry point.

3. **Updated all references** — `Package.swift` (new SPM targets), `project.yml` (new XcodeGen targets, bundle IDs, embed list), import statements in 5 consumer files.

Build succeeded. Xcode automatically cleaned up the stale `ApprovalTile.framework` and `TavernBoardTile.framework` from the build products.

All Grade 1+2 tests passed. All 14 Grade 3 integration tests passed.


### Rule Documentation

**[U]** also, emphasize this in the ADRs and other rules as appropriate

**[C]** Documented the "one tile per module" rule in three places:

- **ADR-008 Tile Anatomy section** — "Each SPM tile target contains exactly one tile class. If a module needs two distinct tile types, split them into separate modules."

- **CLAUDE.md Honor System** — new bullet: "One tile per SPM module — if a module needs two tile types, split them into separate targets (ADR-008)"

- **CLAUDE.md Core Patterns** — appended to "Tiles Own All State": "One tile per SPM module — each tile target contains exactly one tile class."

Also updated ADR-008's SPM Module Map to reflect the new module names, and added the `Tiles/` subtree to CLAUDE.md's Project Structure.


___

**[S]** This session established the **one-tile-per-module invariant** — each SPM tile target contains exactly one tile class. The rationale: precise dependency graphs (consumers import only what they need), no empty marker files, and clear module boundaries. When a module accumulates two tile types, it's a signal to split. The rule joins the Honor System alongside preview requirements and provenance tracking.

The naming decision — **TavernBoard** over WindowBoard — reveals a preference for project-namespace-prefixed module names even when the primary type inside has a different name. The module is `TavernBoard`; the class inside is `WindowBoard`.

Tileboard protocol conformances (like `TavernNavigator`) belong in extensions, not inline on the class. This keeps the main class body focused on owned state and the conformance clearly demarcated.
