# Tuple Space Architecture: Complete Analysis

This document contains the full research, analysis, and reasoning behind the Tuple Space architecture proposal for Tavern.


## Research Findings


### Current Codebase Analysis

The Tavern codebase has several components relevant to Tuple Space coordination:

**Persistence Layer:**
- `SessionStore` uses UserDefaults for session ID storage (key-value, not tuple-based)
- The PRD states: "Doc store IS the filesystem. A file is a document."
- No existing tuple-like abstraction; documents are markdown with YAML frontmatter
- Thread safety via `DispatchQueue` for concurrent access

**Agent Model:**
- `Agent` protocol: `id`, `name`, `state`, `send()`, `resetConversation()`
- `AgentState` enum: `idle`, `working`, `waiting`, `verifying`, `done`
- Agents are currently independent with no coordination primitives
- `AgentSpawner` creates agents via factory pattern

**Coordination Layer:**
- `TavernCoordinator` manages agent selection and spawning
- `AgentRegistry` tracks agents by ID and name
- No work queues, message passing, or shared state mechanisms exist yet
- Commitment verification is per-agent, not distributed

**PRD Requirements Relevant to Tuple Space:**
- "Multiple agents working in parallel on a single project"
- "Work queues: Parents create them, agents attach at spawn or mid-task"
- "Agents have instructions for empty queue (idle, hibernate, terminate)"
- "Merge queue for coordinated changesets"
- "Deterministic verification of agent commitments"


### The Linda Coordination Language

Linda was developed by David Gelernter at Yale in the 1980s. It introduces three core operations on a shared tuple space:

**Operations:**
1. `out(tuple)` -- Deposit a tuple into the space (non-blocking)
2. `in(pattern)` -- Find and remove a matching tuple (blocking if none match)
3. `rd(pattern)` -- Find and copy a matching tuple without removing (blocking)

**Extensions:**
- `inp(pattern)` -- Non-blocking `in`; returns null if no match
- `rdp(pattern)` -- Non-blocking `rd`
- `eval(tuple)` -- Deposit tuple after evaluating expressions in it

**Tuple Matching:**
- Tuples are ordered sequences of typed values: `("task", 42, "pending")`
- Patterns use actuals and formals: `("task", ?id, "pending")` matches any task ID
- Matching is structural: arity and types must align

**Key Properties:**
- **Associative access** -- Tuples retrieved by content, not address
- **Temporal decoupling** -- Writer and reader need not coexist
- **Spatial decoupling** -- Writer doesn't know who will read
- **Synchronization** -- Blocking `in`/`rd` provide implicit coordination
- **Atomicity** -- `in` operation is indivisible


### How This Differs from Blackboard (#6)

The Blackboard and Tuple Space architectures are often confused because both involve shared memory. The distinctions are fundamental:

**Blackboard Architecture:**
- **Shared mutable state** -- Multiple agents read and write the same data structures
- **Knowledge sources observe** -- Agents monitor regions and contribute when relevant
- **Collaborative refinement** -- Multiple agents incrementally improve shared artifacts
- **Scheduler-driven** -- A control component decides which knowledge source runs
- **State is persistent** -- Data remains until explicitly deleted or replaced

**Tuple Space Architecture:**
- **Consumption-based coordination** -- Tuples are claimed (removed) by consumers
- **Anonymous matching** -- Producers don't know consumers; matching is by pattern
- **Exclusive ownership** -- Taking a tuple transfers exclusive possession
- **Self-scheduling** -- Agents block on `in`/`rd` until tuples appear
- **State is transient** -- Tuples exist to be consumed, not to persist

**Concrete Example:**

Imagine a task "implement feature X" with subtasks A, B, C.

*Blackboard approach:*
```
solutions/feature-x/
  ├── design.md       (Architect writes, all read)
  ├── subtask-a.md    (Implementer writes, Tester reads, Reviewer annotates)
  ├── subtask-b.md    (same collaborative pattern)
  └── subtask-c.md
```
Multiple agents observe and contribute to the same files.

