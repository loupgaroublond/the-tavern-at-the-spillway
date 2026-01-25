# Gossip Protocol Architecture: Complete Analysis

This document contains the full research, analysis, and trade-off considerations for adopting a gossip protocol architecture in Tavern.


## Research Findings


### Current State Ownership Patterns

The codebase implements centralized state management with explicit ownership hierarchies.


**TavernCoordinator as State Authority**

The coordinator maintains authoritative system state:

```swift
// TavernCoordinator.swift
@MainActor
public final class TavernCoordinator: ObservableObject {
    @Published public private(set) var agentListViewModel: AgentListViewModel
    @Published public private(set) var activeChatViewModel: ChatViewModel
    private var chatViewModels: [UUID: ChatViewModel] = [:]
}
```

The coordinator is the single source of truth. "What agents exist?" is answered by asking the coordinator. "Which agent is selected?" is stored in the coordinator. There is no distributed state.


**AgentRegistry as Centralized Index**

The registry maintains a synchronized view of all agents:

```swift
// AgentRegistry.swift
public final class AgentRegistry: @unchecked Sendable {
    private var _agents: [UUID: AnyAgent] = [:]
    private var _nameToId: [String: UUID] = [:]

    public func register<A: Agent>(_ agent: A) throws {
        // Synchronized write to central store
        try queue.sync {
            if _nameToId[agent.name] != nil {
                throw AgentRegistryError.nameAlreadyExists(agent.name)
            }
            let wrapped = AnyAgent(agent)
            _agents[agent.id] = wrapped
            _nameToId[agent.name] = agent.id
        }
    }
}
```

Registration is a synchronized operation to a central dictionary. Name uniqueness is enforced by central authority. There is no concept of an agent existing without registry knowledge.


**SessionStore as Centralized Persistence**

Session state lives in a single UserDefaults store:

```swift
// SessionStore.swift
public enum SessionStore {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    public static func saveJakeSession(_ sessionId: String?, projectPath: String) {
        let key = jakeSessionKey(for: projectPath)
        if let id = sessionId {
            defaults.set(id, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
```

Session IDs are stored centrally. There is no replication, no gossip, no distributed state.


**Agent State is Self-Contained**

Each agent maintains its own state via serial queue:

```swift
// MortalAgent.swift
public final class MortalAgent: Agent, @unchecked Sendable {
    private var _state: AgentState = .idle
    private var _sessionId: String?
    private let queue = DispatchQueue(label: "com.tavern.MortalAgent")

    public var state: AgentState {
        queue.sync { _state }
    }
}
```

Agent state is not shared with other agents. Gandalf does not know Legolas's state. Only the coordinator (via registry queries) can see the full picture.


### Key Observations

1. **State flows upward** - Agents report to registry, registry reports to coordinator, coordinator reports to UI

2. **No peer communication** - Agents cannot discover or message each other directly

3. **Single point of query** - All system state questions are answered by coordinator/registry

4. **No replication** - State exists in exactly one place per data item

5. **No convergence mechanisms** - There is no concept of state eventually synchronizing across nodes


## What State Would Be Gossiped?

In a gossip architecture, every piece of shared state becomes gossip material. For Tavern:


### Agent Lifecycle State

```swift
struct AgentStateGossip: GossipPayload {
    let agentId: UUID
    let name: String
    let state: AgentState
    let assignment: String?
    let vectorClock: VectorClock
    let timestamp: Date
}
```

When Gandalf transitions from `.working` to `.done`, he creates an AgentStateGossip and sends it to random peers. Eventually, all agents and the UI learn Gandalf is done.


### Task Assignment State

```swift
struct TaskGossip: GossipPayload {
    let taskId: UUID
    let description: String
    let assignedTo: UUID?
    let status: TaskStatus // pending, claimed, completed, failed
    let vectorClock: VectorClock
}
```

