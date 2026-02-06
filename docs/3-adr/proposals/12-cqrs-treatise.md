# CQRS Architecture: Complete Analysis

This document contains the full research, reasoning, and implementation considerations for applying Command Query Responsibility Segregation to the Tavern multi-agent orchestrator.


## Research Findings


### Current Architecture State

The existing codebase already exhibits proto-CQRS patterns, though not formalized:

**Write Path (Current)**
- Commands flow through `TavernCoordinator.spawnAgent()`, `dismissAgent()`, `selectAgent()`
- Agent state mutations happen in `Jake.send()`, `MortalAgent.send()`, `MortalAgent.markDone()`
- Persistence writes to `SessionStore` (UserDefaults) and `DocStore` (filesystem)
- Thread safety via `DispatchQueue` synchronization on each domain object

**Read Path (Current)**
- `AgentListViewModel.items` is a projection of registry state
- `ChatViewModel.messages` is a projection of conversation history
- `AgentListItem` is a read-optimized DTO (display name, state indicator, assignment summary)
- View models are `@MainActor` with `@Published` properties for SwiftUI binding

**The Asymmetry Problem**
- UI polls agent list frequently (every frame when visible)
- Chat view re-renders on each new message
- Agent state indicators need instant visual feedback
- But writes are infrequent: user sends message, agent responds, state transitions

This asymmetry is exactly what CQRS addresses.


### PRD Requirements Mapped to CQRS

| PRD Section | Requirement | CQRS Mapping |
|-------------|-------------|--------------|
| 5.1 Core Loop | User sees dashboard, drills into agents | Read model: `AgentListProjection` with pre-computed badges |
| 5.2 Attention Model | Notification bubbles when agents have questions | Read model: `NotificationProjection` updated on state events |
| 5.4 UI Principles | Stream separation (thinking vs tool use vs code) | Read model: `ChatProjection` with pre-categorized content blocks |
| 21.1 Isolation | No operation may impact unrelated parts | CQRS enables isolated read paths per concern |
| 21.2 Responsiveness | UI must always respond to input | Read models can be optimized/cached independently |
| 21.4 Scale Independence | Viewing current content must not degrade as history grows | Read projections can be windowed/paginated |


### How CQRS Maps to UI/Agent Asymmetry

The fundamental insight: **UI is read-heavy, agents are write-heavy**.

**UI Characteristics:**
- SwiftUI recomputes view bodies on any `@Published` change
- `ObservableObject` conformance means the framework tracks dependencies
- Chat scrolling, list rendering, state badges all need immediate data
- Users expect 60fps responsiveness regardless of background agent activity

**Agent Characteristics:**
- `send()` calls involve API latency (seconds to minutes)
- State transitions are discrete events, not continuous
- Commitment verification is batch processing
- Session persistence can be async/background

**The CQRS Solution:**

```
Write Side                          Read Side
-----------                         ----------
SpawnAgentCommand                   AgentListProjection
  -> AgentRegistry.register()         -> [AgentListItem]
  -> emit(AgentSpawned)               -> subscribed to AgentSpawned

SendMessageCommand                  ChatProjection
  -> Jake.send() / MortalAgent.send() -> [ChatMessage]
  -> emit(MessageSent)                -> subscribed to MessageSent
  -> emit(ResponseReceived)           -> subscribed to ResponseReceived

UpdateStateCommand                  StateProjection
  -> agent.state = .working           -> state indicators
  -> emit(StateChanged)               -> subscribed to StateChanged
```

Read projections are optimized snapshots. Write operations emit events. The two never share mutable state directly.


## Trade-offs Considered


### Eventual Consistency vs. Immediate Feedback

**The Problem:** If the UI reads from projections that lag behind writes, users may see stale data.

Example: User sends message, but chat view hasn't updated yet because the projection hasn't processed the `MessageSent` event.

**Mitigation Strategies:**

1. **Optimistic UI Updates** -- Add message to chat immediately, mark as "pending", confirm when event arrives
2. **Synchronous Projections** -- Update read model in same transaction as write (hybrid CQRS)
3. **UI-Local State** -- `ChatViewModel` holds immediate state; projection confirms/reconciles
4. **Event Ordering Guarantees** -- Ensure events are processed in causal order

**Recommendation:** For Tavern, use optimistic UI updates with synchronous projections for critical paths (message display, state indicators). Eventual consistency is acceptable for secondary displays (notification counts, agent list refresh).


### Duplication vs. Normalization

**The Problem:** CQRS duplicates data between write store and read projections.

```
Write Store: Agent { id, name, state, sessionId, commitments... }
Read Projection: AgentListItem { id, name, state, assignmentSummary }
```

