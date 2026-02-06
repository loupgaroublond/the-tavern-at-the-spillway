# GUI Instrumentation Guide

## The Failure That Prompted This Document

On 2026-01-24, we spent significant time debugging a "stuck on loading" issue during window restoration. The process was chaotic:

1. User reported windows stuck on loading spinner
2. We had minimal logging in the GUI layer
3. Multiple round-trips with the human required ("what do you see?", "try that again")
4. Logs showed `config: nil` but user saw project names - contradiction
5. Only after adding body-level logging did we discover SwiftUI was mixing view instances

**Root cause:** `.task` was running on view instances with `config: nil` while the body rendered with valid configs. Fix: `.task(id: config?.projectURL)`.

**The real failure:** We violated the Instrumentation Principle. The GUI layer had almost no logging, making autonomous diagnosis impossible.


## The Instrumentation Principle

> Debug builds must be instrumented thoroughly enough that issues can be diagnosed from logs alone — without needing screenshots, videos, or human reproduction.

This principle exists in CLAUDE.md but wasn't applied to the GUI layer. This document corrects that.


## What To Log in SwiftUI Views

### 1. View Body Evaluation

Log every time the body computes, with all relevant state:

```swift
var body: some View {
    let _ = Self.logger.debug("[MyView] body - state1: \(state1), state2: \(state2)")
    // ... view content
}
```

The `let _ =` pattern executes the log without producing a value.


### 2. Conditional Branches

Log which branch the view is taking:

```swift
var body: some View {
    Group {
        if let data = data {
            let _ = Self.logger.info("[MyView] SHOWING DATA: \(data.id)")
            DataView(data: data)
        } else if isLoading {
            let _ = Self.logger.info("[MyView] SHOWING LOADING")
            ProgressView()
        } else {
            let _ = Self.logger.info("[MyView] SHOWING EMPTY STATE")
            EmptyView()
        }
    }
}
```


### 3. Lifecycle Events

```swift
.onAppear {
    Self.logger.debug("[MyView] onAppear - relevantState: \(relevantState)")
}
.onDisappear {
    Self.logger.debug("[MyView] onDisappear")
}
```


### 4. Task Execution

Log entry, key decision points, and exit:

```swift
.task(id: triggerValue) {
    let taskId = UUID().uuidString.prefix(8)
    Self.logger.info("[MyView:\(taskId)] .task started - trigger: \(triggerValue)")

    guard let value = optionalValue else {
        Self.logger.warning("[MyView:\(taskId)] guard failed - optionalValue is nil")
        return
    }

    Self.logger.debug("[MyView:\(taskId)] calling async operation...")
    let result = await someAsyncOperation()
    Self.logger.info("[MyView:\(taskId)] async operation returned: \(result)")

    Self.logger.debug("[MyView:\(taskId)] .task completed")
}
```


### 5. State Changes

```swift
.onChange(of: someState) { oldValue, newValue in
    Self.logger.debug("[MyView] someState changed: \(oldValue) -> \(newValue)")
}
```


## Logger Setup Pattern

Each view/service should have its own static logger:

```swift
struct MyView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "myview")

    // ...
}
```

Use categories to filter logs:
- `window` - Window management, opening, closing
- `chat` - Chat/message handling
- `coordination` - Agent coordination
- `agents` - Agent lifecycle
- `claude` - Claude API interactions


## The Problem: SwiftUI View Instance Confusion

SwiftUI can create multiple instances of a view and may run modifiers (like `.task`) on different instances than the one being displayed. This caused our bug:

```
# What logs showed:
body evaluated - config: /path/to/project  (Instance A)
.task started - config: nil                 (Instance B!)
```

**Lesson:** Always use `.task(id:)` when the task depends on a value that may change or be set after initial creation:

```swift
// BAD - task runs once on whatever instance SwiftUI chooses
.task {
    guard let url = config?.projectURL else { return }
    // ...
}

// GOOD - task re-runs when the id changes
.task(id: config?.projectURL) {
    guard let url = config?.projectURL else { return }
    // ...
}
```


## Programmatic Testing Without Human Input

The chaos in debugging this issue came from requiring human observation. Here's how to test GUI behavior programmatically.


### 1. Log-Based Verification

Write tests that launch the app and verify log output:

```swift
func testWindowRestoration() async throws {
    // Setup: Write known state to UserDefaults
    let testProjects = ["/tmp/test-project-1", "/tmp/test-project-2"]
    let data = try JSONEncoder().encode(testProjects)
    UserDefaults.standard.set(data, forKey: "com.tavern.recentProjects")

    // Launch app and capture logs
    let logCapture = LogCapture(subsystem: "com.tavern.spillway", category: "window")

    // Wait for startup
    try await Task.sleep(for: .seconds(5))

    // Verify expected log sequence
    let logs = logCapture.messages

    // Should see tasks start with actual configs (not nil)
    let taskStarts = logs.filter { $0.contains(".task started - config:") }
    for start in taskStarts {
        XCTAssertFalse(start.contains("config: nil"),
            "Task should not start with nil config after restoration")
    }

    // Should see projects loaded successfully
    XCTAssertTrue(logs.contains { $0.contains("project set: true") },
        "Projects should be set after loading")
}
```


