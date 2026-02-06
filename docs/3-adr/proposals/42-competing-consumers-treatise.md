# Competing Consumers Architecture: Complete Analysis

This document contains the full research, reasoning, and trade-off analysis for the Competing Consumers architecture proposal for the Tavern multi-agent orchestrator.


## Research Findings


### Current Codebase State

The existing v1 implementation has the foundational building blocks but no queue infrastructure:

**Existing Components:**

- `AgentRegistry` -- Thread-safe registry tracking agents by ID and name using `DispatchQueue`
- `AgentSpawner` -- Factory for creating `MortalAgent` instances with themed names
- `MortalAgent` -- Task-scoped agent with state machine (idle/working/waiting/verifying/done)
- `TavernCoordinator` -- Central hub managing Jake, spawner, and chat view models (`@MainActor`)
- `DocStore` -- File-based document storage with CRUD operations, thread-safe via `DispatchQueue`
- `Agent` protocol -- Common interface with `send()`, state, and `resetConversation()`
- `CommitmentList` and `CommitmentVerifier` -- Verification infrastructure for task completion

**Key Observations:**

1. Agents are currently spawned per-assignment, one-to-one mapping
2. No work queue abstraction exists (PRD Section 18 marks "Drones / work queues" as deferred)
3. `AgentState` enum has states that map to consumer lifecycle: `idle`, `working`, `done`
4. Thread safety is well-established via `DispatchQueue` pattern
5. `DocStore` provides the storage layer but lacks queue semantics (FIFO, visibility timeout, acknowledgment)


### PRD Requirements for Work Queues and Drones

From the PRD (`docs/seed-design/prd_2026-01-19.md`):

**Section 4.1 - Agent Types:**
> | **Drone** | Single task | Meeseeks-style, one task then terminate, cheap models, cheap to fail |

**Section 6.3 - Work Queues:**
> - Live in document store
> - Parents create them
> - Agents attach at spawn or mid-task
> - Agents have instructions for empty queue (idle, hibernate, terminate, etc.)
> - Determinism ensures instructions are present

**Section 6.2 - Agent Spawn Configuration:**
> - Model selection (Haiku for drones, Sonnet for coordinators, Opus for architects)
> - Token budget
> - Work queue attachment
> - What to do when done (terminate, wait, check queue)

**Section 9 - Metrics:**
> - High amplification = many agents productively working while human focuses elsewhere
> - Primary measure: count of saturated agents running concurrently


### Design Transcript Insights

From `docs/seed-design/transcript_2026-01-19-1144.md`:

> "We'll just keep firing off a drone if there's a work item on the queue and have it go immediately."

> "Work queues are in the document store, parents create them. Agents can attach at spawn time or mid-task."

> "When we can break down work into a bunch of chunks, we may want to use agents on less powerful models to do heavy lifting. If they hit a problem, they fail, and some other agent comes to clean up the mess."

These quotes establish:
1. Drones are disposable, failure-tolerant workers
2. Work queues are the dispatch mechanism
3. Failure is expected and handled by "some other agent" -- exactly competing consumer semantics


## How Competing Consumers Maps to PRD Goals


### Direct Alignment

| PRD Requirement | Competing Consumers Implementation |
|-----------------|-----------------------------------|
| Drones terminate after task | Consumer completes work item, immediately polls for next |
| Cheap models for drones | Consumer pool configured with Haiku; all consumers share model tier |
| Cheap to fail | Failed item returns to queue via visibility timeout; any consumer retries |
| Queue attachment at spawn | Consumer configured with list of queues to poll |
| Queue attachment mid-task | Consumer can subscribe to additional queues dynamically |
| Empty queue behavior | Consumer polls; if all subscribed queues empty, hibernates or terminates |
| High amplification | Consumer count = concurrent processing capacity = amplification metric |
| Work queue in doc store | Queue persistence via DocStore documents |


