# Grade 4 XCUITest Failures — 2026-02-21

Run: `redo Tavern/test-grade4`
Result: 4 passed, 4 failed, 0 skipped
Platform: macOS 26.3, arm64, Xcode 17C52


## Root Cause

All 4 failures share the same root cause: **two project windows open simultaneously** during UI testing. The `--ui-testing` flag bypasses the welcome window and opens one project window, but macOS window restoration opens a second one from a previous session. Every element query that expects a single match (`chatInputField`, `"Jake"` StaticText) finds two — one per window — and XCUITest's `Find single matching element` assertion fails.

This is a window management / state restoration bug, not a rename regression. The `servitorList` accessibility identifier appears correctly in the element tree.


## Failed Tests

### 1. `SmokeTests/testCanTypeInput()`

**What it does:** Clicks the `chatInputField` TextView and types text.

**Failure:** `Failed to click "chatInputField" TextView: Find single matching element. Multiple matching elements found.`

**Element tree shows:**
- Window `AppWindow-2` → `chatInputField`
- Window `AppWindow-1` → `chatInputField`


### 2. `SmokeTests/testInputFieldExists()`

**What it does:** Asserts that a single `chatInputField` TextView exists.

**Failure:** `Failed to get matching snapshot: Find single matching element. Multiple matching elements found.`

**Same duplicate element tree as #1.**


### 3. `E2ETests/testSendMessageAndReceiveResponse()`

**What it does:** Clicks `chatInputField`, types a message, sends it, waits for a response from real Claude.

**Failure:** `Failed to click "chatInputField" TextView: Find single matching element. Multiple matching elements found.`

**Fails at the first interaction step — never gets to the send/receive part.**


### 4. `E2ETests/testSwitchBetweenServitors()`

**What it does:** Clicks `"Jake"` in the sidebar, spawns a servitor, switches between them.

**Failure:** `Failed to click "Jake" StaticText: Find single matching element. Multiple matching elements found.`

**Element tree shows "Jake" appearing in 3 places across 2 windows:**
- Window 1 sidebar: `servitorList` → OutlineRow → Cell → StaticText "Jake"
- Window 1 chat header: StaticText "Jake" (plus a second one inside a ScrollView/Other)
- Window 2 sidebar: `servitorList` → OutlineRow → Cell → StaticText "Jake"

**Additional diagnostic:** Xcode reports an automation type mismatch — `AXRole = AXHeading` is computed as `Other` from legacy attributes vs `StaticText` from modern attributes. This is a macOS 26 SwiftUI accessibility quirk.


## Passing Tests

- `SmokeTests/testJakeAppearsInSidebar()` — passes because it uses `waitForExistence` which doesn't require uniqueness
- `SmokeTests/testWindowOpens()` — passes (checks window existence, not element uniqueness)
- `E2ETests/testSpawnServitor()` — passes (clicks the `+` button which is unique per window? or uses a different query strategy)
- `E2ETests/testServitorListShowsJake()` — passes (likely uses existence check, not click)


## Fix Options

1. **Disable window restoration during UI testing** — Add `NSQuitAlwaysKeepsWindows = NO` to the launch arguments or Info.plist when `--ui-testing` is active. This prevents macOS from restoring the previous session's windows.

2. **Scope queries to a single window** — Change test helpers to query within `app.windows.firstMatch` instead of the entire `app` element tree. This tolerates multiple windows.

3. **Close extra windows on launch** — In `TavernApp.swift`, detect `--ui-testing` and close any restored windows before opening the test project window.
