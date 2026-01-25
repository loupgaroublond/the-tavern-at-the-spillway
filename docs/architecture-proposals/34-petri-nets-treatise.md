# Petri Nets Architecture: Complete Analysis

This treatise contains the full research findings, design considerations, and implementation analysis for the Petri Nets architecture proposal. It is the companion to the 1-pager proposal.


## Research Findings


### Petri Net Fundamentals

Petri Nets (Carl Adam Petri, 1962) are a mathematical formalism for modeling concurrent systems. The core components are:

**Places (circles):** Represent conditions or states. Can hold zero or more *tokens*.

**Transitions (rectangles/bars):** Represent events or actions. Have input places and output places.

**Arcs:** Connect places to transitions (input arcs) and transitions to places (output arcs). Can have weights.

**Tokens (dots):** Represent resources or active instances. Flow through the network.

**Firing rules:**
1. A transition is *enabled* when all input places have at least as many tokens as their arc weights
2. When a transition *fires*, it atomically consumes input tokens and produces output tokens
3. If multiple transitions are enabled, any one may fire (nondeterminism)

**Example - Simple Producer-Consumer:**
```
     [Producer]      [Consumer]
         |               ^
         v               |
      (Buffer)---------->|
         |               |
         +----->[Consume]
```

Producer transition adds tokens to Buffer place. Consumer transition removes tokens from Buffer. If Buffer is empty, Consumer cannot fire.


### Extended Petri Net Variants

Several extensions are relevant to the Tavern:

**Colored Petri Nets (CPN):** Tokens carry data values (colors). Transitions have guards and expressions. Essential for modeling agent assignments and commitment data.

**Hierarchical Petri Nets:** Places can contain subnets. Enables compositional design (agent lifecycle subnet, coordination subnet).

**Timed Petri Nets:** Transitions have delays. Models timeouts and fish-or-cut-bait.

**Inhibitor Arcs:** Transition fires only when a place is empty. Useful for guards like "spawn only if under capacity."

**Object Petri Nets:** Tokens are themselves Petri Nets. Could model agents as active tokens with internal behavior.

For Tavern v1, Colored Petri Nets with timed transitions are likely sufficient.


### Analyzable Properties

Petri Nets enable proving properties at design time:

**Reachability:** Can the system reach a specific marking (token distribution)? "Can we ever have zero agents but pending work?"

**Boundedness:** Does any place's token count stay within bounds? "Can the agent pool grow unboundedly?"

**Liveness:** Can every transition eventually fire from any reachable state? "Can the system ever get stuck where no progress is possible?"

**Deadlock freedom:** Is there always at least one enabled transition? Stronger than liveness.

**Fairness:** Are all enabled transitions eventually fired? "Do all agents eventually get work?"

These properties can be verified using:
- **Coverability trees:** Finite representation of reachable markings
- **State equation analysis:** Linear algebra on incidence matrix
- **Model checking tools:** LoLA, TAPAAL, CPN Tools


### Current Codebase Analysis

Analyzing the existing Tavern implementation through a Petri Net lens:

**AgentState as Places:**

The current `AgentState` enum maps directly to places:
```swift
public enum AgentState: String, Equatable, Sendable {
    case idle       // Place: P_Idle
    case working    // Place: P_Working
    case waiting    // Place: P_Waiting
    case verifying  // Place: P_Verifying
    case done       // Place: P_Done
}
```

In Petri Net terms, each agent has exactly one token distributed among these places (1-safe net).


**State Transitions as Petri Transitions:**

Current implicit transitions in `MortalAgent.swift`:
```
T_Send: P_Idle -> P_Working          (line 109)
T_Response: P_Working -> P_Idle      (lines 202-208, when no signal)
T_WaitSignal: P_Working -> P_Waiting (line 220)
T_DoneSignal: P_Working -> P_Verifying (line 236)
T_Pass: P_Verifying -> P_Done        (line 242)
T_Fail: P_Verifying -> P_Idle        (line 247)
T_InputReceived: P_Waiting -> P_Working (not explicitly implemented)
```

