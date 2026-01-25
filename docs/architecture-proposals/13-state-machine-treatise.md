# State Machine Architecture: Complete Analysis

This treatise contains the full research findings, design considerations, and implementation analysis for the State Machine architecture proposal.


## Research Findings


### Current State Management in the Codebase

The existing implementation uses a simple `AgentState` enum with five cases:

```swift
public enum AgentState: String, Equatable, Sendable {
    case idle
    case working
    case waiting
    case verifying
    case done
}
```

State transitions are scattered across multiple locations:

1. **MortalAgent.swift** - Transitions happen imperatively within `send()`:
   - Line 109: `queue.sync { _state = .working }` at method entry
   - Line 202-208: `updateStateAfterResponse()` resets to `.idle` if still `.working`
   - Line 220: `queue.sync { _state = .waiting }` when "WAITING" signal detected
   - Line 230: `queue.sync { _state = .done }` when no commitments
   - Line 236: `queue.sync { _state = .verifying }` before verification
   - Line 242-247: `.done` or `.idle` based on verification result

2. **Jake.swift** - Uses a separate `_isCogitating` boolean mapped to AgentState:
   - Line 17: `_isCogitating ? .working : .idle` (only two states exposed)
   - Line 105-108: Direct boolean manipulation with defer block

3. **Commitment.swift** - Has its own status enum (pending, verifying, passed, failed) with mutation methods

4. **ChatViewModel.swift** - Has `isCogitating` and `showSessionRecoveryOptions` as independent booleans


### Problems with Current Approach

1. **No transition validation** - Nothing prevents `_state = .done` from `.idle` directly

2. **Scattered logic** - State changes happen in multiple methods with no central authority

3. **Signal detection is fragile** - Checking for "DONE" or "WAITING" in response text is heuristic

4. **No transition history** - Cannot answer "how did we get to this state?"

5. **Inconsistent patterns** - Jake uses boolean, MortalAgent uses enum, Commitment uses yet another enum

6. **No guards** - Can transition to `.verifying` even with no commitments (though code handles this)

7. **No entry/exit actions** - Logging is ad-hoc, not systematized


### PRD State Model

The PRD (Section 4.2) defines a richer state model than currently implemented:

```
Working ──────► Waiting for Input ──────► Done
    │                   │                   ▲
    │                   ▼                   │
    └──────► Waiting for Wakeup ───────────┘
                        │
                        ▼
                  Failed/Reaped
```

Notable gaps between PRD and implementation:

- **Waiting for Wakeup** - Not implemented; perseverance mode would auto-prompt
- **Failed/Reaped** - No explicit state; agents are simply dismissed
- **Wakeup → Done path** - Implies autonomous completion without user input


### PRD Task Modes

Section 4.3 defines five task modes agents can bounce between:

1. **Execute** - Do the work directly
2. **Delegate** - Pass to new agent
3. **Plan** - Think more before acting
4. **Break up** - Split into pieces, assign children
5. **Unify** - Combine work from delegated agents

These are orthogonal to lifecycle states. An agent in `Working` state could be in any task mode. This suggests a **hierarchical state machine** or **parallel state regions**.


## Mapping to State Machine Concepts


### Agent Lifecycle State Machine

```
States:
  - Idle (initial)
  - Working
    - Substates: Execute, Delegate, Plan, BreakUp, Unify (task modes)
  - WaitingForInput
  - WaitingForWakeup
  - Verifying
  - Done (final)
  - Reaped (final)

Events:
  - send(message: String)
  - responseReceived(content: String, signals: Set<Signal>)
  - inputProvided(content: String)
  - wakeupTriggered
  - verificationComplete(result: VerificationResult)
  - timeout
  - budgetExceeded
  - dismissed
  - fishOrCutBait

Guards:
  - hasCommitments: Bool
  - commitmentsAllPassed: Bool
  - withinBudget: Bool
  - responseContainsSignal(Signal): Bool

Effects:
  - logTransition(from: State, to: State, event: Event)
  - persistState()
  - notifyUI()
  - scheduleWakeup(after: Duration)
  - cancelWakeup()
  - runVerification()
```


