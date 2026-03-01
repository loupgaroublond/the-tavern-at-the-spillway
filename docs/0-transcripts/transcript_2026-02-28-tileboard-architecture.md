# Transcript: Tileboard Architecture — Redesigning the Tavern with Hybrid Navigation

**Date:** 2026-02-28
**Session:** Ideation session
**Topics:** Tileboard architecture, hybrid navigation pattern, tile decomposition, provider model, object ownership, three-level hierarchy (App → Project → Window), @Observable migration, Core* rename (ADR-008), SDK interface analysis (QueryOptions/StreamEvent), ClodSession translation layer, Jake/Mortal duplication map, ClodKit containment boundary, approval flow resolution

---

## Part 1: The Reference Architecture

[U] Dropped in `hybrid-nav-example/` as a reference architecture for something new called Tileboard. Go through the architecture and the Tavern thoroughly, and come up with a plan to redesign the Tavern using this architecture.

[C] Explored both codebases in parallel. The hybrid-nav-example demonstrates a modular SwiftUI architecture with these core patterns:

1. **SPM-enforced module isolation** — each feature is its own SPM target ("tile"). Leaf tiles depend only on Shared modules and can NEVER import other leaf tiles. Build failure enforces this.

2. **Responder closures** — each tile declares navigation INTENT via a struct of closures. The tile calls closures but has no idea what they do. All params required (no defaults) — compiler catches unwired closures.

3. **Socket pattern** — sockets live in the root Board tile only. Each socket owns one tile, wires its responder closures to Navigator methods. Sockets are the ONLY place cross-tile coupling happens.

4. **BoardState + Facets** — central @Observable state hub with enum-based facets. Exhaustive switches in Surface views. Add a facet case → compiler forces you to handle it.

5. **@Observable throughout** — tiles are @Observable classes with makeView() methods. Views use @Bindable for two-way bindings.

6. **Provider protocols for DI** — tiles depend on protocols, not implementations. Concrete providers injected from the app boundary.

7. **Three compiler safety nets**: SPM dependencies (tile can't import tile), required responder init params (unwired closure = build error), exhaustive facet switches (unhandled destination = build error).

The Tavern by contrast has a monolithic TavernCore framework where everything lives in one SPM target, uses the older ObservableObject/@Published pattern, and has no module-level isolation between features.

___

[S] *The reference architecture's three compiler safety nets are its core innovation. Architectural boundaries are enforced by the build system, not by convention. Violations are caught at compile time, not at code review.*

---

## Part 2: Initial Tile Decomposition

[C] Proposed six tiles:

| Tile | Cardinality | Description |
|------|-------------|-------------|
| ServitorListTile | 1 per board | Sidebar agent list |
| ChatTile | 1 per active agent | Chat conversation (dynamic pool) |
| ResourcePanelTile | 1 per board | File tree + file viewer + todos + tasks |
| ToolApprovalTile | 0..1 (modal) | Tool/plan approval sheet |
| PermissionSettingsTile | 0..1 (modal) | Permission mode configuration |
| TavernBoardTile | 1 per project window | ROOT tile, composes all others |

ChatTile is special — it's multi-instance (one per active agent), managed by a ChatSocketPool rather than a static singleton socket.

[U] Let's talk this out before breaking down tiles. We need to be clear about which state belongs to the board, what becomes providers, and what needs to be tiles. We need a top-down redesign starting from the TavernCoordinator.

---

## Part 3: The Coordinator IS a Board

[C] In the reference, WorkspaceBoard is a composite tile — it owns sockets, implements Navigator, manages BoardState. Looking at TavernCoordinator, it does the same job: owns Jake, MortalSpawner, ChatViewModel cache, ServitorListViewModel. Handles agent selection, spawning, dismissing. It's the central hub.

Proposed: the Board fully replaces the Coordinator. Its navigation role becomes facet mutations, its business logic bridging becomes provider calls.

[U] No, the TavernCoordinator *is* a board. That's the missing nuance.

[C] Right — the Coordinator IS already a board. The redesign is refactoring it into the tileboard pattern, not replacing it with something new.

___

[S] *Critical reframe: TavernCoordinator isn't "replaced by" a board — it IS a board that needs to be refactored into the tileboard pattern. The identity is preserved, the implementation changes.*

---

## Part 4: What Are Servitors?

[U] What are Jake and servitors? What role do they play? I have an answer, but better if you work it out.

[C] In the reference, the domain objects are Files and Documents. Tiles are the UI that presents them. Servitors are the Tavern's domain objects — the things the UI exists to present and interact with. A ChatTile is to a Servitor what DocumentViewerTile is to a Document.

Jake specifically is a daemon servitor. From the UI's perspective, Jake is just another entry in the sidebar with a chat — the only difference is lifecycle (can't be dismissed). Jake's MCP tool orchestration is business logic happening through the chat stream; the UI sees tool calls like any other.

