# ADR-005: XCUITest Strategy

**Status:** Accepted
**Date:** 2026-02-07
**Context:** End-to-end testing that validates real user journeys with real Claude


## Decision

XCUITest for smoke tests and E2E tests at Grade 4. **E2E tests never mock.**

### Smoke Tests

Verify the app launches and renders basic UI:
- `testAppLaunches` — window exists
- `testJakeAppearsInSidebar` — "Jake" text visible
- `testInputFieldExists` — text field present and enabled
- `testCanTypeInput` — type text, verify it appears in field

### E2E Tests

Exercise full user journeys with real Claude:
- `testSendMessageAndReceiveResponse` — type, send, verify response appears
- `testSpawnAgent` — click spawn, verify new agent in sidebar
- `testSwitchBetweenAgents` — spawn, switch, switch back
- `testCloseAgent` — spawn, close, verify removed

### Launch Arguments

The app supports `--ui-testing` and `--project-path <sandbox>` launch arguments:

- `--ui-testing` — Bypasses the welcome window and directly opens a project window, making tests deterministic.
- `--project-path <path>` — Specifies a sandbox project directory instead of requiring user selection.

### Runner

```bash
redo Tavern/test-grade4
```

Uses `xcodebuild test -only-testing:TavernUITests`. Output saved to `~/.local/builds/tavern/test-reports/grade4-output.txt`.


## Context

XCUITest is Grade 4 because it **steals focus**. It launches the app window and simulates clicks/keystrokes via the accessibility API. This interrupts the user's work. The tests must run either:

1. When the user isn't actively using the machine
2. In a Tart VM (future improvement)

E2E tests **never mock** because their purpose is to validate the actual user experience end-to-end. If a response takes 30 seconds from real Claude, the E2E test should wait 30 seconds. If the SDK has a bug, the E2E test should catch it.


## Alternatives Considered

- **XCUITest with mocks**: Defeats the purpose. The whole point of E2E is real behavior. Mocked E2E tests test the mocks, not the product.

- **Playwright/browser testing**: Tavern is a native macOS app, not a web app. XCUITest is the right tool.

- **Accessibility-based testing without XCUITest**: Libraries like `AXSwift` can drive accessibility APIs, but XCUITest provides better test infrastructure (assertions, waits, recording).


## Consequences

- **Grade 4 constraint**: These tests cannot be part of the autonomous fast loop. They require explicit scheduling or a dedicated environment.

- **project.yml changes**: A `TavernUITests` target is added with the app as a dependency.

- **TavernApp.swift changes**: Launch argument handling (`--ui-testing`, `--project-path`) adds a small amount of code to the app entry point. This code is inert when not testing.

- **Future**: When Tart VM infrastructure is available, Grade 4 tests can run autonomously by launching the VM, running `redo Tavern/test-grade4`, and capturing results.
