# Transcript: TavernKit Consolidation — Eliminating Core* Indirection

**Date:** 2026-03-01
**Session:** Continuation of tileboard architecture session (2026-02-28)
**Topics:** Dependency graph analysis, Core* module questioning, "importing up" vs "peering in", TavernKit creation, CoreUI dissolution, compiler enforcement rationale, infinite recursion bug, "sockets lift up" pattern, test timeout coverage

---

## Part 16: Dependency Graph Analysis

[U] When this is done, can we make a complete and fully detailed import dependency tree? I'm questioning whether CoreUI and CoreModels needs to be separate from TavernCore at all, and the one argument against combining them is that there are clear dependencies on Core* modules that don't need TavernCore.

I doubt we'll see any legitimate use cases, but we must be thorough and check first, so a complete diagram is essential.

[U] Actually, build the graph now.

[T] *Claude audits every module's actual imports, cross-referencing declared dependencies in Package.swift against real `import` statements. Discovers several declared-but-unused dependencies (ApprovalTile declares CoreUI but never imports it, etc.).*

[C] Produced the complete dependency graph as a flat edge list and import matrix. Key finding on the central question — who uses CoreUI:

Only 3 consumers, using only 3 types:
- ChatTile: MessageRowView, MultiLineTextInput
- ResourcePanelTile: LineNumberedText
- TavernTests: (declared but only via test target)

TavernCore does NOT import CoreUI. TavernBoardTile does NOT import CoreUI. 3 of 5 leaf tiles do NOT import CoreUI.

CoreProviders has legitimate standalone consumers — 4 leaf tiles and TavernBoardTile all depend on its protocols without needing TavernCore. CoreModels is the same story — every tile needs the value types without needing ClodKit.

CoreUI is the questionable one. Only 2 tiles actually import it, using just 3 views. The "independent consumer" argument is thin — these 3 views could live in the tiles that use them.

[U] This graph has cycles. That is not a correct graph.

[C] The ASCII art had arrows pointing the wrong way. Switched to a flat edge list format.

[U] TavernCore doesn't depend on CoreModels?

[C] It does — the flat list has the edge `TavernCore --> CoreModels` and `TavernCore --> CoreProviders`. The ASCII diagram was broken, which is why it was abandoned for the flat list.

[U] No, I need to see an actual graph. Can you make a Mermaid graph, and embed it in a markdown file?

[C] Wrote `docs/4-docs/dependency-graph.md` with proper Mermaid diagrams showing the complete dependency graph, unused dependencies, and the CoreUI analysis.

---

## Part 17: What's Really in CoreUI?

[U] What's in CoreUI really?

[C] 6 views, ~1030 lines. Of those, only 3 are actually imported by anyone:

- **MessageRowView** (286 lines) — renders a single chat message with role styling. Used by ChatTile.
- **MultiLineTextInput** (276 lines) — NSViewRepresentable wrapping NSTextView for multi-line input. Used by ChatTile.
- **LineNumberedText** (57 lines) — displays text with line numbers. Used by ResourcePanelTile.

The other 3 are orphans:

- **CodeBlockView** (105 lines) — syntax-highlighted code block rendering
- **DiffView** (127 lines) — side-by-side diff display
- **CollapsibleBlockView** (179 lines) — expandable/collapsible content sections

Those 3 were moved from the old Views/ directory during Phase 2 anticipating they'd be shared across tiles for content block rendering, but nothing uses them yet.

[U] Are any of those common items? Seems to me like they belong with tiles.

Next question, if we swapped out CoreProviders and CoreModels for other theoretical modules, does that even make sense for TavernCore? If we can't thread that needle, we need to have a good reason to separate the model types. Do all the tiles ever talk to TavernCore's package directly?

[C] On the first point — yes, MessageRowView and MultiLineTextInput are chat-specific (ChatTile), LineNumberedText is file-viewing-specific (ResourcePanelTile), and the other 3 are unused. They're not "common" in any real sense.

