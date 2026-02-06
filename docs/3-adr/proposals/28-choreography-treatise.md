# Choreography Architecture: Complete Analysis

This document contains the full research, analysis, and trade-off considerations for adopting a choreography architecture in Tavern.


## Research Findings


### Current Orchestration Patterns

The codebase implements a classic orchestration pattern with explicit central coordination.


**TavernCoordinator as Central Hub**

The `TavernCoordinator` is the system's conductor:

```swift
// TavernCoordinator.swift
@MainActor
public final class TavernCoordinator: ObservableObject {
    public let jake: Jake
    public let spawner: AgentSpawner
    private var chatViewModels: [UUID: ChatViewModel] = [:]

    public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
        let agent = try spawner.spawn(assignment: assignment)
        agentListViewModel.cacheAssignment(agentId: agent.id, assignment: assignment)
        agentListViewModel.agentsDidChange()
        if selectAfterSpawn {
            selectAgent(id: agent.id)
        }
        return agent
    }
}
```

The coordinator knows about all agents, manages their lifecycle, tracks selection state, and orchestrates UI updates. It is the single point through which all agent-related actions flow.


**Jake as Top-Level Director**

Jake's role as described in the system prompt establishes hierarchical authority:

```swift
// Jake.swift
public static let systemPrompt = """
    You are Jake, The Proprietor of The Tavern at the Spillway.
    ...
    You run a multi-agent orchestration system. Your worker agents are "the Slop Squad."
    ...
"""
```

Jake is explicitly positioned as the one who "runs" the system. Worker agents are "his" - they work for him, not alongside him.


**AgentSpawner as Factory Under Control**

Agents are created through a controlled factory:

```swift
// AgentSpawner.swift
public func spawn(assignment: String) throws -> MortalAgent {
    let name = nameGenerator.nextNameOrFallback()
    let claude = claudeFactory()
    let agent = MortalAgent(name: name, assignment: assignment, claude: claude)
    try registry.register(agent)
    return agent
}
```

The spawner is owned by the coordinator. Agents cannot spawn other agents directly - they must go through the hierarchical chain.


**No Inter-Agent Communication**

Currently, agents have no way to communicate with each other:

```swift
// MortalAgent.swift
public func send(_ message: String) async throws -> String {
    // Communicates with Claude only
    // No mechanism to message other agents
}
```

The only communication paths are:
- User -> Agent (via ChatViewModel)
- Agent -> Claude API
- Agent -> Parent (not implemented yet)

Agents cannot discover or message siblings.


### Key Observations

1. **Hierarchical control is deeply embedded** - The coordinator/spawner/agent hierarchy is fundamental to the current design

2. **Jake's identity is tied to authority** - His character ("The Proprietor") assumes command-and-control

3. **No event infrastructure exists** - No publish/subscribe, no event bus, no observable document changes

4. **Agents are isolated** - Each agent operates independently with no awareness of siblings

5. **State is centralized** - The coordinator tracks agent list, selection, and view model cache

6. **PRD assumes hierarchy** - Parent-child relationships, bubbling, and oversight all assume hierarchical structure


## How Choreography Would Transform Jake's Role


### From Conductor to First Violin

In orchestration, Jake is the conductor - he tells every agent what to play and when. In choreography, Jake becomes the first violin - the most prominent player who sets the tone, but one of many musicians following a shared score.

**Current Role (Orchestration):**
- Receives user requests
- Decides how to decompose work
- Spawns agents with specific assignments
- Monitors agent progress
- Aggregates results
- Reports to user

**Transformed Role (Choreography):**
- Receives user requests
- Publishes TaskAvailable events describing needed work
- Agents self-select (or are assigned by convention)
- Monitors via event subscription, not direct queries
- Reacts to completion events
- Reports to user when relevant events indicate completion

The key shift: Jake no longer "knows" what agents are doing. He knows what events have occurred. His understanding of system state comes from the same event stream that all agents share.


### Character Implications

Jake's persona as a used-car-salesman carnival barker fits orchestration naturally - he is the showman running the show. Choreography creates tension with this character:

**Compatible aspects:**
- Jake can still be the user-facing personality
- His theatrical commentary can describe observed events ("Well NOW, looks like Gandalf just wrapped up that refactoring SPECTACLE!")
- He remains the entry point for user interaction

**Incompatible aspects:**
- "I run a multi-agent orchestration system" becomes false - he participates in it
- "My Slop Squad" suggests ownership that choreography dissolves
- The "proprietor" metaphor implies control he no longer has