The PRD (Section 4.2) adds states not currently implemented:
- `Waiting for Wakeup` (perseverance mode)
- `Failed/Reaped` (fish-or-cut-bait)


**Commitment Verification as Subnet:**

`Commitment.swift` has its own state flow:
```
P_Pending -> T_StartVerify -> P_Verifying -> T_CheckResult -> P_Passed | P_Failed
```

This is a separate net that synchronizes with the agent net via shared places.


**Problems with Current Approach:**

1. **No explicit concurrency model:** Multiple agents are independent; no formal coordination

2. **Implicit token flow:** State changes are imperative assignments, not token movements

3. **No resource contention modeling:** User attention and API capacity are implicit

4. **No analyzability:** Cannot prove deadlock freedom or liveness

5. **Scattered transitions:** State changes happen in multiple methods without centralization


**AgentRegistry as Token Pool:**

```swift
private var _agents: [UUID: AnyAgent] = [:]
```

In Petri Net terms, this is a place holding agent tokens. The `register` and `remove` operations are input/output arcs.


**TavernCoordinator as Transition Enabler:**

The coordinator decides when transitions fire:
```swift
func spawnAgent(assignment:selectAfterSpawn:)  // Fires T_Spawn
func dismissAgent(id:)                          // Fires T_Dismiss
func selectAgent(id:)                           // Fires T_Select (UI focus)
```


### PRD Mapping to Petri Net Concepts


**Agent Types (PRD Section 4.1):**

| Agent Type | Petri Net Model |
|------------|-----------------|
| Jake (Daemon) | Token that never leaves; always in Active subnet |
| Mortal | Token with full lifecycle; flows Spawn -> Work -> Done -> Reaped |
| Drone | Token with minimal lifecycle; flows Spawn -> Work -> Reaped |
| Monitor Daemon | Background token; flows through monitoring subnet |


**Agent States (PRD Section 4.2):**

```
              P_Spawned
                  |
                  v
            [T_Initialize]
                  |
                  v
              P_Idle
             /   |   \
            /    |    \
           v     v     v
    [T_Work] [T_Wait] [T_Wakeup]
        |       |        |
        v       v        v
   P_Working P_Waiting P_WaitingWakeup
        |       |        |
        |       v        |
        |  [T_Input]     |
        |       |        |
        +<------+--------+
        |
        v
   [T_CheckDone]
        |
    +---+---+
    |       |
    v       v
[T_Verify] [T_Continue]
    |           |
    v           |
P_Verifying     |
    |           |
    v           |
[T_Result]      |
   / \          |
  v   v         |
P_Done P_Idle<--+
    |
    v
[T_Dismiss/Reap]
    |
    v
P_Reaped (terminal)
```


**Task Modes (PRD Section 4.3):**

Task modes (Execute, Delegate, Plan, Break up, Unify) are orthogonal to lifecycle states. In Petri Net terms, these are *colors* on the Working token:

```
Token in P_Working carries color:
  - Execute: Direct work
  - Delegate: Spawns child, adds token to P_ChildPending
  - Plan: Internal cogitation
  - BreakUp: Spawns multiple children
  - Unify: Waits for child tokens to arrive
```


**Operating Modes (PRD Section 4.4):**

```
P_ChatMode: User is engaged, pings on state change
P_PerseveranceMode: Background, auto-prompt on idle
```

These are additional places with tokens representing mode state.


**Commitments (PRD Section 4.7):**

Commitments are colored tokens:
```
Token: (commitment_id, description, assertion, status)
Colors: Pending, Verifying, Passed, Failed
```

Flow:
```
P_CommitmentPending -> [T_StartVerify] -> P_CommitmentVerifying
P_CommitmentVerifying -> [T_RunAssertion] -> (P_Passed | P_Failed)
```

Synchronization: Agent token in P_Verifying holds until all commitment tokens reach P_Passed.