### The "Meeseeks Pattern"

The PRD's drone description ("Meeseeks-style, one task then terminate") is precisely what Competing Consumers provides:

1. **Mr. Meeseeks is summoned** -- Consumer claims work item from queue
2. **Mr. Meeseeks does the task** -- Consumer processes work item
3. **Mr. Meeseeks vanishes** -- Consumer acknowledges completion, immediately claims next item (logical termination per-task)
4. **Meeseeks are interchangeable** -- Any consumer can handle any item; no identity persistence

The key insight is that "terminate" in drone terms means "finish this unit of work and forget about it" -- not necessarily "destroy the process." A consumer that finishes one item and starts another is logically a new Meeseeks for that new item.


## How Competing Consumers Differs from Work-Stealing Pool (#8)


### Philosophical Difference

**Work-Stealing Pool (#8):**
- Agents have "home" queues they're primarily attached to
- When home queue is empty, agent looks for work elsewhere ("stealing")
- Implies task affinity -- agent prefers its assigned queue
- Stealing is an optimization for load balancing
- More complex coordination (who can steal from whom, fairness)

**Competing Consumers (#42):**
- Agents have no queue affinity; all queues are equal
- Agent claims from any queue with available work
- No concept of "stealing" -- just claiming
- Simpler mental model: agents are fungible workers
- Queue depth is the only coordination signal


### Structural Differences

| Aspect | Work-Stealing Pool (#8) | Competing Consumers (#42) |
|--------|------------------------|---------------------------|
| **Queue Binding** | Agents bound to home queue | Agents poll from any/all queues |
| **Load Balancing** | Active stealing when idle | Passive via shared claim pool |
| **Coordination** | PoolSupervisor tracks stealing | QueueManager tracks visibility only |
| **Complexity** | Higher (stealing logic, fairness) | Lower (just claim semantics) |
| **Affinity** | Agents prefer home queue | No preference; first available |
| **Scaling Unit** | DronePool with home queue | Consumer count (queue-agnostic) |
| **Empty Queue** | Steal from other pools | Poll other subscribed queues |


### When Each Wins

**Work-Stealing Pool wins when:**
- Queues represent semantic categories (build vs test vs review)
- You want agents to develop "expertise" in a queue type
- Load is predictably uneven across categories
- Stealing provides better locality than random claiming

**Competing Consumers wins when:**
- All work items are homogeneous
- Agents are truly interchangeable
- Simplicity and fault tolerance matter most
- You want straightforward horizontal scaling


### Technical Implementation Differences

**Work-Stealing Pool:**
```swift
// Agent has home queue and steal targets
class DroneAgent {
    let homeQueue: WorkQueue
    let stealableQueues: [WorkQueue]

    func getNextWork() async -> WorkItem? {
        // Try home queue first
        if let item = await homeQueue.claim() {
            return item
        }
        // Steal from others
        for queue in stealableQueues {
            if let item = await queue.steal() {
                return item
            }
        }
        return nil
    }
}
```

**Competing Consumers:**
```swift
// Agent polls from all subscribed queues equally
class Consumer {
    let subscribedQueues: [WorkQueue]

    func getNextWork() async -> WorkItem? {
        // Round-robin or priority across all queues
        for queue in subscribedQueues.shuffled() {
            if let item = await queue.claim() {
                return item
            }
        }
        return nil
    }
}
```

The difference is subtle but important: Work-Stealing has explicit "home" vs "steal" semantics; Competing Consumers treats all queues equally.


## Trade-offs Considered


### Visibility Timeout vs Immediate Requeue

**Visibility Timeout (SQS-style):**
- Item becomes invisible when claimed
- If not acknowledged within timeout, item reappears
- Prevents double-processing
- Requires tuning timeout duration
- Natural fault tolerance

**Immediate Requeue on Failure:**
- Consumer explicitly requeues on failure
- Requires consumer to survive long enough to requeue
- If consumer crashes, item is lost
- Simpler implementation
- Less fault tolerant

**Decision:** Visibility timeout. The PRD emphasizes fault tolerance ("cheap to fail"). Visibility timeout handles consumer crashes gracefully -- exactly what we need for disposable drones.


### Single Queue vs Multiple Queue Subscription

**Single Queue per Consumer:**
- Simpler consumer logic
- Requires more consumers for more queues
- Natural queue affinity (becomes work-stealing)

**Multiple Queue Subscription:**
- Consumer can pull from any subscribed queue
- Fewer consumers needed
- Better load balancing across queues
- More complex polling logic

**Decision:** Multiple queue subscription with configurable priority. This matches PRD's "agents can attach to queues at spawn time or mid-task" and enables flexible deployment.


### In-Memory vs DocStore-Backed Queues

**In-Memory Queues:**
- Fast claiming and acknowledgment
- Lost on restart
- Simpler implementation
- No persistence semantics

**DocStore-Backed Queues:**
- Survives restarts
- Auditable (queue state is visible in files)
- Matches PRD's "work queues live in document store"
- Higher latency for operations
- Need atomic operations

**Decision:** DocStore-backed with in-memory caching. Queue metadata and pending items persist to DocStore; active claims cached in memory for performance. This matches PRD while maintaining speed.


### Acknowledgment Semantics

**Auto-acknowledge on claim:**
- Item removed from queue immediately
- Simple; no tracking needed
- If consumer fails, item is lost
- Not fault tolerant

**Explicit acknowledgment:**
- Item stays in queue until acknowledged
- Visibility timeout hides it from other consumers
- If consumer fails, item reappears after timeout
- More complex but fault tolerant

**Manual delete:**
- Consumer must explicitly delete after processing
- Most control but most error-prone
- Forgotten deletes cause reprocessing

**Decision:** Explicit acknowledgment with visibility timeout. This is the standard enterprise pattern and matches "cheap to fail" requirements.


### Dead Letter Queue Strategy

**No DLQ:**
- Failed items retry forever
- Can cause queue backup
- Simple to implement

**DLQ after N attempts:**
- Items moved to DLQ after max retries
- Prevents infinite retry loops
- Requires monitoring and manual handling
- PRD says "failures must be visible"

**DLQ with escalation:**
- Failed items go to DLQ AND notify parent/user
- Matches PRD's "failures must be visible"
- More complex but appropriate

**Decision:** DLQ with escalation. After `maxAttempts`, item moves to dead letter queue AND parent agent (or user) is notified. This satisfies PRD invariant "failures must be visible."


## Implementation Complexity


### New Components Required

1. **WorkQueue** -- DocStore-backed queue with FIFO semantics
2. **WorkItem** -- Individual work unit with metadata
3. **QueueManager** -- Creates, monitors, and manages queue lifecycle
4. **Consumer** -- Agent configured for queue consumption
5. **VisibilityManager** -- Tracks in-flight items and timeouts
6. **DeadLetterQueue** -- Holds permanently failed items
7. **ConsumerSupervisor** -- Scales consumer count based on queue depth


### Data Model

```swift
/// A work queue persisted in DocStore
struct WorkQueue: Codable, Identifiable {
    let id: UUID
    let name: String
    let parentAgentId: UUID  // Who created this queue
    var visibilityTimeout: TimeInterval  // How long before unclaimed item reappears
    var maxAttempts: Int  // After this many failures, move to DLQ
    var emptyBehavior: EmptyQueueBehavior
    let createdAt: Date
}

/// Individual work item
struct WorkItem: Codable, Identifiable {
    let id: UUID
    let queueId: UUID
    let assignment: String
    let commitments: [CommitmentDefinition]
    var status: WorkItemStatus
    var attempts: Int
    var claimedBy: UUID?  // Consumer ID
    var claimedAt: Date?
    var visibleAt: Date  // When item becomes visible again
    let createdAt: Date
    var metadata: [String: String]  // Arbitrary key-value pairs
}

enum WorkItemStatus: String, Codable {
    case pending      // Available for claiming
    case claimed      // Claimed by a consumer, invisible to others
    case completed    // Successfully processed
    case failed       // Processing failed, will retry
    case deadLettered // Max attempts exceeded, moved to DLQ
}

enum EmptyQueueBehavior: String, Codable {
    case poll         // Consumer keeps polling
    case hibernate    // Consumer suspends until signal
    case terminate    // Consumer exits
}
```


### Consumer Implementation Sketch

```swift
actor Consumer {
    let id: UUID
    let name: String
    let subscribedQueues: [UUID]
    let queueManager: QueueManager
    let claude: ClaudeCode
    private var isRunning = true

    func start() async {
        while isRunning {
            // Try to claim work from any subscribed queue
            if let item = await claimNextWork() {
                await process(item)
            } else {
                // No work available; wait before polling again
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func claimNextWork() async -> WorkItem? {
        for queueId in subscribedQueues.shuffled() {
            if let item = await queueManager.claim(from: queueId, by: id) {
                return item
            }
        }
        return nil
    }

    private func process(_ item: WorkItem) async {
        do {
            // Execute the work
            let result = try await claude.runSinglePrompt(
                prompt: item.assignment,
                outputFormat: .json,
                options: ClaudeCodeOptions()
            )

            // Verify commitments if any
            if !item.commitments.isEmpty {
                let passed = try await verifyCommitments(item.commitments)
                if !passed {
                    throw ConsumerError.commitmentsFailed
                }
            }

            // Acknowledge successful completion
            await queueManager.acknowledge(item.id, success: true)

        } catch {
            // Processing failed; item will reappear after visibility timeout
            await queueManager.acknowledge(item.id, success: false, error: error)
        }
    }

    func stop() {
        isRunning = false
    }
}
```


### QueueManager Implementation Sketch

```swift
actor QueueManager {
    private let docStore: DocStore
    private var queues: [UUID: WorkQueue] = [:]
    private var items: [UUID: [WorkItem]] = [:]  // queueId -> items
    private var inFlight: [UUID: (item: WorkItem, claimedAt: Date)] = [:]

    /// Claim the next available item from a queue
    func claim(from queueId: UUID, by consumerId: UUID) async -> WorkItem? {
        guard var queueItems = items[queueId] else { return nil }

        let now = Date()

        // Find first item that is pending or has timed out
        for (index, item) in queueItems.enumerated() {
            if item.status == .pending || item.visibleAt <= now {
                // Claim it
                var claimed = item
                claimed.status = .claimed
                claimed.claimedBy = consumerId
                claimed.claimedAt = now
                claimed.visibleAt = now + queue(queueId).visibilityTimeout

                queueItems[index] = claimed
                items[queueId] = queueItems
                inFlight[item.id] = (claimed, now)

                await persistQueueState(queueId)
                return claimed
            }
        }

        return nil
    }

    /// Acknowledge processing result
    func acknowledge(_ itemId: UUID, success: Bool, error: Error? = nil) async {
        guard let (item, _) = inFlight.removeValue(forKey: itemId) else { return }
        guard var queueItems = items[item.queueId] else { return }

        if success {
            // Remove from queue
            queueItems.removeAll { $0.id == itemId }
        } else {
            // Increment attempt count
            if let index = queueItems.firstIndex(where: { $0.id == itemId }) {
                var failed = queueItems[index]
                failed.attempts += 1
                failed.claimedBy = nil
                failed.claimedAt = nil

                if failed.attempts >= queue(item.queueId).maxAttempts {
                    failed.status = .deadLettered
                    await moveToDeadLetter(failed, error: error)
                    queueItems.remove(at: index)
                } else {
                    failed.status = .pending
                    failed.visibleAt = Date()  // Immediately visible for retry
                    queueItems[index] = failed
                }
            }
        }

        items[item.queueId] = queueItems
        await persistQueueState(item.queueId)
    }

    /// Check for timed-out claims and make items visible again
    func checkTimeouts() async {
        let now = Date()
        for (itemId, (item, claimedAt)) in inFlight {
            let timeout = queue(item.queueId).visibilityTimeout
            if now.timeIntervalSince(claimedAt) > timeout {
                // Timed out; make visible again
                await acknowledge(itemId, success: false, error: ConsumerError.timeout)
            }
        }
    }
}
```


### Modifications to Existing Components

**AgentSpawner:**
- Add `spawnConsumer(queues:)` method
- Consumer is a specialized agent type (or MortalAgent with queue config)

**TavernCoordinator:**
- Own QueueManager instance
- Expose queue creation/monitoring APIs
- Track consumer pool size

**DocStore:**
- Add atomic update support for claim operations
- Add watch/notify capability for queue changes (optional, for hibernation wake)


### Estimated Complexity

| Component | Effort | Risk |
|-----------|--------|------|
| WorkQueue/WorkItem data models | Low | Low |
| QueueManager core operations | Medium | Medium |
| Consumer implementation | Medium | Low |
| Visibility timeout handling | Medium | Medium |
| DocStore persistence integration | Medium | Medium |
| Dead letter queue + escalation | Low | Low |
| ConsumerSupervisor (auto-scaling) | Medium | Medium |
| Integration with TavernCoordinator | Low | Low |

**Total estimate:** 2-3 weeks of focused work. Lower than Work-Stealing Pool because there's no stealing coordination logic.


### Concurrency Considerations

1. **Claim race conditions** -- Two consumers try to claim same item
   - Solution: Atomic claim operation via actor isolation or DocStore atomic update

2. **Acknowledgment after timeout** -- Consumer finishes after visibility timeout expired and another consumer claimed item
   - Solution: Acknowledgment includes claim timestamp; reject stale acknowledgments

3. **Queue modification during polling** -- Items added while consumer is polling
   - Solution: Snapshot-based iteration; new items appear in next poll cycle

4. **Scaling race conditions** -- Scaling decision based on stale queue depth
   - Solution: Actor-based ConsumerSupervisor with periodic checks


## Migration Path from Current State


### Phase 1: Queue Infrastructure (Non-breaking)

Add WorkQueue and WorkItem to DocStore. Jake can create queues and add items. Items sit there -- no consumption yet.

```
Sources/TavernCore/WorkQueues/WorkQueue.swift
Sources/TavernCore/WorkQueues/WorkItem.swift
Sources/TavernCore/WorkQueues/QueueManager.swift
Tests/TavernCoreTests/WorkQueues/WorkQueueTests.swift
```

**Existing code continues working unchanged.**


### Phase 2: Basic Consumer

Introduce Consumer that polls a single queue and processes items.

```
Sources/TavernCore/Agents/Consumer.swift
Sources/TavernCore/WorkQueues/VisibilityManager.swift
```

Consumer claims, processes via Claude, acknowledges. No scaling, no multi-queue.


### Phase 3: Multi-Queue Subscription

Enable consumers to subscribe to multiple queues with configurable priority.

```swift
// Consumer polls from all subscribed queues
let consumer = Consumer(
    queues: [buildQueue.id, testQueue.id],
    priority: .roundRobin  // or .weighted, .random
)
```


### Phase 4: Dead Letter Queue and Escalation

Add DLQ and notification when items fail permanently.

```
Sources/TavernCore/WorkQueues/DeadLetterQueue.swift
```

Failed items move to DLQ; parent agent (or user) receives notification.


### Phase 5: Consumer Scaling

Add ConsumerSupervisor that scales consumer count based on queue depth.

```
Sources/TavernCore/WorkQueues/ConsumerSupervisor.swift
```

```swift
let supervisor = ConsumerSupervisor(
    queueManager: queueManager,
    minConsumers: 2,
    maxConsumers: 10,
    scaleUpThreshold: 20,  // items in queue
    scaleDownThreshold: 5,
    claudeFactory: { ClaudeCode() }
)
```


### Phase 6: Integration with Jake

Wire queue creation into Jake's spawn capabilities.

```swift
// Jake can now:
// - Create work queues for task decomposition
// - Submit work items to queues
// - Monitor queue depth and consumer count
// - Handle DLQ notifications
```


## Open Questions


### 1. Consumer Session Persistence

Current `MortalAgent` persists session IDs via `SessionStore`. Should consumers persist sessions?

- **Option A:** No persistence -- consumers are ephemeral, no history matters between items
- **Option B:** Per-consumer persistence -- useful if consumer handles related items
- **Option C:** Per-item persistence -- session tied to WorkItem, handed off if consumer fails

**Recommendation:** Option A. Competing Consumers assumes items are independent. If items need context, use Option C (session in WorkItem metadata).


### 2. Queue Priority

Should consumers have queue priorities?

- **Option A:** Round-robin across subscribed queues
- **Option B:** Weighted priority (check high-priority queue more often)
- **Option C:** Strict priority (always check queue A before queue B)

**Recommendation:** Configurable, default to round-robin. PRD doesn't specify queue priority; keep it simple until needed.


### 3. Consumer Health Checking

How do we detect stuck consumers?

- **Option A:** Visibility timeout is the health check -- if consumer doesn't ack, item reappears
- **Option B:** Separate heartbeat from consumer to supervisor
- **Option C:** Both

**Recommendation:** Option A for v1. Visibility timeout naturally handles stuck consumers. Add heartbeat if we need faster detection later.


### 4. Batch Processing

Should consumers claim multiple items at once?

- **Option A:** Single item per claim (current design)
- **Option B:** Batch claim (get N items, process all, ack all)

**Recommendation:** Single item for v1. Batch adds complexity and partial failure scenarios. Optimize later if throughput demands.


### 5. Commitment Verification Timing

When does commitment verification happen?

- **Option A:** After each item (current MortalAgent behavior)
- **Option B:** Deferred to separate verification queue
- **Option C:** Configurable per work item

**Recommendation:** Option A. Each work item is independent; verify immediately. Option B would be useful for batching verification, but adds complexity.


### 6. Model Tier per Queue vs per Consumer Pool

Queues might want different model tiers (Haiku for simple, Sonnet for complex).

- **Option A:** Model tier on queue, consumer adapts when claiming
- **Option B:** Model tier on consumer, different consumer pools for different models
- **Option C:** Model tier on work item

**Recommendation:** Option B. Multiple consumer pools, each configured with a model tier. Queues bind to appropriate pool via subscription. This matches PRD's "Haiku for drones, Sonnet for coordinators" distinction.


## Comparison with Other Proposals


### vs Work-Stealing Pool (#8)

Covered in detail above. Key difference: Competing Consumers has no queue affinity; Work-Stealing has home queues with stealing.

**Choose Competing Consumers when:** Work is homogeneous, simplicity matters, fault tolerance is critical.

**Choose Work-Stealing when:** Queues have semantic meaning, agent specialization helps, load is predictably uneven.


### vs Broker Pattern (#32)

Broker Pattern centralizes communication routing; Competing Consumers centralizes work distribution.

**Combine:** Broker handles message routing (questions, discoveries, notifications). QueueManager handles work distribution (task items). These are orthogonal concerns.

**Example:** Agent submits question to broker (routed to parent). Parent decomposes task into work items, submits to queue. Consumers claim and process items. Results go back through broker.


### vs Actor Model (#2)

Actor Model provides isolation through Swift actors; Competing Consumers provides work distribution.

**Combine:** QueueManager and Consumer are both actors. Actor isolation protects queue state. Consumer actors poll and process independently.


### vs Document-Centric (#3)

Document-Centric stores state in files; Competing Consumers uses DocStore for queue persistence.

**Combine:** WorkQueue and WorkItem are documents in DocStore. Queue state is inspectable as files. This aligns with PRD's "if it's not in a file, it doesn't exist."


### vs Supervisor Trees (#4)

Supervisor Trees define fault handling hierarchy; Competing Consumers provides fault tolerance through requeue.

**Combine:** ConsumerSupervisor is the supervisor for consumer pool. If consumer fails, supervisor can restart it. Item is independently protected by visibility timeout -- doesn't need supervisor for item recovery.


## Conclusion

The Competing Consumers architecture is a strong fit for Tavern's drone and work queue requirements:

1. **Direct PRD alignment** -- Meeseeks semantics, work queues in doc store, cheap to fail
2. **Simpler than Work-Stealing** -- No stealing coordination, no queue affinity management
3. **Battle-tested pattern** -- Well-understood from enterprise messaging (SQS, RabbitMQ, Kafka)
4. **Natural fault tolerance** -- Visibility timeout handles consumer failures gracefully
5. **Clear scaling story** -- Add consumers to increase throughput; queue depth is the signal

The main trade-offs:

1. **No task affinity** -- Consumers don't remember previous items (mitigated by design: items are independent)
2. **Queue contention at scale** -- Many consumers polling same queue (mitigated by efficient actor-based QueueManager)
3. **Visibility timeout tuning** -- Requires calibration per workload (start conservative, adjust based on metrics)

**Recommendation:** Proceed with Phase 1 (queue infrastructure) to validate the data model. This is lower risk than Work-Stealing Pool because the core pattern is simpler. If queue affinity becomes important later, can evolve toward Work-Stealing without rewriting queue infrastructure.


## Appendix: Comparison to Cloud Messaging Services

Competing Consumers is the core pattern behind:

- **AWS SQS** -- Standard queues with visibility timeout, dead letter queues, long polling
- **Azure Service Bus** -- Queues with peek-lock (visibility timeout), dead letter support
- **RabbitMQ** -- Consumer acknowledgment, redelivery on failure, dead letter exchange
- **Apache Kafka** -- Consumer groups, partition assignment (more complex, partition-based)

The Tavern implementation would be most similar to **SQS Standard Queue**:

| Feature | SQS | Tavern Competing Consumers |
|---------|-----|---------------------------|
| Visibility timeout | Yes | Yes |
| Dead letter queue | Yes | Yes |
| Long polling | Yes | Simple polling loop (can add) |
| At-least-once delivery | Yes | Yes |
| Message deduplication | Optional | Not initially (can add) |
| FIFO ordering | Optional (FIFO queues) | Basic FIFO within queue |
| Batch operations | Yes | Not initially (can add) |

This validates that the pattern is well-understood and proven at scale. Implementation can borrow concepts from these mature systems.


## Appendix: Metrics for Competing Consumers

Key metrics to expose:

| Metric | Description | Use |
|--------|-------------|-----|
| `queue_depth` | Number of pending items | Scaling signal |
| `in_flight_count` | Number of claimed but unacknowledged items | Processing load |
| `consumer_count` | Active consumers | Capacity |
| `claim_rate` | Items claimed per second | Throughput |
| `completion_rate` | Items completed per second | Effective throughput |
| `failure_rate` | Items failed per second | Error rate |
| `dlq_depth` | Items in dead letter queue | Permanent failures |
| `avg_processing_time` | Time from claim to acknowledgment | Latency |
| `timeout_rate` | Claims that exceeded visibility timeout | Consumer health |
| `age_of_oldest_item` | Time since oldest pending item was created | Queue backup |

These metrics directly support PRD's "high amplification" goal -- you can see exactly how many consumers are saturated and how work is flowing through the system.
