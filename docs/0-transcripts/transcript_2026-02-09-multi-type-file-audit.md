# Transcript: Multi-Type File Audit & Separation

**Date:** 2026-02-09
**Type:** Code hygiene / refactoring session

---

[U] Give me a thorough audit of every file that has more than one class or struct in it. Write it to markdown. Also, provide justification for each of the few cases where it makes sense to keep them together, or mark that as a candidate for separation.

[C] Audited all 90 Swift source files under `Tavern/Sources/`. Found 15 files with multiple top-level type definitions. Classified each as either "keep together" (with justification) or "candidate for separation."

**Three candidates identified:**

1. **`AgentMessenger.swift`** (7 types, 406 lines) — Protocol, production implementation, mock implementation, data types, and a utility class. Three distinct responsibilities in one file.

2. **`CommitmentVerifier.swift`** (8 types, 383 lines) — Same anti-pattern. Protocol, two implementations (shell + mock), result types, error types, and concurrency utilities.

3. **`TavernApp.swift`** (13 types, 650+ lines) — App entry point grown into a monolith containing WindowOpeningService (120 lines), WelcomeView (95 lines), TavernAppDelegate (75 lines), and multiple project views.

**Twelve files justified as co-located**, all following standard Swift patterns:
- Service + Error enum (DocStore, AgentRegistry)
- Protocol + Property-type enum (Agent+AgentState, SlashCommand+Result)
- Request + Response pair (ToolApproval)
- DTO cluster for serialization pipeline (ClaudeSessionModels)
- SwiftUI View + private helper views (all View files)

Report written to `docs/4-docs/multi-type-file-audit.md`.

[U] Make it so.

[C] Executed all three splits:

**Split 1 — AgentMessenger.swift → 3 files:**
- `AgentMessenger.swift` — protocol, StreamEvent, SessionUsage
- `LiveMessenger.swift` — LiveMessenger, UnsafeSendableBox
- `MockMessenger.swift` — MockMessenger
- Moved `ToolApprovalHandler` typealias to `Permissions/ToolApprovalRequest.swift`

**Split 2 — CommitmentVerifier.swift → 4 files:**
- `AssertionRunner.swift` — protocol, AssertionResult, AssertionTimeoutError
- `ShellAssertionRunner.swift` — ShellAssertionRunner + private concurrency utilities
- `MockAssertionRunner.swift` — moved to Testing/
- `CommitmentVerifier.swift` — just the verifier class

**Split 3 — TavernApp.swift → 5 files:**
- `TavernApp.swift` — TavernApp, ProjectWindowConfig, UI testing vars
- `WindowOpeningService.swift` — service + ViewModifiers
- `TavernAppDelegate.swift` — NSApplicationDelegate
- `Views/WelcomeView.swift` — welcome/project-picker view
- `Views/ProjectView.swift` — all project views + TavernHeader

Also cleaned up 9 iCloud duplicate files ("` 2.swift`") that were causing build noise.

Build passes. All 574 unit tests pass.

___

[S] **Anti-pattern identified:** "Protocol + Production impl + Mock impl + Data types + Utilities" in a single file. Found in both AgentMessenger.swift and CommitmentVerifier.swift. The fix: protocol and data types in one file, each implementation in its own file, mocks in Testing/.

**Healthy patterns confirmed:** Small enum companions to their primary type (AgentState with Agent, CommitmentStatus with Commitment, MessageType with ChatMessage) are properly co-located and should stay together. The threshold is roughly: if the companion type is <20 lines, has no independent consumers, and serves as a property type on the main type, keep them together.

**SwiftUI view co-location is always fine** — private helper views are implementation details, not reusable components. Even ChatView.swift with 9 private helper structs is correctly organized.
