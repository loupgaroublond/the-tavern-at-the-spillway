# Data Flow Architecture — Complete Treatise

This document contains my complete analysis of applying Data Flow patterns to the Tavern multi-agent orchestrator.


## Research Findings


### What Is Data Flow Architecture?

Data Flow architecture treats computation as a directed graph where data flows from sources (inputs) through transformations (computations) to sinks (outputs). The key characteristics:

1. **Declarative dependencies** — You specify *what* depends on *what*, not *how* updates propagate
2. **Automatic propagation** — When a source changes, all downstream nodes update automatically
3. **Memoization** — Computed values are cached until their dependencies change
4. **Glitch-free** — Updates are atomic; no intermediate inconsistent states are visible

The canonical example is a spreadsheet: cell A1 contains a number, cell B1 contains `=A1*2`. Change A1, B1 updates. You don't write code to update B1; the dependency is implicit in the formula.

Modern reactive frameworks like React, Elm, MobX, and SwiftUI are all variations on this theme.


### Current Codebase Analysis

**Existing Data Flow Patterns:**

The codebase already uses data flow in several places:

1. **SwiftUI's `@Published`** — `ChatViewModel`, `TavernCoordinator`, `ProjectManager` all use `@Published` properties that automatically update views when changed. This IS data flow at the view layer.

2. **Derived state in view models:**

```swift
// AgentListViewModel.swift
public var selectedItem: AgentListItem? {
    guard let id = selectedAgentId else { return nil }
    return items.first { $0.id == id }
}
```

`selectedItem` is derived from `selectedAgentId` and `items`. This is a computed property, which is data flow.

3. **Agent state derivation:**

```swift
// Jake.swift
public var state: AgentState {
    queue.sync { _isCogitating ? .working : .idle }
}
```

The exposed `state` is derived from internal `_isCogitating`. Pure data flow.

**Imperative Patterns (Not Data Flow):**

1. **Manual refresh calls:**

```swift
// TavernCoordinator.swift
public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
    let agent = try spawner.spawn(assignment: assignment)
    agentListViewModel.cacheAssignment(agentId: agent.id, assignment: assignment)
    agentListViewModel.agentsDidChange()  // MANUAL UPDATE CALL
    if selectAfterSpawn {
        selectAgent(id: agent.id)
    }
    return agent
}
```

The explicit `agentsDidChange()` is imperative — we're telling the view model to update rather than having it automatically derive from the registry.

2. **State machine transitions in MortalAgent:**

```swift
// MortalAgent.swift
private func updateStateAfterResponse() {
    queue.sync {
        if _state == .working {
            _state = .idle
        }
    }
}
```

State transitions are imperative, not declarative. Pure data flow would have state derived from other values.

3. **Message accumulation in ChatViewModel:**

```swift
// ChatViewModel.swift
messages.append(userMessage)
// ... later
messages.append(agentMessage)
```

Messages are accumulated imperatively. A pure data flow model would derive `messages` from session history.


### PRD Requirements Mapping

**How Data Flow addresses PRD requirements:**

| PRD Requirement | Data Flow Mapping |
|-----------------|-------------------|
| "Doc store is source of truth" | Doc store = source nodes; all else derived |
| "Commitments verified independently" | `CommitmentStatus` computed from shell results |
| "User attention is sacred" | Notification count derived from pending questions |
| Agent state transitions | State derived from response content + verification status |
| Multi-agent dashboard | Dashboard metrics derived from all agent states |
| Persistence across restart | Source nodes restored from disk; derived nodes recompute |

**Key Insight:** The PRD's emphasis on "doc store as source of truth" aligns perfectly with data flow. If the filesystem is the only authoritative state, everything else (agent status, message history, commitment status) should be *derived* from files, not stored separately.

**Potential Implementation:**

