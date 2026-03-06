# Work-Stealing Pool Architecture - Complete Analysis

This treatise documents the full research, reasoning, and trade-offs behind the Work-Stealing Pool architecture proposal for the Tavern multi-agent orchestrator.


## Research Findings


### Current Codebase State

The current v1 implementation provides foundational building blocks but lacks work queue infrastructure:

**Existing Components:**
- `AgentRegistry` - Thread-safe registry tracking agents by ID and name
- `AgentSpawner` - Factory for creating mortal agents with themed names
- `MortalAgent` - Task-scoped agent with commitments and state machine (idle/working/waiting/verifying/done)
- `TavernCoordinator` - Central hub managing Jake, spawner, and chat view models
- `DocStore` - File-based document storage with CRUD operations

**Key Observations:**
1. Agents are currently spawned per-assignment, not pooled
2. No work queue abstraction exists yet (mentioned as deferred in PRD section 18)
3. `AgentState` already has the right states for pool semantics: idle, working, waiting, done
4. `CommitmentList` and `CommitmentVerifier` provide verification infrastructure
5. Thread safety via `DispatchQueue` is well-established pattern throughout


### PRD Requirements for Drones and Work Queues

From the PRD (Section 4.1, 6.2, 6.3):

**Drone Characteristics:**
- "Meeseeks-style, one task then terminate"
- Use cheap models (Haiku for drones, Sonnet for coordinators)
- "Cheap to fail" - failure is expected and handled
- Single task lifecycle: activated -> do work -> terminate

**Work Queue Requirements:**
- Live in document store
- Parents create them
- Agents attach at spawn or mid-task
- Empty queue behavior must be specified (idle, hibernate, terminate)
- Determinism ensures instructions are present

**Spawn Configuration:**
- Model selection per agent type
- Token budget
- Work queue attachment
- What to do when done (terminate, wait, check queue)


### Design Transcript Insights

From `transcript_2026-01-19-1144.md`:

> "When we can break down work into a bunch of chunks, we may want to use agents on less powerful models to do heavy lifting. If they hit a problem, they fail, and some other agent comes to clean up the mess."

> "Work queues are in the document store, parents create them. Agents can attach at spawn time or mid-task, agents will have instructions what to do when the queue is empty."

> "We'll just keep firing off a drone if there's a work item on the queue and have it go immediately."

These quotes establish:
1. Drones are disposable, failure-tolerant workers
2. Work queues are the dispatch mechanism
3. Queue-to-agent binding is flexible (spawn-time or dynamic)


## Mapping to Drone/Work Queue Requirements


### How Work-Stealing Satisfies PRD Goals

| PRD Requirement | Work-Stealing Implementation |
|-----------------|------------------------------|
| Drones terminate after task | Drone returns to pool (logical termination) or truly terminates |
| Cheap models for drones | Pool configured with model tier; all drones in pool share model |
| Cheap to fail | Failed work item returns to queue; drone can be replaced |
| Queue attachment at spawn | Pool supervisor binds pool to queue(s) at creation |
| Queue attachment mid-task | Agent can subscribe to additional queues dynamically |
| Empty queue behavior | Pool shrinks or drones hibernate; configurable per pool |
| High amplification | Pool size = concurrent drone count = amplification metric |


### Work Queue Data Model

```swift
struct WorkQueue: Codable {
    let id: UUID
    let name: String
    let parentAgentId: UUID  // Who created this queue
    var items: [WorkItem]
    var emptyBehavior: EmptyQueueBehavior
    var stealingEnabled: Bool
    var priority: Int  // For stealing preference
}

struct WorkItem: Codable {
    let id: UUID
    let queueId: UUID
    let assignment: String
    let commitments: [CommitmentDefinition]
    var status: WorkItemStatus  // pending, claimed, executing, completed, failed
    var claimedBy: UUID?  // Drone ID
    var attempts: Int
    var maxAttempts: Int
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
}

enum EmptyQueueBehavior {
    case idle           // Drone waits, checks periodically
    case hibernate      // Drone suspends, woken by queue event
    case terminate      // Drone exits, pool may shrink
    case stealFromOthers  // Look for work in other queues
}
```


### Pool Supervisor Responsibilities

```swift
actor PoolSupervisor {
    private var pools: [UUID: DronePool]
    private let workQueueManager: WorkQueueManager

    // Scale pool based on queue depth
    func evaluateScaling(for poolId: UUID) async

    // Handle work stealing coordination
    func findStealableWork(for drone: Drone, excluding: [UUID]) async -> WorkItem?

    // Route failed work back to queue
    func handleFailure(_ item: WorkItem, from drone: Drone, error: Error) async

    // Collect completion results
    func handleCompletion(_ item: WorkItem, from drone: Drone, result: WorkResult) async
}
```