**Possible character evolution:**
- Jake as "town crier" - announcing what's happening rather than directing it
- Jake as "concierge" - helping the user navigate the dance rather than choreographing it
- Jake as "impresario" - the face of the show even if he doesn't control every act


### Practical Jake Changes

```swift
// Current: Jake spawns and tracks
class Jake {
    func handleUserRequest(_ request: String) {
        let agent = spawner.spawn(assignment: request)
        trackAgent(agent)
        await monitorProgress(agent)
        reportToUser(agent.result)
    }
}

// Choreography: Jake publishes and reacts
class Jake {
    func handleUserRequest(_ request: String) {
        eventBus.publish(TaskRequested(description: request, priority: .high))
        // Done - Jake doesn't track, spawn, or monitor
        // He reacts when TaskCompleted events arrive
    }

    func onEvent(_ event: TavernEvent) {
        switch event {
        case let completion as TaskCompleted:
            eventBus.publish(UserNotification(
                message: "Gandalf just CRUSHED that \(completion.taskDescription)!"
            ))
        case let question as QuestionRaised:
            bubbleToUser(question)
        }
    }
}
```


## Mapping to PRD Requirements


### PRD Section 2: Invariants

| Invariant | Choreography Impact |
|-----------|---------------------|
| **Test suite must pass** | No change - choreography is testable via event assertions |
| **Every feature must be testable** | Event-driven systems are highly testable |
| **Commitments verified independently** | Challenge: who verifies? Events can include verification results |
| **User attention is sacred** | Events enable attention management - user subscribes to relevant streams |
| **Doc store is source of truth** | Doc store becomes event store; events are documents |
| **Agents cannot modify their own invariants** | Event schemas define invariants; agents can only publish conforming events |
| **Failures must be visible** | FailureOccurred events make failures first-class |
| **Original project files protected** | Unchanged - choreography doesn't affect file safety |


### PRD Section 4.1: Agent Types

| Agent Type | Orchestration Role | Choreography Role |
|------------|-------------------|-------------------|
| **Jake** | Top-level coordinator, oversees all | First among peers, primary user interface |
| **Mortal** | Handles assignments from Jake | Self-assigns from TaskAvailable events |
| **Drone** | One task then terminate | Subscribes to single event type, publishes completion |
| **Monitor Daemons** | Work for Jake | Independent observers subscribing to health events |

The hierarchical relationships become subscription patterns:
- Jake spawns Mortals -> Jake publishes TaskAvailable, Mortals subscribe
- Drones work for Mortals -> Mortals publish SubtaskAvailable, Drones subscribe
- Monitors report to Jake -> Monitors publish HealthReport, Jake subscribes


### PRD Section 4.2: Agent States

The state machine remains valid but transitions become event-driven:

```
Working -> publishes WorkingOnTask event
Waiting for Input -> publishes QuestionRaised event
Done -> publishes TaskCompleted event
Failed -> publishes TaskFailed event
```

State is derived from events rather than directly mutated:

```swift
// Event-derived state
var state: AgentState {
    guard let lastEvent = eventStore.lastEvent(for: id) else {
        return .idle
    }
    switch lastEvent {
    case is WorkStarted: return .working
    case is QuestionRaised: return .waiting
    case is TaskCompleted: return .done
    case is TaskFailed: return .failed
    default: return .idle
    }
}
```


### PRD Section 4.7: Deterministic Shell and Commitments

This is the hardest PRD requirement to satisfy with pure choreography.

**The Challenge:**

The PRD states: "Child works -> Independent assertion verifies commitments were met -> Only then is agent 'done'."

This implies a supervisor relationship. Someone must:
1. Know what commitments exist
2. Run verification
3. Decide if agent is truly done

**Choreography Approaches:**

**Option A: Self-verification with audit**
```
Agent publishes: CommitmentClaimed { description, assertion, result }
Any interested party (Jake, Monitor) can re-run assertion
Disputes handled via DisputeRaised event
```

Risk: Agent could lie about verification. Trust but verify.

**Option B: Verification agent**
```
Agent publishes: ReadyForVerification { commitments }
VerificationDaemon subscribes, runs checks
VerificationDaemon publishes: VerificationResult { passed/failed }
Agent reacts to VerificationResult
```

This reintroduces hierarchy (verifier has authority) but maintains loose coupling.

**Option C: Community verification**
```
Agent publishes: CommitmentMade { description, assertion }
Agent publishes: WorkCompleted
Multiple observers run verification
Consensus determines truth (majority of verifiers agree)
```

Complex but fully decentralized.

**Recommendation:** Option B - a verification daemon maintains the invariant while preserving choreography's loose coupling for other interactions.