*Tuple Space approach:*
```
out(("subtask", "feature-x-a", "pending", {...}))
out(("subtask", "feature-x-b", "pending", {...}))
out(("subtask", "feature-x-c", "pending", {...}))

Worker 1: in(("subtask", _, "pending", ?data)) -> claims subtask-a
Worker 2: in(("subtask", _, "pending", ?data)) -> claims subtask-b
Worker 3: in(("subtask", _, "pending", ?data)) -> claims subtask-c

Worker 1: out(("result", "feature-x-a", "complete", {...}))
```
Each agent claims exactly one subtask; no coordination during execution.

**Synthesis:**

The PRD describes *both* patterns:
- **Tuple Space fits:** Work queues, task distribution, resource tokens, merge queue
- **Blackboard fits:** Collaborative editing, discovery sharing, incremental refinement

A hybrid architecture could use Tuple Space for work distribution and Blackboard for artifact collaboration.


### DocStore as Tuple Space Substrate

The PRD's DocStore philosophy ("file is a document") can map to tuple space:

**Option A: File-per-Tuple**
Each tuple is a file:
```
.tavern/tuples/
├── task-001.json     # {"type": "task", "id": "001", "status": "pending", ...}
├── task-002.json
├── result-001.json   # {"type": "result", "task_id": "001", "outcome": "success", ...}
```

Operations:
- `out()` creates a new file with UUID name
- `in()` atomically finds and deletes matching file (rename to claimed/)
- `rd()` reads file content without deletion

Advantages: Simple, filesystem-native, human-inspectable.
Disadvantages: O(n) matching, filesystem overhead, no blocking reads.


**Option B: Indexed Tuple Store**
A structured store with indexes:
```swift
struct TupleStore {
    // Storage
    private var tuples: [TupleID: Tuple] = [:]

    // Indexes for fast pattern matching
    private var byType: [String: Set<TupleID>] = [:]
    private var byStatus: [String: Set<TupleID>] = [:]

    // Blocking waiters
    private var waiters: [(Pattern, Continuation)] = []

    func out(_ tuple: Tuple) {
        // Insert and check waiters
    }

    func `in`(_ pattern: Pattern) async -> Tuple {
        // Find match or suspend
    }
}
```

Advantages: Fast matching, native blocking, compact storage.
Disadvantages: In-memory state, needs persistence layer, less inspectable.


**Option C: Hybrid**
Indexed in-memory store with file-based durability:
- Tuples live in memory for fast matching
- Write-ahead log for durability
- Periodic snapshots to files
- Human-readable export on demand

This balances performance with the PRD's filesystem philosophy.


## Architectural Mapping


### Tuple Types for Tavern

Define a schema for coordination tuples:

**Task Tuples:**
```swift
struct TaskTuple {
    let type = "task"
    let id: String                    // Unique task ID
    let status: TaskStatus            // pending, claimed, complete, failed
    let assignment: String            // Task description
    let parentId: String?             // For subtasks
    let priority: Int                 // 0-4 (matching PRD)
    let createdAt: Date
    let claimedBy: UUID?              // Agent ID when claimed
}

enum TaskStatus: String, Codable {
    case pending    // Available for claiming
    case claimed    // An agent took it
    case complete   // Done successfully
    case failed     // Done with failure
}
```

**Result Tuples:**
```swift
struct ResultTuple {
    let type = "result"
    let taskId: String                // Which task this completes
    let outcome: Outcome              // success, failure, partial
    let agentId: UUID                 // Who produced this
    let data: [String: Any]           // Result payload
    let completedAt: Date
}
```

**Resource Tuples:**
```swift
struct ResourceTuple {
    let type = "resource"
    let resourceType: ResourceType    // api_quota, file_lock, merge_slot
    let resourceId: String            // Specific resource instance
    let available: Bool               // Can be claimed?
    let heldBy: UUID?                 // Current holder
    let expiresAt: Date?              // Auto-release time
}

enum ResourceType: String, Codable {
    case apiQuota       // Rate limiting
    case fileLock       // Exclusive file access
    case mergeSlot      // Position in merge queue
}
```