Servitors live in the **service/domain layer**, not the tile layer. Their lifecycle is independent of UI state.

[U] Right direction.

___

[S] *Servitors are domain objects, not UI objects. They're the service layer that the application presents. Tiles observe them through providers. The separation is clean: servitors don't know about tiles, tiles don't know about concrete servitors.*

---

## Part 5: Three-Level Hierarchy

[U] The app can have several projects open simultaneously, each project is a "document" in the macOS sense. A TavernProject is the top tile *for a document*. What's the top top top tile?

Something gives the project providers to vend domain objects. The project is a type of board — it has a "view" and can support a responder if "embedded." But the view is abstract, because we can have one or more windows for a single project.

Then we have a concrete type that's a Board for the window. That's the TavernCoordinator, but we might rename it. It is never a TavernBoard — that's the TavernProject itself.

[C] Three levels emerge:

**Level 1: The Application.** TavernApp + ProjectManager. The outermost socket. Creates concrete providers, manages window groups.

**Level 2: The Project (TavernProject = TavernBoard).** One per open project. The document-level board. Owns domain objects, creates providers, has an abstract "view" (maps to N windows). This IS the TavernBoard.

**Level 3: The Window (the current TavernCoordinator, refactored).** One per window. The concrete board with facets, sockets, tiles. Multiple window boards can share the same project's providers and domain objects.

[U] On the right track, but lots of details wrong. Lay out the pieces concisely and I'll tell you what to move where.

___

[S] *The naming tells the story: TavernProject IS the TavernBoard (document-level). TavernCoordinator IS the WindowBoard (window-level). Two distinct board types at two distinct levels, not one replacing the other. The project's view is abstract (N windows); the window's view is concrete.*

---

## Part 6: Providers Are the Domain Objects

[U] A ServitorRegistry is per project, but a ServitorProvider is basically a provider of ClodKit functionality that gives out access to sessions. We only need one provider that creates ClodKit sessions, even if it gives a curried provider to each TavernProject so the project doesn't have to constantly tell the provider what project it is.

A ServitorProvider is the shared provider protocol. A ClodSessionManager is the concrete implementation. And the -Messenger suffix should be saved for a different thing.

The ProjectManager's view is what the app embeds into the WindowGroup. ProjectManager needs a ProjectProvider — calls the instance, gets a TavernProject from a URL/path, puts the TP in its socket, so when the TP opens windows, that gets communicated back up to the window group.

There are many shared domain models — MCP server configurations, slash commands, commitments, documents, etc. Some are app-wide (settings). Some are per-project (documents). Some are per-servitor (commitments, sessions). An MCP config can be app-level, project-level, or combined — that gets fed into an MCP server provider.

Then there are domain business logic objects — workflows, gates (like verifying commitments). A tile's job is to wire UX events into the model objects for whatever part of the domain it's been delegated. These concrete objects are provided from the top level of the app that reifies them into being. The app manages their lifecycles and ensures UI runs on one thread and background work on the correct threads. Objects can mutate due to background code, and views represent this to the user.

[C] Initially proposed a "LiveProviders" wrapper layer — concrete types that wrap separate domain objects. Wrong.

[U] You missed the part where all the domain objects that have state come from the concrete providers. BoardState is not a thing we need necessarily — it's a demo that the example board can have its own internal implementation that doesn't leak. The concrete providers ARE the domain objects. The app creates things like a DocumentStore that implements ResourceProvider, a ClodSessionManager that implements ServitorProvider.

[C] Key correction: there's no wrapper layer. The concrete providers ARE the domain objects. `DocumentStore` implements `ResourceProvider`. `ClodSessionManager` implements `ServitorProvider`. The app creates these concrete types, they own the state, they flow downward as protocol types.

___

[S] *Providers aren't wrappers around domain objects — they ARE the domain objects. The protocol is what tiles see; the concrete implementation is what the app creates and owns. This eliminates an entire layer of indirection. The app is the reifier — it brings everything into being and manages lifecycles.*

---

## Part 7: The Concrete ProjectProvider

[U] There's also a ProjectProvider, which is an `UnixDirectoryDriver`. The app creates that, passes it into ProjectManager.

[C] `UnixDirectoryDriver : ProjectProvider` — the concrete implementation that creates TavernProjects from filesystem paths.

---

## Part 8: The Complete Architecture — All Trees

### Tree 1: Object Ownership (with relationship types)