**Analysis:**

Current codebase already does this:
- `AgentRegistry` stores full `AnyAgent` objects
- `AgentListViewModel` stores `[AgentListItem]` projections
- `ChatViewModel` stores `[ChatMessage]` separate from session storage

The duplication is intentional: read models contain exactly what the view needs.

**Recommendation:** Accept duplication as the cost of read optimization. Use events to keep projections synchronized. The existing pattern is correct; CQRS formalizes it.


### Complexity vs. Simplicity

**The Problem:** CQRS adds layers of abstraction (commands, events, projectors, query handlers).

**Current Complexity:**
- `TavernCoordinator` mixes command handling with query serving
- View models both mutate and display state
- No clear boundary between "changing state" and "reading state"

**CQRS Complexity:**
- Explicit command types (`SpawnAgentCommand`, `SendMessageCommand`)
- Event types (`AgentSpawned`, `MessageSent`, `StateChanged`)
- Projector protocols for updating read models
- Query handler protocols for serving UI

**Analysis:**

The additional structure provides:
- Clear contracts between components
- Isolated testing of command handlers
- Isolated testing of projectors
- Freedom to optimize each path independently

But also:
- More files, more types, more indirection
- Learning curve for contributors
- Potential over-engineering for MVP

**Recommendation:** Introduce CQRS incrementally. Start with the most asymmetric cases (chat history, agent list). Keep simple cases simple (agent selection is a direct state mutation, no need for full CQRS ceremony).


## Implementation Complexity


### Phase 1: Formalize Existing Patterns (Low Complexity)

The codebase already has implicit CQRS. Formalize it:

1. **Extract Command Types**
```swift
enum TavernCommand {
    case spawnAgent(assignment: String, selectAfterSpawn: Bool)
    case dismissAgent(id: UUID)
    case selectAgent(id: UUID)
    case sendMessage(agentId: UUID, text: String)
}
```

2. **Extract Event Types**
```swift
enum TavernEvent {
    case agentSpawned(id: UUID, name: String, assignment: String)
    case agentDismissed(id: UUID)
    case agentSelected(id: UUID)
    case messageSent(agentId: UUID, message: ChatMessage)
    case responseReceived(agentId: UUID, response: ChatMessage)
    case stateChanged(agentId: UUID, from: AgentState, to: AgentState)
}
```

3. **Create Command Handler Protocol**
```swift
protocol CommandHandler {
    func handle(_ command: TavernCommand) async throws -> [TavernEvent]
}
```

4. **Create Projector Protocol**
```swift
protocol Projector {
    func project(_ event: TavernEvent)
}
```


### Phase 2: Separate Read Models (Medium Complexity)

Create dedicated projection types:

1. **AgentListProjection**
```swift
final class AgentListProjection: Projector, ObservableObject {
    @Published private(set) var items: [AgentListItem] = []
    @Published private(set) var selectedId: UUID?

    func project(_ event: TavernEvent) {
        switch event {
        case .agentSpawned(let id, let name, let assignment):
            items.append(AgentListItem(id: id, name: name, ...))
        case .agentDismissed(let id):
            items.removeAll { $0.id == id }
        case .agentSelected(let id):
            selectedId = id
        // ...
        }
    }
}
```

2. **ChatProjection** (per-agent)
```swift
final class ChatProjection: Projector, ObservableObject {
    let agentId: UUID
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isCogitating: Bool = false

    func project(_ event: TavernEvent) {
        guard relevantToThisAgent(event) else { return }
        switch event {
        case .messageSent(_, let message):
            messages.append(message)
        case .responseReceived(_, let response):
            messages.append(response)
        case .stateChanged(_, _, let to):
            isCogitating = (to == .working)
        // ...
        }
    }
}
```


### Phase 3: Event Bus (Medium-High Complexity)

Connect command handlers to projectors via event bus:

```swift
final class TavernEventBus {
    private var projectors: [Projector] = []

    func register(_ projector: Projector) {
        projectors.append(projector)
    }

    func publish(_ events: [TavernEvent]) {
        for event in events {
            for projector in projectors {
                projector.project(event)
            }
        }
    }
}
```


### Phase 4: Persistence Integration (High Complexity)

Events can optionally be persisted for replay (moves toward Event Sourcing):

```swift
final class EventStore {
    func append(_ events: [TavernEvent]) { ... }
    func replay(from: Date? = nil) -> [TavernEvent] { ... }
}
```

This enables:
- Session recovery by replaying events
- Debugging by inspecting event history
- Rewind/branch by replaying to specific point

**Note:** This phase overlaps with Event Sourcing architecture. CQRS can be implemented without persistent events (projections rebuilt from write store on startup).