## Trade-offs Considered


### Pooling vs Per-Task Spawning

**Per-Task Spawning (current model):**
- Simple mental model: 1 task = 1 agent
- Agent has full context from start to finish
- No coordination overhead
- But: spawn cost per task, no reuse, potential resource exhaustion

**Pooling:**
- Amortized spawn cost across many tasks
- Better resource utilization
- But: agents have no task history, cold start per work item
- But: need pool management infrastructure

**Decision:** For drone-style work (Meeseeks pattern), pooling wins. Drones have no meaningful history to preserve. The spawn cost saved over hundreds of tasks is significant.


### Work Stealing vs Static Assignment

**Static Assignment:**
- Each queue has dedicated agents
- Simple, predictable
- But: uneven load creates idle agents while others are overwhelmed

**Work Stealing:**
- Idle agents look for work elsewhere
- Maximum utilization
- But: coordination complexity, potential contention
- But: agent may work on unfamiliar queue

**Decision:** Work stealing aligns with "high amplification" goal. The coordination complexity is worth it for throughput-oriented workloads. Static assignment is simpler for simpler use cases (could be configurable).


### Centralized vs Distributed Queue

**Centralized Queue Manager:**
- Single point of coordination
- Simpler consistency model
- But: potential bottleneck at scale

**Distributed Queues:**
- Each queue is independent
- Scales better
- But: stealing requires cross-queue coordination

**Decision:** Start centralized. The DocStore is already the central nervous system. Queue manager lives alongside. If scale demands, can distribute later with CRDTs or similar.


### Claim-Based vs Push-Based Work Distribution

**Push-Based:**
- Supervisor assigns work to drones
- Centralized control
- But: supervisor becomes bottleneck

**Claim-Based (Pull):**
- Drones claim work from queues
- Natural load balancing
- But: need atomic claim operation to prevent double-processing

**Decision:** Claim-based with optimistic locking. Drone attempts to claim, if conflict, try next item. This matches the "agents autonomously pull work" philosophy.


## Implementation Complexity


### New Components Required

1. **WorkQueue** - Document type stored in DocStore
2. **WorkItem** - Document type for individual tasks
3. **DronePool** - Collection of warm agents with shared configuration
4. **PoolSupervisor** - Manages pool scaling and stealing coordination
5. **WorkQueueManager** - CRUD + watching for queue documents
6. **DroneAgent** - Specialized MortalAgent subclass (or configuration)


### Modifications to Existing Components

**AgentSpawner:**
- Add `spawnDrone(pool:)` method for pool-managed agents
- Support batch spawning for pool initialization

**DocStore:**
- Add watch/subscribe capability for queue changes
- Atomic update support for claim operations

**TavernCoordinator:**
- Add pool and queue management APIs
- Expose amplification metrics


### Estimated Complexity

| Component | Effort | Risk |
|-----------|--------|------|
| WorkQueue/WorkItem models | Low | Low |
| DronePool basic implementation | Medium | Low |
| PoolSupervisor with scaling | Medium | Medium |
| Work stealing logic | High | High |
| DocStore watching | Medium | Medium |
| Integration with existing spawn | Medium | Low |

**Total estimate:** 2-3 weeks of focused work, with stealing logic being the riskiest piece.


### Concurrency Considerations

Work stealing introduces several concurrency challenges:

1. **Double-claim prevention** - Two drones must not claim the same item
   - Solution: Atomic compare-and-swap on WorkItem.status

2. **Queue modification during iteration** - New items added while stealing
   - Solution: Snapshot-based iteration, re-check before claim

3. **Pool scaling race conditions** - Scaling decision vs current drone count
   - Solution: Actor-based PoolSupervisor with serial decision making

4. **Cross-queue stealing fairness** - Prevent starvation of low-priority queues
   - Solution: Weighted stealing probability or round-robin across queues


## Migration Path from Current State


### Phase 1: Work Queue Foundation

Add WorkQueue and WorkItem to DocStore without changing agent behavior.

```swift
// New files
Sources/TavernCore/WorkQueues/WorkQueue.swift
Sources/TavernCore/WorkQueues/WorkItem.swift
Sources/TavernCore/WorkQueues/WorkQueueStore.swift

// Test coverage
Tests/TavernCoreTests/WorkQueues/WorkQueueTests.swift
```

Jake can create queues and add items. Items just sit there. No execution yet.


### Phase 2: Basic Drone Pool

