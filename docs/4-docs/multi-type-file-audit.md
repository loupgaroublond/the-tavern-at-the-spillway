# Multi-Type File Audit

Audit of every Swift source file containing more than one top-level type definition (class, struct, enum, protocol, actor). Nested types (defined inside another type's body) are excluded — only types that could be extracted to their own file are counted.

**Audited:** All 90 Swift source files under `Tavern/Sources/`

**Date:** 2026-02-09


## Summary

| Verdict | Count | Files |
|---------|-------|-------|
| Keep together | 12 | Well-justified co-location |
| Candidate for separation | 3 | AgentMessenger.swift, CommitmentVerifier.swift, TavernApp.swift |
| **Total** | **15** | |


## TavernCore — Candidates for Separation

### 1. `Testing/AgentMessenger.swift` (406 lines, 7 top-level types)

**CANDIDATE FOR SEPARATION**

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `ToolApprovalHandler` | typealias | 13 | public |
| `SessionUsage` | struct | 20–34 | public |
| `StreamEvent` | enum | 36–51 | public |
| `AgentMessenger` | protocol | 58–72 | public |
| `LiveMessenger` | struct | 84–254 | public |
| `UnsafeSendableBox` | class | 259–262 | internal |
| `MockMessenger` | class | 277–405 | public |

**Problem:** This file conflates three distinct responsibilities:
1. **Protocol + data types** (`AgentMessenger`, `StreamEvent`, `SessionUsage`) — the messaging contract
2. **Production implementation** (`LiveMessenger`, `UnsafeSendableBox`) — real SDK calls with permission handling
3. **Test double** (`MockMessenger`) — canned responses for unit tests

The `ToolApprovalHandler` typealias also doesn't belong here — it's a permissions concept, not a messaging concept.

**Suggested split:**
- `AgentMessenger.swift` — protocol, `StreamEvent`, `SessionUsage`
- `LiveMessenger.swift` — `LiveMessenger`, `UnsafeSendableBox` (move to `Agents/` or keep in `Testing/`)
- `MockMessenger.swift` — `MockMessenger` (stays in `Testing/`)
- Move `ToolApprovalHandler` typealias into `Permissions/ToolApprovalRequest.swift` alongside the types it references


### 2. `Commitments/CommitmentVerifier.swift` (383 lines, 8 top-level types)

**CANDIDATE FOR SEPARATION**

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `AssertionRunner` | protocol | 6–11 | public |
| `AssertionResult` | struct | 14–37 | public |
| `AssertionTimeoutError` | struct | 40–47 | public |
| `LockedFlag` | class | 50–76 | private |
| `LockedRef` | class | 79–99 | private |
| `ShellAssertionRunner` | class | 103–200 | public |
| `MockAssertionRunner` | class | 203–278 | public |
| `CommitmentVerifier` | class | 281–382 | public |

**Problem:** Same pattern as AgentMessenger — protocol, production impl, mock impl, data types, and utility classes all in one file. The two `private` concurrency utilities (`LockedFlag`, `LockedRef`) are only used by `ShellAssertionRunner` and could travel with it.

**Suggested split:**
- `AssertionRunner.swift` — protocol, `AssertionResult`, `AssertionTimeoutError`
- `ShellAssertionRunner.swift` — `ShellAssertionRunner`, `LockedFlag`, `LockedRef`
- `MockAssertionRunner.swift` — move to `Testing/`
- `CommitmentVerifier.swift` — just the verifier class


### 3. `Tavern/TavernApp.swift` (650+ lines, 13 top-level types)

**CANDIDATE FOR SEPARATION**

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `WindowOpeningService` | class | 11–127 | internal |
| `WindowOpenerRegistration` | struct (ViewModifier) | 130–145 | internal |
| `WelcomeWindowRegistration` | struct (ViewModifier) | 147–185 | internal |
| `TavernAppDelegate` | class | 187–262 | internal |
| `TavernApp` | struct (App) | 264–331 | internal |
| `ProjectWindowConfig` | struct | 333–339 | internal |
| `ProjectWindowView` | struct (View) | 341–402 | internal |
| `WelcomeView` | struct (View) | 404–499 | internal |
| `ProjectView` | struct (View) | 501–516 | internal |
| `ProjectContentView` | struct (View) | 518–604 | internal |
| `ProjectLoadingView` | struct (View) | 606–619 | internal |
| `ProjectErrorView` | struct (View) | 621–644 | internal |
| `TavernHeader` | struct (View) | 646–end | private |

**Problem:** This is the app's entry point but it's grown into a monolith. `WindowOpeningService` (120 lines) is a full-fledged service class. `WelcomeView` (95 lines) is a significant standalone view. `TavernAppDelegate` (75 lines) handles app lifecycle. These aren't small helper views — they're substantial, independently testable components.

**Suggested split:**
- `TavernApp.swift` — `TavernApp`, `ProjectWindowConfig`, the two ViewModifier registrations
- `WindowOpeningService.swift` — the window management service
- `TavernAppDelegate.swift` — the `NSApplicationDelegate`
- `WelcomeView.swift` — the welcome/project-picker window
- `ProjectView.swift` — `ProjectView`, `ProjectContentView`, `ProjectWindowView`
- `ProjectLoadingView.swift` and `ProjectErrorView.swift` could stay inline or be extracted (small enough either way)
- `TavernHeader` is private and small — stays with whatever view uses it


## TavernCore — Justified Co-location

### 4. `Persistence/ClaudeSessionModels.swift` (351 lines, 5 top-level types)

**KEEP TOGETHER** — Data Transfer Object cluster

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `ClaudeStoredSession` | struct | 12–38 | public |
| `StoredContentBlock` | enum | 41–57 | public |
| `ClaudeStoredMessage` | struct | 60–98 | public |
| `ClaudeJSONLEntry` | struct | 101–280 | internal |
| `SessionJSONValue` | enum | 286–342 | internal |

**Justification:** These are all data models for a single serialization pipeline — Claude's native JSONL session format. `ClaudeJSONLEntry` and `SessionJSONValue` are internal parsing types that only exist to produce `ClaudeStoredSession` and its children. Splitting them would scatter a cohesive parsing story across files with no independent reuse value. The "Models" suffix in the filename signals this is an intentional DTO cluster.


### 5. `DocStore/AgentNode.swift` (297 lines, 3 top-level types)

**KEEP TOGETHER** — Serialization pair + error type

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `AgentNode` | struct | 5–239 | public |
| `CommitmentNode` | struct | 242–290 | public |
| `AgentNodeError` | enum | 293–296 | public |

**Justification:** `CommitmentNode` is a child of `AgentNode` in the serialization graph — `AgentNode.commitments` is `[CommitmentNode]`. They serialize and deserialize together. `AgentNodeError` is 4 lines and only thrown by `AgentNode.from(document:)`. These three types form a single persistence unit.


### 6. `Agents/Agent.swift` (50 lines, 2 top-level types)

**KEEP TOGETHER** — Protocol + required associated enum

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `AgentState` | enum | 4–22 | public |
| `Agent` | protocol | 25–48 | public |

**Justification:** `AgentState` is the type of the `Agent.state` property. Every consumer of `Agent` needs `AgentState`. Splitting them would force every file using the protocol to import an additional file for a 19-line enum. This is the standard Swift pattern for protocol + associated type co-location.


### 7. `Chat/ChatMessage.swift` (89 lines, 2 top-level types)

**KEEP TOGETHER** — Value type + its property type

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `MessageType` | enum | 4–11 | public |
| `ChatMessage` | struct | 14–88 | public |

**Justification:** `MessageType` is the type of `ChatMessage.messageType`. 8 lines. No independent consumers. Same reasoning as Agent.swift.


### 8. `Commitments/Commitment.swift` (117 lines, 2 top-level types)

**KEEP TOGETHER** — Value type + its status enum

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `CommitmentStatus` | enum | 4–16 | public |
| `Commitment` | struct | 20–116 | public |

**Justification:** `CommitmentStatus` is the type of `Commitment.status`. 13 lines. Standard property-type co-location.


### 9. `DocStore/DocStore.swift` (205 lines, 2 top-level types)

**KEEP TOGETHER** — Service + its error type

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `DocStoreError` | enum | 4–9 | public |
| `DocStore` | class | 13–204 | public |

**Justification:** `DocStoreError` is thrown exclusively by `DocStore` methods. 6 lines. Standard Swift error-type co-location.


### 10. `Permissions/PermissionRule.swift` (64 lines, 2 top-level types)

**KEEP TOGETHER** — Value type + its property enum

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `PermissionRule` | struct | 7–55 | public |
| `PermissionDecision` | enum | 58–63 | public |

**Justification:** `PermissionDecision` is the type of `PermissionRule.decision`. 6 lines. No independent consumers.


### 11. `Permissions/ToolApprovalRequest.swift` (53 lines, 2 top-level types)

**KEEP TOGETHER** — Request-response pair

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `ToolApprovalRequest` | struct | 7–37 | public |
| `ToolApprovalResponse` | struct | 40–52 | public |

**Justification:** These are a semantic pair — one is meaningless without the other. Both are small. Splitting request from response would be over-engineering.


### 12. `Commands/SlashCommand.swift` (39 lines, 2 top-level types)

**KEEP TOGETHER** — Protocol + its result type

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `SlashCommandResult` | enum | 4–13 | public |
| `SlashCommand` | protocol | 19–33 | public |

**Justification:** `SlashCommandResult` is the return type of `SlashCommand.execute()`. 10 lines. Standard protocol + return-type co-location.


### 13. `Commands/SlashCommandParser.swift` (73 lines, 2 top-level types)

**KEEP TOGETHER** — Parser + its result type

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `ParseResult` | enum | 5–11 | public |
| `SlashCommandParser` | enum | 25–72 | public |

**Justification:** `ParseResult` is only returned by `SlashCommandParser.parse()`. 7 lines. Would be orphaned in its own file.


### 14. `Testing/MockClaudeCode.swift` (94 lines, 2 top-level types)

**KEEP TOGETHER** — Test helper pair

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `MockSDKMessage` | enum | 16–51 | public |
| `MockQueryStream` | struct | 57–93 | public |

**Justification:** Both exist solely for testing. `MockQueryStream` uses `MockSDKMessage` in its convenience initializer. They're a cohesive test toolkit — splitting them adds file noise for no separation-of-concerns benefit.


### 15. `Agents/AgentRegistry.swift` (101 lines, 2 top-level types)

**KEEP TOGETHER** — Service + its error type

| Type | Kind | Lines | Visibility |
|------|------|-------|------------|
| `AgentRegistryError` | enum | 4–7 | public |
| `AgentRegistry` | class | 11–101 | public |

**Justification:** `AgentRegistryError` is thrown exclusively by `AgentRegistry`. 4 lines. Standard error-type co-location.


## Tavern (App Target) — View Files

SwiftUI view files routinely co-locate private helper views with their parent. This is standard practice — private views are implementation details, not reusable components. All app-target view files follow this pattern and are **justified as-is**, with the exception of `TavernApp.swift` (covered above as candidate #3).

| File | Main View | Private helpers |
|------|-----------|-----------------|
| `ChatView.swift` | `ChatView` | 9 private structs (ChatHeader, InputBar, indicators, popups) |
| `AgentListView.swift` | `AgentListView` | `EditDescriptionSheet` + 3 private structs |
| `DiffView.swift` | `DiffView` | `DiffLine` (non-private data model) + `DiffLineView` (private) |
| `CollapsibleBlockView.swift` | `CollapsibleBlockView` | `ErrorBlockContent` (private) |
| `MessageRowView.swift` | `MessageRowView` | `DiffCollapsibleBlock` (private) |
| `TodoListView.swift` | `TodoListView` | `TodoItemRow` (private) |
| `FileTreeView.swift` | `FileTreeView` | `FileTreeRow` (private) |
| `BackgroundTasksView.swift` | `BackgroundTasksView` | `BackgroundTaskRow` (private) |
| `ResourcePanelView.swift` | `ResourcePanelView` | `FilesTabContent` (private) |
| `MultiLineTextInput.swift` | `MultiLineTextInput` | `MultiLineTextInputSized` (non-private wrapper) |

**Note on `DiffView.swift`:** `DiffLine` is a non-private struct used as the data model for `DiffView`. It's 15 lines and has no consumers outside this view. Keeping it co-located is justified.

**Note on `MultiLineTextInput.swift`:** `MultiLineTextInputSized` is a public wrapper around `MultiLineTextInput` that adds sizing behavior. These are tightly coupled — the wrapper exists because `NSViewRepresentable` can't self-size. Keeping them together is justified.


## Patterns Observed

**Healthy co-location patterns in this codebase:**
1. Service + Error enum (DocStore, AgentRegistry) — always keep together
2. Protocol + Property-type enum (Agent+AgentState, SlashCommand+Result) — always keep together
3. Request + Response pair (ToolApproval) — always keep together
4. DTO cluster for a serialization pipeline (ClaudeSessionModels) — always keep together
5. SwiftUI View + private helper views — always keep together

**Anti-pattern found in 2 files:**
- Protocol + Production impl + Mock impl + Data types + Utilities all in one file
- Both `AgentMessenger.swift` and `CommitmentVerifier.swift` exhibit this
- The mock implementations should live in `Testing/` where consumers can find them
- Production implementations are substantial enough (100+ lines each) to warrant their own files