### PRD Section 5.3: Bubbling

The PRD describes bubbling as "context-dependent, based on zoom level and user attention."

**Orchestration approach:** Parent explicitly receives child questions, decides whether to handle or bubble further.

**Choreography approach:** Events have scope tags. Bubbling is subscription with filtering:

```swift
struct QuestionRaised: TavernEvent {
    let agentId: UUID
    let parentId: UUID?
    let depth: Int
    let question: String
    let priority: QuestionPriority
}

// Jake subscribes to questions from his direct children
jake.subscribe(where: { $0.parentId == jake.id })

// User attention manager subscribes to high-priority questions
userAttention.subscribe(where: { $0.priority == .high })

// Parent subscribes to children's questions
mortalAgent.subscribe(where: { $0.parentId == self.id })
```

Bubbling becomes:
1. Child publishes QuestionRaised
2. Parent sees it (if subscribed)
3. Parent can publish ParentHandledQuestion (suppressing further bubbling) or let it continue
4. Eventually reaches Jake or User


### PRD Section 9.3: Discovery Sharing

This is where choreography shines:

> Agents (even drones) prompted to notice oddities and share them via messaging, even while continuing main task.

In choreography, this is natural:

```swift
// Any agent can publish discoveries
eventBus.publish(Discovery(
    source: self.id,
    observation: "Found deprecated API usage in auth module",
    context: currentTaskId
))

// Any agent can subscribe to discoveries
sibling.subscribe(to: Discovery.self) { discovery in
    if relevant(discovery) {
        incorporate(discovery)
    }
}
```

No special "discovery sharing" infrastructure needed - it's just events.


## Trade-offs Considered


### Simplicity vs. Flexibility

**Orchestration simplicity:**
- Clear control flow: Coordinator -> Spawner -> Agent
- Easy to trace: "who told X to do Y" has obvious answer
- Predictable: given inputs, outputs are deterministic

**Choreography flexibility:**
- New agent types just subscribe to existing events
- Coordination patterns can evolve without central changes
- Agents can collaborate in ways not originally designed

For v1 with limited scope, orchestration's simplicity wins. For a mature system with many agent types and collaboration patterns, choreography's flexibility becomes valuable.


### Debugging and Observability

**Orchestration debugging:**
- Follow method calls from coordinator down
- Breakpoints in coordinator show all control flow
- State is visible in coordinator's properties

**Choreography debugging:**
- Must trace event sequences across agents
- Need event visualization tools
- State is distributed across event history

Mitigation: Build event tracing tools. Log all events. Create event replay debugger. The investment is higher but the observability can become superior (complete event history vs. transient state).


### Performance Characteristics

**Orchestration:**
- Direct method calls, minimal overhead
- Synchronous where possible
- Predictable latency

**Choreography:**
- Event serialization/deserialization overhead
- Async event dispatch
- Potential event storms under load

Mitigation: Use in-process events (not serialized) for hot paths. Batch event publication. Implement backpressure.


### Consistency Guarantees

**Orchestration:**
- Coordinator has authoritative state
- "What agents exist?" has single answer
- Operations are serialized through coordinator

**Choreography:**
- State is eventually consistent
- Different observers may see different event prefixes
- Concurrent events may conflict

Mitigation: Use event ordering (sequence numbers). Implement conflict resolution protocols. Accept eventual consistency for non-critical state.


## Implementation Complexity


### Phase 1: Event Infrastructure (3-4 weeks)

1. Define TavernEvent protocol
2. Implement in-memory event bus with pub/sub
3. Create event persistence (JSONL in doc store)
4. Build event replay for debugging

```swift
protocol TavernEvent: Codable, Identifiable {
    var id: UUID { get }
    var timestamp: Date { get }
    var sourceAgentId: UUID { get }
}

class TavernEventBus {
    func publish<E: TavernEvent>(_ event: E)
    func subscribe<E: TavernEvent>(to: E.Type, handler: @escaping (E) -> Void) -> Subscription
    func history<E: TavernEvent>(of: E.Type) -> [E]
}
```


### Phase 2: Agent Event Protocols (2-3 weeks)

Define the event vocabulary:

```swift
// Lifecycle events
struct AgentSpawned: TavernEvent { ... }
struct AgentDismissed: TavernEvent { ... }

// Task events
struct TaskRequested: TavernEvent { ... }
struct TaskClaimed: TavernEvent { ... }
struct TaskCompleted: TavernEvent { ... }
struct TaskFailed: TavernEvent { ... }

// Communication events
struct QuestionRaised: TavernEvent { ... }
struct AnswerProvided: TavernEvent { ... }
struct Discovery: TavernEvent { ... }

// Commitment events
struct CommitmentMade: TavernEvent { ... }
struct CommitmentVerified: TavernEvent { ... }
```


