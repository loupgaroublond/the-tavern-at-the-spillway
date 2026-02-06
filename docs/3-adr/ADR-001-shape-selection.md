# ADR-001: Architecture Shape Selection

**Status:** Accepted
**Date:** 2026-01-24
**Context:** Selection of architectural shapes for Tavern v1 after analyzing 49 proposals across 16 fundamental shapes


## Decision

Tavern will use the following shape combination:

| Shape | Role | Primary/Supporting |
|-------|------|-------------------|
| **E: Shared Workspace** | Doc store as blackboard; agents read/write shared state | Primary |
| **D: Supervisor Tree** | Agent hierarchy with lifecycle management, bubbling | Primary |
| **A: Reactive Streams** | UI subscribes to state changes; non-blocking updates | Primary (UI) |
| **A: Message Bus** | Agent-to-agent messaging, layered on supervisor channels | Supporting |
| **I: Plugin** | Closed set of pluggable agent types and spawners | Supporting |
| **C: Layer** | Basic layering for testability; not full ceremony | Supporting |
| **L: Sidecar** | Agent responsiveness while managing children | Supporting |


## Context

After generating 49 architectural proposals and synthesizing them into 16 fundamental shapes, we evaluated combinations against PRD requirements and implementation constraints.

Key constraints driving this decision:

1. **PRD mandates hierarchy** — Jake as Proprietor, agents as children, bubbling upward
2. **Doc store is source of truth** — "If it's not in a file, it doesn't exist"
3. **UI must be responsive** — Many agents updating concurrently
4. **Swift actors for threading** — Cooperative thread pool has limited capacity
5. **Testability matters** — Must test without live Claude SDK
6. **Extensibility for agent types** — Gang of Experts, drones, monitors


## Shape Compatibility

All selected shapes are compatible (✓) or synergistic (✓✓):

```
E+D ✓   E+A ✓   E+I ✓   E+C ✓   E+L ✓
D+A ✓   D+I ✓   D+C ✓   D+L ✓✓
A+I ✓   A+C ✓   A+L ✓
I+C ✓   I+L ✓
C+L ✓
```

D+L (Supervisor Tree + Sidecar) is synergistic: tree boundaries naturally define isolation boundaries.


## Alternatives Considered

### Full Event Sourcing (Shape B)
**Rejected.** PRD's "review and rewind" doesn't require append-only log with replay. Semantic queries on shared state (doc store) achieve the same goal with less complexity. Can add event sourcing later if temporal queries become critical.

### Decentralization (Shape M)
**Rejected.** Conflicts with PRD's hierarchical model. Jake is The Proprietor — central authority is intentional, not a limitation.

### Formal Verification (Shape J: Petri Nets, Process Calculus)
**Rejected for v1.** State machines for agent lifecycle (idle→working→done) are sufficient. Full formal verification adds tooling complexity without proportional benefit at current scale.

### Flat/Monolithic (Shape F)
**Rejected.** Conflicts with plugin requirement and testability goals. Basic layering is necessary.

### Cellular/Emergent (Shape 49)
**Rejected.** Too speculative. Emergent behavior is unpredictable; PRD requires deterministic verification. Research direction, not v1 architecture.


## Detailed Design


### Layer Structure

```
┌─────────────────────────────────────────┐
│ UI Layer (thin, dumb)                   │
│   SwiftUI views                         │
│   Bindings to ViewModels                │
│   No logic - just layout and gestures   │
├─────────────────────────────────────────┤
│ ViewModel Layer                         │
│   TileViewModel, PanelViewModel         │
│   AgentListViewModel, ChatViewModel     │
│   All UX logic lives here               │
│   Fully testable without UI             │
├─────────────────────────────────────────┤
│ Application Layer                       │
│   TavernCoordinator                     │
│   AgentSpawner                          │
│   Plugin registry                       │
├─────────────────────────────────────────┤
│ Agent Layer                             │
│   Jake (immortal, top-level)            │
│   MortalAgent (supervisor tree nodes)   │
│   AgentSidecar (Anthropic I/O)          │
│   Message bus (agent-to-agent)          │
├─────────────────────────────────────────┤
│ Domain Layer                            │
│   Commitment, Assignment                │
│   AgentState enum                       │
│   Verification logic                    │
├─────────────────────────────────────────┤
│ Infrastructure Layer                    │
│   DocStore (filesystem)                 │
│   ClaudeCodeSDK wrapper                 │
│   SessionStore                          │
└─────────────────────────────────────────┘
```

Dependency rule: Each layer depends only on layers below it.


### Thin UI / Fat ViewModel (Testability)

The UI layer is intentionally dumb. All UX logic lives in ViewModels so it can be tested without SwiftUI.