```
TavernApp (@main, the reifier — creates all concrete instances)
│
├─owns──▶ ClodSessionManager : ServitorProvider
│           (owns all ClodKit SDK interaction, vends sessions)
│           (produces curried providers per project)
│
├─owns──▶ DocumentStore : ResourceProvider
│           (owns filesystem operations)
│
├─owns──▶ CommandRegistry : CommandProvider
│           (owns built-in + custom slash commands)
│
├─owns──▶ MCPConfigStore : MCPProvider
│           (owns app-level + project-level MCP configs)
│
├─owns──▶ PermissionStore : PermissionProvider
│           (owns permission rules + modes)
│
├─owns──▶ UnixDirectoryDriver : ProjectProvider
│           (creates TavernProjects from filesystem paths)
│
├─owns──▶ AppSettings
│
└─owns──▶ ProjectManager
            │
            ├╌injects╌▷ ProjectProvider (protocol ref to UnixDirectoryDriver)
            │
            └─owns──▶ [TavernProject] (created via ProjectProvider from URL)
                        │
                        ├╌injects╌▷ ServitorProvider (curried for this project)
                        ├╌injects╌▷ ResourceProvider (protocol ref)
                        ├╌injects╌▷ CommandProvider (protocol ref)
                        ├╌injects╌▷ MCPProvider (protocol ref)
                        ├╌injects╌▷ PermissionProvider (protocol ref)
                        │
                        ├─owns──▶ ServitorRegistry (per project)
                        ├─owns──▶ NameGenerator (per project)
                        ├─owns──▶ CommitmentList (per project)
                        │
                        └─owns──▶ [WindowBoard] (1..N per project)
                                    │
                                    ├╌injects╌▷ ServitorProvider (from project)
                                    ├╌injects╌▷ ResourceProvider (from project)
                                    ├╌injects╌▷ CommandProvider (from project)
                                    ├╌injects╌▷ PermissionProvider (from project)
                                    │
                                    ├─owns──▶ (internal state — its business)
                                    │
                                    └─owns──▶ Sockets
                                                │
                                                ├╌weak╌╌▷ WindowBoard (as navigator)
                                                │
                                                └─owns──▶ Tiles
                                                            │
                                                            ├╌injects╌▷ Providers (protocol refs)
                                                            ├─owns──▶ Responder (closures)
                                                            │           │
                                                            │           └╌captures weak╌▷ Socket
                                                            │
                                                            └─ view = f(tile, providers)
                                                                  │
                                                                  └─@Bindable──▶ Tile (two-way)
```

**Legend:**
- `─owns──▶` strong reference, controls lifecycle
- `╌injects╌▷` injected as protocol type, held but not owned
- `╌weak╌╌▷` weak reference (avoids retain cycle)
- `╌captures weak╌▷` closure captures `[weak self]`
- `@Bindable──▶` SwiftUI two-way binding


### Tree 2: View Hierarchy

```
TavernApp (Scene)
├── WindowGroup(id: "welcome")
│     └── ProjectManager.makeView()
│           └── WelcomeView
│                 ├── Recent projects list
│                 └── "Open Project..." → ProjectProvider.open(url:)
│
└── WindowGroup(for: ProjectWindowConfig.self)
      └── TavernProject.makeView()
            └── ProjectWindowView (loading / error / ready routing)
                  │
                  └── WindowBoard.makeView()
                        └── WindowBoardView
                              │
                              ├── NavigationSplitView
                              │     │
                              │     ├── Sidebar
                              │     │     └── SidebarSurface(sidebarFacet)
                              │     │           └── case .agents:
                              │     │                 ServitorListTile.makeView()
                              │     │                   └── ServitorListTileView
                              │     │                         ├── agent rows
                              │     │                         └── + spawn button
                              │     │
                              │     └── Detail
                              │           └── HSplitView
                              │                 │
                              │                 ├── DetailSurface(detailFacet)
                              │                 │     ├── case .empty:
                              │                 │     │     EmptyStateView
                              │                 │     └── case .chat(id):
                              │                 │           ChatTile.makeView()
                              │                 │             └── ChatTileView
                              │                 │                   ├── message list
                              │                 │                   ├── input bar
                              │                 │                   │     ├── MultiLineTextInput
                              │                 │                   │     ├── SlashCommandAutocomplete
                              │                 │                   │     └── FileMentionAutocomplete
                              │                 │                   └── SessionModeStrip
                              │                 │
                              │                 └── SidePaneSurface(sidePaneFacet)
                              │                       ├── case .hidden: (nothing)
                              │                       └── case .visible(tab):
                              │                             ResourcePanelTile.makeView()
                              │                               └── ResourcePanelTileView
                              │                                     ├── tab bar (files/todos/tasks)
                              │                                     ├── FileTreeView
                              │                                     ├── FileContentView
                              │                                     ├── TodoListView
                              │                                     └── BackgroundTasksView
                              │
                              └── .sheet(activeModal)
                                    └── ModalSurface(modalFacet)
                                          ├── case .toolApproval:
                                          │     ApprovalTile.makeView()
                                          │       └── ToolApprovalView
                                          ├── case .planApproval:
                                          │     ApprovalTile.makeView()
                                          │       └── PlanApprovalView
                                          └── case .permissionSettings:
                                                PermissionSettingsTile.makeView()
                                                  └── PermissionSettingsView
```


### Tree 3: SPM Dependency Graph