### Phase 3: Migrate Jake (2-3 weeks)

Transform Jake from controller to participant:

1. Jake publishes events instead of calling spawner directly
2. Jake subscribes to completion/question events
3. Jake's state derived from events, not properties
4. AgentSpawner becomes event-reactive (spawns on TaskRequested if no agent claims)


### Phase 4: Migrate MortalAgent (2-3 weeks)

1. Agents subscribe to TaskRequested/TaskAssigned
2. Agents publish TaskCompleted/QuestionRaised
3. Agents can discover siblings via AgentSpawned events
4. Inter-agent messaging via Discovery events


### Phase 5: Verification Daemon (2 weeks)

Implement commitment verification as a daemon:

1. Subscribes to CommitmentMade events
2. Subscribes to WorkCompleted events
3. Runs verification assertions
4. Publishes VerificationResult events


### Phase 6: UI Event Integration (2-3 weeks)

1. ChatViewModel subscribes to agent events
2. AgentListViewModel subscribes to lifecycle events
3. Event-driven state replaces direct property observation
4. Event history enables UI replay


### Total Estimate: 13-18 weeks

This is substantial investment, more than event sourcing alone because it requires rethinking coordination patterns, not just persistence.


## Migration Path from Current State


### Step 1: Add Event Bus (Parallel Infrastructure)

Keep existing coordinator. Add event bus. Publish events alongside existing control flow:

```swift
// In TavernCoordinator.spawnAgent
let agent = try spawner.spawn(assignment: assignment)
eventBus.publish(AgentSpawned(agentId: agent.id, name: agent.name))
// Continue with existing logic
```

Events are informational. Control flow unchanged.


### Step 2: Subscribe for Observation

Add subscriptions that observe but don't control:

```swift
// AgentListViewModel subscribes for consistency checks
eventBus.subscribe(to: AgentSpawned.self) { event in
    assert(self.agents.contains { $0.id == event.agentId })
}
```

Verify events match existing state.


### Step 3: Introduce Task Events

Add TaskRequested/TaskCompleted events. Initially, these mirror existing spawning:

```swift
// User request triggers event
eventBus.publish(TaskRequested(description: userMessage))

// Coordinator still handles directly, but also publishes
let agent = try spawner.spawn(assignment: userMessage)
eventBus.publish(TaskClaimed(taskId: taskId, agentId: agent.id))
```


### Step 4: Event-Driven Agent Selection

New agents can claim tasks via events rather than being assigned:

```swift
// New pattern: Agent self-selects
class SelfSelectingAgent {
    init(eventBus: TavernEventBus) {
        eventBus.subscribe(to: TaskRequested.self) { task in
            if self.canHandle(task) && !task.claimed {
                eventBus.publish(TaskClaimed(taskId: task.id, agentId: self.id))
                self.work(on: task)
            }
        }
    }
}
```


### Step 5: Coordinator Retreat

Gradually remove coordinator responsibilities:

1. Agent list derived from AgentSpawned/AgentDismissed events
2. Selection state derived from AgentSelected events
3. Task tracking derived from TaskRequested/TaskCompleted events

Coordinator becomes thin shell that publishes user events and subscribes to UI-relevant events.


### Step 6: Jake Transformation

Final step: Jake becomes event-driven:

1. Remove Jake's spawning logic
2. Jake publishes TaskRequested, subscribes to results
3. Jake's character remains; implementation changes


### Rollback Strategy

At each step, the old path remains functional. If choreography causes issues:

1. Disable event subscriptions
2. Restore direct method calls
3. Events become audit log only

The dual-path approach enables safe experimentation.


## Open Questions


### Event Ordering Guarantees

What ordering guarantees do we need?

- **Causal ordering:** Events caused by earlier events appear later (hard in distributed systems)
- **FIFO per agent:** Events from single agent appear in order (easier)
- **Total ordering:** All events have global sequence (requires coordination)

Recommendation: Start with FIFO per agent. Add global sequence if needed. Use logical clocks.


### Event Retention

How long do we keep events?

- **Forever:** Complete history, enables full replay
- **Time-bounded:** Last N days, keeps storage manageable
- **Milestone-bounded:** Until confirmed complete (task done, commitment verified)

Recommendation: Keep recent events (7 days). Snapshot state periodically. Archive old events to cold storage.