```swift
// DocStore as the source node
actor DocStore {
    @Published var documents: [DocumentID: Document]

    // Changes here propagate downstream
}

// Agent state derived from document
struct AgentNode {
    let document: Document

    var state: AgentState {
        // Derived from document content
        if document.metadata["status"] == "done" { return .done }
        if document.metadata["status"] == "verifying" { return .verifying }
        // ...
    }

    var commitments: [Commitment] {
        // Derived from document YAML frontmatter
        document.metadata["commitments"] as? [Commitment] ?? []
    }
}

// View automatically updates when document changes
@MainActor
class ChatViewModel: ObservableObject {
    @Published var agentNode: AgentNode?

    var state: AgentState {
        agentNode?.state ?? .idle  // Derived
    }

    var messages: [ChatMessage] {
        agentNode?.messages ?? []  // Derived from document
    }
}
```


### How Combine/SwiftUI Already Does This Partially

SwiftUI is fundamentally a data flow framework. The view is a function of state:

```swift
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        // View is derived from viewModel
        // When viewModel.messages changes, body recomputes
        List(viewModel.messages) { msg in
            MessageRow(message: msg)
        }
    }
}
```

**What SwiftUI provides:**
- `@State`, `@Binding`, `@ObservedObject`, `@StateObject` — different ways to declare source nodes
- `@Published` — marks properties that trigger propagation
- `View.body` — a computed derivation that rerenders on dependency change
- `onReceive(_:perform:)` — bridge from Combine publishers to SwiftUI

**What SwiftUI doesn't provide:**
- Business logic derivations — it only handles view layer
- Cross-object dependency tracking — each `@Published` is independent
- Fine-grained invalidation — entire view body recomputes, not individual parts

**The gap:** The codebase uses SwiftUI for views but uses imperative patterns for business logic. A full data flow architecture would extend the declarative model to the domain layer.


### How This Differs from Reactive Streams (#10)

Reactive Streams and Data Flow are related but distinct paradigms:

| Aspect | Reactive Streams | Data Flow |
|--------|-----------------|-----------|
| **Core abstraction** | Publisher/Subscriber with backpressure | Dependency graph with automatic propagation |
| **Async model** | First-class async; streams can be unbounded | Primarily synchronous; async is awkward |
| **Backpressure** | Explicit demand signaling | No backpressure; all downstream nodes update |
| **Typical use** | Event streams, I/O, message queues | UI state, computed values, caches |
| **Swift primitives** | `AsyncSequence`, Combine publishers | `@Published`, computed properties |
| **Error handling** | Typed failures propagate through stream | Errors in derivations require explicit handling |
| **Memory model** | Only current item in flight (streaming) | All intermediate values stored (snapshot) |

**Key distinction for Tavern:**