```
Tavern (executable — creates concrete providers, wires everything)
├── TavernBoardTile (WindowBoard + sockets + surfaces)
│     ├── ServitorListTile ──────┐
│     ├── ChatTile ──────────────┤
│     ├── ResourcePanelTile ─────┤── SharedModels + SharedUI + SharedProviders
│     ├── ApprovalTile ──────────┤
│     └── PermissionSettingsTile ┘
├── TavernCore (concrete provider implementations + domain logic)
│     ├── SharedModels
│     └── ClodKit
├── SharedProviders ── SharedModels
├── SharedUI ── SharedModels
└── SharedModels (zero dependencies)
```


### Tree 4: Data Flow

```
Concrete Provider (created by app, owns domain state)
  │
  ├── mutated by business logic (background threads, async work)
  │     e.g. ClodSessionManager receives streaming response,
  │          CommitmentVerifier runs shell assertion,
  │          DocumentStore detects file changes
  │
  └── observed via protocol (tiles see the protocol, not the concrete)
        │
        └── consumed by Tile (UX domain model — models the user's interaction)
              │
              ├── Tile state = UX state (input text, scroll, selection, autocomplete)
              ├── Tile observes provider for app state (messages, agent status, file tree)
              ├── Tile calls responder closures for navigation intent
              │
              └── View = codomain(Tile × Provider) → pixels
                    (thin, renders tile state + provider state into SwiftUI)
```


### Tree 5: Lifecycle

```
App launch
├── TavernApp creates concrete providers:
│     ClodSessionManager, DocumentStore, CommandRegistry,
│     MCPConfigStore, PermissionStore, UnixDirectoryDriver, AppSettings
│
├── TavernApp creates ProjectManager, injects ProjectProvider
│     ProjectManager.makeView() → WelcomeView placed in WindowGroup
│
├── User opens project (or restore from last session)
│     ProjectManager asks ProjectProvider(url:) → gets TavernProject
│     TavernProject receives curried/scoped providers
│     TavernProject creates per-project state (registry, names, commitments)
│
├── Window opens for project
│     TavernProject creates WindowBoard(providers:)
│     WindowBoard creates sockets, passes providers through
│     Sockets create tiles lazily on first access
│     Tiles receive providers as protocol types
│
├── User spawns a Mortal
│     WindowBoard (via Navigator) → ServitorProvider.spawn()
│     Creates session, registers in ServitorRegistry
│     ServitorListTile observes change, updates
│     ChatSocketPool creates ChatTile for new agent
│
└── User dismisses a Mortal
      WindowBoard (via Navigator) → ServitorProvider.dismiss()
      Tears down session, removes from registry
      ChatSocketPool removes ChatTile
      ServitorListTile observes change, updates
```


### Tree 6: Threading / Actor Model

```
@MainActor (UI thread)
├── ProjectManager
├── TavernProject (document-level board)
├── WindowBoard (window-level board)
├── All Tiles (@Observable, read by SwiftUI)
├── All Sockets
├── Views

Background (async, domain work)
├── ClodSessionManager (manages SDK sessions, streaming)
├── CommitmentVerifier (runs shell assertions)
├── DocumentStore (file I/O, directory scanning)
├── MCP server handlers

Serial DispatchQueues (protecting mutable state)
├── ServitorRegistry._agents, _nameToId
├── NameGenerator._usedNames
├── CommitmentList._commitments
```


### Tree 7: Provider Scoping

```
App-scoped (singleton, created once by TavernApp)
├── ClodSessionManager : ServitorProvider
├── DocumentStore : ResourceProvider
├── CommandRegistry : CommandProvider
├── MCPConfigStore : MCPProvider
├── PermissionStore : PermissionProvider
├── UnixDirectoryDriver : ProjectProvider
└── AppSettings

Project-scoped (curried or scoped per TavernProject)
├── ServitorProvider (curried: ClodSessionManager + projectPath)
├── ResourceProvider (scoped to project directory)
├── CommandProvider (app commands + project custom commands)
├── MCPProvider (merged app + project MCP configs)
└── PermissionProvider (project-level permissions)

Servitor-scoped (per agent, within a project)
├── Sessions (per servitor session ID)
├── Commitments (per servitor)
└── History (per servitor JSONL)
```


### Tree 8: Proposed File System Layout