**Signal Tuples:**
```swift
struct SignalTuple {
    let type = "signal"
    let signalType: SignalType        // question, discovery, alert
    let sourceAgent: UUID
    let targetAgent: UUID?            // nil for broadcast
    let payload: String
    let priority: Int
    let createdAt: Date
}

enum SignalType: String, Codable {
    case question       // Needs human/parent attention
    case discovery      // Noticed something interesting
    case alert          // Something went wrong
    case completion     // Task finished (for parent notification)
}
```


### Tuple Space Operations

Core protocol for Tavern's tuple space:

```swift
protocol TupleSpace: Sendable {
    /// Deposit a tuple (non-blocking)
    func out<T: TavernTuple>(_ tuple: T) async throws

    /// Read matching tuple without removing (blocking)
    func rd<T: TavernTuple>(_ pattern: TuplePattern<T>) async throws -> T

    /// Read and remove matching tuple (blocking)
    func `in`<T: TavernTuple>(_ pattern: TuplePattern<T>) async throws -> T

    /// Non-blocking read (returns nil if no match)
    func rdp<T: TavernTuple>(_ pattern: TuplePattern<T>) async throws -> T?

    /// Non-blocking take (returns nil if no match)
    func inp<T: TavernTuple>(_ pattern: TuplePattern<T>) async throws -> T?

    /// Read all matching tuples
    func rdAll<T: TavernTuple>(_ pattern: TuplePattern<T>) async throws -> [T]
}

protocol TavernTuple: Codable, Sendable {
    var tupleType: String { get }
}

struct TuplePattern<T: TavernTuple> {
    // Pattern matching predicates
    let predicates: [(KeyPath<T, Any>, Predicate)]

    static func any() -> TuplePattern<T> { ... }
    static func matching(_ predicates: (KeyPath<T, Any>, Predicate)...) -> TuplePattern<T> { ... }
}
```


### Agent Integration

Agents interact with tuple space instead of direct communication:

**Jake as Task Producer:**
```swift
class Jake: Agent {
    let tupleSpace: TupleSpace

    func handleUserRequest(_ request: String) async throws {
        // Create task tuple
        let task = TaskTuple(
            id: UUID().uuidString,
            status: .pending,
            assignment: request,
            priority: 1
        )

        // Deposit to space
        try await tupleSpace.out(task)

        // Wait for result (blocking)
        let result = try await tupleSpace.rd(
            .matching(\.taskId, .equals(task.id))
        )

        return result.data["response"] as? String ?? ""
    }
}
```

**MortalAgent as Task Consumer:**
```swift
class MortalAgent: Agent {
    let tupleSpace: TupleSpace

    func run() async {
        while state != .done {
            // Block until a task is available, then claim it
            let task = try await tupleSpace.in(
                .matching(\.status, .equals(.pending))
            )

            // Mark as claimed
            var claimed = task
            claimed.status = .claimed
            claimed.claimedBy = self.id
            try await tupleSpace.out(claimed)

            // Do the work
            let outcome = try await execute(task)

            // Produce result
            let result = ResultTuple(
                taskId: task.id,
                outcome: outcome,
                agentId: self.id,
                data: [...]
            )
            try await tupleSpace.out(result)

            // Remove claimed tuple
            _ = try await tupleSpace.in(
                .matching(\.id, .equals(task.id), \.status, .equals(.claimed))
            )

            // Add completed tuple
            var completed = task
            completed.status = .complete
            try await tupleSpace.out(completed)
        }
    }
}
```


### Coordination Patterns

**Work Queue Pattern:**
```swift
// Producer (Jake or parent agent)
for subtask in subtasks {
    try await tupleSpace.out(TaskTuple(
        id: UUID().uuidString,
        status: .pending,
        assignment: subtask.description,
        parentId: parentTask.id,
        priority: subtask.priority
    ))
}

// Consumers (worker agents)
// Each worker loops:
while true {
    let task = try await tupleSpace.in(
        .matching(\.status, .equals(.pending), \.parentId, .equals(myParentId))
    )
    // Process task...
}
```