**Sandbox Primitives (PRD Section 4.6):**

Each sandbox primitive is a resource place with bounded capacity:
```
P_ChangesetSlots: Capacity = max concurrent changesets
P_ContainerSlots: Capacity = max containers
P_NetworkPermit: Token present = network access allowed
```

Agent spawn transition requires tokens from resource places.


**Work Queues (PRD Section 6.3):**

Work queues are places:
```
P_WorkQueue: Holds task tokens awaiting assignment
[T_AssignTask]: P_WorkQueue x P_IdleAgent -> P_WorkingAgent
```

Empty queue behavior is a guard on agent termination transition.


**Merge Queue (PRD Section 6.5):**

```
P_MergeQueue: Ordered queue of changeset tokens
[T_Merge]: Takes first token from queue when target available
P_TargetLock: Single token controls exclusive access
```


## How This Differs from State Machine (#13) and Process Calculus (#20)


### State Machine Comparison

| Aspect | State Machine | Petri Net |
|--------|--------------|-----------|
| Focus | Single entity lifecycle | Multi-entity coordination |
| States | Exclusive (one active) | Concurrent (multiple places can hold tokens) |
| Transitions | Deterministic (guards pick one) | Nondeterministic (any enabled can fire) |
| Resources | Implicit | Explicit (tokens in places) |
| Analysis | Reachable states | Reachability, boundedness, liveness |
| Composition | Hierarchical substates | Parallel subnets |
| PRD fit | Agent lifecycle | Agent coordination + lifecycle |

**Key difference:** State machines model one agent at a time. Petri Nets model the entire system of agents, their interactions, and shared resources simultaneously.

**Example - Spawn Coordination:**

State Machine: Parent state = Spawning, Child state = Idle. No formal relationship.

Petri Net:
```
P_ParentWorking + P_SpawnRequest -> [T_Spawn] -> P_ParentWorking + P_ChildIdle
```
The spawn transition atomically updates both parent and child states.


### Process Calculus Comparison

| Aspect | Process Calculus | Petri Net |
|--------|-----------------|-----------|
| Focus | Channel-based communication | Token-based resource flow |
| Concurrency | Process composition (P | Q) | Token distribution |
| Communication | Synchronous channel send/receive | Transition firing |
| Mobility | First-class channels | Static topology (mostly) |
| Analysis | Bisimulation, trace equivalence | Coverability, liveness |
| Implementation | AsyncStream/Actor | Custom token tracking |
| PRD fit | Agent messaging | Agent coordination |

**Key difference:** Process calculus emphasizes communication protocols between processes. Petri Nets emphasize resource flow and contention.

**Example - Bubbling:**

Process Calculus: Child process sends on parent's channel.
```
Child = work.parent<question>.answer.Child
Parent = child(q).handle(q).child<a>.Parent
```

Petri Net:
```
P_ChildQuestion + P_ParentIdle -> [T_Bubble] -> P_ParentHandling
P_ParentHandling -> [T_Answer] -> P_ChildContinue + P_ParentIdle
```

Process calculus makes the message content explicit. Petri Nets make the resource dependencies explicit.


### Hybrid Potential

These architectures are not mutually exclusive:

- **State Machine + Petri Net:** Use state machines for individual agent lifecycles, Petri Nets for coordination between agents

- **Process Calculus + Petri Net:** Use channels for message content, Petri Nets for synchronization and resource management

- **All Three:** State machines for agents, Process Calculus for protocols, Petri Nets for system-wide properties


## Trade-offs Considered


### 1. Classic vs Colored Petri Nets

**Classic Petri Nets:**
- Simpler theory, more tools
- Tokens are undifferentiated
- Agent identity requires separate place per agent

**Colored Petri Nets:**
- Tokens carry data (agent ID, assignment, commitments)
- Single place for all agents of same state
- More complex but more expressive

**Decision:** Colored Petri Nets. Agent identity and commitment data are essential.


### 2. Static vs Dynamic Topology

