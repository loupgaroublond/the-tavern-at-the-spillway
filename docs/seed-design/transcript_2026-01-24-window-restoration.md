# Transcript: Multi-Window Architecture & Window Restoration

**Date:** 2026-01-24
**Session:** Multi-window support, per-project sessions, app icon, window restoration debugging, GUI instrumentation


## Multi-Window Architecture

**[U]** "i just tried to open a second project, no window popped up"

*[T] The app was single-window. Opening a second project replaced the first rather than creating a new window.*

**[C]** Implemented multi-window support:
- Changed `WindowGroup` to use `WindowGroup(for: ProjectWindowConfig.self)`
- Created `WindowOpeningService` to bridge AppKit ↔ SwiftUI window opening
- Used `@Environment(\.openWindow)` for SwiftUI-side window creation


## Window Behavior Specifications

**[U]** "when i click on recently opened, the welcome window should close. if i press command O, give me the welcome screen again. also, i need a button, in the toolbar, to raise all windows of this app to the front, like clicking the dock icon does."

**[C]** Implemented specified behaviors:
- Welcome window closes when opening a project from recent list
- Cmd+O brings back welcome screen (via `@Environment(\.openWindow)`)
- Toolbar button to raise all windows (uses `NSApp.activate(ignoringOtherApps:)`)


## Per-Project Session Storage

**[C]** Changed `SessionStore` from global to per-project:
- Session keys now include encoded project path
- Each project has its own Jake session ID
- Sessions persist independently across projects

```swift
private static let jakeSessionPrefix = "com.tavern.jake.session."

public static func saveJakeSession(_ sessionId: String?, projectPath: String) {
    let key = jakeSessionKey(for: projectPath)
    // ...
}
```


## App Icon

**[U]** "can you scratch out a very simple icon for the app? an orange squircle with a JT inset"

**[U]** "also, use Luminari for a font"

**[C]** Created icon generation script using uv inline dependencies:

```python
# /// script
# dependencies = ["pillow"]
# ///
```

Generated light and dark mode variants:
- Orange squircle background
- "JT" in Luminari font (light mode: dark text, dark mode: light text)
- Integrated into redo build system via `icon.do`


## The Dvorak Easter Egg

*[T] During character development, added a small detail to Jake's personality.*

**[C]** Added to Jake's character spec: Jake can recognize keyboard smashes from Dvorak users (`aoeuidhtns` vs QWERTY `asdfghjkl`) and will comment on it. A small reward for attentive users.


---


## Window Restoration Bug

Continuing from the multi-window work above. User reported windows getting "stuck on loading" when the app tried to restore previously open project windows.


## The Problem

**[U]** "now, when it starts, and tries to open previous windows, they get stuck on loading. before you try fixing it, have you instrumented things enough to detect the issue?"

**[C]** Checked logging coverage. Found minimal logging in `TavernApp.swift` where the loading happens. `ProjectWindowView.task` had NO logging at all.


## Initial Instrumentation

Added logging to `ProjectWindowView`:
- `onAppear` with config and project state
- `.task` entry, guard failures, and completion
- `WindowOpeningService` operations
- View modifier registrations

First test run showed `config: nil` in logs, but user reported seeing spinners with project names. Contradiction.


## The Discovery

**[U]** "three windows, one launcher, two project, the projects have a spinner and Loading project... plus the project name"

**[C]** Added logging directly in the body render path:

```swift
var body: some View {
    let _ = Self.logger.debug("[ProjectWindowView] body evaluated - config: ...")
```

This revealed the actual issue:

```
body evaluated - config: /Users/yankee/Documents/Projects/the-monkey  (rendering spinner)
body evaluated - config: /Users/yankee/Documents/Projects/untitled folder  (rendering spinner)
...
.task started - config: nil   <-- DIFFERENT INSTANCE!
.task started - config: nil   <-- DIFFERENT INSTANCE!
```

SwiftUI was rendering the body with valid configs (showing spinners with project names), but running `.task` on DIFFERENT view instances that had `config: nil`.


## The Fix

Changed from `.task { }` to `.task(id: config?.projectURL) { }`.

This makes the task re-run when SwiftUI finally provides the actual config value to the correct view instance.

**[C]** After the fix:

```
.task started - config: /Users/yankee/Documents/Projects/the-monkey
...
projectManager.openProject returned - name: the-monkey, isReady: true
.task completed - project set: true
```

Windows now restore correctly.


## The Meta-Problem

**[U]** "i want you to write a document now about how you had to instrument this in the end state in order to discover the problem, and make it a guide on instrumentation of the GUI to diagnose issues the human sees. moreover, come up with ways you can programmatically script things to test without requiring the human input at all, just to verify that everything works. in this case, it was a complete failure of the principles of this project to do these things, and it caused a lot of chaos in the process just to fix it."

**[C]** Created `docs/gui-instrumentation-guide.md` covering:
- What to log in SwiftUI views (body, branches, lifecycle, tasks)
- The SwiftUI view instance confusion problem
- Using `.task(id:)` when task depends on changing values
- Programmatic testing patterns (log-based verification, state verification, XCTest UI testing)
- Diagnostic shell commands
- Checklist for shipping GUI code


## Document Reorganization

**[U]** "claude.md has a whole jake thing, write out the jake parts to a character document about jake, rather than claude.md"

**[C]** Extracted ~800 lines of Jake character specification from `CLAUDE.md` into `docs/jake-character.md`. Left a brief summary and link in `CLAUDE.md`.


## Key Insight: SwiftUI View Instance Confusion

SwiftUI's `WindowGroup(for: Codable.self)` has a subtle behavior:
1. On window restoration, SwiftUI creates view instances
2. The binding value may be nil initially, then updated
3. `.task` runs on whatever instance exists when the view appears
4. But body may re-render on a different instance with the actual value

**Solution:** Always use `.task(id: dependentValue)` when the task depends on a value that may change or be set after initial creation.


## Files Created

1. **`docs/gui-instrumentation-guide.md`** - Comprehensive guide on GUI instrumentation
2. **`docs/jake-character.md`** - Full Jake character specification


## Files Modified

1. **`TavernApp.swift`**
   - Added extensive logging throughout
   - Changed `.task` to `.task(id: config?.projectURL)`
   - Added body-level logging to catch render vs task mismatches

2. **`ProjectManager.swift`**
   - Added detailed logging for recent projects load/save

3. **`TavernProject.swift`**
   - Added step-by-step logging during initialization

4. **`CLAUDE.md`**
   - Removed Jake character content
   - Added reference to `docs/jake-character.md`


## Principles Violated (Then Corrected)

**Instrumentation Principle:** The GUI layer had almost no logging. Issue diagnosis required multiple human observation cycles.

**Autonomous Testing Principle:** No programmatic way to verify window restoration worked. Required human to "open projects, quit, tell me to relaunch."

**Sum Type Error Design:** The view didn't have a clear state machine — `config` could be nil from restoration failure OR from being a new welcome window.


## Lessons

1. **Log body evaluation, not just lifecycle events** — SwiftUI may render the body on different instances than where `.onAppear` fires

2. **Use `.task(id:)` for dependent values** — Plain `.task` runs once on initial appearance, which may be before SwiftUI provides the actual data

3. **SwiftUI window restoration is unreliable** — The `Codable` data often doesn't survive the round-trip; may need manual window state management

4. **Instrument aggressively before shipping** — The cost of logging is negligible; the cost of blind debugging is enormous


---

*Perfect execution. But only after we could actually see what was happening.*