No tile imports TavernCore. That's the whole point of the separation — tiles see only CoreModels types and CoreProviders protocols, never the concrete implementations.

But the question cuts deeper: could you swap CoreModels for something else and have TavernCore still work? No. `ChatMessage`, `StreamEvent`, `ServitorState`, `PermissionMode`, `TavernError` — these aren't abstract vocabulary that multiple domain implementations could share. They're Tavern's domain types that got extracted into a separate module purely so tiles can see them without importing TavernCore (and transitively getting ClodKit).

The real dependency constraint is one-directional: **tiles must not see ClodKit**. That's the actual invariant. CoreModels and CoreProviders exist as a mechanism to enforce that — they're the "ClodKit-free surface" of TavernCore.

The honest answer: CoreModels and CoreProviders are Tavern-specific types with no plausible alternate consumers. The separation adds 2 modules and 20 files of indirection to enforce something that could be enforced with a single module.

---

## Part 18: "Importing Up" vs "Peering In"

[U] TavernBoardTile is importing up, because it's utilizing the other tiles. It doesn't peer into private or internal interfaces, make sense?

We can't rely on code review, that's the whole reason for this. If TavernCore has a strong public/private interface barrier to make sure tiles can't get at concrete classes, and that is compiler enforceable, then we need to make sure certain things don't become public accidentally. It sounds like we have two sides to TavernCore here. One is the "interfaces" side, protocols, types and typealiases, that should be available to everyone, and then a TavernCore that implements the interfaces, but is only used in key places. Can you sketch out a simplified graph what this could look like?