**Static topology:**
- Fixed number of places and transitions
- Analysis is straightforward
- Cannot model unbounded agent spawning

**Dynamic topology (Object Petri Nets):**
- Tokens are themselves nets
- Spawning creates new subnets
- Complex theory, limited tooling

**Decision:** Semi-dynamic. Fixed coordination net, but place capacities and token colors allow variable agent counts.


### 3. Centralized vs Distributed Token Tracking

**Centralized:**
```swift
actor PetriNetExecutor {
    var marking: [PlaceID: TokenBag]
    func fire(_ transition: TransitionID) async
}
```

**Distributed:**
```swift
actor Place {
    var tokens: TokenBag
}
actor Transition {
    var inputs: [Place]
    var outputs: [Place]
}
```

**Decision:** Centralized for v1. Simpler reasoning, atomic firing. Distribute later if performance requires.


### 4. Design-time vs Runtime Analysis

**Design-time only:**
- Model in external tool (LoLA, CPN Tools)
- Generate Swift code from verified model
- No runtime overhead

**Runtime analysis:**
- Track marking at runtime
- Detect deadlock dynamically
- Performance cost

**Decision:** Design-time primarily, with runtime marking tracking for debugging. Full runtime analysis is overkill for v1.


### 5. Full Formalism vs Petri-Inspired

**Full formalism:**
- Implement complete Petri Net semantics
- Use established analysis algorithms
- Higher complexity, proven properties

**Petri-inspired:**
- Use place/transition concepts informally
- No formal verification
- Easier implementation

**Decision:** Formal enough to use existing tools for analysis, but pragmatic about runtime implementation.


## Implementation Complexity


### Core Infrastructure

**PlaceID and TransitionID:**
```swift
struct PlaceID: Hashable {
    let name: String
}

struct TransitionID: Hashable {
    let name: String
}
```

**Token with Color:**
```swift
struct Token: Equatable, Sendable {
    let color: TokenColor
}

enum TokenColor: Equatable, Sendable {
    case agent(id: UUID, assignment: String)
    case commitment(id: UUID, status: CommitmentStatus)
    case resource(type: ResourceType)
    case unit // Uncolored token
}
```

**Marking (token distribution):**
```swift
struct Marking: Equatable, Sendable {
    var places: [PlaceID: [Token]]

    func tokens(in place: PlaceID) -> [Token] {
        places[place] ?? []
    }

    mutating func add(_ token: Token, to place: PlaceID) {
        places[place, default: []].append(token)
    }

    mutating func remove(_ token: Token, from place: PlaceID) -> Bool {
        guard let index = places[place]?.firstIndex(of: token) else {
            return false
        }
        places[place]?.remove(at: index)
        return true
    }
}
```

**Transition Definition:**
```swift
struct Transition {
    let id: TransitionID
    let inputs: [(PlaceID, TokenMatcher)]
    let outputs: [(PlaceID, TokenProducer)]
    let guard: (Marking) -> Bool

    func isEnabled(in marking: Marking) -> Bool {
        guard self.guard(marking) else { return false }
        for (place, matcher) in inputs {
            if !matcher.matches(any: marking.tokens(in: place)) {
                return false
            }
        }
        return true
    }

    func fire(in marking: inout Marking) -> [Effect] {
        var consumedTokens: [Token] = []

        // Consume inputs
        for (place, matcher) in inputs {
            guard let token = matcher.firstMatch(in: marking.tokens(in: place)) else {
                fatalError("Transition fired when not enabled")
            }
            marking.remove(token, from: place)
            consumedTokens.append(token)
        }

        // Produce outputs
        var effects: [Effect] = []
        for (place, producer) in outputs {
            let (token, effect) = producer.produce(from: consumedTokens)
            marking.add(token, to: place)
            if let effect = effect {
                effects.append(effect)
            }
        }

        return effects
    }
}
```

