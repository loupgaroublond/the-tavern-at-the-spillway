# Event-Sourced Architecture: Complete Analysis

This document contains the full research, analysis, and trade-off considerations for adopting an event-sourced architecture in Tavern.


## Research Findings


### Current State Management Patterns

The codebase currently uses several state management approaches:

**Agent State (Mutable Properties with DispatchQueue)**

Each agent (`Jake`, `MortalAgent`) maintains mutable state protected by a serial `DispatchQueue`:

```swift
// Jake.swift
private let queue = DispatchQueue(label: "com.tavern.Jake")
private var _sessionId: String?
private var _projectPath: String?
private var _isCogitating: Bool = false
```

State transitions happen directly via property mutation. There is no history of how the agent arrived at its current state.


**AgentState Enum**

The `AgentState` enum defines the lifecycle: `idle`, `working`, `waiting`, `verifying`, `done`. Transitions are implicit in the agent methods (`send()` sets working, response handling may set waiting/done).


**Session Persistence (UserDefaults)**

`SessionStore` persists session IDs to UserDefaults with path-encoded keys:

```swift
// SessionStore.swift
private static let jakeSessionPrefix = "com.tavern.jake.session."
defaults.set(id, forKey: key)
```

This stores only the current session ID per project. If the session becomes corrupt, there is no history to recover from.


**ChatViewModel (In-Memory Array)**

Messages live in an in-memory array:

```swift
// ChatViewModel.swift
@Published public private(set) var messages: [ChatMessage] = []
```

History is loaded from Claude's native storage (`ClaudeNativeSessionStorage`) at startup, but in-app changes are not persisted separately. The app depends on the Claude CLI's JSONL files for history.


**DocStore (File-Based Documents)**

The `DocStore` implements CRUD on markdown files with YAML frontmatter:

```swift
// DocStore.swift
public func update(_ document: Document) throws {
    var updatedDoc = document
    updatedDoc.updatedAt = Date()
    // ... write to file
}
```

Updates overwrite the file. No versioning, no history.


**Commitment Status**

Commitments have a status enum (`pending`, `verifying`, `passed`, `failed`) with direct mutation:

```swift
// Commitment.swift
public mutating func markPassed() {
    status = .passed
    updatedAt = Date()
}
```

The `updatedAt` timestamp provides minimal history, but the previous status is lost.


### Key Observations

1. **State is mutable everywhere** - No event log, no history of transitions

2. **No undo capability** - Once state changes, previous state is gone

3. **Debugging requires reproduction** - Cannot replay sequence that led to a bug

4. **Concurrent modification risks** - DispatchQueue serialization prevents races but doesn't resolve conflicts

5. **Session recovery is binary** - Either session works or it's corrupt; no partial recovery

6. **Chat history depends on external system** - Claude CLI's storage is the de facto event log for messages


## How Event Sourcing Enables Rewind/Branch

The PRD (Section 13) describes Rewind and Branch as:

> General capability to checkpoint, tweak prompt, fork new timeline. Works at both agent and changeset level.


### The Fundamental Insight

Event sourcing makes rewind and branch trivial because state is already derived from history. To rewind:

1. Take the event log up to checkpoint time T
2. Replay events to rebuild state at T
3. Optionally create a new branch from T

No special "checkpoint" mechanism is needed. The event log is continuous checkpoints.


### Rewind Implementation

```swift
// Conceptual implementation
struct EventStore {
    func replayTo(timestamp: Date) -> ProjectState {
        let events = loadEvents().filter { $0.timestamp <= timestamp }
        return events.reduce(ProjectState.initial) { state, event in
            state.applying(event)
        }
    }
}
```

The user can:
- View state at any historical moment
- Continue from that moment (creating a branch)
- Compare states across time


### Branch Implementation

Branches are projections that diverge from a common ancestor:

```swift
struct Branch {
    let id: UUID
    let parentBranchId: UUID?
    let forkPoint: EventSequenceNumber
    let events: [Event]  // Events on this branch after fork
}
```