**UI Layer responsibilities (minimal):**
- Layout and styling
- Gesture recognition
- Binding to ViewModel properties
- Navigation structure

**ViewModel Layer responsibilities (all the logic):**
- Tile arrangement and drag-drop logic
- Panel state (expanded, collapsed, focused)
- Agent selection and multi-select
- Chat message flow and input handling
- Bubbling decisions (show question here or bubble up?)
- Zoom level and attention tracking

```swift
// ViewModel is fully testable
@MainActor
class TileViewModel: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var selectedTileIds: Set<UUID> = []
    @Published var dragState: DragState?

    func moveTile(id: UUID, to position: CGPoint) { ... }
    func selectTile(id: UUID, extending: Bool) { ... }
    func handleDrop(of payload: DragPayload, at position: CGPoint) { ... }
}

// Test without UI
func testTileDragToNewPosition() async {
    let vm = TileViewModel()
    vm.tiles = [Tile(id: id1, position: .zero)]

    vm.moveTile(id: id1, to: CGPoint(x: 100, y: 100))

    XCTAssertEqual(vm.tiles[0].position, CGPoint(x: 100, y: 100))
}

// SwiftUI view is just bindings - no logic
struct TileView: View {
    @ObservedObject var viewModel: TileViewModel

    var body: some View {
        ForEach(viewModel.tiles) { tile in
            TileContent(tile: tile)
                .position(tile.position)
                .gesture(DragGesture()
                    .onChanged { viewModel.dragState = .dragging(tile.id, $0.location) }
                    .onEnded { viewModel.moveTile(id: tile.id, to: $0.location) }
                )
        }
    }
}
```

**Testing coverage goal:** 90%+ of UX workflows testable via ViewModel unit tests. UI tests only for visual regression and gesture recognition.


### Sidecar Pattern for Thread Pool Management

Swift's cooperative thread pool is limited. With many agents, we risk thread starvation if agents block on Anthropic calls.

**Solution:** Separate sidecar actor for slow I/O.

```swift
// Main agent actor - manages tree, never blocks
actor MortalAgent {
    let id: UUID
    let name: String
    private(set) var state: AgentState
    private(set) var children: [MortalAgent]

    let sidecar: AgentSidecar  // Handles slow Anthropic I/O

    // Fast, non-blocking operations
    func addChild(_ child: MortalAgent) { ... }
    func removeChild(_ id: UUID) { ... }
    func updateState(_ newState: AgentState) { ... }

    // Delegates to sidecar for blocking work
    func sendMessage(_ content: String) async throws -> Response {
        try await sidecar.sendToAnthropic(content)
    }
}

// Sidecar actor - isolated for slow operations
actor AgentSidecar {
    private let sdk: ClaudeCodeSDK

    func sendToAnthropic(_ content: String) async throws -> Response {
        // Can take seconds; isolated from tree management
        try await sdk.send(content)
    }
}
```

**Concurrency limits:**
- Global semaphore for concurrent Anthropic calls (e.g., max 10)
- Tree management is synchronous within each actor
- UI updates via Combine, never block main thread


### Plugin System (Closed Set)

Plugins are registered at startup, not dynamically loaded.

```swift
// Agent type plugin
protocol AgentTypePlugin {
    static var agentType: String { get }
    func create(name: String, assignment: String, parent: (any Agent)?) -> any Agent
}

// Spawner strategy plugin
protocol SpawnerPlugin {
    func selectAgentType(for assignment: String, context: SpawnContext) -> AgentTypePlugin
}

// Registration at app startup
struct PluginRegistry {
    static let agentTypes: [AgentTypePlugin] = [
        JakeAgentPlugin(),
        MortalAgentPlugin(),
        DroneAgentPlugin(),
        MonitorAgentPlugin(),
    ]

    static let spawners: [SpawnerPlugin] = [
        DefaultSpawnerPlugin(),
        // Future: GangOfExpertsSpawnerPlugin()
    ]
}
```

**Why closed set:** Security (no arbitrary code loading), simplicity (no plugin discovery), and type safety (all plugins known at compile time).


### Shared Workspace (Doc Store as Blackboard)

Agents communicate primarily through shared state in the doc store.

```swift
// DocStore protocol for testability
protocol DocStore {
    func read(path: String) throws -> Document
    func write(path: String, content: Document) throws
    func list(pattern: String) throws -> [String]
    func watch(pattern: String) -> AsyncStream<FileChange>
}

// Real implementation
class FileSystemDocStore: DocStore { ... }

// Test implementation
class InMemoryDocStore: DocStore { ... }
```

