# Outbox Pattern Architecture: Complete Analysis

This document contains the full research, analysis, and trade-off considerations for adopting the Outbox Pattern in Tavern.


## Research Findings


### The Dual-Write Problem in the Current Codebase

The Tavern codebase exhibits classic dual-write patterns where state changes and notifications happen in separate, non-atomic operations.


**Agent Spawning Flow (`AgentSpawner.spawn()`)**

```swift
// AgentSpawner.swift
let agent = MortalAgent(name: name, assignment: assignment, claude: claude)
try registry.register(agent)  // Step 1: State change
// ... implicit: UI observes registry changes via @Published
```

The registry update and UI notification are decoupled. If the app crashes after registration but before the UI updates, the agent exists but was never properly announced. The `@Published` property wrapper handles most cases, but it's in-memory only -- no durability.


**Session Persistence (`SessionStore.saveJakeSession()`)**

```swift
// SessionStore.swift
public static func saveJakeSession(_ sessionId: String?, projectPath: String) {
    let key = jakeSessionKey(for: projectPath)
    if let id = sessionId {
        defaults.set(id, forKey: key)  // State change to UserDefaults
    }
}
```

Session ID is saved to UserDefaults, but no event is published. If other components need to know about session changes (e.g., for history loading), they must poll or rely on implicit coordination.


**Commitment Verification (`MortalAgent.handleCompletionAttempt()`)**

```swift
// MortalAgent.swift
private func handleCompletionAttempt() async {
    queue.sync { _state = .verifying }  // State change 1
    let allPassed = try await verifier.verifyAll(in: commitments)
    if allPassed {
        queue.sync { _state = .done }  // State change 2
    }
}
```

State transitions happen in memory with no persistent event record. If the app crashes during verification, the verification result is lost. There's no guarantee that parent agents or monitoring daemons learn about completion.


**DocStore Updates (`DocStore.update()`)**

```swift
// DocStore.swift
public func update(_ document: Document) throws {
    try queue.sync {
        var updatedDoc = document
        updatedDoc.updatedAt = Date()
        let content = updatedDoc.render()
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
```

The document is updated atomically (good), but no event is published about the update. Other components that care about document changes have no notification mechanism.


### Key Observations

1. **State changes are atomic but isolated** -- Each component updates its own state reliably, but cross-component notification is ad-hoc

2. **No guaranteed event delivery** -- Events are either in-memory (`@Published`) or implicit (polling file changes)

3. **Crash recovery depends on polling** -- If something changes and the app crashes before notifying subscribers, they must rediscover state by polling

4. **Verification flow is vulnerable** -- Commitment verification involves multiple state transitions with no persistence of the verification event

5. **DocStore has no change feed** -- Other components can't subscribe to document changes


## How the Outbox Pattern Solves These Problems


### The Core Mechanism

Instead of:
1. Write state
2. (Crash risk)
3. Publish event

The Outbox Pattern does:
1. Write state + event to same transaction
2. Background process reads outbox
3. Background process publishes to subscribers
4. Background process marks event as published

If a crash occurs after step 1, the event remains unpublished in the outbox. When the app restarts, the background process picks up where it left off.


### DocStore as Outbox

The existing `DocStore` is file-based, writing markdown documents with YAML frontmatter. An outbox can be implemented as:


**Option A: Sidecar Event Files**

Each document has an associated `.events` file in the same directory:

```
.tavern/
  agents/
    gandalf.md           # Agent document
    gandalf.events       # Outbox events for this agent
  outbox/
    pending.jsonl        # Global pending events
    published.jsonl      # Archived published events (for debugging)
```

**Option B: Frontmatter Event Queue**

Events embedded in document frontmatter until published:

```yaml
---
id: gandalf-uuid
state: working
pending_events:
  - type: StateChanged
    timestamp: 2026-01-24T10:30:00Z
    previous: idle
    new: working
    published: false
---
```

**Option C: Dedicated Outbox Store**

Separate outbox storage from documents:

```swift
class OutboxStore {
    let rootDirectory: URL  // ~/.tavern/outbox/

    func appendEvent(_ event: TavernEvent, forAggregate id: String) throws
    func pendingEvents() -> [PendingEvent]
    func markPublished(_ eventId: UUID) throws
}
```

**Recommendation: Option C**

Option C provides cleanest separation of concerns:
- DocStore remains simple CRUD on documents
- OutboxStore handles event durability
- Background publisher has a dedicated place to poll
- Cleanup is straightforward (archive or delete published events)