**Resource Token Pattern (for merge queue):**
```swift
// Initialize merge slots
for i in 0..<maxConcurrentMerges {
    try await tupleSpace.out(ResourceTuple(
        resourceType: .mergeSlot,
        resourceId: "slot-\(i)",
        available: true
    ))
}

// Agent requesting merge
func requestMerge() async throws {
    // Block until a slot is available, then claim it
    let slot = try await tupleSpace.in(
        .matching(\.resourceType, .equals(.mergeSlot), \.available, .equals(true))
    )

    // Mark as held
    var held = slot
    held.available = false
    held.heldBy = self.id
    try await tupleSpace.out(held)

    defer {
        // Release slot when done
        Task {
            var released = held
            released.available = true
            released.heldBy = nil
            try? await tupleSpace.out(released)
        }
    }

    // Perform merge...
}
```

**Question Bubbling Pattern:**
```swift
// Child agent with question
func bubbleQuestion(_ question: String) async throws {
    try await tupleSpace.out(SignalTuple(
        signalType: .question,
        sourceAgent: self.id,
        targetAgent: parentId,
        payload: question,
        priority: 1
    ))

    // Block waiting for answer
    let answer = try await tupleSpace.rd(
        .matching(
            \.signalType, .equals(.answer),
            \.targetAgent, .equals(self.id)
        )
    )

    return answer.payload
}

// Parent agent (or Jake) monitors
func monitorQuestions() async {
    while true {
        let question = try await tupleSpace.in(
            .matching(
                \.signalType, .equals(.question),
                \.targetAgent, .equals(self.id)
            )
        )

        let answer = await getAnswer(question)

        try await tupleSpace.out(SignalTuple(
            signalType: .answer,
            sourceAgent: self.id,
            targetAgent: question.sourceAgent,
            payload: answer
        ))
    }
}
```


## Trade-offs Analysis


### Strengths for Tavern

**Perfect Fit for Work Queues**

The PRD explicitly mentions work queues: "Parents create them, agents attach at spawn or mid-task." This is exactly what tuple space excels at. The `in` operation provides atomic claiming -- no two agents can accidentally grab the same task.

Current `AgentSpawner.spawn(assignment:)` could internally `out()` a task tuple, with the spawned agent's main loop doing `in()` to claim work.

**Natural Resource Management**

The PRD mentions:
- "Token budget" for agents
- "Merge queue for coordinated changesets"
- Rate limiting concerns (throttle time in metrics)

All of these are resource scarcity problems where tuple space tokens shine. An API quota becomes a pool of tokens; agents `in()` a token before making calls, `out()` when done.

**Temporal Decoupling Enables Perseverance Mode**

The PRD's "perseverance mode" has agents continue working while user is away. Tuple space naturally supports this: tasks deposited persist until claimed, results persist until read. No need for both parties to be present.

**Clean Agent Independence**

Current agents are independent (no parent-child relationships in code). Tuple space maintains this independence while adding coordination. Agents don't know about each other; they know about tuple patterns.


### Challenges for Tavern

**Not Ideal for Conversations**

The PRD emphasizes chat: "User can engage with any agent at any depth." Multi-turn conversation doesn't map cleanly to tuples. Options:
- Treat each turn as a tuple (awkward, loses context)
- Use tuple space only for coordination, not conversation (hybrid)
- Model conversation as a series of claim/response cycles

Recommendation: Keep `ChatViewModel` and `send()` for conversation; use tuple space for task coordination.

**Discovery Sharing is Awkward**

The PRD wants agents to "notice oddities and share them via messaging." Blackboard handles this naturally (write to observations region). Tuple space equivalent:
- `out(SignalTuple(signalType: .discovery, ...))` -- but who consumes it?
- Multiple agents might want to see the same discovery (but `in` removes it)
- Could use `rd` but then discoveries accumulate forever

Recommendation: Discoveries could be "broadcasted" tuples that self-expire, or use a separate Blackboard-style region for shared observations.

**Limited Query Expressiveness**

Tuple pattern matching is structural. "Find all high-priority tasks from the last hour" requires:
- Index by priority AND timestamp
- Or scan all task tuples

SQL-style queries are more expressive. Mitigation: careful index design, or hybrid with query layer.

**Tuple Cleanup**

Unlike Blackboard where stale data can be explicitly deleted, tuple space tends to accumulate:
- Results that were never read
- Expired resource tokens
- Old signals

Need garbage collection: background task that removes tuples past TTL.


### Performance Considerations