**PetriNet Definition:**
```swift
struct PetriNet {
    let places: Set<PlaceID>
    let transitions: [TransitionID: Transition]
    let initialMarking: Marking

    func enabledTransitions(in marking: Marking) -> [TransitionID] {
        transitions.values
            .filter { $0.isEnabled(in: marking) }
            .map { $0.id }
    }
}
```

**Executor:**
```swift
actor PetriNetExecutor {
    let net: PetriNet
    private(set) var marking: Marking
    private var history: [(TransitionID, Marking)] = []

    init(net: PetriNet) {
        self.net = net
        self.marking = net.initialMarking
    }

    func fire(_ transitionID: TransitionID) async throws -> [Effect] {
        guard let transition = net.transitions[transitionID],
              transition.isEnabled(in: marking) else {
            throw PetriNetError.transitionNotEnabled(transitionID)
        }

        history.append((transitionID, marking))
        let effects = transition.fire(in: &marking)

        // Execute effects
        for effect in effects {
            await execute(effect)
        }

        return effects
    }

    func enabledTransitions() -> [TransitionID] {
        net.enabledTransitions(in: marking)
    }

    func rollback(steps: Int) {
        for _ in 0..<steps {
            guard let (_, previousMarking) = history.popLast() else { break }
            marking = previousMarking
        }
    }
}
```


### Effort Estimation

| Component | Complexity | Effort |
|-----------|------------|--------|
| Core data structures (Token, Marking, Transition) | Low | 1-2 days |
| PetriNet definition and parsing | Medium | 2-3 days |
| PetriNetExecutor with history | Medium | 2-3 days |
| Agent lifecycle subnet | Medium | 2-3 days |
| Commitment verification subnet | Low | 1-2 days |
| Coordination net (spawning, dismissal) | High | 3-5 days |
| Integration with existing code | High | 3-5 days |
| Visualization/debugging tools | Medium | 2-3 days |
| Analysis tooling integration | High | 3-5 days |
| **Total** | | **20-30 days** |


### Integration Points

**Agent State:**
```swift
// Current
public var state: AgentState {
    queue.sync { _state }
}

// Petri Net
public var state: AgentState {
    executor.placeContainingToken(agentId: id).toAgentState()
}
```

**Spawn:**
```swift
// Current
public func spawn(assignment: String) throws -> MortalAgent

// Petri Net
public func spawn(assignment: String) async throws -> MortalAgent {
    let token = Token.agent(id: UUID(), assignment: assignment)
    try await executor.fire(.spawn, consuming: [.assignment(assignment)], producing: [token])
    return MortalAgent(backing: token)
}
```

**Commitment Verification:**
```swift
// Current
try await verifier.verifyAll(in: commitments)

// Petri Net
for commitment in commitments.pending {
    let token = Token.commitment(id: commitment.id, status: .pending)
    try await executor.fire(.startVerification, with: token)
    // Verification runs as effect
}
await executor.awaitMarking { marking in
    commitments.allIDs.allSatisfy { id in
        marking.contains(Token.commitment(id: id, status: .passed), in: .commitmentPassed)
    }
}
```


## Migration Path from Current State


### Phase 1: Model Current Behavior (1 week)

Create Petri Net model of existing agent lifecycle without changing code:

```
Places:
- P_Idle, P_Working, P_Waiting, P_Verifying, P_Done

Transitions:
- T_Send: P_Idle -> P_Working
- T_Response: P_Working -> P_Idle
- T_WaitSignal: P_Working -> P_Waiting
- T_InputReceived: P_Waiting -> P_Working
- T_DoneSignal: P_Working -> P_Verifying (guarded by has_commitments)
- T_Pass: P_Verifying -> P_Done
- T_Fail: P_Verifying -> P_Idle
```

Validate model against test cases. Document where current code deviates from model.


### Phase 2: Add Parallel Tracking (1 week)

Run Petri Net executor in parallel with existing code:

```swift
class MortalAgent {
    private var _state: AgentState // Existing
    private var petriState: PetriNetExecutor // New, shadow

    public func send(_ message: String) async throws -> String {
        // Shadow fire
        Task { try? await petriState.fire(.send) }

        queue.sync { _state = .working }
        defer { updateStateAfterResponse() }

        // ... existing code ...
    }
}
```

Log discrepancies between `_state` and Petri Net marking. Fix model or code to align.


### Phase 3: Petri Net as Source of Truth (2 weeks)

Replace imperative state assignments with transition firing:

```swift
class MortalAgent {
    private let executor: PetriNetExecutor

    public var state: AgentState {
        executor.agentState(for: id)
    }

    public func send(_ message: String) async throws -> String {
        try await executor.fire(.send, with: Token.agent(id: id))
        defer { Task { try? await executor.fire(.response, with: Token.agent(id: id)) } }
        // ... rest of method ...
    }
}
```


### Phase 4: Add Coordination Net (2 weeks)

Extend net to model agent spawning, dismissal, and coordination:

```
Additional Places:
- P_SpawnRequest: Holds pending spawn requests
- P_AgentPool: All active agent tokens
- P_DismissRequest: Holds pending dismiss requests

Additional Transitions:
- T_Spawn: P_SpawnRequest -> P_Idle (creates new agent token)
- T_Dismiss: P_Done + P_DismissRequest -> (removes agent token)
- T_Reap: P_Waiting + P_Timeout -> P_Reaped
```


### Phase 5: Add PRD Features (2 weeks)

Model PRD-specified features not yet implemented:

- Waiting for Wakeup (perseverance mode)
- Work queues with empty-queue policies
- Resource contention (user attention, API capacity)
- Merge queue for changesets


### Phase 6: Formal Analysis (ongoing)

Export Petri Net model to analysis tool (LoLA or similar):

```
PLACE P_Idle, P_Working, P_Waiting, P_Verifying, P_Done, P_Reaped;
TRANSITION T_Send, T_Response, T_WaitSignal, T_InputReceived, ...;
FLOW T_Send: P_Idle -> P_Working;
     T_Response: P_Working -> P_Idle;
     ...
INITIAL_MARKING P_Idle: 1;

FORMULA deadlock_free: AG EX true;
FORMULA bounded: AG (P_Working <= 1);
```

Run analysis, fix violations, iterate.


## Open Questions


### 1. Token Identity

Should tokens be value types (copied on transition) or reference types (moved)?

**Value types:**
- Simpler semantics
- History contains full token data
- Memory overhead for large tokens

**Reference types:**
- Tokens are handles
- Mutation requires careful tracking
- Less memory overhead

**Leaning toward:** Value types with lazy loading for large data.


### 2. Concurrent Transition Firing

When multiple transitions are enabled, who decides which fires?

**Options:**
- Random selection (true nondeterminism)
- Priority ordering (transitions have weights)
- External scheduler (coordinator picks)
- All fire in parallel (if conflict-free)

**Leaning toward:** External scheduler. TavernCoordinator decides based on policies.


### 3. Subnet Boundaries

How do subnets communicate?

**Options:**
- Shared places (tokens visible to multiple subnets)
- Fusion places (same place appears in multiple subnets)
- Interface transitions (subnet exposes transition as API)

**Leaning toward:** Interface transitions. Encapsulates subnet internals.


### 4. Timed Transitions

How to model timeouts (fish-or-cut-bait)?

**Options:**
- Explicit timer places with countdown tokens
- Transition delays (timed Petri Nets)
- External timer that injects timeout tokens

**Leaning toward:** External timer. Swift's Task timeout + token injection.


### 5. Swift Actor Integration

Petri Net executor is an actor. How to integrate with existing actors?

**Options:**
- Single global executor
- Per-project executor
- Per-agent executor with shared coordination net

**Leaning toward:** Per-project executor. Matches current TavernCoordinator scope.


### 6. UI Updates

How does UI observe marking changes?

**Options:**
- Publish marking as `@Published`
- Transition effects trigger UI updates
- Observers subscribe to specific places