### Agent Discovery

How do agents learn about each other?

- **Registry events:** Subscribe to AgentSpawned/AgentDismissed
- **On-demand query:** Ask event bus for active agents
- **Broadcast:** Agents periodically announce presence

Recommendation: Registry events for basic discovery. Add query for complex scenarios.


### Conflict Resolution

What happens when two agents claim the same task?

- **First-write-wins:** First TaskClaimed event wins
- **Coordinator arbitration:** Central authority decides (reintroduces hierarchy)
- **Agent negotiation:** Agents negotiate via events

Recommendation: First-write-wins with backoff. Loser agent publishes TaskReliquished and moves on.


### User as Event Source

Is the user an agent?

- **Yes:** User actions are events (UserSentMessage, UserSelectedAgent)
- **No:** User actions trigger events but user is external

Recommendation: User actions are events. Enables replay, testing, and treating user as "ultimate agent."


### Hybrid Patterns

Pure choreography may be too extreme. What hybrid is right?

- **Choreography for discovery, orchestration for execution:** Agents discover work via events, but task coordination is hierarchical
- **Choreography for siblings, orchestration for parent-child:** Jake directs his children, but children collaborate via events
- **Choreography for read, orchestration for write:** Observation via events, mutations via methods

Recommendation: Start with hybrid - orchestration for core task lifecycle (Jake assigns, verifies completion) but choreography for discovery, sharing, and observation.


## Comparison with Related Architectures


### vs. Message Bus (15-message-bus.md)

Message Bus provides infrastructure; Choreography is a pattern using it.

- Message Bus: "Here's a way to route messages"
- Choreography: "Here's how to coordinate without a coordinator, using those messages"

Choreography could be implemented on a message bus, but the bus alone doesn't imply choreography.


### vs. Event Sourcing (05-event-sourced.md)

Event Sourcing is about persistence; Choreography is about control.

- Event Sourcing: "State is derived from event history"
- Choreography: "Coordination emerges from event reactions"

They combine well: choreography produces events, event sourcing persists them. But they're orthogonal - you can have choreography without event sourcing (events are transient) or event sourcing without choreography (central coordinator, events just for audit).


### vs. Reactive Streams (10-reactive-streams.md)

Reactive Streams adds backpressure to event flow.

- Reactive Streams: "Consumers control the rate of events"
- Choreography: "Agents react to events without central control"

Choreography benefits from backpressure (prevents event storms) but doesn't require it.


### vs. Actor Model (02-actor-model.md)

Both are decentralized. Key difference is communication style.

- Actor Model: Message passing with explicit recipients ("send message to agent X")
- Choreography: Event publishing with implicit subscribers ("publish event, whoever cares reacts")

Choreography is more loosely coupled. Actors can implement choreography by publishing to a shared mailbox rather than sending to specific actors.


## Conclusion

Choreography represents a fundamental shift from control to emergence. It aligns with several PRD goals (discovery sharing, lateral communication, resilience) but conflicts with others (hierarchical oversight, deterministic verification, Jake-as-proprietor).


### Arguments For Choreography

1. **PRD's vision of agent collaboration** - Agents sharing discoveries, lateral messaging, bubbling - all become natural event patterns

2. **Scalability** - Adding new agent types requires no coordinator changes

3. **Resilience** - No single point of failure; system degrades gracefully

4. **Testability** - Event-driven systems are highly testable via event assertions

5. **Future-proofing** - Unknown coordination patterns can emerge without redesign


### Arguments Against Choreography

1. **PRD's verification invariant** - "Commitments must be verified independently" implies hierarchical oversight

2. **Jake's character** - The Proprietor runs the show; choreography makes him a participant

3. **V1 complexity** - Choreography is harder to build, debug, and understand

4. **Debugging overhead** - Requires new tools and mental models

5. **Emergent behavior risks** - Unintended coordination patterns may cause bugs


### Recommendation

**For V1:** Do not adopt pure choreography. The investment is too high for the current scope, and the PRD's hierarchical model is well-suited to orchestration.

**For V2+:** Consider a hybrid approach:
- Core lifecycle (spawn, assign, verify, complete) remains orchestrated
- Discovery sharing and lateral communication use choreography
- Observation and monitoring are event-driven

This hybrid preserves Jake's authority for critical paths while enabling emergent collaboration for opportunistic behaviors.

**Key insight:** Choreography is not all-or-nothing. Start with orchestration, add event publication for observation, then selectively enable event-driven behavior where it adds value. The migration path allows gradual adoption based on actual needs rather than architectural purity.