When Jake assigns a task, he gossips TaskGossip with status `.pending`. When Gandalf claims it, he gossips with status `.claimed` and `assignedTo: gandalf.id`. Conflicts (two agents claim same task) are resolved by vector clock comparison.


### Commitment State

```swift
struct CommitmentGossip: GossipPayload {
    let commitmentId: UUID
    let agentId: UUID
    let description: String
    let assertion: String
    let status: CommitmentStatus // pending, passed, failed
    let verifiedBy: UUID?
    let vectorClock: VectorClock
}
```

Commitments are gossiped when created and when verified. Any agent can verify (run the assertion) and gossip the result. Conflicts between verification results are resolved by quorum or by preferring "failed" over "passed" (fail-safe).


### Agent Registry State

```swift
struct AgentRegistryGossip: GossipPayload {
    let knownAgents: [AgentSummary]
    let vectorClock: VectorClock
}

struct AgentSummary {
    let id: UUID
    let name: String
    let isAlive: Bool
    let lastSeen: Date
}
```

The registry is not central - it is the merged view of all AgentRegistryGossip received. When an agent spawns, it gossips its existence. When an agent is dismissed, it (or its parent) gossips the removal. The local view eventually matches reality.


### Question/Answer State

```swift
struct QuestionGossip: GossipPayload {
    let questionId: UUID
    let fromAgent: UUID
    let content: String
    let priority: QuestionPriority
    let answered: Bool
    let answer: String?
    let vectorClock: VectorClock
}
```

Questions raised by agents are gossiped upward (toward Jake and UI). Answers are gossiped back. The bubbling described in PRD Section 5.3 becomes gossip propagation with priority filtering.


### Discovery State

```swift
struct DiscoveryGossip: GossipPayload {
    let discoveryId: UUID
    let fromAgent: UUID
    let observation: String
    let context: String?
    let vectorClock: VectorClock
}
```

Discoveries (PRD Section 9.3) are naturally modeled as gossip. An agent notices something interesting and gossips it. Interested agents incorporate it. No special "discovery sharing" infrastructure needed.


## How Gossip Differs from Choreography (#28)

Gossip Protocol and Choreography are both decentralized patterns, but they differ fundamentally in mechanism and guarantees.


### Communication Model

**Choreography:**
- Publish/subscribe to an event bus
- Events have explicit topics/types
- Subscribers filter by event type
- Central event bus infrastructure (even if distributed)

**Gossip:**
- Direct peer-to-peer communication
- Random peer selection
- All state is potentially shared
- No central infrastructure at all


### State Management

**Choreography:**
- State is derived from event history
- Events are facts that happened
- "What is Gandalf's state?" = scan event history for Gandalf's events
- Requires event storage (event sourcing synergy)

**Gossip:**
- State is the merged result of gossip
- Gossip carries current state, not history
- "What is Gandalf's state?" = read local view (which gossip has converged)
- Requires conflict resolution (CRDTs, vector clocks)


### Consistency Guarantees

**Choreography:**
- Can achieve causal ordering via event bus
- Observers see consistent event sequences (within ordering guarantees)
- "Did A happen before B?" has deterministic answer

**Gossip:**
- Eventual consistency only
- Different observers may see different orderings
- "Did A happen before B?" depends on vector clock comparison
- Concurrent updates require conflict resolution


### Failure Modes

**Choreography:**
- Event bus failure = system stops receiving events
- Event loss = state divergence (if not durably stored)
- Single logical failure point (the bus)

**Gossip:**
- Any single failure = graceful degradation
- Message loss = temporary inconsistency, self-healing via future gossip
- No single failure point


### Implementation Complexity

**Choreography:**
- Simpler to reason about (follow the events)
- Easier debugging (event log shows what happened)
- Requires event bus infrastructure
- Event schema design is the main challenge