**Pattern Matching Cost:**
- Naive: O(n) scan of all tuples
- With indexes: O(1) for exact match, O(k) for partial
- Blocking operations: O(waiters) to check when new tuple arrives

**Contention:**
- High contention on popular patterns (e.g., "any pending task") can cause thundering herd
- Mitigation: randomized backoff, local caching, tuple partitioning

**Persistence Overhead:**
- Write-ahead logging adds latency to `out()`
- Snapshot frequency trades durability vs. recovery time

Recommendation: Start with in-memory + periodic snapshot; add WAL if durability issues emerge.


## Implementation Complexity


### Phase 1: Core Tuple Space (Medium complexity)

Implement the basic tuple space abstraction:

```swift
actor TupleStore: TupleSpace {
    // Storage
    private var tuples: [UUID: any TavernTuple] = [:]

    // Indexes (for fast pattern matching)
    private var tasksByStatus: [TaskStatus: Set<UUID>] = [:]
    private var resultsByTaskId: [String: Set<UUID>] = [:]

    // Waiters for blocking operations
    private var waiters: [(UUID, any TuplePattern, CheckedContinuation<any TavernTuple, Error>)] = []

    func out<T: TavernTuple>(_ tuple: T) async throws {
        let id = UUID()
        tuples[id] = tuple
        updateIndexes(id, tuple)

        // Check if any waiter matches
        for (waiterId, pattern, continuation) in waiters {
            if pattern.matches(tuple) {
                waiters.removeAll { $0.0 == waiterId }
                if pattern.consumesOnMatch {
                    tuples.removeValue(forKey: id)
                    removeFromIndexes(id, tuple)
                }
                continuation.resume(returning: tuple)
                return
            }
        }
    }

    func `in`<T: TavernTuple>(_ pattern: TuplePattern<T>) async throws -> T {
        // Check existing tuples
        if let match = findMatch(pattern) {
            tuples.removeValue(forKey: match.0)
            removeFromIndexes(match.0, match.1)
            return match.1 as! T
        }

        // Block until match arrives
        return try await withCheckedThrowingContinuation { continuation in
            let waiterId = UUID()
            waiters.append((waiterId, pattern, continuation))
        }
    }

    // Similar for rd, inp, rdp...
}
```

Estimated effort: 2-3 weeks


### Phase 2: Persistence Layer (Medium complexity)

Add durability to tuple space:

```swift
struct PersistentTupleStore: TupleSpace {
    let memoryStore: TupleStore
    let persistence: TuplePersistence

    func out<T: TavernTuple>(_ tuple: T) async throws {
        // Write to WAL first
        try await persistence.logOut(tuple)

        // Then to memory
        try await memoryStore.out(tuple)
    }

    func `in`<T: TavernTuple>(_ pattern: TuplePattern<T>) async throws -> T {
        let tuple = try await memoryStore.in(pattern)

        // Log the take
        try await persistence.logIn(tuple)

        return tuple
    }
}

struct TuplePersistence {
    let walPath: URL
    let snapshotPath: URL

    func logOut(_ tuple: any TavernTuple) async throws { ... }
    func logIn(_ tuple: any TavernTuple) async throws { ... }
    func snapshot(_ tuples: [any TavernTuple]) async throws { ... }
    func recover() async throws -> [any TavernTuple] { ... }
}
```

Estimated effort: 1-2 weeks


### Phase 3: Agent Integration (Medium complexity)

Refactor agents to use tuple space:

```swift
class TupleSpaceAgent: Agent {
    let tupleSpace: TupleSpace
    let workPattern: TuplePattern<TaskTuple>

    func run() async {
        while state != .done {
            // Block until work is available
            let task = try await tupleSpace.in(workPattern)

            // Claim and execute
            try await claimAndExecute(task)
        }
    }
}

// Spawner integration
class AgentSpawner {
    let tupleSpace: TupleSpace

    func spawn(assignment: String) throws -> MortalAgent {
        // Create task tuple
        let task = TaskTuple(...)
        Task { try await tupleSpace.out(task) }

        // Create agent that will claim it
        let agent = TupleSpaceAgent(
            tupleSpace: tupleSpace,
            workPattern: .matching(\.id, .equals(task.id))
        )

        return agent
    }
}
```