To branch:
1. Record the fork point (event sequence number or timestamp)
2. New events append to the branch's event stream
3. Each branch maintains its own projection


### Agent-Level Rewind

For a single agent, rewind means:
- Replay agent events up to a checkpoint
- Allow user to provide different input
- Continue from there (new events on a branch)

This is valuable when an agent goes down a wrong path. Instead of "fish or cut bait" (kill and restart), the user can rewind to before the mistake and steer differently.


### Changeset-Level Rewind

For changesets (file modifications), rewind means:
- Replay file events up to a checkpoint
- Discard events after that point (or branch)
- Files return to their checkpoint state

This is the overlay filesystem behavior described in the PRD, but with history.


## Mapping to PRD Requirements

| PRD Requirement | Event Sourcing Support |
|-----------------|----------------------|
| **Section 2: Doc store is source of truth** | Event store becomes the source of truth; doc store is a projection |
| **Section 2: If it's not in a file, it doesn't exist** | Events can be stored as JSONL files (append-only) |
| **Section 4.2: Agent States** | AgentStateChanged events track all transitions with history |
| **Section 4.5: The Document Store** | Documents become event streams; CRUD becomes events |
| **Section 4.7: Commitment flow** | CommitmentAdded, CommitmentVerified events capture full lifecycle |
| **Section 5.2: Attention Model** | UserFocusChanged, AgentPinged events enable attention analytics |
| **Section 9: Metrics** | Events naturally support time-based metrics (token time, tool time) |
| **Section 12: Fish or Cut Bait** | Rewind/branch provides alternative to killing agents |
| **Section 13: Rewind and Branch** | Core capability of event sourcing |
| **Section 16: Violation Monitoring** | ViolationDetected events with full context |
| **Section 19.1: Logging Standards** | Events provide structured logs by design |


### Specific PRD Alignments


**Invariant 3: Commitments must be verified independently**

Event sourcing enhances this by recording the full verification sequence:

```
CommitmentAdded { agentId, description, assertion }
CommitmentVerificationStarted { commitmentId }
CommitmentVerificationCompleted { commitmentId, passed: true, output }
```

Each step is independently verifiable from the event log.


**Invariant 5: Doc store is source of truth**

The event store becomes the source of truth. Documents and current state are projections:

```
DocumentCreated { docId, content }
DocumentUpdated { docId, changes }
DocumentDeleted { docId }
```

Current document state is derived by replaying DocumentCreated + all DocumentUpdated events.


**Invariant 7: Failures must be visible**

Events naturally capture failures:

```
AgentSendFailed { agentId, error, prompt }
CommitmentVerificationFailed { commitmentId, output }
SessionCorruptDetected { sessionId, reason }
```

These events are persisted and queryable, not just logged.


## Event Schema Design


### Core Event Types

```swift
// Base event protocol
protocol TavernEvent: Codable {
    var id: UUID { get }
    var timestamp: Date { get }
    var version: Int { get }  // For schema evolution
}

// Agent lifecycle events
struct AgentSpawned: TavernEvent {
    let agentId: UUID
    let name: String
    let assignment: String
    let parentId: UUID?  // Jake's ID or parent agent
}

struct AgentStateChanged: TavernEvent {
    let agentId: UUID
    let previousState: AgentState
    let newState: AgentState
    let trigger: String  // What caused the change
}

struct AgentDismissed: TavernEvent {
    let agentId: UUID
    let reason: String
}

// Communication events
struct MessageSent: TavernEvent {
    let agentId: UUID
    let role: ChatMessage.Role
    let content: String
    let sessionId: String?
}

struct MessageReceived: TavernEvent {
    let agentId: UUID
    let content: String
    let sessionId: String
    let contentBlocks: [ContentBlock]  // Rich content
}

// Commitment events
struct CommitmentAdded: TavernEvent {
    let commitmentId: UUID
    let agentId: UUID
    let description: String
    let assertion: String
}

struct CommitmentVerified: TavernEvent {
    let commitmentId: UUID
    let passed: Bool
    let output: String
}

// Document events
struct DocumentCreated: TavernEvent {
    let documentId: String
    let title: String?
    let content: String
    let frontmatter: [String: String]
}

struct DocumentUpdated: TavernEvent {
    let documentId: String
    let changes: [DocumentChange]  // Diff-based
}

// Coordination events
struct AgentSelected: TavernEvent {
    let agentId: UUID
    let previousAgentId: UUID?
}

struct ProjectOpened: TavernEvent {
    let projectPath: String
}
```


