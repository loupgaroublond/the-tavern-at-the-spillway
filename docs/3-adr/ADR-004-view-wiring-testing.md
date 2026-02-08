# ADR-004: View Wiring Testing with ViewInspector

**Status:** Accepted
**Date:** 2026-02-07
**Context:** Catching SwiftUI view-ViewModel binding regressions without launching the app


## Decision

Use [ViewInspector](https://github.com/nalexn/ViewInspector) for SwiftUI view-ViewModel contract tests at Grade 1-2. These tests verify that views correctly bind to their ViewModels — the wiring layer between fat ViewModels and thin views.

**Test files:**
- `Tests/TavernTests/ViewWiringTests/ChatViewWiringTests.swift` (~7 tests)
- `Tests/TavernTests/ViewWiringTests/AgentListViewWiringTests.swift` (~5 tests)

**What wiring tests cover:**
1. InputBar text field exists and is bound to `viewModel.inputText`
2. Send button disabled state tracks `isCogitating` and `inputText.isEmpty`
3. Cogitation indicator visibility tracks `viewModel.isCogitating`
4. ForEach renders correct number of message rows
5. Session recovery banner tracks `viewModel.showSessionRecoveryOptions`
6. Agent list renders with correct structure
7. Spawn button exists in toolbar
8. Agent name displays in header

**What wiring tests do NOT cover:**
- Functional behavior (that's ChatViewModelTests)
- Visual appearance (that's XCUITest or manual QA)
- User interaction flows (that's XCUITest E2E)


## Context

The Tavern follows Thin UI / Fat ViewModel (ADR-001). 90%+ of UX logic is testable via ViewModel unit tests. However, the binding layer between views and ViewModels can silently break during refactoring:

- Renaming a `@Published` property breaks `$viewModel.property` bindings
- Changing a conditional (`if viewModel.isCogitating`) to use the wrong property
- Accidentally removing an accessibility identifier that XCUITests depend on

These bugs produce no compiler errors — the view just renders incorrectly.

ViewInspector introspects the SwiftUI view hierarchy at test time, running as regular unit tests. No app launch, no GUI, no focus stealing.


## Alternatives Considered

- **XCUITest only**: XCUITest catches wiring bugs but is Grade 4 (steals focus, slow). Wiring tests should run on every change (Grade 1-2).

- **Snapshot testing**: Catches visual regressions but is brittle to unrelated styling changes and doesn't verify binding correctness.

- **No wiring tests**: Relies on XCUITest and manual QA. Too slow for the feedback loop we need.


## Consequences

- **New dependency**: ViewInspector is added as a test-only SPM dependency. It does not ship in the production binary.

- **Accessibility identifiers**: Views gain `.accessibilityIdentifier()` modifiers for test lookup. These are also used by XCUITest (Phase 4), so they serve double duty.

- **Maintenance**: Wiring tests must be updated when view structure changes. This is intentional — a test failing because the view changed is exactly the signal we want.