Estimated effort: 2-3 weeks


### Phase 4: Monitoring & Cleanup (Low complexity)

Add observability and garbage collection:

```swift
actor TupleSpaceMonitor {
    let tupleSpace: TupleSpace

    func metrics() async -> TupleSpaceMetrics {
        TupleSpaceMetrics(
            totalTuples: await tupleSpace.count(),
            byType: await tupleSpace.countByType(),
            pendingWaiters: await tupleSpace.waiterCount(),
            oldestTuple: await tupleSpace.oldestTimestamp()
        )
    }

    func cleanup(olderThan: Date) async throws -> Int {
        // Remove expired tuples
        try await tupleSpace.removeWhere { $0.createdAt < olderThan }
    }
}
```

Estimated effort: 1 week


### Total Estimated Effort

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Core Tuple Space | 2-3 weeks | None |
| Persistence Layer | 1-2 weeks | Core |
| Agent Integration | 2-3 weeks | Core |
| Monitoring & Cleanup | 1 week | Core |
| Integration Testing | 1-2 weeks | All |

**Total: 7-11 weeks** for complete implementation.


## Migration Path from Current State


### Step 1: Introduce TupleSpace Protocol

Add tuple space alongside existing coordination:

```swift
// New files
Sources/TavernCore/Coordination/TupleSpace/
├── TupleSpace.swift        // Protocol
├── TavernTuple.swift       // Base types
├── TupleStore.swift        // In-memory implementation
├── TuplePattern.swift      // Pattern matching
└── TaskTuple.swift         // Task-specific tuple
```

No changes to existing code; pure addition.


### Step 2: Add Tuple Space to Coordinator

Inject tuple space into `TavernCoordinator`:

```swift
@MainActor
public final class TavernCoordinator: ObservableObject {
    // Existing
    public let jake: Jake
    public let spawner: AgentSpawner

    // New
    public let tupleSpace: TupleSpace

    public init(jake: Jake, spawner: AgentSpawner, tupleSpace: TupleSpace) {
        // ...
    }
}
```

Backward compatible: existing code continues to work.


### Step 3: Migrate Work Queues

If/when work queues are implemented (PRD mentions but not in v1), use tuple space:

```swift
// Instead of:
class WorkQueue {
    private var items: [WorkItem] = []
    func push(_ item: WorkItem) { ... }
    func pop() -> WorkItem? { ... }
}

// Use:
extension TupleSpace {
    func pushWork(_ item: WorkItem) async throws {
        try await out(WorkTuple(item: item))
    }

    func popWork() async throws -> WorkItem {
        let tuple = try await `in`(.matching(\.status, .equals(.pending)))
        return tuple.item
    }
}
```

Work queues become tuple space patterns.


### Step 4: Optional Agent Migration

Agents can optionally adopt tuple-based coordination:

```swift
protocol TupleAwareAgent: Agent {
    var tupleSpace: TupleSpace { get }
    var workPattern: TuplePattern<TaskTuple> { get }
}

// Existing MortalAgent continues to work
// New TupleSpaceAgent uses tuple-based coordination
```

Gradual migration; no big bang required.


### Backward Compatibility

The tuple space sits alongside existing infrastructure:
- `AgentRegistry` continues tracking agents
- `SessionStore` continues handling sessions
- `ChatViewModel` continues managing conversations
- Tuple space adds a new coordination layer

Migration is additive, not replacement.


## Open Questions


### Tuple Type System

How strongly typed should tuples be?

Options:
1. **Fully typed** -- `TaskTuple`, `ResultTuple`, etc. as concrete types
2. **Partially typed** -- Enum wrapper with associated values
3. **Dynamic** -- `[String: Any]` dictionaries

Recommendation: Fully typed for safety, with a `DynamicTuple` escape hatch for extensibility.


### Pattern Matching Syntax

How should patterns be expressed?

Options:
1. **KeyPath-based** -- `.matching(\.status, .equals(.pending))`
2. **Builder DSL** -- `Pattern.task.where(.status == .pending)`
3. **SQL-like** -- `"SELECT * FROM tuples WHERE status = 'pending'"`