### Event Storage Format

Events can be stored as JSONL (one JSON object per line), matching the existing Claude CLI storage pattern:

```
{"type":"AgentSpawned","id":"...","timestamp":"...","agentId":"...","name":"Gandalf",...}
{"type":"AgentStateChanged","id":"...","timestamp":"...","agentId":"...","newState":"working",...}
{"type":"MessageSent","id":"...","timestamp":"...","agentId":"...","content":"Hello",...}
```

Benefits:
- Append-only (no locking for writes)
- Human-readable
- Streamable
- Compatible with existing session storage patterns


## Trade-offs Considered


### Complexity vs. Capability

**The cost:**
- Event/command separation requires more code
- Projectors must be maintained alongside events
- Eventually consistent reads require careful UI design
- Schema evolution needs upfront planning

**The payoff:**
- Rewind/branch "for free" once events exist
- Complete audit trail enables debugging
- Temporal queries enable analytics
- Event-driven architecture aligns with SwiftUI reactivity


### Storage Growth

Events accumulate indefinitely. Mitigation strategies:

1. **Snapshots** - Periodically save projected state as a checkpoint
2. **Compaction** - Merge old events into summary events
3. **Archival** - Move old events to cold storage
4. **Per-agent streams** - Limit growth to active agent's lifetime

Example snapshot strategy:
```swift
// Every 1000 events or daily, save snapshot
struct Snapshot {
    let sequenceNumber: UInt64
    let timestamp: Date
    let state: ProjectState
}

// Replay: load snapshot, replay only events after snapshot
func replayFrom(snapshot: Snapshot, events: [Event]) -> ProjectState
```


### Schema Evolution

Events must remain readable forever. Strategies:

1. **Version field** - Each event has a version number
2. **Upcasters** - Transform old event versions to current
3. **Event wrappers** - New fields are optional with defaults

```swift
// v1 event
struct AgentSpawned_v1 {
    let agentId: UUID
    let name: String
}

// v2 adds assignment field
struct AgentSpawned_v2 {
    let agentId: UUID
    let name: String
    let assignment: String?  // Optional for v1 compatibility
}

// Upcaster
func upcast(_ event: AgentSpawned_v1) -> AgentSpawned_v2 {
    AgentSpawned_v2(
        agentId: event.agentId,
        name: event.name,
        assignment: nil  // Unknown for v1
    )
}
```


### Eventual Consistency

Projections may lag behind events. This affects:

1. **UI responsiveness** - User sees stale state briefly
2. **Read-your-writes** - After writing event, immediate read may not reflect it

Mitigations:
- Synchronous projections for critical paths
- Optimistic UI updates before event confirmation
- Version vectors to detect stale reads


## Implementation Complexity


### Phase 1: Event Infrastructure (2-3 weeks)

1. Define core event protocol and base types
2. Implement JSONL event store (append-only)
3. Create simple projector framework
4. Migrate one component (e.g., agent state) as proof of concept


### Phase 2: Agent Events (2-3 weeks)

1. Define all agent lifecycle events
2. Implement agent state projector
3. Migrate `Jake` and `MortalAgent` to emit events
4. Update `TavernCoordinator` to use projections


### Phase 3: Message Events (2 weeks)

1. Define message events (sent, received, content blocks)
2. Implement message history projector
3. Migrate `ChatViewModel` to event-driven
4. Integrate with Claude CLI's existing JSONL storage