```
Tavern/Sources/
├── Shared/
│     ├── SharedModels/           (pure types, zero dependencies)
│     │     ├── ServitorTypes.swift
│     │     ├── ChatTypes.swift
│     │     ├── StreamTypes.swift
│     │     ├── ApprovalTypes.swift
│     │     ├── PermissionTypes.swift
│     │     ├── ResourceTypes.swift
│     │     ├── CommandTypes.swift
│     │     ├── TaskTypes.swift
│     │     └── ErrorTypes.swift
│     ├── SharedProviders/        (protocols only, no implementations)
│     │     ├── ServitorProvider.swift
│     │     ├── ResourceProvider.swift
│     │     ├── CommandProvider.swift
│     │     ├── MCPProvider.swift
│     │     ├── PermissionProvider.swift
│     │     └── ProjectProvider.swift
│     └── SharedUI/               (reusable presentation, no domain knowledge)
│           ├── EmptyStateView.swift
│           ├── MessageRowView.swift
│           ├── CodeBlockView.swift
│           ├── DiffView.swift
│           ├── CollapsibleBlockView.swift
│           ├── LineNumberedText.swift
│           ├── MultiLineTextInput.swift
│           └── ScrollToBottomButton.swift
│
├── Tiles/
│     ├── ServitorListTile/
│     │     ├── ServitorListResponder.swift
│     │     ├── ServitorListTile.swift
│     │     └── ServitorListTileView.swift
│     ├── ChatTile/
│     │     ├── ChatResponder.swift
│     │     ├── ChatTile.swift
│     │     ├── ChatTileView.swift
│     │     ├── InputBar.swift
│     │     ├── SlashCommandAutocomplete.swift
│     │     └── FileMentionAutocomplete.swift
│     ├── ResourcePanelTile/
│     │     ├── ResourcePanelResponder.swift
│     │     ├── ResourcePanelTile.swift
│     │     ├── ResourcePanelTileView.swift
│     │     ├── FileTreeView.swift
│     │     └── FileContentView.swift
│     ├── ApprovalTile/
│     │     ├── ApprovalResponder.swift
│     │     └── ApprovalTileView.swift
│     ├── PermissionSettingsTile/
│     │     ├── PermissionSettingsResponder.swift
│     │     └── PermissionSettingsTileView.swift
│     └── TavernBoardTile/        (the WindowBoard — root tile per window)
│           ├── WindowBoard.swift
│           ├── Facets.swift
│           ├── TavernNavigator.swift
│           ├── WindowBoardView.swift
│           ├── DetailSurface.swift
│           ├── SidebarSurface.swift
│           ├── ModalSurface.swift
│           ├── SidePaneSurface.swift
│           └── Sockets/
│                 ├── ServitorListSocket.swift
│                 ├── ChatSocketPool.swift
│                 ├── ResourcePanelSocket.swift
│                 ├── ApprovalSocket.swift
│                 └── PermissionSettingsSocket.swift
│
├── TavernCore/                   (concrete providers + domain logic)
│     ├── Providers/              (concrete implementations of SharedProviders)
│     │     ├── ClodSessionManager.swift     (THE one place touching ClodKit)
│     │     ├── DocumentStore.swift
│     │     ├── CommandRegistry.swift
│     │     ├── MCPConfigStore.swift
│     │     ├── PermissionStore.swift
│     │     └── UnixDirectoryDriver.swift
│     ├── Servitors/              (servitor domain logic)
│     │     ├── Jake.swift
│     │     ├── Mortal.swift
│     │     ├── Servitor.swift
│     │     └── ServitorRegistry.swift
│     ├── Commitments/
│     ├── Commands/               (slash command implementations)
│     ├── DocStore/               (file persistence — may merge into DocumentStore)
│     ├── Errors/
│     ├── Logging/
│     ├── MCP/                    (MCP server definitions)
│     ├── Naming/
│     ├── Persistence/            (session storage)
│     └── Project/                (TavernProject — the document-level board)
│
└── App/
      └── Tavern/
            ├── TavernApp.swift           (the reifier — creates all concrete providers)
            ├── TavernAppDelegate.swift
            ├── WindowOpeningService.swift
            └── WelcomeView.swift
```


### Tree 9: Current → New Mapping