### Commitment Verification State Machine

```
States:
  - Pending (initial)
  - Verifying
  - Passed (final)
  - Failed (final)

Events:
  - startVerification
  - assertionSucceeded
  - assertionFailed(message: String)
  - reset

Transitions:
  - Pending + startVerification → Verifying
  - Verifying + assertionSucceeded → Passed
  - Verifying + assertionFailed → Failed
  - Failed + reset → Pending
  - Passed + reset → Pending
```


### Session Lifecycle State Machine

```
States:
  - New
  - Active
  - Suspended
  - Corrupt
  - Closed

Events:
  - firstMessage
  - messageExchange
  - suspend
  - resume
  - errorDetected
  - clearSession
  - projectClosed

This would formalize the current ad-hoc session handling in SessionStore.
```


### Coordination State Machine (Per-Project)

```
States:
  - Uninitialized
  - Initializing
  - Ready
  - Busy (agents working)
  - ShuttingDown
  - Closed

Events:
  - projectOpened(url: URL)
  - claudeClientCreated
  - jakeSpawned
  - coordinatorReady
  - agentSpawned
  - allAgentsIdle
  - projectClosing
  - cleanupComplete
```


## Trade-offs Considered


### 1. Library vs Hand-Rolled

**Option A: Use XState-style library (e.g., swift-fsm, Gauntlet)**

Pros:
- Proven patterns, less reinvention
- Visualization tools (state charts)
- Community support

Cons:
- Additional dependency
- May not fit Swift idioms perfectly
- Potential API churn

**Option B: Hand-roll with Swift enums and pattern matching**

Pros:
- No dependencies
- Perfect Swift integration
- Complete control

Cons:
- More initial work
- Easy to drift from formal state machine semantics
- No visualization tools

**Recommendation:** Start hand-rolled with a clear protocol, migrate to library if complexity warrants.


### 2. Flat vs Hierarchical State Machines

The task modes (Execute, Delegate, Plan, BreakUp, Unify) create a natural hierarchy:

```
Working
├── Execute
├── Delegate
├── Plan
├── BreakUp
└── Unify
```

**Flat approach:** Treat each (lifecycle state, task mode) pair as a unique state:
- `WorkingExecuting`, `WorkingDelegating`, etc.
- Explodes state count: 5 lifecycle × 5 modes = 25 states

**Hierarchical approach:** Nest task mode within Working state:
- Working state has a sub-machine for task mode
- Transitions out of Working automatically exit sub-state

**Recommendation:** Hierarchical. Task modes only matter while Working.


### 3. Event-Driven vs Method-Driven API

**Event-driven:**
```swift
agent.dispatch(.send(message: "hello"))
// Returns new state, effects are pure data
```

**Method-driven:**
```swift
try agent.send("hello")
// Mutates internal state, runs effects inline
```

The current codebase uses method-driven. Full event-driven is a larger refactor.

**Recommendation:** Hybrid approach - methods that internally dispatch events. Enables gradual migration.


### 4. Centralized vs Distributed State Machines

**Centralized:** One machine tracks all agents' states:
```swift
class OrchestratorMachine {
    var agentStates: [AgentID: AgentState]
    func dispatch(_ event: AgentEvent, for agent: AgentID)
}
```

**Distributed:** Each agent has its own machine:
```swift
class MortalAgent {
    var machine: AgentStateMachine
}
```

**Recommendation:** Distributed. Agents are independent; their machines should be too. Coordinator observes via transition events.


## Implementation Complexity


### Minimal Implementation (Low Complexity)

Replace current `AgentState` enum with transition-aware wrapper:

```swift
struct AgentStateMachine: Sendable {
    private(set) var state: AgentState

    enum Event {
        case send(String)
        case responseReceived(String)
        case inputProvided(String)
        case verificationComplete(Bool)
        case dismissed
    }

    mutating func dispatch(_ event: Event) -> [Effect] {
        let (newState, effects) = transition(from: state, on: event)
        state = newState
        return effects
    }

    private func transition(from: AgentState, on: Event) -> (AgentState, [Effect]) {
        switch (from, event) {
        case (.idle, .send):
            return (.working, [.log("Transitioning to working")])
        case (.working, .responseReceived(let content)) where content.contains("DONE"):
            return (.verifying, [.runVerification])
        // ... exhaustive matching
        default:
            // Invalid transition - log and stay in current state
            return (from, [.logWarning("Invalid transition")])
        }
    }
}
```

**Effort:** 1-2 days to wrap existing code.
**Risk:** Low - doesn't change external APIs.


### Full Implementation (High Complexity)

Complete state machine infrastructure with:

1. **StateMachine protocol** defining states, events, effects
2. **Hierarchical state support** for task modes
3. **Transition history** for debugging and rewind
4. **Effect interpreter** that executes side effects
5. **Visualization** (generate Mermaid diagrams from machine definition)
6. **Persistence** of state machine snapshots

```swift
protocol StateMachine {
    associatedtype State: Hashable
    associatedtype Event
    associatedtype Effect

    static var initial: State { get }
    static func transition(from: State, on: Event) -> Transition<State, Effect>
}

struct Transition<State, Effect> {
    let target: State
    let effects: [Effect]
    let guard: Bool
}

class StateMachineExecutor<M: StateMachine> {
    private(set) var state: M.State
    private var history: [(M.State, M.Event, M.State)] = []

    func dispatch(_ event: M.Event) async {
        let transition = M.transition(from: state, on: event)
        guard transition.guard else { return }

        let oldState = state
        state = transition.target
        history.append((oldState, event, state))

        for effect in transition.effects {
            await interpret(effect)
        }
    }
}
```

**Effort:** 1-2 weeks for infrastructure + migration.
**Risk:** Medium - requires coordinated refactor.


### Incremental Path

1. **Week 1:** Add StateMachine protocol, migrate MortalAgent
2. **Week 2:** Migrate Jake, Commitment
3. **Week 3:** Add hierarchical states for task modes
4. **Week 4:** Add transition history, visualization
5. **Future:** Session and Coordinator state machines


## Migration Path from Current State


### Phase 1: Wrapper (Non-Breaking)

Wrap existing state management without changing external APIs:

```swift
// Current
public var state: AgentState {
    queue.sync { _state }
}

// Wrapped
public var state: AgentState {
    queue.sync { _machine.state }
}
```

Internal methods dispatch events to machine instead of directly mutating `_state`.


### Phase 2: Centralize Transitions

Move all `_state = .newState` assignments to dispatch calls:

```swift
// Before
if upperResponse.contains("DONE") {
    queue.sync { _state = .verifying }
}

// After
if upperResponse.contains("DONE") {
    dispatch(.doneSignalDetected)
}
```


### Phase 3: Add Guards

Extract conditions into guard functions:

```swift
case (.working, .doneSignalDetected):
    if hasCommitments {
        return (.verifying, [.runVerification])
    } else {
        return (.done, [.log("No commitments, marking done")])
    }
```


### Phase 4: Add Effects

Replace inline side effects with declarative effect values:

```swift
enum AgentEffect {
    case log(String)
    case persist
    case notifyUI(AgentState)
    case scheduleWakeup(TimeInterval)
    case runVerification
}

// Executor interprets effects
func interpret(_ effect: AgentEffect) async {
    switch effect {
    case .log(let message):
        TavernLogger.agents.info("\(message)")
    case .persist:
        SessionStore.saveAgentSession(...)
    // ...
    }
}
```


### Phase 5: Add History

Track all transitions for debugging and rewind:

```swift
struct TransitionRecord {
    let timestamp: Date
    let fromState: AgentState
    let event: AgentEvent
    let toState: AgentState
    let effects: [AgentEffect]
}

// Query: "Show me all transitions to Failed state"
let failureRecords = history.filter { $0.toState == .reaped }
```


## Open Questions


### 1. State Machine Library Choice

If we go beyond hand-rolled, which library? Options:

- **Gauntlet** (Swift state machine library)
- **SwiftState** (older but battle-tested)
- **Hand-rolled** with inspiration from XState

Research needed on Swift ecosystem options and their maintenance status.


### 2. Persistence Format

How should state machine snapshots be persisted?

- **Current state only:** Matches current approach, simple
- **State + recent history:** Enables debugging
- **Full history:** Enables complete rewind, but storage cost

Recommendation: Start with current state only; add history for debugging later.


### 3. Inter-Machine Communication

When parent agent spawns child, how do their state machines interact?

- **Events bubble up:** Child transition events visible to parent machine
- **Polling:** Parent periodically queries child state
- **Callbacks:** Child calls parent on significant transitions

The PRD mentions bubbling (Section 5.3). State machines could formalize this.


### 4. UI Binding

How do state machines integrate with SwiftUI?

- **Published state:** `@Published var state: AgentState` (current approach)
- **State observation:** Subscribe to transition events
- **Derived state:** Compute UI state from machine state

Current approach works; question is whether to enhance with transition observation.


### 5. Jake's Special Status

Jake currently uses `isCogitating` boolean mapped to `.working` / `.idle`. Should Jake:

- **Use same state machine as MortalAgent:** Simplifies code, but Jake never goes to Done/Reaped
- **Use simplified machine:** Only Idle/Working transitions
- **Use hierarchical machine:** Jake's machine supervises child agent machines

Recommendation: Simplified machine for Jake; his lifecycle is fundamentally different.


### 6. Task Mode Transitions

The PRD says agents can "bounce between" task modes. What triggers these transitions?

- **Agent self-reports:** Response contains mode indicator
- **Parent directs:** Parent sends mode-change command
- **Automatic:** Based on context (e.g., receiving subtask results → Unify)

This needs PRD clarification before implementation.


### 7. Concurrency Model

State machines should be thread-safe. Options:

- **Actor:** Machine is a Swift actor (see proposal 02-actor-model)
- **Dispatch queue:** Current approach, proven to work
- **Mutex/lock:** Lower-level, potentially faster

The state machine architecture complements actor model; they're not mutually exclusive.


## Relationship to Other Proposals


### Actor Model (02)

State machines can be implemented as actors. Each agent actor owns its state machine. The actor model provides the concurrency isolation; the state machine provides the transition logic.

**Synergy:** High. Consider combining these proposals.


### Supervisor Trees (04)

Supervisor strategies map to state machine transitions. When an agent's machine enters `Reaped` state, the supervisor's machine can transition to `Restarting` or `Escalating`.

**Synergy:** Medium. Supervisors observe child machines.


### Event-Sourced (05)

State machine transitions are events. An event-sourced system could persist the transition log, with current state as a projection.

**Synergy:** Very high. State machines produce the events that event sourcing persists.


### Document-Centric (03)

Agent nodes in doc store could include state machine snapshots. The "doc store is source of truth" invariant applies to state machines too.

**Synergy:** Medium. Persistence integration needed.


### CQRS (12)

Commands trigger state machine events. Queries read projected state. Natural fit for state machine + CQRS.

**Synergy:** High. Commands dispatch events; queries read machine state.


## Conclusion

The State Machine architecture addresses fundamental issues in Tavern's current state management:

1. **Correctness:** Compile-time validation of transitions
2. **Observability:** Natural hooks for logging and metrics
3. **Testability:** Exhaustive enumeration of (state, event) pairs
4. **Documentation:** Machine definition is the specification

The PRD already thinks in state machine terms (agent states, task modes). Formalizing this into actual state machines aligns code with design.

**Recommended approach:**

1. Start with minimal wrapper around MortalAgent
2. Migrate Jake with simplified machine
3. Add hierarchical states for task modes
4. Add transition history for debugging
5. Consider event sourcing integration for rewind/branch

The implementation complexity scales with ambition. A minimal wrapper is 1-2 days of work. Full infrastructure with history and visualization is 1-2 weeks. The incremental path allows shipping value at each step.