### Phase 4: Rewind/Branch (3-4 weeks)

1. Implement branch data structure
2. Add checkpoint/fork API
3. Build rewind UI
4. Implement branch switching


### Phase 5: Optimization (ongoing)

1. Snapshot strategy
2. Compaction rules
3. Cold storage archival
4. Performance tuning


### Total Estimate: 10-14 weeks

This is significant investment. However, much of the infrastructure (event store, projectors) is reusable across all domain areas.


## Migration Path from Current State


### Step 1: Dual-Write Period

Keep existing state management, add event emission:

```swift
// In Jake.send()
queue.sync { _isCogitating = true }
eventStore.append(AgentStateChanged(
    agentId: id,
    previousState: .idle,
    newState: .working
))
```

Both systems maintain state. Events are audit trail.


### Step 2: Projection Verification

Build projectors that reconstruct state from events. Verify projection matches direct state:

```swift
let directState = jake.state
let projectedState = projector.currentState(for: jake.id)
assert(directState == projectedState)
```

Run in test/debug mode to catch discrepancies.


### Step 3: Read from Projections

Switch reads to use projections:

```swift
// Before
public var state: AgentState {
    queue.sync { _state }
}

// After
public var state: AgentState {
    projector.currentState(for: id)
}
```

Keep direct state as fallback.


### Step 4: Remove Direct State

Once projections are verified, remove mutable state:

```swift
// Remove
private var _state: AgentState = .idle

// Keep only
private let projector: AgentStateProjector
```


### Risks and Mitigations

**Risk:** Event/projection desync during migration
**Mitigation:** Comprehensive assertions, gradual rollout per component

**Risk:** Performance regression from projection overhead
**Mitigation:** In-memory caching of projections, lazy rebuilding

**Risk:** Schema locked in prematurely
**Mitigation:** Start with coarse-grained events, refine based on actual queries needed


## Open Questions


### Event Granularity

How fine-grained should events be?

- **Coarse:** `AgentUpdated { agentId, fields: [String: Any] }`
- **Fine:** Separate event per field: `AgentNameChanged`, `AgentStateChanged`

Fine-grained is more queryable but more events. Start coarse, refine based on actual query patterns.


### Event Store Location

Where do events live?

- **Option A:** Dedicated event store directory (e.g., `~/.tavern/events/`)
- **Option B:** Alongside doc store (events as special documents)
- **Option C:** Per-project event streams

Recommendation: Option C, matching Claude CLI's per-project session storage.


### Relationship to Claude CLI Storage

Claude CLI already stores session history as JSONL. Options:

- **Wrap it:** Treat Claude's storage as the source of message events
- **Mirror it:** Copy messages into Tavern's event store
- **Replace it:** Use Tavern events exclusively (requires ClaudeCodeSDK changes)

Recommendation: Wrap initially, consider replace long-term.


### Snapshot Frequency

How often to snapshot?

- Time-based: Every hour, daily
- Count-based: Every N events
- Size-based: When event log exceeds M bytes

Depends on startup time requirements. Profile once implemented.


### Branch UI/UX

How does the user interact with branches?

- Git-style checkout/merge?
- Timeline visualization with fork points?
- Automatic branch on any rewind?

Design decision deferred until core event infrastructure exists.


## Conclusion

Event sourcing is a natural fit for Tavern's requirements:

1. **Rewind/Branch** is a core PRD feature that event sourcing provides "for free"
2. **Audit trail** aligns with invariants about visibility and verification
3. **SwiftUI reactivity** aligns with event-driven projections
4. **Claude CLI storage** already follows event patterns (JSONL session logs)

The main costs are implementation complexity and the learning curve. However, the architecture provides a solid foundation for features beyond rewind/branch: analytics, debugging, conflict resolution, and temporal queries.

Recommendation: Adopt event sourcing if rewind/branch is a must-have feature. The investment pays off through multiple capabilities enabled by the same infrastructure.