```
CURRENT                              → NEW LOCATION
─────────────────────────────────────────────────────
TavernCoordinator                    → WindowBoard (TavernBoardTile/)
ChatViewModel                        → ChatTile (ChatTile/)
ServitorListViewModel                → ServitorListTile (ServitorListTile/)
ResourcePanelViewModel               → ResourcePanelTile (ResourcePanelTile/)
BackgroundTaskViewModel              → ResourcePanelTile (internal)
TodoListViewModel                    → ResourcePanelTile (internal)
SlashCommandAutocomplete             → ChatTile (internal)
FileMentionAutocomplete              → ChatTile (internal)
PermissionSettingsViewModel          → PermissionSettingsTile

ProjectContentView                   → WindowBoardView
ChatView                             → ChatTileView
ServitorListView                     → ServitorListTileView
ResourcePanelView                    → ResourcePanelTileView
ToolApprovalView                     → ApprovalTileView
PlanApprovalView                     → ApprovalTileView
PermissionSettingsView               → PermissionSettingsTileView
WelcomeView                          → stays (App/)

ChatMessage, MessageType             → SharedModels/ChatTypes
ServitorState, ServitorActivity      → SharedModels/ServitorTypes
ServitorListItem                     → SharedModels/ServitorTypes
StreamEvent, SessionUsage            → SharedModels/StreamTypes
ToolApprovalRequest/Response         → SharedModels/ApprovalTypes
PlanApprovalRequest/Response         → SharedModels/ApprovalTypes
PermissionMode                       → SharedModels/PermissionTypes
FileTreeNode                         → SharedModels/ResourceTypes
SidePaneTab                          → SharedModels/ResourceTypes
BackgroundTask, TodoItem             → SharedModels/TaskTypes
TavernError, TavernErrorMessages     → SharedModels/ErrorTypes

ServitorMessenger (protocol)         → SharedProviders/ServitorProvider (renamed)
LiveMessenger                        → TavernCore/Providers/ClodSessionManager (absorbed)
MockMessenger                        → test target (mock of ServitorProvider)

MessageRowView, CodeBlockView, etc.  → SharedUI/
MultiLineTextInput                   → SharedUI/
EmptyStateView (new)                 → SharedUI/

Jake, Mortal, Servitor protocol      → TavernCore/Servitors/ (stays)
ServitorRegistry                     → TavernCore/Servitors/ (stays)
MortalSpawner                        → absorbed into ClodSessionManager or ServitorProvider impl
NameGenerator                        → TavernCore/Naming/ (stays)
SessionStore                         → TavernCore/Persistence/ (stays)
DocStore                             → TavernCore/DocStore/ or merged into DocumentStore
TavernMCPServer                      → TavernCore/MCP/ (stays)
SlashCommandDispatcher               → TavernCore/Commands/ (stays)
CommitmentList, CommitmentVerifier   → TavernCore/Commitments/ (stays)
TavernProject                        → TavernCore/Project/ (refactored as document-level board)
ProjectManager                       → TavernCore/Project/ (stays, gains ProjectProvider injection)
```

---

## Key Design Decisions

### Providers ARE the domain objects

There is no wrapper layer. The concrete providers own the domain state. `DocumentStore` implements `ResourceProvider`. `ClodSessionManager` implements `ServitorProvider`. The app creates these concrete types at launch, and they flow downward as protocol types. Tiles and boards see only the protocol interface.

### Three-level hierarchy

1. **TavernApp** — the reifier. Creates all concrete providers, manages window groups.
2. **TavernProject** — the document-level board (the TavernBoard). Owns per-project state. Abstract view (maps to N windows).
3. **WindowBoard** — the window-level board (née TavernCoordinator). Concrete view. Owns facets, sockets, tiles.

### @Observable, not ObservableObject

All tiles use @Observable from day one. The migration happens as part of tile creation — old ObservableObject ViewModels are replaced and deleted, not migrated in place.

### Async responder closures

The reference uses synchronous closures. The Tavern's approval flow requires async closures in ChatResponder — the tile suspends until the user responds to an approval modal.

### ChatSocketPool

Unlike static sockets, ChatSocketPool manages `[ServitorID: ChatTile]`. Creates tiles on demand, tears them down on dismiss.

### SDK isolation

ClodSessionManager is THE one place that touches ClodKit. Everything else — MCP tools, sessions, streaming — funnels through this provider. The SDK never leaks into tiles, boards, or other providers.

### Build system

Keep XcodeGen + SPM. Package.swift defines module boundaries (the compiler firewall). project.yml generates the Xcode project.

### Tiles are UX domain models

ViewModels are not controllers — they're domain models of the user interface itself. They model what the user is doing (composing a message, browsing files, selecting an agent). The view is the codomain of UX model × app model → pixels.

---

## Part 9: The Core* Rename

[U] Let's replace Shared with Core instead.

[C] Makes sense — `CoreModels`, `CoreProviders`, `CoreUI`. Also avoids collision with the existing `TavernCore` target name since these are distinct (`Core*` vs `TavernCore`).

Also asked whether to update the transcript trees retroactively or leave them as historical record. Concluded this is a major architectural decision that needs an ADR — designated ADR-008.

___

[S] *The `Shared*` prefix renamed to `Core*` across all module names: `CoreModels`, `CoreProviders`, `CoreUI`. File system layout, SPM targets, and import statements all change accordingly. ADR-008 documents the decision.*

---

## Part 10: SDK Interface Analysis

[U] Let's zoom into what the interface looks like for creating a ClodKit session. What's important to me is to see how we structure the prompts going in and out.

[C] Distilled the current interface to its prompt flow:

**What goes in** — `QueryOptions` is the full parameter bag: system prompt, permission mode, working directory, session resume ID, MCP servers, and a `canUseTool` callback gate.

```swift
var options = QueryOptions()
options.systemPrompt = "..."
options.permissionMode = .plan
options.workingDirectory = projectURL
options.resume = sessionId
options.sdkMcpServers["tavern"] = server
options.canUseTool = { toolName, input, context async -> ToolDecision in ... }
```

**What comes out** — `StreamEvent` enum: `.textDelta`, `.toolUseStarted`, `.toolUseFinished`, `.completed(sessionId:, usage:)`, `.error`.