## Migration Path from Current State


### Step 1: No-Op Refactor

Extract command handling from `TavernCoordinator` without changing behavior:

**Before:**
```swift
public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
    let agent = try spawner.spawn(assignment: assignment)
    agentListViewModel.cacheAssignment(agentId: agent.id, assignment: assignment)
    agentListViewModel.agentsDidChange()
    if selectAfterSpawn { selectAgent(id: agent.id) }
    return agent
}
```

**After:**
```swift
public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
    let agent = try spawner.spawn(assignment: assignment)
    let event = TavernEvent.agentSpawned(id: agent.id, name: agent.name, assignment: assignment)
    eventBus.publish([event])
    if selectAfterSpawn {
        eventBus.publish([.agentSelected(id: agent.id)])
    }
    return agent
}
```

The `AgentListViewModel` becomes a projector subscribed to events.


### Step 2: Split View Models

Currently `ChatViewModel` both processes sends and displays messages. Split:

- `ChatCommandHandler` -- handles `sendMessage` command, talks to agent, emits events
- `ChatProjection` -- subscribes to events, maintains `messages` array for display


### Step 3: Optimize Read Path

Once reads are isolated:

- Add caching to projections (invalidate on events)
- Pre-compute expensive derivations (e.g., message content block parsing)
- Paginate/window large histories


### Step 4: Optional Event Persistence

If rewind/branch features are prioritized, add event persistence:

- Append events to log
- Rebuild projections from event log on startup
- Support replay to arbitrary point


## Open Questions


### Q1: How granular should events be?

**Options:**
- Coarse: `AgentStateChanged(id, newState)` -- simple but loses history
- Fine: `AgentStartedWorking(id)`, `AgentFinishedWorking(id)`, etc. -- detailed but verbose

**Recommendation:** Start coarse, refine as needed. Rewind/branch features may drive finer granularity.


### Q2: Should events be persisted?

**Options:**
- No persistence: Projections rebuild from write store on startup
- Full persistence: Event log is source of truth (becomes Event Sourcing)
- Hybrid: Persist events for current session, rebuild from write store across restarts

**Recommendation:** Start without persistence. Add if rewind/branch features prove valuable.


### Q3: How to handle command failures?

**Options:**
- Throw exceptions (current pattern)
- Return Result types
- Emit failure events

**Recommendation:** Emit failure events (`SpawnAgentFailed`, `SendMessageFailed`) so error UI can be a projection too. Also throw for caller to handle synchronously.


### Q4: Thread safety with event bus?

Current architecture uses `DispatchQueue` per object. Event bus creates cross-cutting concerns.

**Options:**
- Main actor for all events (simple, UI-friendly)
- Dedicated event queue (requires dispatching to main for UI updates)
- Swift concurrency with actors

**Recommendation:** `@MainActor` for event bus and projections. Matches SwiftUI's requirements.


### Q5: Testing strategy?

**CQRS enables:**
- Command handler unit tests (input command, assert emitted events)
- Projector unit tests (input events, assert projection state)
- Integration tests (commands through to UI assertions)

**Recommendation:** Lean into the testability benefits. Mock event bus for command handler tests. Use real event bus for integration tests.


## Relationship to Other Proposals

**Event Sourcing (05):** CQRS is a prerequisite pattern. Event Sourcing takes CQRS further by making the event log authoritative. Can adopt CQRS without full Event Sourcing.

**Actor Model (02):** Actors provide isolation; CQRS provides read/write separation. Complementary patterns. Actors could implement command handlers with isolated state.

**Document-Centric (03):** DocStore is the write model. CQRS adds explicit read models optimized for UI. DocStore remains source of truth; projections derive from it.

**Blackboard (06):** Blackboard is a shared-state model; CQRS separates read and write state. Tension between patterns. Could use Blackboard for agent collaboration, CQRS for UI layer.


## Summary

CQRS formalizes patterns already emerging in the Tavern codebase. The UI layer already maintains read-optimized projections (`AgentListViewModel`, `ChatViewModel`). The write layer already processes commands through domain logic (`TavernCoordinator`, agent `send()` methods).

The migration path is incremental:
1. Extract explicit command and event types
2. Formalize projectors as event subscribers
3. Connect via event bus
4. Optimize read path independently
5. Optionally persist events for rewind/branch

The key benefit is optimizing the asymmetric workload: fast UI reads, complex agent writes. The key cost is additional abstraction layers and eventual consistency considerations.

For Tavern v1, recommend Phase 1-2 implementation: formalize existing patterns without adding event persistence. Reserve Phase 3-4 for when rewind/branch features are prioritized.