### Atomic Write Pattern

```swift
// Enhanced DocStore with outbox integration
public func updateWithEvent(_ document: Document, event: TavernEvent) throws {
    try queue.sync {
        // 1. Update document (existing behavior)
        var updatedDoc = document
        updatedDoc.updatedAt = Date()
        let content = updatedDoc.render()
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // 2. Append event to outbox (same "transaction" scope)
        try outboxStore.appendEvent(event, forAggregate: document.id)
    }
}
```

The DispatchQueue serialization provides transaction-like behavior for the single-process case. For true ACID guarantees (e.g., across process crashes mid-write), we'd need SQLite or similar, but for v1 this is sufficient.


## Relationship to Event Sourcing (#5)


### Outbox vs. Event Sourcing: Complementary, Not Competing

The Event Sourcing proposal (#5) describes deriving all state from an immutable event log. The Outbox Pattern is orthogonal -- it solves *delivery* of events, not *storage* of state.

| Aspect | Event Sourcing | Outbox Pattern |
|--------|----------------|----------------|
| Primary concern | State representation | Event delivery |
| Source of truth | Event log | Current state + outbox |
| State derivation | Replay events | Direct storage |
| Event role | Defines state | Notifies about changes |
| Rewind capability | Full | None (requires ES) |


### Combining Outbox with Event Sourcing

If Tavern adopts Event Sourcing, the outbox becomes even more natural:

```
Command → Validate → Append to Event Log (outbox integrated)
                              ↓
              Background process publishes from log
                              ↓
              Projectors update read models
```

In this model, the event log IS the outbox. Events are appended once and read multiple times (for both projection AND notification). This is why many Event Sourcing implementations include outbox semantics inherently.


### Outbox as Event Sourcing Lite

For teams not ready for full Event Sourcing:

1. **Adopt outbox first** -- Get guaranteed event delivery without changing state model
2. **Add projections later** -- Some consumers can be event-driven (outbox subscribers)
3. **Migrate incrementally** -- Convert one aggregate at a time to event-sourced

The outbox provides event infrastructure that makes later Event Sourcing adoption easier.


## Trade-offs Considered


### At-Least-Once vs. Exactly-Once Delivery

The Outbox Pattern guarantees at-least-once delivery, not exactly-once. If the publisher crashes after delivering but before marking published, the event will be redelivered on restart.

**Implications for Tavern:**

- **UI subscribers**: Must handle duplicate state-change events (SwiftUI already handles this via value comparison in `@Published`)
- **Commitment verification**: Idempotent by nature (running the same assertion twice doesn't change result)
- **Agent parent notifications**: Must deduplicate "child completed" messages

**Mitigation strategies:**

1. **Idempotent handlers** -- Design all subscribers to handle duplicates gracefully
2. **Event IDs** -- Each event has a UUID; subscribers track seen IDs
3. **Versioning** -- State carries a version number; outdated events are ignored


### Polling Latency vs. Push Complexity

The outbox requires a background process to poll for unpublished events. This introduces latency between state change and subscriber notification.

**Design choices:**

- **Polling interval**: 100ms gives near-real-time feel; 1s is acceptable for most cases
- **Hybrid approach**: In-memory notification for fast path, outbox for durability
- **Push notification**: File system watchers can trigger immediate polling

For v1, a simple polling loop with 100-500ms interval provides reasonable responsiveness without complexity.


### Outbox Growth and Cleanup

Events accumulate in the outbox. Strategies:

1. **Mark-and-sweep**: Published events marked, periodically deleted
2. **Rotation**: Daily outbox files, old files archived
3. **Retention policy**: Keep last N days/events for debugging

**Recommendation**: Retain published events for 7 days (debugging), then delete. Total storage is minimal (events are small JSON objects).


### Single-Process Atomicity

The current `DispatchQueue` serialization provides atomicity within a single process. This is sufficient for v1 (macOS app, single process). For future distributed scenarios (cloud agents, multiple Tavern instances), we'd need:

- SQLite with transactions
- Distributed locks
- Consensus protocols

This is explicitly out of scope per PRD: "Distributed/replicated doc store (single machine first)"


## Implementation Complexity


### Phase 1: Outbox Infrastructure (1-2 weeks)

1. Define `TavernEvent` protocol (shared with potential Event Sourcing)
2. Implement `OutboxStore` with append and mark-published operations
3. Create `OutboxPublisher` background process with polling loop
4. Define subscriber protocol for event delivery


### Phase 2: DocStore Integration (1 week)

1. Add `updateWithEvent()` method to DocStore
2. Ensure atomic writes (document + event in same queue block)
3. Add event types for document CRUD: `DocumentCreated`, `DocumentUpdated`, `DocumentDeleted`


### Phase 3: Agent Events (1-2 weeks)

1. Define agent lifecycle events: `AgentSpawned`, `AgentStateChanged`, `AgentDismissed`
2. Modify `AgentSpawner` to emit events via outbox
3. Modify `MortalAgent` state transitions to emit events
4. Connect `TavernCoordinator` as subscriber


### Phase 4: Commitment Events (1 week)

1. Define commitment events: `CommitmentAdded`, `CommitmentVerificationStarted`, `CommitmentVerificationCompleted`
2. Modify `CommitmentVerifier` to emit events
3. Connect parent agents and monitoring as subscribers


### Phase 5: UI Integration (1 week)

1. Create event-to-view-model bridge
2. Replace some `@Published` polling with event subscription
3. Handle duplicate events gracefully


### Total Estimate: 5-7 weeks

This is lighter than full Event Sourcing (10-14 weeks per #5) because we're not changing the state model, just adding guaranteed notification.


## Migration Path from Current State


### Step 1: Introduce OutboxStore (No Behavior Change)

Add the OutboxStore infrastructure but don't use it yet. Verify it can persist and read events correctly. Run in parallel with existing code.

```swift
// No production use yet, just infrastructure
let outboxStore = OutboxStore(rootDirectory: outboxURL)
// ... tests verify append/read/markPublished
```


### Step 2: Instrument Key Operations

Add event emission to high-value operations without changing behavior:

```swift
// In AgentSpawner.spawn()
let agent = MortalAgent(...)
try registry.register(agent)

// NEW: Also emit event (non-critical path)
try? outboxStore.appendEvent(
    AgentSpawned(agentId: agent.id, name: agent.name, assignment: assignment)
)
```

At this stage, events are written but not consumed. We're building up the event stream.


### Step 3: Add Background Publisher

Start the OutboxPublisher daemon. It polls for events and publishes to in-memory subscribers.

```swift
// In TavernCoordinator initialization
outboxPublisher = OutboxPublisher(outboxStore: outboxStore)
outboxPublisher.start(pollingInterval: .milliseconds(200))
```


### Step 4: Connect First Subscriber

Connect the UI layer as the first subscriber. Verify it receives events correctly.

```swift
outboxPublisher.subscribe { event in
    switch event {
    case let spawned as AgentSpawned:
        agentListViewModel.handleAgentSpawned(spawned)
    // ...
    }
}
```


### Step 5: Verify Dual Delivery

For a period, keep both the existing notification path (`@Published`) and the outbox path. Verify they agree:

```swift
// Existing path
@Published public private(set) var agents: [Agent] = []

// New path
func handleAgentSpawned(_ event: AgentSpawned) {
    // Should already be in agents array via existing path
    assert(agents.contains { $0.id == event.agentId })
}
```


### Step 6: Remove Redundant Paths

Once the outbox path is verified, remove direct notifications where appropriate. Some `@Published` properties remain (they're the read model), but their updates come from event handlers rather than direct mutation.


## Open Questions


### Event Schema Design

How should events be structured?

**Option A: Coarse Events**
```swift
struct AgentChanged: TavernEvent {
    let agentId: UUID
    let changeType: ChangeType  // spawned, stateChanged, dismissed
    let details: [String: Any]
}
```

**Option B: Fine-Grained Events**
```swift
struct AgentSpawned: TavernEvent { ... }
struct AgentStateChanged: TavernEvent { ... }
struct AgentDismissed: TavernEvent { ... }
```

**Recommendation**: Fine-grained (Option B). Matches the Event Sourcing proposal, enables type-safe handling, and provides better subscriber filtering.


### Publisher Failure Handling

What happens if the OutboxPublisher crashes or hangs?

- **Detection**: Watchdog timer checks last publish timestamp
- **Recovery**: Restart publisher; it picks up from last published event
- **Alerting**: Log errors, surface in UI if persistent

For v1, a simple restart-on-failure approach is sufficient.


### Cross-Aggregate Ordering

If Agent A and Agent B both emit events, is ordering preserved?

**Within single aggregate**: Yes, events are appended sequentially
**Across aggregates**: Not guaranteed unless explicitly designed

For Tavern, within-agent ordering matters (state transitions must be ordered). Cross-agent ordering is less critical (they're independent actors).


### Integration with Claude CLI Events

Claude CLI already stores session history as JSONL. Should Tavern's outbox integrate?

**Option A: Separate Systems**
- Tavern outbox for Tavern events
- Claude CLI storage for message history
- Bridge layer translates when needed

**Option B: Unified Event Stream**
- Tavern events include message events
- Claude CLI events are imported into outbox
- Single stream for all events

**Recommendation for v1**: Option A. Keep systems separate, avoid coupling to Claude CLI internals. Consider unification later if Event Sourcing is adopted.


### Outbox Location

Where should the outbox files live?

**Option A: Project-local** (`.tavern/outbox/` in project directory)
- Pros: Project-portable, git-ignorable
- Cons: May conflict with project files

**Option B: User-local** (`~/.tavern/outbox/`)
- Pros: System-wide, not in project
- Cons: Not portable with project

**Option C: Per-project in user space** (`~/.tavern/projects/<hash>/outbox/`)
- Pros: Combines benefits
- Cons: More complex path management

**Recommendation**: Option C, consistent with Claude CLI's per-project session storage pattern.


## Alignment with PRD Requirements


### Invariant 5: Doc store is source of truth

The outbox extends the doc store's role. Events about document changes are stored alongside documents, ensuring the doc store remains the authoritative source for both state AND change notifications.


### Invariant 7: Failures must be visible

The outbox guarantees that failure events are never lost. A `CommitmentVerificationFailed` event will be delivered to all subscribers, even if the app crashes immediately after the failure.


### Section 4.1: Monitor Daemons

PRD describes "Monitor Daemons" that "work for Jake, monitor health/progress/spending." The OutboxPublisher is a natural implementation: a daemon that ensures events flow reliably to all interested parties.


### Section 4.7: Commitment flow

The outbox guarantees the commitment lifecycle is observable:
- `CommitmentAdded` when parent assigns
- `CommitmentVerificationStarted` when verification begins
- `CommitmentVerificationCompleted` with result

Parent agents and monitoring daemons subscribe to these events for guaranteed notification.


### Section 19.1: Logging Standards

Events in the outbox serve as structured logs by design:
- Every event has timestamp and context
- Events are queryable (filter by type, agent, time range)
- Events are preserved (not just ephemeral log lines)


## Comparison with Related Patterns


### vs. Message Bus (#15)

The Message Bus proposal describes in-memory pub/sub for component communication. The Outbox Pattern adds durability:

| Aspect | Message Bus | Outbox |
|--------|-------------|--------|
| Durability | None (in-memory) | Persistent |
| Crash recovery | Messages lost | Messages preserved |
| Latency | Near-zero | Polling interval |
| Complexity | Lower | Higher |

**Recommendation**: Use both. Message bus for fast in-memory notification, outbox for guaranteed delivery. Subscribers receive via bus; outbox is fallback for missed messages.


### vs. Saga Pattern (#24)

Sagas are about coordinating multi-step transactions with compensation. The outbox could be used to reliably notify the saga coordinator:

```
Step 1 completes → Outbox event → Saga coordinator → Trigger step 2
```

The outbox doesn't replace sagas; it provides reliable communication within a saga.


### vs. CQRS (#12)

CQRS separates read and write models. The outbox provides the communication channel between them:

```
Write model → Outbox event → Projector → Read model
```

If Tavern adopts CQRS, the outbox becomes the bridge from commands to projections.


## Conclusion

The Outbox Pattern addresses a real gap in Tavern's current architecture: guaranteed event delivery for cross-component communication. It's lighter than full Event Sourcing while providing significant benefits:

1. **Guaranteed notification** for critical events (commitment verification, agent completion)
2. **Crash recovery** without lost events
3. **Debugging visibility** via persistent event log
4. **Foundation for future patterns** (Event Sourcing, CQRS, Sagas)

The implementation is incremental and non-disruptive. Existing code continues to work; the outbox adds durability without changing behavior.

**Recommendation**: Adopt the Outbox Pattern for high-value events (agent lifecycle, commitment verification) as a foundation. This provides immediate benefit and opens the path for more sophisticated eventing patterns as the system matures.