### 2. State Verification via UserDefaults

Test that state is correctly persisted:

```swift
func testRecentProjectsPersistence() {
    let manager = ProjectManager.shared
    let testURL = URL(fileURLWithPath: "/tmp/test-\(UUID())")

    // Open project
    await manager.openProject(at: testURL)

    // Verify UserDefaults
    let data = UserDefaults.standard.data(forKey: "com.tavern.recentProjects")!
    let paths = try! JSONDecoder().decode([String].self, from: data)

    XCTAssertTrue(paths.contains(testURL.path))
}
```


### 3. Window State Verification via NSApplication

```swift
func testWindowCreation() async {
    let testURL = URL(fileURLWithPath: "/tmp/test-project")

    // Open project window
    await MainActor.run {
        WindowOpeningService.shared.openProjectWindow(url: testURL)
    }

    // Wait for window creation
    try await Task.sleep(for: .seconds(1))

    // Verify window exists
    await MainActor.run {
        let windows = NSApp.windows.filter {
            $0.title.contains("test-project")
        }
        XCTAssertEqual(windows.count, 1, "Should have exactly one window for project")
    }
}
```


### 4. Simulated App Lifecycle

Test window restoration by simulating quit/relaunch:

```swift
func testWindowRestorationCycle() async throws {
    // Phase 1: Open windows and capture state
    let project1 = URL(fileURLWithPath: "/tmp/project1")
    let project2 = URL(fileURLWithPath: "/tmp/project2")

    await MainActor.run {
        WindowOpeningService.shared.openProjectWindow(url: project1)
        WindowOpeningService.shared.openProjectWindow(url: project2)
    }

    try await Task.sleep(for: .seconds(1))

    // Capture what UserDefaults looks like
    let savedState = UserDefaults.standard.dictionaryRepresentation()

    // Phase 2: Simulate fresh launch with saved state
    // Reset in-memory state
    await MainActor.run {
        ProjectManager.shared.closeAllProjects()
        // Windows would be closed here in real scenario
    }

    // Restore from saved state (simulates app relaunch)
    // In real tests, you'd launch a fresh process

    // Phase 3: Verify restoration works
    // ...
}
```


### 5. XCTest UI Testing

For true end-to-end verification:

```swift
class TavernUITests: XCTestCase {
    func testWindowRestorationShowsProjects() throws {
        let app = XCUIApplication()

        // Setup: ensure we have recent projects
        app.launchArguments = ["--uitesting", "--recent-projects=/tmp/p1,/tmp/p2"]
        app.launch()

        // Verify we see project windows, not loading spinners
        // After 5 seconds, no "Loading project..." should be visible
        let loadingText = app.staticTexts["Loading project..."]
        let exists = loadingText.waitForExistence(timeout: 2)

        if exists {
            // If loading appears, it should disappear
            let disappeared = loadingText.waitForNonExistence(timeout: 5)
            XCTAssertTrue(disappeared, "Loading spinner should disappear")
        }

        // Verify project names are visible
        XCTAssertTrue(app.staticTexts["p1"].exists || app.windows.count >= 2)
    }
}
```


## Diagnostic Shell Commands

For manual debugging, these commands help:

```bash
# Stream all Tavern logs
log stream --predicate 'subsystem == "com.tavern.spillway"' --level debug

# Filter to specific category
log stream --predicate 'subsystem == "com.tavern.spillway" AND category == "window"' --level debug

# Save logs to file while running
log stream --predicate 'subsystem == "com.tavern.spillway"' --level debug > /tmp/tavern.log 2>&1 &

# Check recent logs (last 5 minutes)
log show --predicate 'subsystem == "com.tavern.spillway"' --last 5m --level debug

# Check UserDefaults state
defaults read com.tavern.app

# Check specific key
defaults read com.tavern.app "com.tavern.recentProjects"
```


## Checklist: Before Shipping GUI Code

- [ ] Every view has a static `Logger` instance
- [ ] Body evaluation is logged with relevant state
- [ ] Conditional branches log which path is taken
- [ ] `.task` blocks log entry, guard failures, async results, and exit
- [ ] `.task` uses `id:` parameter when depending on optional/changing values
- [ ] State changes are logged via `.onChange`
- [ ] Tests exist that verify log output without human observation
- [ ] Window/scene creation can be verified programmatically


## The Cost of Skipping Instrumentation

In this debugging session:
- ~30 minutes spent on back-and-forth with human
- Multiple "try again" cycles
- Confusion when logs contradicted user observations
- User had to describe what they saw repeatedly

With proper instrumentation from the start:
- Logs would have immediately shown the instance mismatch
- No human observation required
- Fix identified in first log capture

**Instrument aggressively. The cost of logging is negligible. The cost of blind debugging is enormous.**