Reactive Streams (#10) focuses on **how agents communicate** — backpressure when user is overwhelmed, demand signaling for question delivery.

Data Flow (#31) focuses on **how state is derived** — agent state computed from responses, dashboard metrics computed from agent states, views computed from models.

They can coexist:
- Use Data Flow for synchronous derivations (state → view)
- Use Reactive Streams for asynchronous flows (agent → user notifications)

**Example hybrid:**

```swift
// Data Flow: Dashboard metrics derived from agent states
struct Dashboard {
    let agents: [Agent]

    var totalSaturated: Int {
        agents.filter { $0.state == .working }.count  // Derived
    }

    var amplificationFactor: Double {
        Double(totalSaturated) / max(1.0, Double(agents.count))  // Derived
    }
}

// Reactive Streams: Question delivery with backpressure
class UserAttention {
    let questionStream: AsyncStream<AgentQuestion>

    func receive(demand: Int) async -> [AgentQuestion] {
        // Pull only what user can handle
    }
}
```


### Trade-offs Considered


#### Synchronous vs Asynchronous Propagation

**Synchronous (classic data flow):**
```swift
// When agentState changes, all dependents update in same runloop
agentState = .working
// By the time this line executes, all views have updated
```

Pros:
- No intermediate inconsistent states
- Easier to reason about
- Natural for UI frameworks

Cons:
- Can't model async operations (LLM calls) naturally
- Long propagation chains block the main thread
- Every dependency must be computed immediately

**Asynchronous (reactive data flow):**
```swift
// Changes schedule updates, may not complete immediately
agentState = .working
// Views will update eventually, but not synchronously
```

Pros:
- Long computations don't block UI
- Natural for async operations
- Can debounce rapid-fire changes

Cons:
- Risk of "glitches" (seeing intermediate states)
- Harder to test deterministically
- Must handle propagation order carefully

**Recommendation for Tavern:** Hybrid approach. UI updates (via SwiftUI) are already async via `@Published`. Business logic derivations should be synchronous when possible but allow async breaks for LLM calls.


#### Eager vs Lazy Evaluation

**Eager (compute on change):**
```swift
var commitmentStatus: CommitmentStatus {
    didSet {
        // Immediately recompute all dependents
        updateAgentState()
        updateDashboard()
        updateBadges()
    }
}
```

Pros:
- State is always consistent
- No stale values
- Simple mental model

Cons:
- Wasted computation if dependent not needed
- Can cause cascading recomputations
- Memory pressure from all intermediate values

**Lazy (compute on access):**
```swift
var _agentStateCache: AgentState?
var agentState: AgentState {
    if let cached = _agentStateCache { return cached }
    let computed = deriveAgentState()  // Recompute if stale
    _agentStateCache = computed
    return computed
}

func invalidateAgentState() {
    _agentStateCache = nil  // Mark stale, don't recompute yet
}
```

Pros:
- Only compute what's accessed
- Better for large graphs with many unused branches
- Lower memory pressure

Cons:
- Complex invalidation logic
- Risk of stale values if invalidation missed
- Access timing affects performance

**Recommendation for Tavern:** Eager for core state (agent state, commitment status), lazy for expensive derivations (metrics aggregation, history search).


#### Fine-Grained vs Coarse-Grained Dependencies

**Fine-grained:**
```swift
// Each property is independently observable
@Published var name: String
@Published var state: AgentState
@Published var commitments: [Commitment]
// View updates only when specific property it uses changes
```

Pros:
- Minimal recomputation
- Better performance for large objects
- Precise invalidation

Cons:
- More boilerplate
- Complex to track all dependencies
- Risk of missing dependencies

**Coarse-grained:**
```swift
// Entire object is observable
@Published var agent: Agent
// Any change to agent triggers all dependent views
```

Pros:
- Simple implementation
- No missing dependencies
- Natural for value types

Cons:
- Over-invalidation
- Poor performance for large objects
- Hard to optimize hot paths

**Recommendation for Tavern:** Fine-grained for frequently-changing state (messages, cogitation status), coarse-grained for stable configuration (agent assignment, commitments).


### Implementation Complexity


#### Minimal Data Flow Layer

If we commit to data flow patterns for business logic, here's the minimal implementation:

**New abstractions needed:**

```swift
/// A value that other values can depend on
@propertyWrapper
struct Source<Value> {
    private var value: Value
    private var subscribers: [(Value) -> Void] = []

    var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            subscribers.forEach { $0(newValue) }
        }
    }

    func subscribe(_ handler: @escaping (Value) -> Void) {
        subscribers.append(handler)
        handler(value)  // Immediate delivery of current value
    }
}

/// A value derived from other values
@propertyWrapper
struct Derived<Value> {
    private let compute: () -> Value
    private var cached: Value?

    init(wrappedValue: @escaping @autoclosure () -> Value) {
        self.compute = wrappedValue
    }

    var wrappedValue: Value {
        mutating get {
            if let cached = cached { return cached }
            let value = compute()
            cached = value
            return value
        }
    }

    mutating func invalidate() {
        cached = nil
    }
}
```

**Changes to existing types:**

| Type | Change |
|------|--------|
| `Jake` | Replace `_isCogitating` with `@Source var isCogitating` |
| `MortalAgent` | Derive `state` from `_sessionId`, `commitments.allPassed`, response content |
| `ChatViewModel` | Derive `messages` from session history document |
| `AgentListViewModel` | Remove `agentsDidChange()`, derive `items` from registry |
| `TavernCoordinator` | Remove manual refresh calls |

**Estimated effort:** 1-2 weeks for core abstractions, plus 1 week per major type migration.


#### Alternative: Use Existing Frameworks

Instead of building custom data flow primitives, we could adopt:

**1. Combine (Apple):**
```swift
class AgentModel: ObservableObject {
    @Published var isCogitating: Bool = false

    var state: AnyPublisher<AgentState, Never> {
        $isCogitating
            .map { $0 ? .working : .idle }
            .eraseToAnyPublisher()
    }
}
```

Pros: Native to Swift, well-tested, integrates with SwiftUI
Cons: Verbose, maintenance mode, complex error handling

**2. The Composable Architecture (TCA):**
```swift
@Reducer
struct AgentFeature {
    @ObservableState
    struct State {
        var isCogitating: Bool = false
        var state: AgentState { isCogitating ? .working : .idle }
    }

    enum Action {
        case startCogitating
        case finishCogitating
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startCogitating:
                state.isCogitating = true
                return .none
            case .finishCogitating:
                state.isCogitating = false
                return .none
            }
        }
    }
}
```

Pros: Comprehensive solution, great testing support, active community
Cons: Large dependency, steep learning curve, opinionated architecture

**3. Custom with Swift Observation (iOS 17+):**
```swift
@Observable
class Agent {
    var isCogitating: Bool = false

    var state: AgentState {
        isCogitating ? .working : .idle
    }
}
```

Pros: Native, minimal boilerplate, compiler-tracked dependencies
Cons: iOS 17+ only, macOS 14+ only, may conflict with existing `@Published`

**Recommendation:** Start with Swift Observation if targeting macOS 14+, otherwise stay with current `@Published` patterns and enhance incrementally.


### Migration Path from Current State


#### Phase 1: Identify Imperative Update Paths (Analysis Only)

1. Grep for `agentsDidChange()`, `refreshItems()`, `refresh()`
2. Map which state changes should trigger which updates
3. Document the implicit dependency graph

**Current imperative paths:**

```
spawnAgent() → agentsDidChange() → refreshItems() → items update
dismissAgent() → agentsDidChange() → refreshItems() → items update
selectAgent() → updateActiveChatViewModel() → activeChatViewModel update
sendMessage() → messages.append() → view update (via @Published)
```

**Desired declarative graph:**

```
registry.agents (source) → agentListViewModel.items (derived)
selectedAgentId (source) → activeChatViewModel (derived)
session.history (source) → messages (derived)
```


#### Phase 2: Convert View Models to Derived State

1. Make `AgentListViewModel.items` a computed property
2. Remove `agentsDidChange()` and `refreshItems()` methods
3. Subscribe to registry changes to trigger SwiftUI updates

```swift
// Before
@Published public private(set) var items: [AgentListItem] = []

public func refreshItems() {
    var newItems: [AgentListItem] = []
    newItems.append(AgentListItem.from(jake: jake))
    for anyAgent in spawner.activeAgents {
        newItems.append(/* ... */)
    }
    items = newItems
}

// After
@Published private var registryVersion: Int = 0  // Triggers SwiftUI update

public var items: [AgentListItem] {
    var result: [AgentListItem] = []
    result.append(AgentListItem.from(jake: jake))
    for anyAgent in spawner.activeAgents {
        result.append(/* ... */)
    }
    return result
}

init(jake: Jake, spawner: AgentSpawner) {
    // Subscribe to registry changes
    spawner.registry.onAgentsChanged { [weak self] in
        self?.registryVersion += 1  // Trigger recomputation
    }
}
```


#### Phase 3: Convert Agent State to Derived

1. Define what agent state is derived from:
   - `isCogitating` (during API call)
   - Response content (contains "DONE" or "WAITING")
   - Commitment status (all passed/failed/pending)

2. Implement as computed property:

```swift
// Before
private var _state: AgentState = .idle

// After
var state: AgentState {
    if isCogitating { return .working }
    if lastResponse?.contains("DONE") == true {
        return commitments.allPassed ? .done : .verifying
    }
    if lastResponse?.contains("WAITING") == true {
        return .waiting
    }
    return .idle
}
```


#### Phase 4: Connect to Doc Store

1. Agent nodes backed by documents
2. All agent state derived from document content
3. Changes to filesystem propagate to agents

```swift
// AgentNode.swift (enhanced)
struct AgentNode {
    let document: Document

    var state: AgentState {
        switch document.metadata["status"] as? String {
        case "done": return .done
        case "verifying": return .verifying
        case "working": return .working
        case "waiting": return .waiting
        default: return .idle
        }
    }

    var messages: [ChatMessage] {
        // Parse from document content
    }

    var commitments: [Commitment] {
        // Parse from document YAML
    }
}

// When document changes on disk, agent updates automatically
class DocStoreWatcher {
    func watch(path: URL, handler: @escaping (Document) -> Void) {
        // FSEvents or DispatchSource for file watching
    }
}
```


#### Rollback Strategy

Each phase is independently revertible:

- Phase 1: Pure analysis, no code changes
- Phase 2: Keep old `refreshItems()` as backup, add feature flag
- Phase 3: Keep `_state` property, derived version calls it
- Phase 4: Most invasive; would require careful rollback planning

Recommend implementing through Phase 2 for v1, defer Phases 3-4 until needed.


### Open Questions


#### 1. How do cycles in agent communication map to a DAG?

Data flow requires a directed acyclic graph. But agents may communicate bidirectionally:
- Parent assigns task to child
- Child asks question to parent
- Parent answers, child continues

**Options:**

1. **Separate graphs per direction** — Assignment flows down, questions flow up. Two DAGs that don't cycle.

2. **Temporal unrolling** — Each "turn" is a new node. `ChildState_t1` depends on `ParentMessage_t0`, which depends on `ChildQuestion_t0`, which depends on `ChildState_t0`. No cycles across time.

3. **Hybrid with events** — Use data flow for derived state, events for bidirectional communication.

**Recommendation:** Option 2 (temporal unrolling) aligns with conversation-as-history model.


#### 2. How do async LLM responses fit into synchronous data flow?

Data flow assumes changes propagate synchronously. LLM calls are fundamentally async.

**Options:**

1. **Async sources** — Source nodes can be async; propagation waits for resolution.

2. **Placeholder values** — While waiting, use `.loading` placeholder; replace when resolved.

3. **Separate async layer** — Data flow for derived state, async/await for fetching.

**Recommendation:** Option 2 with Swift's `@State` and async view modifiers:

```swift
@State var response: LoadingState<String> = .idle

var body: some View {
    switch response {
    case .idle: EmptyView()
    case .loading: ProgressView()
    case .loaded(let text): Text(text)
    case .failed(let error): ErrorView(error)
    }
}

func sendMessage() {
    response = .loading
    Task {
        do {
            let result = try await agent.send(message)
            response = .loaded(result)
        } catch {
            response = .failed(error)
        }
    }
}
```


#### 3. How does this interact with the doc store as source of truth?

If doc store is the only source, all derived state must compute from files. This is powerful but has latency implications:

- Reading files on every access is slow
- Caching introduces consistency questions
- File watching adds complexity

**Recommendation:** Layered caching with invalidation:

```
Filesystem (authoritative)
    ↓ (file watcher invalidates)
Document Cache (in-memory copy)
    ↓ (change invalidates)
Derived State (computed properties)
    ↓ (change triggers)
SwiftUI Views
```

When a file changes:
1. File watcher detects change
2. Document cache marks entry as stale
3. Next access reloads from disk
4. Derived properties recompute
5. SwiftUI rerenders


#### 4. What about derived state that's expensive to compute?

Dashboard metrics across many agents could be expensive. Options:

1. **Lazy computation** — Only compute when accessed
2. **Debounced updates** — Wait for changes to settle before recomputing
3. **Background computation** — Compute off main thread, update when ready
4. **Incremental updates** — Maintain running totals, update incrementally

**Recommendation:** Combine lazy + background for expensive derivations:

```swift
@Published private var metricsCache: DashboardMetrics?
private var metricsTask: Task<Void, Never>?

var metrics: DashboardMetrics {
    if let cached = metricsCache { return cached }
    return DashboardMetrics.empty  // Placeholder while computing
}

func invalidateMetrics() {
    metricsCache = nil
    metricsTask?.cancel()
    metricsTask = Task.detached(priority: .utility) {
        let computed = await self.computeMetrics()
        await MainActor.run {
            self.metricsCache = computed
        }
    }
}
```


#### 5. How does testing work with data flow?

Testing becomes snapshot-based: given these source values, assert these derived values.

```swift
func testAgentStateDerivedFromCommitments() {
    // Set up source state
    let agent = MortalAgent(/* ... */)
    agent.addCommitment(description: "Tests pass", assertion: "exit 0")

    // Simulate response with DONE
    agent.lastResponse = "Task DONE"

    // Before verification
    XCTAssertEqual(agent.state, .verifying)

    // After verification passes
    agent.commitments.markAllPassed()
    XCTAssertEqual(agent.state, .done)
}
```

No need to verify method calls; just verify state derivations.


### Comparison Matrix: Data Flow vs Other Patterns

| Criterion | Data Flow | Reactive Streams | Actor Model | Event Sourcing |
|-----------|-----------|------------------|-------------|----------------|
| Sync/async | Primarily sync | Primarily async | Async messages | Sync applies |
| Backpressure | None | First-class | Mailbox overflow | N/A |
| Time travel | Snapshot replay | No (streaming) | No | First-class |
| Testing | Snapshot comparison | Virtual schedulers | Actor isolation | Event replay |
| Debugging | State inspection | Stack traces opaque | Actor dumps | Event log |
| SwiftUI fit | Excellent | Good (bridging) | Moderate | Moderate |
| Learning curve | Low (if familiar with React/SwiftUI) | Medium | Low | Medium |
| Implementation | 1-2 weeks | 2-3 weeks | 1 week | 2-3 weeks |


### Conclusion

Data Flow architecture aligns well with the Tavern's design philosophy:

1. **Doc store as source of truth** maps to source nodes in a dependency graph
2. **SwiftUI already uses data flow** for the view layer; extending to business logic is natural
3. **Derived state eliminates bugs** from forgotten update calls
4. **Testing becomes simpler** with snapshot-based assertions

However, there are significant challenges:

1. **Async LLM calls** don't fit the synchronous propagation model cleanly
2. **Bidirectional agent communication** requires careful modeling to avoid cycles
3. **SwiftUI already covers the view layer** — benefit is primarily in business logic
4. **Current codebase is mostly imperative** — migration is non-trivial

**Recommendation:**

- **For v1:** Keep current patterns; SwiftUI already provides data flow for views
- **Incremental adoption:** Convert `AgentListViewModel` to derived state first (Phase 2)
- **Trigger for full adoption:** When stale state bugs become a pattern OR doc store integration requires it
- **Alternative:** Consider TCA (The Composable Architecture) if a full data flow solution is desired — it's battle-tested and Swift-native

Data Flow is a strong fit for the Tavern's "doc store is source of truth" philosophy, but the async nature of LLM interactions and the bidirectional agent communication patterns add complexity that pure data flow handles awkwardly. A hybrid approach — data flow for derived state, async/await for I/O, events for agent communication — may be the pragmatic path forward.