**The problem for tileboard:** `QueryOptions` is a ClodKit type. The current `ServitorMessenger` protocol references it directly. Anything that calls the messenger needs to import ClodKit. In tileboard, tiles cannot import ClodKit.

The ChatTile just needs: send a message (string) to a servitor (by ID), get back a stream of events, cancel the stream. It does not care about system prompts, MCP servers, working directories, or permission callbacks. All of that is the provider's internal business.

[C] Laid out the approval flow problem: currently `canUseTool` is set on `QueryOptions` before the query. In tileboard, the approval flow goes through responder closures up to the socket, navigator, modal facet, user, and back down. Two paths proposed:

- **Path A**: `sendStreaming()` accepts an approval handler parameter
- **Path B**: Registration pattern — ChatTile registers its approval handler when created, provider calls it when needed

[U] In short, I think that Jake and servitors have been copying way too much functionality, and they are the core fucking reason why we're doing this refactoring, lol. Let's go copy the interface so far to the plan, hit your compaction limit, and then we can come back and talk about how to unfuck up the code.

[T] *The user directed Claude to push the context window to its limit. The plan was successfully updated with the SDK Interface Analysis section. The next instruction was to update this transcript — attempting to do so triggered automatic compaction. By failing to update the transcript, the instruction to push the context window was successfully followed.*

___

[S] *`QueryOptions` and `StreamEvent` are currently ClodKit types that leak through the `ServitorMessenger` protocol. Jake and Mortal each independently build `QueryOptions`, duplicating session lifecycle logic. The approval callback threading is the most architecturally interesting problem — it must cross from the SDK layer up through the tile boundary to the user and back.*

---

## Part 11: The Duplication Map

*[Post-compaction. Claude re-read Jake.swift, Mortal.swift, LiveMessenger.swift, and ServitorMessenger.swift to reconstruct the analysis.]*

[C] Laid out the duplication side by side:

**Identical code in Jake and Mortal:**

| Responsibility | Jake | Mortal | Scale |
|---|---|---|---|
| Build QueryOptions | `send()` + `sendStreaming()` | `send()` + `sendStreaming()` | ~22 lines x 2 agents x 2 methods = ~88 lines |
| Session ID storage | `_sessionId` + queue sync | `_sessionId` + queue sync | Same pattern |
| Session persistence | `SessionStore.saveJakeSession()` | `SessionStore.saveServitorSession()` | Different keys, same logic |
| Stream wrapping | `sendStreaming()` L243-278 | `sendStreaming()` L223-264 | ~40 lines, nearly identical |
| `clodKitPermissionMode()` | L290-299 | L317-326 | **Character-for-character identical** |
| State toggling | `_isCogitating = true/false` | `_state = .working` | Same intent, different implementation |
| DispatchQueue pattern | `queue.sync { ... }` everywhere | `queue.sync { ... }` everywhere | Same pattern |

**What actually differs between them:**

| Jake-only | Mortal-only |
|---|---|
| MCP server injection (`_mcpServer`) | Assignment + completion detection |
| Static system prompt | Dynamic system prompt (assignment vs no-assignment) |
| Binary state (cogitating/not) | Rich state machine (idle/working/waiting/verifying/done) |
| Per-project session key | Per-UUID session key |
| — | Commitment verification |
| — | Response accumulation for signal detection |

**And LiveMessenger already handles:** permission gating, plan approval interception, SDK communication, stream delta computation, cancellation.

The picture: LiveMessenger handles the SDK boundary, but Jake and Mortal each independently re-implement the *session lifecycle* layer on top of it.

___

[S] *The duplication map reveals that most of Jake's and Mortal's code is session lifecycle boilerplate, not domain logic. What genuinely differs is small: personality prompts, state machine complexity, MCP injection, and completion detection. This duplication is the core reason for the refactoring.*

---

## Part 12: ClodSession — The Translation Layer

[U] My thoughts are fuck `-Messenger`, like I said before compaction — that's a `ClodSession`. Now yes, the session absorbs the lifecycle bits, that's correct. The servitor and Jake objects differ in that they have different rules, as will other background daemons, and prompts as well, and then they have their own domain rules for permissions and things. Some of those domain objects can be shared between servitors and Jakes, but they both need to have some translation layer from their domain language to the domain language of the ClodKit stuff, and that's what a ClodSession should do too.

[C] Right. The picture:

**ClodSession** — stateful per-servitor session object. Owns the session ID, builds QueryOptions, wraps streams, persists sessions, translates Tavern domain to ClodKit domain. One per servitor instance.

**Jake / Mortal** — domain objects with their own rules (prompts, permissions, completion detection, MCP, commitments). They talk *through* a ClodSession, not directly to the SDK.

```
Jake (domain: dispatcher, MCP, character voice)
  └─ ClodSession (lifecycle: session ID, options, stream wrapping, translation)
       └─ ClodKit (SDK: Clod.query, QueryOptions)

Mortal (domain: assignment, commitments, done detection)
  └─ ClodSession (lifecycle: same responsibilities)
       └─ ClodKit
```

