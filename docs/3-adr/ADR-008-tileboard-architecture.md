# ADR-008: Tileboard Architecture

**Status:** Accepted
**Date:** 2026-02-28
**Context:** Decomposing the Tavern's monolithic UI layer into isolated, testable tile modules with compiler-enforced safety nets


## Decision

The Tavern will adopt the **tileboard pattern** — a modular SwiftUI architecture with compiler-enforced module isolation. The pattern introduces:

1. **Three-level hierarchy** for state ownership
2. **Provider protocols** as the domain access layer (providers ARE the domain objects)
3. **SPM module isolation** as the primary correctness mechanism
4. **@Observable migration** from ObservableObject/Combine
5. **Three compiler safety nets** replacing runtime discipline

The `hybrid-nav-example/` directory contains the reference implementation of this pattern.


## Three-Level Hierarchy

| Level | Type | Owns | Lifecycle |
|-------|------|------|-----------|
| **TavernApp** | The Reifier | Concrete providers, WindowGroups | App-scoped |
| **TavernProject** | Document-level board (TavernBoard) | Per-project domain state | Project-scoped |
| **WindowBoard** | Window-level board (née TavernCoordinator) | Facets, sockets, tiles, navigation | Window-scoped |

```
TavernApp (reifier)
    └── creates concrete providers
    └── passes protocol-typed providers to TavernProject

TavernProject (document board)
    └── per-project domain state
    └── creates WindowBoard instances

WindowBoard (window board)
    └── owns sockets → owns tiles
    └── facets drive surface views
    └── implements Navigator protocol
```


## Provider-as-Domain-Object Model

Providers are NOT wrapper layers. The concrete domain objects (ClodSessionManager, FileTreeScanner, etc.) implement provider protocols directly. The app creates concrete types and passes them down as protocol types.

```
CoreProviders (protocol layer)     — tiles see only this
    ↑ conforms
TavernCore (implementation)        — imports ClodKit, owns domain logic
    ├── ClodSessionManager         → implements ServitorProvider
    ├── FileTreeScanner            → implements ResourceProvider
    ├── SlashCommandDispatcher     → implements CommandProvider
    └── PermissionManager          → implements PermissionProvider
```

This avoids the wrapping overhead and indirection of a separate adapter layer.


## SPM Module Map

```
Core Layer (zero or single Core dependency):
├── CoreModels/          Pure value types (ChatMessage, ServitorState, etc.)
├── CoreProviders/       Provider protocols (depends: CoreModels)
└── CoreUI/              Reusable views (depends: CoreModels)

Tile Layer (depends only on Core*):
├── ApprovalTile/        Tool/plan approval UI
├── PermissionSettingsTile/
├── ServitorListTile/    Sidebar agent list
├── ResourcePanelTile/   File tree, tasks, TODOs
├── ChatTile/            Conversation view (the complex one)
└── TavernBoardTile/     Root tile — composes all leaf tiles

App Layer:
├── TavernCore/          Business logic + ClodKit SDK (depends: CoreModels, CoreProviders)
└── Tavern/              App entry point (depends: everything)
```


## Three Compiler Safety Nets

### 1. SPM Dependency Graph

Leaf tiles **cannot import other leaf tiles**. Package.swift enforces:

```swift
.target(name: "ChatTile", dependencies: ["CoreModels", "CoreUI", "CoreProviders"])
// Cannot add "ServitorListTile" here — architectural violation
```

If a developer accidentally adds a cross-tile import, the build fails.

### 2. Required Responder Parameters

Every tile declares a `Responder` struct with required closure parameters:

```swift
public struct ChatResponder {
    public var onApprovalRequired: (ToolApprovalRequest) async -> ToolApprovalResponse
    public var onActivityChanged: (ServitorActivity) -> Void
    // ... all required, no defaults
}
```

If a new navigation intent is added to the responder, every call site (socket) that constructs it breaks at compile time. No silent omissions.

### 3. Exhaustive Facet Switches

Navigation state is modeled as enums:

```swift
enum DetailFacet {
    case empty
    case chat(UUID)
}
```

Surface views use exhaustive switches (no `default:`). Adding a new facet case breaks compilation at every surface that doesn't handle it.


## Tile Anatomy

Each tile module contains:

| Component | Purpose |
|-----------|---------|
| **Responder** (struct) | Navigation intent closures, no implementation knowledge |
| **Tile** (@Observable class) | State + logic, accepts provider + responder via init |
| **TileView** (SwiftUI View) | Pure rendering, `@Bindable var tile` |
| **Socket** (in board tile) | Wiring — creates tile, connects responder to navigator |

Navigation flow:
```
TileView → tile.action() → responder.onSomething() → socket → navigator → board state → surface → view
```


## @Observable Migration

All ViewModels migrate from `ObservableObject` + `@Published` to `@Observable`:

| Before | After |
|--------|-------|
| `class Foo: ObservableObject` | `@Observable class Foo` |
| `@Published var x: Int` | `var x: Int` (auto-tracked) |
| `@ObservedObject var vm` | `@Bindable var tile` (in views) |
| `@StateObject var vm` | `@State var tile` (in owners) |

This eliminates Combine as the observation mechanism. AsyncStream replaces Combine publishers for long-running data flows.


## ClodSession Translation Layer

A key enabling refactoring: `ClodSession` absorbs the ~88 lines of duplicated session lifecycle code from Jake and Mortal.

```
Jake (domain: dispatcher, MCP, character voice)
  └→ ClodSession (lifecycle: session ID, options, stream wrapping)
       └→ ClodKit SDK

Mortal (domain: assignment, commitments, done detection)
  └→ ClodSession (lifecycle: same)
       └→ ClodKit SDK
```

ClodSession is the **containment boundary** — everything ClodKit-flavored stays inside TavernCore. CoreProviders sees nothing from ClodKit.


## ClodKit Containment Boundary

```
CoreProviders (protocol layer)     — no ClodKit imports
    ↑
TavernCore (implementation layer)  — imports ClodKit
    ├── ClodSession                — the translation seam
    ├── ClodSessionManager         — factory, implements ServitorProvider
    ├── Jake                       — domain object, owns a ClodSession
    └── Mortal                     — domain object, owns a ClodSession
```

`StreamEvent` and `SessionUsage` move to CoreModels — they reference zero ClodKit types.


## Supersedes

This ADR supersedes ADR-001's UI layer description by providing the concrete realization. ADR-001's shape selections (Shared Workspace, Supervisor Tree, Reactive Streams, etc.) remain valid — tileboard is how those shapes manifest in the SwiftUI layer.


## Alternatives Considered

### Wrapper Provider Layer

**Rejected.** An intermediate adapter layer between domain objects and provider protocols adds indirection without value. The domain objects can conform to the protocols directly.

### Combine-Based Observation

**Rejected.** `@Observable` (Swift 5.9+) provides automatic dependency tracking without explicit publishers. Combine remains only as a transitional bridge where absolutely necessary.

### Single Module with Internal Visibility

**Rejected.** `internal` access control is not enforced across file boundaries within a module. SPM target boundaries provide compiler-enforced isolation that `internal` cannot match.


## References

- Reference implementation: `hybrid-nav-example/`
- Reference CLAUDE.md: `hybrid-nav-example/CLAUDE.md`
- Design transcript: `docs/0-transcripts/transcript_2026-02-28-tileboard-architecture.md`
- ADR-001: Shape selection (architectural foundation)
- ADR-003: Agent mocking strategy (provider pattern origins)