**Leaning toward:** Place observers. UI subscribes to places it cares about.


### 7. DocStore Integration

The PRD emphasizes "doc store is source of truth." Where does Petri Net marking fit?

**Options:**
- Marking is ephemeral (reconstructed from doc store on startup)
- Marking is persisted alongside doc store
- Doc store operations are transitions with effects

**Leaning toward:** Hybrid. Marking is primary at runtime; doc store is backup for restart recovery.


### 8. Analysis Tooling

Which external tools to integrate?

**Candidates:**
- LoLA (Low-Level Petri Net Analyzer)
- TAPAAL (Timed-Arc Petri Net Analyzer)
- CPN Tools (Colored Petri Nets)
- Custom Swift analysis

**Leaning toward:** Start with custom Swift analysis for boundedness/deadlock. Integrate LoLA for complex properties.


## Relationship to Other Proposals


### State Machine (13)

Petri Nets subsume state machines. A state machine is a Petri Net where:
- Each place has at most one token
- Transitions have exactly one input and one output arc

**Synergy:** Use state machine formalism for individual agent lifecycle (1-safe subnet), Petri Net for coordination between agents.


### Actor Model (02)

Actors provide isolation; Petri Nets provide coordination.

**Synergy:** Each agent is an actor. The Petri Net executor is an actor that coordinates agent actors via message passing.


### Supervisor Trees (04)

Supervision strategies map to Petri Net transitions:
```
T_Restart: P_Failed + P_RestartPolicy -> P_Idle
T_Escalate: P_Failed + P_EscalatePolicy -> P_ParentNotified
```

**Synergy:** Supervisor tree structure encoded in Petri Net topology. Restart strategies are guarded transitions.


### Event Sourcing (05)

Transition firing produces events. Event log is transition history.

**Synergy:** High. Every transition firing is an event. Replaying events reconstructs marking.


### Document-Centric (03)

Agent nodes in doc store correspond to tokens.

**Synergy:** Medium. Token data can be serialized to/from doc store. Transition effects include doc store writes.


### Process Calculus (20)

Channels map to places. Channel operations map to transitions.

**Synergy:** Medium. Petri Nets are less expressive for protocols but better for resource analysis. Could use both.


### CQRS (12)

Commands fire transitions. Queries read marking.

**Synergy:** High. Natural fit. Command handler validates transition is enabled, fires it, returns new marking.


### Graph-Based (19)

Petri Net is a bipartite graph (places and transitions).

**Synergy:** Low direct overlap, but graph algorithms (reachability, paths) apply to Petri Net analysis.


## Conclusion

Petri Nets offer a rigorous foundation for modeling the Tavern's multi-agent coordination. The formalism excels at:

1. **Explicit concurrency:** Multiple agents working in parallel are naturally modeled
2. **Resource contention:** User attention, API limits, token budgets become visible
3. **Provable properties:** Deadlock freedom and boundedness can be verified
4. **Visual debugging:** Token flow shows where work is blocked
5. **Composition:** Subnets for lifecycle, verification, and coordination combine cleanly

**Weaknesses to address:**
- Learning curve for team
- Dynamic agent spawning requires colored/object nets
- Swift tooling gap requires custom infrastructure
- May be overkill for v1's simpler requirements

**Recommendation:**

For v1, consider a hybrid approach:
1. Use State Machine (#13) for individual agent lifecycles (simpler, well-understood)
2. Use Petri Net concepts informally for coordination reasoning
3. Build minimal token tracking infrastructure for debugging
4. Invest in full Petri Net formalism for v2 when coordination complexity warrants

If pursuing full Petri Net architecture:
1. Start with agent lifecycle subnet (1 week)
2. Add parallel shadow tracking (1 week)
3. Migrate to Petri Net as source of truth (2 weeks)
4. Add coordination net (2 weeks)
5. Integrate analysis tooling (ongoing)

Total investment: 20-30 days of focused work, with ongoing analysis capabilities as payoff.