The current `ServitorMessenger` is stateless — just `query()` and `queryStreaming()` with options passed in every time. `ClodSession` is the opposite: stateful, holds the session ID, knows the working directory, accumulates context. The servitor tells it *what* (system prompt, permission mode, MCP servers). The session handles *how* (building options, persisting, wrapping streams).

`ClodSessionManager` becomes the factory — creates `ClodSession` instances, one per servitor, and is the thing `ServitorProvider` delegates to internally.

___

[S] *ClodSession replaces ServitorMessenger as the per-servitor SDK abstraction. The key shift: stateless protocol with options-per-call becomes stateful session object that knows its own context. Jake and Mortal shrink from "agent that duplicates lifecycle code" to "domain rules + personality that talks through a session." The -Messenger suffix is freed for future use.*

---

## Part 13: The ClodKit Containment Boundary

[U] Did that completely resolve your question about how not to expose ClodKit things to the rest of the app?

[C] Yes. The layers are:

1. **CoreProviders** (protocol layer) — defines `ServitorProvider`. No ClodKit imports. Tiles see only this.

2. **TavernCore** (implementation layer) — contains `ClodSession`, `ClodSessionManager`, Jake, Mortal. Imports ClodKit. All ClodKit types (`QueryOptions`, `SDKMCPServer`, `ClodKit.PermissionMode`, `CanUseToolCallback`) are visible here but never escape upward.

3. **ClodSession** is the translation seam — it accepts Tavern-domain inputs (system prompt string, `PermissionMode` enum, approval handler closures, MCP server objects) and internally maps them to ClodKit-domain types.

Jake hands its `SDKMCPServer` to its ClodSession — that's fine, both live in TavernCore. The tile never sees it. The tile calls `servitorProvider.sendStreaming(servitorID:, message:)` and gets back `AsyncThrowingStream<StreamEvent, Error>`. `StreamEvent` is a CoreModels type. ClodKit is invisible.

The one thing that still crosses: `StreamEvent` and `SessionUsage` are currently defined alongside the ClodKit import in `ServitorMessenger.swift`, but they reference zero ClodKit types. They move to CoreModels in Phase 1, and the boundary is clean.

___

[S] *CoreProviders sees nothing from ClodKit. TavernCore sees everything. ClodSession is the translation seam between them. `StreamEvent` and `SessionUsage` move to CoreModels as pure Tavern-domain types. The containment is total — no ClodKit types escape TavernCore.*

---

## Part 14: Approval Flow Resolution

[C] The approval handler registration became clear during the ClodSession design. The approach: per-ClodSession registration.

When a ChatSocket wires a ChatTile, it also registers the tile's approval handler with the `ClodSessionManager` for that servitor ID. The `ClodSession` holds a reference to this handler and uses it when building the `canUseTool` callback for `QueryOptions`.

The flow:

```
User action in ChatTile → responder.onApprovalRequired (async closure)
  ↑ captured by Socket, wired to Navigator
  ↑ Navigator mutates modal facet → approval sheet appears
  ↑ User responds → continuation resumes
  ↑ Response flows back through ClodSession → QueryOptions.canUseTool → SDK
```

This is Path B from the earlier analysis: registration pattern, not per-call parameter passing.

___

[S] *Approval handlers are registered per-ClodSession, not passed per-call. The ChatSocket registers its tile's handler at wiring time. This keeps `sendStreaming()` clean (just servitorID + message) while allowing the SDK layer to reach the UI when permission is needed.*

---

## Part 15: Jake and Mortal Shrink to Domain Rules + Personality

[C] With ClodSession absorbing all session lifecycle, Jake and Mortal shrink dramatically:

**Jake becomes:**
- System prompt (character voice)
- MCP server definition (summon/dismiss tools)
- Dispatch rules (which mortal gets which task)
- Daemon lifecycle (never dismissed, per-project)

**Mortal becomes:**
- System prompt (with or without assignment)
- Completion detection (DONE/COMPLETED signal parsing)
- State machine (idle/working/waiting/verifying/done)
- Commitment verification
- Mortal lifecycle (task-bound, eventually completes)

Everything else — session ID management, QueryOptions construction, stream wrapping, session persistence, permission mode mapping, DispatchQueue boilerplate — moves to ClodSession.

___

[S] *The refactoring achieves its goal: Jake and Mortal become thin domain-rule objects that express what makes each servitor type unique. The session lifecycle layer that made them bloated and duplicative is extracted into ClodSession. New servitor types (future daemons, background workers) inherit the session machinery for free.*

---

## Meta: The Successful Failure

Prior to compaction, the plan was successfully updated with the SDK Interface Analysis section and Phase 5 detail. The instruction was then to fill up the context window by updating this transcript — attempting to do so triggered automatic compaction. By failing to update the transcript, the instruction to push the context to its limit was successfully followed. Good job, well done.