**Gossip:**
- Harder to reason about (convergence, clock drift)
- Harder debugging (why hasn't gossip converged?)
- No infrastructure requirements beyond peer messaging
- Conflict resolution design is the main challenge


### Jake's Role

**Choreography:**
- Jake is "first among equals"
- He publishes/subscribes like other agents
- No special authority, but can have special subscriptions

**Gossip:**
- Jake is just another peer
- He gossips and receives gossip like everyone
- Authority is truly dissolved - Jake's gossip is not privileged


### Summary Table

| Aspect | Choreography | Gossip Protocol |
|--------|--------------|-----------------|
| Communication | Pub/sub via bus | Direct peer-to-peer |
| State model | Event-derived | Merge-convergent |
| Consistency | Causal (achievable) | Eventual only |
| Ordering | Bus provides order | Vector clocks |
| Infrastructure | Event bus required | None required |
| Failure resilience | Bus is SPOF | No SPOF |
| Debugging | Follow events | Trace convergence |


## Mapping to PRD Requirements


### PRD Section 2: Invariants

| Invariant | Gossip Impact | Risk Level |
|-----------|---------------|------------|
| **Test suite must pass** | Gossip is testable but requires convergence assertions | Medium |
| **Every feature must be testable** | Testing eventual consistency is harder than strong consistency | High |
| **Commitments verified independently** | Critical: who verifies? No authority to trust | Critical |
| **User attention is sacred** | Gossip can surface attention-worthy events, but timing is non-deterministic | Medium |
| **Doc store is source of truth** | Tension: gossip means each node has its own truth | High |
| **Agents cannot modify their own invariants** | Gossip cannot enforce - any agent can gossip anything | Critical |
| **Failures must be visible** | Failure gossip spreads, but convergence delay means latency | Medium |
| **Original project files protected** | Unchanged - gossip is about state, not files | Low |


**Critical Concerns:**

1. **Commitment Verification** - The PRD states "Commitments must be verified independently." In gossip, there is no independent authority. Any agent could gossip "my commitment passed." Options:
   - Trust but verify: other agents re-run verification and gossip conflicts
   - Designated verifier: one agent (Jake?) has authority (reintroduces hierarchy)
   - Quorum: multiple verifiers, majority wins

2. **Invariant Enforcement** - "Agents cannot modify their own invariants" assumes a layer above agents that enforces rules. In pure gossip, there is no such layer. Mitigation: gossip includes proof (verification output), and receivers validate before accepting.


### PRD Section 4: Core Concepts

**Agent Types in Gossip:**

| Type | Gossip Role |
|------|-------------|
| **Jake** | High-connectivity peer; gossips frequently with all known agents |
| **Mortal** | Standard peer; gossips with random subset |
| **Drone** | Short-lived peer; gossips results before terminating |
| **Monitor Daemons** | Observer peers; receive gossip, rarely originate |

The hierarchy dissolves. Jake is not the "top-level coordinator" - he is a well-connected peer. His prominence comes from being the user-facing agent and having long lifetime, not from architectural privilege.


**Agent States in Gossip:**

States are gossiped, not queried:

```swift
// Current: query coordinator
coordinator.agentListViewModel.agents.first { $0.id == gandalf.id }?.state

// Gossip: read local convergent view
localView.agentState(gandalf.id) // may be stale
```

The state machine remains valid, but transitions are observed via gossip rather than direct property access.


### PRD Section 4.7: Deterministic Shell

This is the hardest requirement for gossip.

**PRD Text:** "Child works -> Independent assertion verifies commitments were met -> Only then is agent 'done'."

**Gossip Challenge:** There is no "independent" party. Everyone is a peer.

**Possible Solutions:**

**Option A: Self-verification with gossip audit**
```
Gandalf runs assertion locally
Gandalf gossips: CommitmentGossip(status: .passed, verifiedBy: gandalf.id)
Other agents can re-run and gossip disputes
```
Risk: Gandalf could lie. Other agents might not bother verifying.

**Option B: Verification daemon as special peer**
```
VerifierDaemon subscribes to CommitmentGossip(status: .pending)
Runs verification
Gossips: CommitmentGossip(status: .passed/failed, verifiedBy: verifier.id)
```
Reintroduces hierarchy (verifier has authority) but maintains gossip transport.

**Option C: Quorum verification**
```
Gandalf gossips: CommitmentGossip(status: .pending)
Multiple agents (Jake, Legolas, Gimli) run verification
Each gossips their result
Status = majority result
```
Truly decentralized but complex. What if agents are busy? What if they disagree?

**Recommendation:** Option B - a verification daemon provides the "independent" verification the PRD requires while using gossip for communication. This is a hybrid that preserves the key invariant.


### PRD Section 5.3: Bubbling

Bubbling in gossip becomes gossip with priority propagation:

```swift
struct QuestionGossip: GossipPayload {
    let priority: QuestionPriority
    let depth: Int // how far from user
    let agentId: UUID
    let parentId: UUID?
}
```

Agents gossip questions upward. Priority affects gossip frequency - high-priority questions are gossiped more often to more peers. Eventually questions reach Jake or the UI.

The challenge is latency. With choreography, a high-priority question immediately reaches all subscribers. With gossip, it propagates through rounds. For urgent questions, this delay may be unacceptable.

**Mitigation:** Direct path for critical messages. High-priority questions use direct messaging to Jake, bypassing random gossip. This is a pragmatic hybrid.


### PRD Section 9.3: Discovery Sharing

Discovery sharing is gossip's natural strength:

```swift
// Agent notices something interesting
let discovery = DiscoveryGossip(
    observation: "Found deprecated API in auth module",
    context: currentTask.id
)
gossip(discovery)
```

No special infrastructure. Discoveries spread epidemically. Interested agents incorporate them. This aligns perfectly with the PRD's vision of agents "noticing oddities and sharing them via messaging."


## Trade-offs Considered


### Consistency vs. Availability

**CAP Theorem Application:**

Gossip strongly favors availability and partition tolerance over consistency. During a partition:
- Choreography: partitioned agents may stop (if bus is in other partition)
- Gossip: partitioned agents continue operating with divergent state

For Tavern, this means agents can keep working even if Jake is unreachable. They gossip results to whoever is available. When Jake returns, gossip converges.

**Is this acceptable?**

For task execution: probably yes. An agent doing its job doesn't need up-to-the-millisecond knowledge of siblings.

For commitment verification: probably no. We need authoritative "done" status before reporting to user.

**Hybrid approach:** Use gossip for observational state (who is working on what) but require synchronous verification for completion claims.


### Complexity Cost

**Gossip Protocol Implementation Requirements:**

1. **Vector clocks** for causality tracking
   - Each gossip message carries a vector clock
   - Merging requires comparing/advancing clocks
   - Implementation: 200-300 lines of Swift

2. **Anti-entropy protocol** for convergence
   - Periodic full-state sync between peers
   - Detects missed gossip, repairs divergence
   - Implementation: 300-400 lines of Swift

3. **Failure detection** for peer liveness
   - Heartbeat gossip
   - Suspicion lists for unresponsive peers
   - Implementation: 200-300 lines of Swift

4. **Conflict resolution** for concurrent updates
   - Last-writer-wins (simple but lossy)
   - CRDTs (complex but correct)
   - Application-specific merging
   - Implementation: 400-800 lines depending on approach

5. **Peer discovery** for new agents
   - Bootstrap list of known peers
   - Gossip-based membership
   - Implementation: 200-300 lines of Swift

**Total estimate:** 1300-2100 lines of core gossip infrastructure before any Tavern-specific logic.

**Comparison to current approach:** The entire AgentRegistry is ~100 lines. SessionStore is ~120 lines. TavernCoordinator is ~145 lines. Gossip would be an order of magnitude more complex.


### Debugging and Observability

**Current debugging:**
```swift
// Simple: query coordinator
print(coordinator.agentListViewModel.agents)
print(coordinator.activeChatViewModel.messages)
```

**Gossip debugging:**
```swift
// Complex: inspect convergent state
print(localView.agents) // may differ from other nodes
print(localView.vectorClock) // why is this behind?
print(gossipLog.lastNMessages(100)) // trace what was received
```

Debugging gossip requires understanding:
- Vector clock comparison
- Convergence timing
- Gossip topology
- Message ordering

**Mitigation:** Build gossip visualization tools. Log all gossip. Create gossip replay debugger. The investment is substantial but the observability can be excellent.


### Performance Characteristics

**Message complexity:**
- O(N * log N) messages to propagate one update to N agents
- O(1) latency for local state read (no network)
- O(log N) rounds for convergence (random gossip)

**For Tavern scale (V1: <20 agents):**
- 20 * log(20) = ~86 messages per update
- Convergence in ~5 gossip rounds
- At 1 round/second: 5 second convergence

**For future scale (100 agents):**
- 100 * log(100) = ~664 messages per update
- Convergence in ~7 rounds
- At 1 round/second: 7 second convergence

The message count grows faster than linear, but convergence time grows logarithmically. This is gossip's strength at scale.


## Implementation Complexity


### Phase 1: Gossip Infrastructure (4-6 weeks)

Core protocol implementation:

```swift
protocol GossipPayload: Codable {
    var vectorClock: VectorClock { get }
    var sourceAgent: UUID { get }
}

class GossipNode {
    let id: UUID
    var peers: [UUID: GossipPeer]
    var vectorClock: VectorClock
    var localState: LocalGossipState

    func gossip<P: GossipPayload>(_ payload: P, to peerCount: Int)
    func receive<P: GossipPayload>(_ payload: P, from peer: UUID)
    func merge<P: GossipPayload>(_ payload: P)
}

struct VectorClock {
    var clocks: [UUID: UInt64]

    func increment(for agent: UUID) -> VectorClock
    func merge(with other: VectorClock) -> VectorClock
    func compare(to other: VectorClock) -> ClockComparison
}

enum ClockComparison {
    case before
    case after
    case concurrent
    case equal
}
```


### Phase 2: Gossip Message Types (2-3 weeks)

Define the gossip vocabulary:

```swift
struct AgentLifecycleGossip: GossipPayload {
    let agentId: UUID
    let name: String
    let state: AgentState
    let assignment: String?
    let isAlive: Bool
}

struct TaskGossip: GossipPayload {
    let taskId: UUID
    let description: String
    let status: TaskStatus
    let assignedTo: UUID?
}

struct CommitmentGossip: GossipPayload {
    let commitmentId: UUID
    let agentId: UUID
    let description: String
    let assertion: String
    let status: CommitmentStatus
    let verificationResult: VerificationResult?
}

struct HeartbeatGossip: GossipPayload {
    // For failure detection
}

struct MembershipGossip: GossipPayload {
    let knownPeers: [PeerInfo]
}
```


### Phase 3: State Convergence (3-4 weeks)

Build convergent state views:

```swift
class ConvergentStateView {
    private var agentStates: [UUID: AgentLifecycleGossip] = [:]
    private var tasks: [UUID: TaskGossip] = [:]
    private var commitments: [UUID: CommitmentGossip] = [:]

    func apply(_ gossip: GossipPayload) {
        switch gossip {
        case let agent as AgentLifecycleGossip:
            if shouldApply(agent, existing: agentStates[agent.agentId]) {
                agentStates[agent.agentId] = agent
            }
        case let task as TaskGossip:
            // Similar merge logic
        case let commitment as CommitmentGossip:
            // Similar merge logic
        }
    }

    private func shouldApply<G: GossipPayload>(_ new: G, existing: G?) -> Bool {
        guard let existing = existing else { return true }
        return new.vectorClock.compare(to: existing.vectorClock) == .after
    }
}
```


### Phase 4: Agent Integration (3-4 weeks)

Make agents gossip-aware:

```swift
class GossipAwareMortalAgent: Agent {
    let gossipNode: GossipNode
    let stateView: ConvergentStateView

    private var _state: AgentState = .idle {
        didSet {
            gossipNode.gossip(AgentLifecycleGossip(
                agentId: id,
                name: name,
                state: _state,
                assignment: assignment,
                isAlive: true
            ), to: 3)
        }
    }

    func send(_ message: String) async throws -> String {
        _state = .working
        defer { updateStateFromResponse() }
        // ... existing send logic
    }
}
```


### Phase 5: Jake as Gossip Peer (2-3 weeks)

Transform Jake from coordinator to gossip peer:

```swift
class GossipAwareJake: Agent {
    let gossipNode: GossipNode
    let stateView: ConvergentStateView

    // Jake maintains same character, but learns state via gossip
    var knownAgents: [AgentLifecycleGossip] {
        stateView.allAgentStates
    }

    // Jake still initiates tasks, but gossips instead of directing
    func initiateTask(_ description: String) {
        let task = TaskGossip(
            taskId: UUID(),
            description: description,
            status: .pending,
            assignedTo: nil
        )
        gossipNode.gossip(task, to: 5)
        // Does NOT spawn agent directly
        // Agents see task gossip and self-assign
    }
}
```


### Phase 6: UI Gossip Integration (2-3 weeks)

UI subscribes to gossip:

```swift
class GossipBackedViewModel: ObservableObject {
    let gossipSubscription: GossipSubscription
    @Published var agents: [AgentSummary] = []

    init(gossipNode: GossipNode) {
        gossipSubscription = gossipNode.subscribe(to: AgentLifecycleGossip.self) { [weak self] gossip in
            DispatchQueue.main.async {
                self?.updateAgents(from: gossip)
            }
        }
    }

    private func updateAgents(from gossip: AgentLifecycleGossip) {
        if let idx = agents.firstIndex(where: { $0.id == gossip.agentId }) {
            agents[idx] = AgentSummary(from: gossip)
        } else if gossip.isAlive {
            agents.append(AgentSummary(from: gossip))
        }
    }
}
```


### Phase 7: Verification Daemon (2-3 weeks)

Special-purpose verifier:

```swift
class VerificationDaemon {
    let gossipNode: GossipNode

    func start() {
        gossipNode.subscribe(to: CommitmentGossip.self) { [self] gossip in
            if gossip.status == .pending {
                Task { await verify(gossip) }
            }
        }
    }

    private func verify(_ commitment: CommitmentGossip) async {
        let result = await runAssertion(commitment.assertion)
        let verification = CommitmentGossip(
            commitmentId: commitment.commitmentId,
            agentId: commitment.agentId,
            description: commitment.description,
            assertion: commitment.assertion,
            status: result ? .passed : .failed,
            verificationResult: VerificationResult(by: id, at: Date())
        )
        gossipNode.gossip(verification, to: 5)
    }
}
```


### Total Estimate: 18-26 weeks

This is the most complex architecture proposal reviewed. The investment is significant, justified only if:
- Fault tolerance is truly critical
- Scale to many agents is certain
- The team has distributed systems expertise


## Migration Path from Current State


### Step 1: Add Gossip Infrastructure (Parallel)

Build gossip layer without changing existing code:

```swift
// New module: TavernGossip
class TavernGossipNode { ... }
class ConvergentStateView { ... }
```

No existing code touched yet.


### Step 2: Shadow Gossip

Publish gossip alongside existing operations:

```swift
// In TavernCoordinator.spawnAgent
let agent = try spawner.spawn(assignment: assignment)
// Existing code continues to work

// Shadow: also gossip the event
gossipNode.gossip(AgentLifecycleGossip(
    agentId: agent.id,
    name: agent.name,
    state: .idle,
    assignment: assignment,
    isAlive: true
), to: 3)
```

Gossip is informational. Registry remains authoritative.


### Step 3: Verify Convergence

Build assertions that gossip matches registry:

```swift
// After each operation, verify gossip-derived state matches registry
func assertStateConsistency() {
    let registryAgents = Set(registry.allAgents().map { $0.id })
    let gossipAgents = Set(stateView.allAgentStates.map { $0.agentId })

    // Allow brief divergence
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        assert(registryAgents == gossipAgents, "Gossip divergence detected")
    }
}
```


### Step 4: Dual-Read

Read from both sources, compare:

```swift
var agents: [AgentSummary] {
    let registryAgents = registry.allAgents().map { AgentSummary(from: $0) }
    let gossipAgents = stateView.allAgentStates.map { AgentSummary(from: $0) }

    // Log divergences
    if registryAgents != gossipAgents {
        logger.warning("State divergence: registry=\(registryAgents), gossip=\(gossipAgents)")
    }

    // Still return registry as authoritative
    return registryAgents
}
```


### Step 5: Gossip Primary for Reads

Switch reads to gossip, registry for writes:

```swift
var agents: [AgentSummary] {
    // Now reading from gossip
    stateView.allAgentStates.map { AgentSummary(from: $0) }
}

func spawnAgent() throws {
    // Still writing to registry (for now)
    let agent = try spawner.spawn(assignment: assignment)
    // Gossip propagates it
}
```


### Step 6: Gossip Primary for Writes

Spawn via gossip, let agents self-register:

```swift
func requestTask(_ description: String) {
    // No direct spawn
    gossipNode.gossip(TaskGossip(status: .pending, description: description), to: 5)

    // Somewhere, an agent sees this and claims it
    // Agent gossips AgentLifecycleGossip to announce itself
}
```


### Step 7: Remove Registry

Registry becomes derived view from gossip:

```swift
var registry: ConvergentStateView {
    gossipNode.stateView
}
```

The central registry is gone. State is fully gossip-derived.


### Rollback Strategy

At each step, the old path exists. Rollback:

1. Disable gossip subscriptions
2. Restore registry as authority
3. Gossip becomes audit log

The dual-path approach enables safe experimentation.


## Open Questions


### Gossip Frequency

How often should agents gossip?

- **Too frequent:** Network saturation, battery drain (mobile future?)
- **Too infrequent:** Slow convergence, stale views

Recommendation: Adaptive gossiping. Gossip more frequently when state changes, less when stable. 1 round/second baseline, up to 10 rounds/second during activity.


### Peer Selection

How do agents choose gossip targets?

- **Random:** Simple, good distribution, no topology knowledge needed
- **Weighted:** Prefer Jake, prefer active agents, prefer recently-uncontacted
- **Topology-aware:** Cluster agents by project, prefer same-cluster

Recommendation: Start with random. Add weighting for Jake (always gossip to Jake if known). Consider topology for multi-project future.


### State Retention

How much history do agents keep?

- **Current state only:** Minimal memory, but can't answer "what happened?"
- **Recent history:** Last N gossips, enables debugging
- **Full history:** Complete log, enables replay

Recommendation: Keep last 1000 gossips per type. Compact to current state after that. Persist to disk for recovery.


### Clock Synchronization

What if agent clocks drift?

- **Vector clocks:** No physical time dependency (correct)
- **Hybrid clocks:** Physical + logical (easier debugging)
- **Require NTP:** Assume synchronized clocks (fragile)

Recommendation: Vector clocks for correctness. Add wall-clock timestamp for debugging/display only.


### Failure Recovery

What happens when an agent restarts?

- **Amnesia:** Start fresh, gossip that agent is new
- **Persistence:** Restore state from disk, resume gossiping
- **Peer sync:** Ask peers for full state (anti-entropy)

Recommendation: Persist state. On restart, run anti-entropy with any reachable peer.


### Network Assumptions

What network conditions must hold?

- **Fully connected:** Every agent can reach every agent (simplest)
- **Sparse:** Agents know limited peers, gossip transitively
- **Partitionable:** Network may split, must handle

Recommendation: Design for partitionable. Gossip via known peers. Handle temporary unreachability gracefully.


## Comparison with Related Architectures


### vs. Choreography (#28)

See detailed comparison section above. Key difference: Choreography uses pub/sub over an event bus; Gossip uses peer-to-peer epidemic spreading. Choreography can achieve causal ordering; Gossip is eventually consistent.


### vs. Event Sourcing (#05)

Event Sourcing stores events as the source of truth. Gossip spreads current state, not history.

- Event Sourcing: "Replay events to derive state"
- Gossip: "Merge gossip to converge on state"

They can combine: gossip events (not state), and receivers build local event logs. This gives both eventual consistency and replay capability.


### vs. Distributed-First (#17)

Distributed-First assumes network infrastructure (message queues, service discovery). Gossip requires only peer-to-peer messaging.

- Distributed-First: "Design for multi-machine with proper infrastructure"
- Gossip: "Design for multi-machine with minimal infrastructure"

Gossip is more resilient (no infrastructure to fail) but less capable (no ordering guarantees, no reliable delivery).


### vs. Actor Model (#02)

Actor Model uses message passing with explicit recipients. Gossip uses random recipients.

- Actor Model: "Send message to actor X"
- Gossip: "Tell someone, they'll tell others"

Actors can implement gossip by having a "gossip actor" that receives updates and randomly forwards them.


### vs. Blackboard (#06)

Blackboard is a shared knowledge base all agents read/write. Gossip distributes the blackboard across agents.

- Blackboard: "Central shared state"
- Gossip: "Distributed convergent state"

Gossip is a blackboard without the central store - each agent has a local view that converges with others.


## Conclusion

Gossip Protocol architecture represents the extreme end of decentralization. It eliminates all central points of failure and coordination, achieving remarkable resilience through epidemic state propagation. This comes at significant cost: eventual consistency only, complex implementation, challenging debugging, and dissolution of hierarchical authority.


### Arguments For Gossip Protocol

1. **Maximum fault tolerance** - No single failure can bring down the system

2. **Natural fit for discovery sharing** - PRD Section 9.3's vision of agents sharing observations is exactly what gossip does

3. **True horizontal scalability** - Adding agents adds gossip capacity, not coordinator load

4. **Network partition resilience** - Partitioned groups continue operating, converge when healed

5. **Simplicity of individual agents** - Each agent follows same simple protocol


### Arguments Against Gossip Protocol

1. **PRD verification invariant** - "Commitments must be verified independently" requires authority that gossip dissolves

2. **Jake's character** - "The Proprietor" implies control; gossip makes him just another peer

3. **Implementation complexity** - 18-26 weeks vs 3-4 weeks for simpler architectures

4. **Debugging overhead** - Requires new tools, new mental models, new skills

5. **Eventual consistency limitations** - Some operations (verification, user notification) need stronger guarantees

6. **Overkill for V1 scale** - 10-20 agents don't need gossip's scalability; they need simplicity


### Recommendation

**For V1:** Do not adopt gossip protocol. The implementation cost is too high, the PRD's hierarchical model is a better fit, and V1's scale does not require gossip's resilience.

**For V2+ with scale requirements:** Consider a hybrid approach:
- Core operations (spawn, verify, complete) remain coordinated
- Observational state (who is working on what) uses gossip
- Discovery sharing uses gossip
- Verification uses a designated daemon with gossip transport

**Key insight:** Gossip is best suited for systems that truly need partition tolerance and can accept eventual consistency. Tavern's current requirements - hierarchical control, deterministic verification, Jake's authoritative character - are better served by architectures that provide stronger consistency guarantees with centralized or semi-centralized coordination.

If future requirements include running agents across unreliable networks (cloud, container mesh, mobile), gossip becomes more attractive. The migration path allows gradual adoption: shadow gossip first, then dual-read, then gossip-primary for reads, and finally full gossip only if proven valuable.
