# UI & Views Instructions

_Sources: 013-user-experience, 014-view-architecture, ADR-004 (ViewInspector), ADR-006 (Preview Blocks), ADR-008 (Tile Architecture)_

Load alongside `core.md` for work on views, tiles, UX, layout, or SwiftUI components.

---

## Tile Architecture (ADR-008)

### Core Rule
Tiles are `@Observable` objects that own all their state and logic. Views are pure renderers.

### What Views Do
- Layout, styling, gestures, bindings. Nothing else.
- Views must NEVER trigger state initialization, data loading, or lifecycle management.
- Views never call methods that load data or start processes.

### What Tiles Do
- Own all state.
- Initialize their own state at creation time (in the socket/pool).
- Handle all business logic, data loading, state transitions.
- Expose state for views to render.

### Module Structure
- **One tile per SPM module.** `ChatTile/`, `ServitorListTile/`, etc.
- Two tile types in one module = split into separate targets.
- Each tile module lives under `Tavern/Sources/Tiles/`.

### Existing Tiles
| Module | Tile | Purpose |
|--------|------|---------|
| `ChatTile` | ChatTile | Conversation |
| `ServitorListTile` | ServitorListTile | Sidebar agent list |
| `ResourcePanelTile` | ResourcePanelTile | File tree, tasks, TODOs |
| `ToolApprovalTile` | ToolApprovalTile | Tool execution approval |
| `PlanApprovalTile` | PlanApprovalTile | Plan approval |
| `PermissionSettingsTile` | PermissionSettingsTile | Permission settings |
| `TavernBoard` | TavernBoard | Root board, composes all leaf tiles |

---

## User Experience (REQ-UX)

### The Core Loop (REQ-UX-001)
User gives intent -> agents work -> user reviews results -> approve/modify/reject.

### Attention Model (REQ-UX-002)
- User attention is sacred (Invariant #4). Never force new content without consent.
- Notifications surface questions, don't interrupt flow.
- Operating mode (hands-on/supervisory/away) determines notification behavior.

### Bubbling (REQ-UX-003)
- Questions and status from agents bubble up through the tree to the user.
- Priority determines routing. High-priority items surface immediately.
- Low-priority items batch and present at natural breakpoints.

### Question Triage (REQ-UX-004)
- Questions classified by urgency and type.
- Blocking questions (agent can't proceed) get priority.
- Non-blocking questions (nice to know) queue.

### Progressive Unlocks (REQ-UX-005, deferred)
- Features unlock based on engagement. Not in V1.

---

## View Architecture (REQ-VIW)

### Multi-Window (REQ-VIW-001)
- Welcome window + per-project windows.
- Each project window has its own tile tree.
- Window restoration on app restart.

### Layout System (REQ-VIW-002)
- TavernBoard composes all leaf tiles.
- Layout is declarative, driven by tile tree structure.
- Tiles can be added, removed, rearranged.

### View-ViewModel Wiring (REQ-VIW-003)
- ViewModels are `@MainActor`.
- Views observe via `@Observable` / `@Bindable`.
- No `@StateObject`, `@ObservedObject`, `@EnvironmentObject`.

### Content Rendering (REQ-VIW-004)
- `MessageType` enum classifies content blocks.
- Thinking blocks, tool calls, text rendered by separate components.
- All rendering is passthrough (REQ-DET-002).

---

## SwiftUI Patterns

### Observation
- `@Observable` macro on all observable types.
- View side: `@State` for owned state, `@Bindable` for passed-in observable objects, `@Environment(Type.self)` for DI.
- `DynamicProperty` = struct with `@StateObject` inside (classes give inconsistent results).
- Content closures don't form dependencies: `List(items) { item in Text(item.name) }` does NOT track `item`.

### Tasks
- Always use `.task(id:)` when the task depends on a value that may change.
- Plain `.task` can run on stale view instances.
- Log task entry, guard failures, async results, and exit with UUID prefix for correlation.

### Instrumentation
Five things to log in views:
1. **Body evaluation** — `let _ = Self.logger.debug("[MyView] body - state: \(state)")`
2. **Conditional branches** — which branch the view takes
3. **Lifecycle events** — `.onAppear`, `.onDisappear`
4. **Task execution** — entry, guards, results, exit
5. **State changes** — via `.onChange`

---

## ViewInspector (ADR-004)

- Test-only SPM dependency. Does not ship in production.
- Grade 1-2 tests for view-ViewModel wiring.
- Catches binding regressions without launching the app.
- Test that views read from the right properties and write to the right bindings.

---

## Preview Blocks (ADR-006)

- Every SwiftUI view file must include at least one `#Preview` block.
- Previews use mock data or fixtures.
- Previews must compile and render without crashing.
- Multiple previews for different states (empty, loaded, error) are encouraged.

---

## Sidebar and Agent List

### ServitorListTile
- Shows all servitors with name, state, description.
- Dead agents persist with "dead" indicator.
- State icons reflect current servitor state.
- Clicking selects and focuses the chat tile on that servitor.

### Chat Description
- Visible in sidebar for each servitor.
- Mutable by both user and servitor.
- Includes original ask + current status.
- Persists across restarts.