Introduce DronePool that spawns agents and binds them to a single queue.

```swift
Sources/TavernCore/Agents/DroneAgent.swift
Sources/TavernCore/WorkQueues/DronePool.swift
Sources/TavernCore/WorkQueues/PoolSupervisor.swift
```

Drones pull from queue, execute, return to pool. No stealing yet.


### Phase 3: Pool Scaling

Add automatic scaling based on queue depth.

```swift
// Enhance PoolSupervisor
- Monitor queue depth
- Scale up when backlog grows
- Scale down when queues drain
- Respect min/max pool bounds
```


### Phase 4: Work Stealing

Add cross-queue work stealing for maximum utilization.

```swift
// Enhance PoolSupervisor
- Track all queues with stealingEnabled
- When drone finishes and home queue empty, try stealing
- Priority-weighted stealing decisions
- Metrics for steal success/failure rates
```


### Phase 5: Integration

Wire pools into Jake's spawn capabilities.

```swift
// Jake can now:
- Create work queues for task decomposition
- Spin up drone pools attached to queues
- Monitor amplification via pool metrics
- Handle drone failures gracefully
```


## Open Questions


### 1. Drone Session Persistence

Current `MortalAgent` persists session IDs via `SessionStore`. Should drones persist sessions?

- **Option A:** No persistence - drones are ephemeral, no history matters
- **Option B:** Per-pool persistence - pool shares session context
- **Option C:** Per-task persistence - session tied to WorkItem, not drone

Leaning toward Option A for true Meeseeks semantics.


### 2. Sandbox Isolation Per Pool vs Per Drone

PRD mentions sandbox primitives are "mix and match per agent." For pools:

- **Option A:** All drones in pool share sandbox config
- **Option B:** Sandbox tied to queue, drones inherit when claiming
- **Option C:** Per-task sandbox specified in WorkItem

Option A simplifies pool management. Option B enables queue-specialized sandboxes.


### 3. Failure Escalation Path

When a work item fails repeatedly (exceeds maxAttempts):

- Dead-letter queue?
- Escalate to parent agent?
- Surface to user?
- All of the above with configuration?

The PRD says failures must be visible. Need to define the visibility mechanism.


### 4. Stealing Granularity

Steal individual items or batches?

- Single item: Simpler, more responsive
- Batch: Amortizes stealing overhead, but may create new imbalance

Start with single item, add batch optimization if needed.


### 5. Model Tier Per Queue vs Per Pool

Queues might want different model tiers:

- Review queue might want Sonnet for quality
- Test queue might want Haiku for speed

Does the pool adapt, or do we have multiple pools?

Leaning toward multiple pools, each configured for a model tier. Queues bind to appropriate pools.


### 6. Commitment Verification Timing

When does commitment verification happen?

- Before returning item to pool (current MortalAgent behavior)
- After all items in batch complete
- As separate verification pass by dedicated verifier agent

Current behavior seems right for drone isolation.


### 7. Metrics Export

How do we surface amplification and utilization metrics?

- Real-time dashboard in UI
- Periodic logging
- DocStore documents with time series

PRD mentions "metrics dashboard" as deferred. Need to decide on data shape now so pool captures right info.


## Comparison with Alternative Architectures

### vs. Simple Spawn-Per-Task

Work-stealing is more complex but provides:
- Higher throughput via warm pools
- Better resource utilization via stealing
- Natural amplification tracking

Spawn-per-task might be sufficient for low-volume use cases.


### vs. Actor Model

Actor model (each agent is an actor with mailbox) provides:
- Cleaner message passing semantics
- Built-in concurrency via Swift actors

But work-stealing specifically addresses load imbalance, which actor model doesn't inherently solve.


### vs. Event-Driven Pub/Sub

Pub/sub (agents subscribe to topics) provides:
- Loose coupling between producers and consumers
- Natural fan-out

But lacks the work-queue semantics (exactly-once processing, claim tracking) that drones need.


## Conclusion

The Work-Stealing Pool architecture is well-suited for the Tavern's drone requirements:

1. **Aligns with PRD** - Meeseeks semantics, work queues, high amplification
2. **Builds on existing foundation** - DocStore, AgentRegistry, spawn patterns
3. **Clear migration path** - Incremental phases, testable at each step
4. **Addresses core problem** - Maximizes throughput, minimizes idle agents

The main risks are coordination complexity in work stealing and the need for robust atomic operations in DocStore. These are manageable with careful implementation and thorough testing.

Recommend proceeding with Phase 1 (work queue foundation) to validate the data model before committing to full work-stealing complexity.