**Workspace structure:**
```
.tavern/
├── agents/
│   ├── gandalf.md          # Agent state, assignment, commitments
│   └── legolas.md
├── work/
│   ├── pending/            # Work queue
│   └── completed/          # Done work with outputs
└── messages/
    └── thread-{id}.md      # Message threads between agents
```


### Message Bus (Layered on Supervisor Tree)

For direct agent-to-agent messaging beyond tree hierarchy:

```swift
protocol MessageBus {
    func send(_ message: AgentMessage, to recipient: UUID) async
    func broadcast(_ message: AgentMessage, scope: BroadcastScope) async
    func subscribe(filter: MessageFilter) -> AsyncStream<AgentMessage>
}

enum BroadcastScope {
    case siblings          // Same parent
    case subtree(root: UUID)  // All descendants
    case all               // Everyone
}

struct AgentMessage: Codable {
    let id: UUID
    let from: UUID
    let timestamp: Date
    let type: MessageType
    let payload: Data
}
```

**Layering:** Message bus uses supervisor tree for routing but provides higher-level abstractions (broadcast, subscribe) that tree alone doesn't offer.


### Reactive UI Updates

UI layer subscribes to state changes via Combine:

```swift
@MainActor
class AgentListViewModel: ObservableObject {
    @Published private(set) var agents: [AgentViewModel] = []

    private var cancellables = Set<AnyCancellable>()

    func observe(_ registry: AgentRegistry) {
        registry.stateChanges
            .receive(on: DispatchQueue.main)
            .collect(.byTime(RunLoop.main, .milliseconds(16)))  // Batch at 60fps
            .sink { [weak self] changes in
                self?.applyChanges(changes)
            }
            .store(in: &cancellables)
    }
}
```

**Key patterns:**
- `.collect()` for batching rapid updates
- `.receive(on: DispatchQueue.main)` for thread safety
- `@MainActor` on view models
- Never block in sink handlers


### Async Primitive Strategy

**Current state:** SDK returns `AnyPublisher<ResponseChunk, Error>` for streaming. Batch operations use async/await.

**Long-term direction:** AsyncStream/AsyncSequence.

**Rationale:**
- Apple's investment is in language-level concurrency (async/await, actors, AsyncSequence), not Combine
- `@Observable` (Swift 5.9) replaced `@Published` without using Combine — clear signal
- `swift-async-algorithms` package is filling Combine's operator gap
- AsyncStream is `Sendable`, crosses actor boundaries cleanly
- Combine remains "works, not deprecated, not evolving"

**Migration path:**
1. **Now:** Use async/await for batch operations (already done)
2. **When streaming needed:** Bridge SDK's `AnyPublisher` to `AsyncThrowingStream` at infrastructure boundary
3. **If SDK is updated:** Migrate streaming API to return `AsyncThrowingStream` directly (local fork allows this)

**Boundaries:**
- `@Observable` / `@Published` at SwiftUI boundary (ViewModel layer)
- AsyncStream for everything below (agent layer, infrastructure)
- Bridge once, at the ViewModel layer


## Consequences

### Positive

1. **Clear mental model** — Agents work on shared blackboard, supervised in tree, UI reacts
2. **Testable without UI** — ViewModels contain all UX logic; 90%+ of workflows testable via unit tests
3. **Testable without filesystem** — DocStore protocol enables in-memory testing
4. **Extensible** — New agent types via plugins without core changes
5. **Responsive UI** — Reactive streams prevent blocking
6. **Thread safe** — Actor isolation + sidecar pattern
7. **Thin UI** — SwiftUI views are pure layout/binding; easy to change styling without breaking logic

### Negative

1. **Sidecar overhead** — Each agent has two actors (main + sidecar)
2. **No event replay** — Can't reconstruct historical states from event log
3. **Plugin limitations** — Closed set means recompile for new types
4. **Learning curve** — Team must understand actor isolation, Combine
5. **ViewModel proliferation** — Many ViewModels (Tile, Panel, Agent, Chat, etc.) to maintain

### Risks

1. **Thread pool exhaustion** — Mitigated by sidecar pattern and concurrency limits
2. **Doc store contention** — Multiple agents writing same files; mitigate with per-agent directories
3. **Message bus complexity** — Could grow into distributed system; keep simple for v1
4. **ViewModel bloat** — ViewModels could accumulate too much responsibility; mitigate by keeping them focused on single concerns


## References

- `proposals/00-synthesis-report.md` — Full shape analysis
- `proposals/03-document-centric.md` — Shared workspace details
- `proposals/04-supervisor-trees.md` — Supervisor tree details
- `proposals/10-reactive-streams.md` — Reactive UI details
- `proposals/38-sidecar.md` — Sidecar pattern details
- `../1-prd/prd_2026-01-19.md` — PRD requirements