[T] *This is the pivotal correction. Claude had argued code review was sufficient; the user pushes back firmly: the whole reason for modularization is compiler enforcement, not code review. The user distinguishes "importing up" (using a module's public API, which is fine) from "peering in" (accessing private/internal implementation details, which must be prevented). The user identifies the need to split TavernCore into two sides: a public "interfaces" side and a private "implementation" side.*

[C] Produced a proposed dependency graph showing CoreModels + CoreProviders merged into a single "TavernKit" module. The key insight: CoreModels, CoreProviders, and CoreUI are three modules doing one job — being the "ClodKit-free public surface." One module (TavernKit) does that job equally well. Tiles get the same compiler guarantee (can't reach ClodKit or concrete implementations), TavernCore stays the private implementation side, and we lose 3 modules worth of indirection.

___

[S] *The distinction between "importing up" and "peering in" is the design principle that justifies the module structure. TavernBoardTile imports leaf tiles — that's importing up (using public APIs). A tile importing TavernCore would be peering in (seeing concrete implementations and ClodKit). TavernKit is the firewall: it holds everything tiles need to see, and nothing they shouldn't.*

---

## Part 19: The Decision — TavernKit and CoreUI Dissolution

[U] Let's eliminate CoreUI completely by moving those views to where they belong. If two tiles want to share a single concrete view, we can create a side package for those views, give it a semantic name and make that a dependency of both of those tiles. Otherwise, CoreUI is implementation, not interface.

TavernKit is a good name, because then it conveys a framework of interlocking objects with a consistent interface provided by that package, where the implementation is hidden.

Let's fix this up now.

[T] *The user resolves the three-module question decisively: CoreUI is implementation (concrete views), not interface. It gets dissolved — views move to their owning tiles. CoreModels and CoreProviders merge into a single module called TavernKit, which becomes the compiler-enforced public interface surface. TavernCore remains the private implementation that only the app target and TavernBoardTile ever import.*

[C] Executed the consolidation:
1. Created `Sources/TavernKit/` with all 14 CoreModels files + 5 CoreProviders protocol files
2. Moved CoreUI views to their consuming tiles (5 to ChatTile, 1 to ResourcePanelTile)
3. Deleted `Sources/Core/` entirely
4. Updated all imports across the codebase (`import CoreModels` → `import TavernKit`, etc.)
5. Rewrote Package.swift and project.yml
6. Build succeeded — 12 modules reduced to 9

---

## Part 20: The Infinite Recursion Bug

[T] *After the consolidation, user ran the app and hit EXC_BAD_ACCESS.*

[U] Also, can you see the errors in the debugging process in Xcode? I ran the Tavern app, but it hit EXC_BAD_ACCESS.

[C] Checked the issue navigator — no build errors. The crash is runtime, only visible in the debug navigator.

[U] `Self.logger.info("[WindowBoard] selectServitor: \(id)")` Thread 1: EXC_BAD_ACCESS (code=2, address=0x16ab3bfa0). 107 of WindowBoard, invokes logging.

[C] EXC_BAD_ACCESS code=2 at a logging line is a stack overflow (hit the guard page). This means infinite recursion. Traced the cycle:

1. `WindowBoard.selectServitor(id:)` (line 107) calls `servitorListSocket.tile.selectServitor(id:)`
2. `ServitorListTile.selectServitor(id:)` (line 46) calls `responder.onServitorSelected(id)`
3. The responder's `onServitorSelected` closure (ServitorListSocket line 18) calls `nav.selectServitor(id:)` — back to step 1

WindowBoard.selectServitor should NOT call `servitorListSocket.tile.selectServitor` — it should just update the tile's selected state directly without going through the responder.

[T] *Initial fix attempted to set `selectedServitorId` directly on the tile from the board. This failed — `selectedServitorId` was `internal` in ServitorListTile, so the board (different module) couldn't access it. Added a public `setSelectedServitor(id:)` method instead.*

---

## Part 21: "Sockets Must Lift Up"

[U] Why is the board modifying a tile? Sockets must lift up.

[T] *The user catches a design violation in the fix. The board should never reach into a tile to modify its state directly. The socket exists precisely as the intermediary layer between board and tile. "Lift up" means the socket should expose the method, and the board talks to the socket, not the tile.*

[C] You're right — the board should talk to the socket, not reach through to the tile. The socket is the intermediary.

Refactored: added a `selectServitor(id:)` method on ServitorListSocket that updates the tile's selected state without triggering the responder callback. The board calls `servitorListSocket.selectServitor(id:)` instead of reaching through to the tile.

Build succeeded. Board now goes through the socket, socket talks to the tile. The layering is preserved: board → socket → tile, with no reverse callbacks.

[U] Yeah, that works.

___

[S] *The "sockets lift up" principle is the corollary to the responder pattern. Responders are how tiles communicate upward (tile → socket → board). When the board needs to communicate downward, it goes through the socket too (board → socket → tile). The board never touches a tile directly in either direction. The socket is always the intermediary.*

---

## Part 22: Test Timeout Coverage

[U] Can you run the testing suite component by component and find the slow tests? Also, make sure every test in code has explicit timeouts, to ensure the whole test suite never runs for too long.

[U] Integration tests must also have sensible timeouts.

[C] Audited all 116 test functions across the codebase. Found that only 4 files had `executionTimeAllowance` set. Added explicit timeouts to every test class:

| Test Target | Timeout | Framework |
|-------------|---------|-----------|
| TavernCoreTests (54 suites) | 1 minute | Swift Testing `.timeLimit(.minutes(1))` |
| TavernTests (wiring + SDK) | 10 seconds | XCTest `executionTimeAllowance` |
| TavernIntegrationTests | 30–60 seconds | XCTest `executionTimeAllowance` |
| TavernUITests | 120 seconds | XCTest `executionTimeAllowance` |
| TavernStressTests (9 classes) | 30 seconds | XCTest `executionTimeAllowance` |

Grade 1+2 tests: 583 tests in 54 suites, all passed in 0.626 seconds.

Grade 3 tests could not run — Claude CLI refuses to start inside another Claude Code session (`CLAUDECODE` env var). Must be run from standalone terminal.

[U] Take a look at the Grade 3 tests, try to calculate the longest it should take if everything times out.

[C] 48 Grade 3 tests × 60s timeout each = 47.5 minutes worst case. Most should complete in seconds. Realistic wall time with a few failures: 5–10 minutes.