Recommendation: KeyPath-based for type safety and Swift idiomaticity.


### Blocking Semantics

How long should `in`/`rd` block?

Options:
1. **Forever** -- Classic Linda semantics
2. **Timeout** -- Return nil or throw after duration
3. **Configurable** -- Caller specifies timeout

Recommendation: Configurable with sensible defaults. Forever-blocking is dangerous in practice.


### Tuple Lifetime

How long do tuples live?

Options:
1. **Until consumed** -- Classic Linda
2. **TTL-based** -- Expire after duration
3. **Explicit** -- Caller specifies lifetime

Recommendation: TTL-based with default of 24 hours; important tuples get longer TTL.


### Distribution

Should tuple space be local or distributed?

The PRD says: "Distributed/replicated doc store (single machine first)" -- explicitly deferred.

Recommendation: Local-only for v1. Design API to allow future distribution without breaking changes.


### Relationship to DocStore

Should tuple space replace DocStore, extend it, or run alongside?

Options:
1. **Replace** -- Tuples become the only persistence
2. **Extend** -- DocStore provides tuple persistence backend
3. **Alongside** -- Separate systems for different purposes

Recommendation: Alongside for v1. DocStore handles documents (specs, code, artifacts); tuple space handles coordination (tasks, signals, resources). They serve different purposes.


## Comparison to Alternative Architectures


### vs. Blackboard (#6)

| Aspect | Tuple Space | Blackboard |
|--------|-------------|------------|
| Sharing model | Consume (take) | Observe (read) |
| Ownership | Exclusive | Shared |
| Collaboration | Low | High |
| Work distribution | Excellent | Moderate |
| Discovery sharing | Awkward | Natural |
| Complexity | Lower | Higher |

Use Tuple Space for work distribution; Blackboard for collaborative refinement.


### vs. Actor Model (#2)

| Aspect | Tuple Space | Actor Model |
|--------|-------------|-------------|
| Addressing | Anonymous (pattern) | Named (actor ID) |
| Coupling | Very low | Low |
| Message retention | Tuples persist | Mailbox buffers |
| Synchronization | Blocking reads | Async only |

Tuple Space is more decoupled; Actor Model is more direct.


### vs. Message Bus (#15)

| Aspect | Tuple Space | Message Bus |
|--------|-------------|-------------|
| Addressing | Pattern matching | Topic/channel |
| Delivery | Pull (blocking read) | Push (publish) |
| Persistence | Native | Optional |
| Ordering | Unordered | Topic-ordered |

Tuple Space is pull-based with persistence; Message Bus is push-based and ephemeral.


### vs. Work-Stealing Pool (#8)

| Aspect | Tuple Space | Work-Stealing |
|--------|-------------|---------------|
| Claiming | Explicit `in()` | Implicit steal |
| Locality | No affinity | Locality-aware |
| Overhead | Pattern matching | Queue operations |
| Flexibility | High (patterns) | Low (FIFO) |

Tuple Space is more flexible; Work-Stealing is more efficient for homogeneous work.


## Conclusion

The Tuple Space architecture offers a compelling coordination model for Tavern's multi-agent system, particularly for work distribution, resource management, and temporal decoupling. Its core strength -- atomic claiming via pattern matching -- directly addresses the PRD's work queue and merge queue requirements.

However, Tuple Space is less suited for collaborative editing and discovery sharing, which are also PRD priorities. A pure Tuple Space implementation would need awkward workarounds for these use cases.

**Recommendation:** Consider Tuple Space as a component within a hybrid architecture. Use it for:
- Task distribution and work queues
- Resource token management (API quota, merge slots)
- Temporal coordination (perseverance mode)

Combine with Blackboard-style regions for:
- Collaborative artifact refinement
- Discovery sharing
- Shared observations

This hybrid would capture Tuple Space's strengths while mitigating its weaknesses. The implementation complexity is moderate (7-11 weeks), and the migration path from current state is incremental and non-breaking.

**Key insight:** The Linda model's formal semantics provide provable properties (no duplicate claiming, guaranteed eventual consumption) that are valuable for work coordination but overkill for casual information sharing. Match the model to the use case.
