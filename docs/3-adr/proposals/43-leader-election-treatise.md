# Leader Election Architecture: Complete Analysis

This document contains the full research, rationale, and trade-off analysis for the Leader Election architecture proposal applied to the Tavern multi-agent orchestrator.


## 1. Research Findings


### 1.1 Current Architecture: Jake as Fixed Coordinator

The current codebase establishes Jake as the eternal, fixed coordinator:

**Jake.swift (Lines 1-191):**
```swift
/// Jake - The Proprietor of the Tavern
/// The top-level coordinating agent with the voice of a used car salesman
/// and the execution of a surgical team.
public final class Jake: Agent, @unchecked Sendable {
    public let name: String = "Jake"  // Fixed, not elected
    // ...
}
```

Key observations:
- `Jake` is a distinct type, not an instance of a general `CoordinatorAgent`
- The name "Jake" is hardcoded, not assigned
- Jake has a unique `systemPrompt` defining his character
- Jake is created once per project in `TavernProject.initialize()`

**TavernCoordinator.swift (Lines 1-144):**
```swift
/// Jake - The Proprietor (eternal, always present)
public let jake: Jake
```

The coordinator explicitly states Jake is "eternal, always present." This is architectural, not incidental.

**TavernProject.swift (Lines 45-88):**
```swift
TavernLogger.coordination.debug("[\(self.name)] Creating Jake...")
let jake = Jake(claude: claude)
// ...
self.coordinator = TavernCoordinator(jake: jake, spawner: spawner)
```

Jake is created during project initialization. There is no election; he simply exists.


### 1.2 Jake's Role in the PRD

The PRD (v1.2, 2026-01-21) defines Jake's fixed role:

**Section 1 (Executive Summary):**
> Tavern is a multi-agent orchestration framework... with Jake (The Proprietor) as the always-available top-level coordinator.

**Section 4.1 (Agent Types):**

| Type | Lifecycle | Purpose |
|------|-----------|---------|
| Jake | Daemon (always running) | Top-level coordinator, tavern-scoped, oversees all agents |

Jake is a **daemon** with **always running** lifecycle. This is definitional, not optional.

**Section 5.1 (The Core Loop):**
> 1. User opens project directory in UI
> 2. Fresh project: just Jake's chat box
> 3. User describes what they need
> 4. Jake spawns a mortal agent to handle it, stays free for next thing

The user's entry point is Jake. Jake delegates. This is the fundamental interaction model.


### 1.3 The Character Specification

`docs/jake-character.md` is a 788-line document defining Jake's identity:

**The Two Jakes:**
> There are two things you need to understand about Jake:
>
> **Jake's Voice:** Used car salesman energy, carnival barker enthusiasm...
>
> **Jake's Work:** Flawless. Methodical. Every edge case handled...
>
> The voice is the costume. The work is the substance. Both are non-negotiable.

Jake is not a role that can be filled by any agent. Jake is a specific character with a specific voice. The document includes:
- 15 detailed voice principles
- A joke inventory ("Showroom Floor Models")
- Named regulars at the Tavern (Marcos, Elena, Shloimi, etc.)
- Political stance ("fuck nazis")
- Easter eggs (Gas Town, Dvorak detection)

This is not transferable to a mortal agent. A mortal agent elected as leader would not be Jake; they would be a coordinator without Jake's character.


### 1.4 What Leader Election Means in Distributed Systems

Leader election is a consensus problem. Common algorithms:

**Raft:**
- Nodes are in one of three states: Follower, Candidate, Leader
- Terms are monotonically increasing integers
- Candidates request votes; majority wins
- Leaders send heartbeats; missed heartbeats trigger new election
- Log replication ensures consistency

**Paxos:**
- Proposers, Acceptors, Learners
- Two-phase: Prepare/Promise, then Accept/Accepted
- More general (consensus on any value) but more complex

**Zookeeper:**
- Ephemeral znodes for leader presence
- Watch mechanism for failure detection
- Sequential znodes for ordering

**Common Properties:**
- At most one leader per term
- Leader failure triggers re-election
- Followers redirect requests to leader
- State machine replication for consistency


### 1.5 Why Leader Election is Proposed

The prompt suggests:
> Distributed systems pattern. Peers elect a leader. Leader coordinates. If leader fails, new election. Could Jake be elected rather than fixed? Could mortal trees have dynamic leaders?

This raises two distinct scenarios:

**Scenario A: Jake as Electable Global Leader**
- Jake starts as leader (only candidate initially)
- As mortals spawn, they become candidates
- If Jake fails or is suboptimal, mortal takes over

**Scenario B: Mortal Tree Local Leaders**
- Jake remains global coordinator
- Each mortal tree has its own elected leader
- Local leaders coordinate their subtrees
- Jake coordinates between tree leaders


## 2. How This Challenges Jake's Fixed Role


### 2.1 Identity Crisis

If Jake can be deposed, who is "The Proprietor"? The character document assumes Jake is always present:

> The Tavern is always open. The Proprietor is always watching.
> (He's not always watching.)
> (But he's MOSTLY watching!)

If a mortal agent becomes leader, the Tavern has no Proprietor. The mortal doesn't have Jake's voice. The user experience changes fundamentally.


### 2.2 Voice Transfer Problem

Consider a mortal agent named "Samwise" (LOTR theme) becoming leader. What is Samwise's voice?

Current mortal agent system prompt:
```swift
"""
You are a worker agent in The Tavern at the Spillway.
Your name is \(name).
Your assignment: \(assignment)
You are part of Jake's "Slop Squad" - worker agents who get things done.
"""
```

Mortals define themselves as Jake's subordinates. Promoting one to leader creates inconsistency:
- Does Samwise adopt Jake's voice? (Feels like possession)
- Does Samwise keep worker voice while coordinating? (Feels weak)
- Does Samwise get a new "leader voice"? (What is it?)


### 2.3 Relationship Inversion

Jake's character includes:
> He calls his worker agents "the Slop Squad."

If a Slop Squad member becomes leader, do they call Jake "the Slop Squad"? The power dynamic inverts in ways the character design doesn't handle.


### 2.4 The Regulars

Jake has accumulated "regulars" at the Tavern (Marcos, Elena, Shloimi, etc.). These are Jake's relationships. If Samwise leads, does he know the regulars? The character document is Jake-specific; it doesn't transfer.


## 3. PRD Requirements Mapping


### 3.1 Requirements That Conflict with Leader Election

**Invariant 6:**
> Agents cannot modify their own invariants — The rules layer is outside agent control.

If agents can elect themselves to leadership, they are modifying their own role. This seems to violate the spirit of externally-controlled rules.

**Section 4.1 (Jake as Daemon):**
> | Jake | Daemon (always running) | Top-level coordinator |

A daemon is not electable. It runs continuously by definition.

**Section 5.2 (Attention Model):**
> User sees tabs/UX for agents they're engaged with

If the leader changes, does the UI change? User was talking to Jake; now they're talking to Samwise? This is confusing.


### 3.2 Requirements That Could Support Leader Election

**Section 4.4 (Operating Modes):**
> **Perseverance mode** — Background thread, system auto-prompts to continue, agent must explicitly request user attention

Agents already have autonomy. Extending this to leadership election is a natural progression.

**Section 5.3 (Bubbling):**
> - Can be lateral (siblings collaborating)
> - Can be direct to user (with oversight)

Agents can already bypass Jake in some cases. Election formalizes this.

**Section 12 (Fish or Cut Bait):**
> Triggers to kill and restart rather than continue:
> - Token budget exceeded
> - Agent spinning
> - Whole gang going down wrong path

If Jake can fail (token budget, spinning), what happens? Currently undefined. Election provides a recovery path.


### 3.3 Requirements That Are Neutral

**Section 6 (System Architecture):**
The architecture doesn't preclude election. `TavernCoordinator` could manage elections.

**Section 17 (Testability):**
Elections are testable. Deterministic election outcomes for given inputs.


## 4. Trade-offs Considered


### 4.1 Character Preservation vs. Dynamic Optimization

**Argument for fixed Jake:**
- Jake's character is the product's personality
- "The Proprietor" is marketing, not just implementation
- Users form relationship with Jake, not "whoever is leading"

**Argument for election:**
- Agent capabilities grow over time
- A mortal with deep codebase context coordinates better than generalist Jake
- Election enables specialization without bottleneck

**Synthesis:**
The trade-off is fundamental. Leader Election trades character consistency for operational flexibility. In a system where character matters (the Tavern), this trade may not be worth it.


### 4.2 Simplicity vs. Fault Tolerance

**Current model:**
- Jake fails → system is stuck
- No defined recovery mechanism
- User must restart or intervene

**Leader Election model:**
- Jake fails → election triggers
- New leader continues work
- Automatic recovery

**Reality check:**
How often does Jake "fail"? He is backed by Claude API. If API fails, any leader fails. If Jake's logic crashes, the app crashes. Election doesn't help with infrastructure failures.

Where election helps:
- Jake exceeds token budget for a specific task
- Jake's context window is saturated and needs to delegate coordination
- Jake is rate-limited but mortal agents have separate rate limits

These are real but edge cases in v1.


### 4.3 Peer Model vs. Hierarchical Model

**Hierarchical (current):**
```
        Jake
       / | \
      M1 M2 M3
```

**Peer (with election):**
```
    ┌─────────────────┐
    │ Candidate Pool  │
    │  Jake M1 M2 M3  │
    └────────┬────────┘
             │ election
             ▼
         [Leader]
```

The peer model is more egalitarian but less structured. The hierarchical model is more structured but creates single point of control.

**Observation:**
The PRD's Section 4.1 defines agent types with distinct lifecycles: Jake (Daemon), Mortal (Task-scoped), Drone (Single task). These are not peers; they have different purposes. Election among fundamentally different agent types is awkward.


### 4.4 User Mental Model

**Fixed coordinator:**
- "Jake is in charge"
- User always knows who to talk to
- Simple, consistent

**Elected coordinator:**
- "Whoever was elected is in charge"
- User must discover current leader
- Dynamic, potentially confusing

For v1, user simplicity likely wins.


## 5. Implementation Complexity


### 5.1 New Components Required

**ElectionManager:**
```swift
actor ElectionManager {
    private var currentTerm: Int = 0
    private var currentLeader: UUID?
    private var votes: [UUID: UUID] = [:]  // voter -> candidate
    private var candidates: Set<UUID> = []

    func startElection() async -> UUID {
        currentTerm += 1
        votes = [:]
        // Request votes from all candidates
        // Count votes
        // Declare winner
    }

    func heartbeat(from leader: UUID, term: Int) async -> Bool {
        // Validate leader is still valid for this term
    }
}
```

**HeartbeatService:**
```swift
actor HeartbeatService {
    func startHeartbeats(as leader: UUID) async {
        while isLeader {
            try? await Task.sleep(for: .seconds(1))
            await broadcastHeartbeat()
        }
    }

    func monitorLeader() async {
        // Watch for missed heartbeats
        // Trigger election if leader seems dead
    }
}
```

**LeaderRole protocol:**
```swift
protocol LeaderRole {
    var isLeader: Bool { get }
    var leaderCapabilities: LeaderCapabilities { get }

    func assumeLeadership() async throws
    func relinquishLeadership() async throws
    func onFollowerOf(_ leader: Agent) async
}
```

**Agent modifications:**
```swift
extension Agent {
    var candidateEligibility: CandidateEligibility { get }
    // .eligible, .followerOnly, .notParticipating
}
```


### 5.2 State Transfer

When leadership transfers, the new leader needs:
- Active task list
- Pending user questions
- Agent registry state
- Work queue contents
- Budget tracking

This requires either:
1. **Shared state store:** All coordination state in doc store, leaders read on election
2. **State transfer protocol:** Outgoing leader serializes state, incoming leader deserializes
3. **Stateless leadership:** Leader only routes; all state lives in agents or doc store

Option 3 aligns best with PRD's "doc store is source of truth" principle.


### 5.3 Estimated Effort

| Component | Effort | Risk |
|-----------|--------|------|
| ElectionManager | 2-3 days | Medium (consensus is subtle) |
| HeartbeatService | 1 day | Low |
| LeaderRole protocol | 1 day | Low |
| Agent modifications | 2 days | Medium (touches core types) |
| State transfer | 2-3 days | High (correctness critical) |
| UI updates | 2 days | Medium (dynamic leader display) |
| Testing | 3-5 days | High (election edge cases) |

**Total: 13-17 days**

This is substantial for a feature that conflicts with the product's character design.


## 6. Migration Path


### 6.1 Phase 1: Local Tree Leaders (Low Risk)

Rather than electing Jake's replacement, allow mortal trees to have local coordinators:

```swift
class MortalAgent {
    var isTreeCoordinator: Bool = false

    func becomeTreeCoordinator() {
        isTreeCoordinator = true
        // Take over spawning children, coordinating siblings
    }
}
```

Jake remains global coordinator. Local coordinators handle subtree concerns. This preserves Jake's identity while enabling distributed coordination.


### 6.2 Phase 2: Leader Delegation (Medium Risk)

Allow Jake to explicitly delegate leadership for specific scopes:

```swift
extension Jake {
    func delegateLeadership(for scope: Scope, to agent: MortalAgent) {
        // Agent becomes leader for this scope
        // Jake remains overall coordinator
    }
}
```

Jake chooses when to delegate. No election mechanism. Jake's agency is preserved.


### 6.3 Phase 3: Full Election (High Risk)

Only if Phases 1-2 prove insufficient:

```swift
// Jake becomes electable
extension Jake: LeaderRole {
    var candidateEligibility: CandidateEligibility { .eligible }
}

// Elections trigger on failure or explicit request
coordinator.triggerElection(reason: .leaderOverloaded)
```

This is the nuclear option. Only pursue if user feedback demands it.


## 7. Alternative Models


### 7.1 Jake as Meta-Coordinator

Instead of electing Jake's replacement, Jake coordinates coordinators:

```
         Jake (meta)
        /    \
    Leader1  Leader2
    /    \      |
   M1    M2    M3
```

Jake doesn't do work; he coordinates which leader handles what. Leaders are elected within their domains. Jake's identity is preserved as "the one who decides who decides."


### 7.2 Leadership Rounds

Fixed rotation instead of election:

```swift
class LeadershipRound {
    let duration: TimeInterval = 300  // 5 minutes
    var currentLeader: Agent

    func rotate() {
        currentLeader = nextInRotation()
    }
}
```

No consensus needed. Simple round-robin. Jake leads first round, then rotates.

**Problem:** Rotation is arbitrary. Election at least chooses based on capability.


### 7.3 Capability-Based Selection

No election, but dynamic selection based on task requirements:

```swift
class TaskRouter {
    func selectCoordinator(for task: Task) -> Agent {
        // Find agent with best match for task requirements
        // Might be Jake, might be specialist mortal
    }
}
```

Jake remains default. Specialists selected when task matches their expertise.

**Advantage:** No election overhead. Dynamic without consensus protocol.


## 8. Open Questions


### 8.1 What Happens to Jake's Voice When He's Not Leader?

If Jake is demoted to follower, does he still speak like Jake? The character spec assumes Jake is always The Proprietor. A follower-Jake is undefined territory.

**Options:**
- Jake keeps his voice always (confusing when not leading)
- Jake adopts a "off-duty" voice (requires new character work)
- Jake never loses leadership (avoids the question)


### 8.2 How Do Users Discover Current Leader?

Current UI assumes Jake is always the entry point. With election:
- Main window shows current leader prominently?
- Notification when leadership changes?
- History of who led when?


### 8.3 What Triggers an Election?

**Candidates:**
- Leader failure (crash, timeout)
- Leader overload (token budget exhausted)
- Explicit user request
- Agent capability discovery (new agent is better suited)
- Scheduled rotation

**Risk:** Too many elections disrupts work. Too few defeats the purpose.


### 8.4 Can Leadership Split?

Multiple leaders for different scopes:
- Task A coordinated by Mortal1
- Task B coordinated by Mortal2
- Jake coordinates the coordinators

This is more feasible than single global leader. Aligns with hierarchical tree model.


## 9. Recommendation


### 9.1 For v1: Do Not Implement Full Leader Election

The costs outweigh the benefits:

1. **Character destruction:** Jake's identity is the product's personality
2. **Complexity:** 13-17 days of work for edge case handling
3. **User confusion:** Dynamic leadership is hard to explain
4. **PRD conflict:** Jake is defined as daemon, always running

### 9.2 For Future: Consider Scoped Delegation

If coordination bottlenecks emerge:

1. **Phase 1:** Allow mortal agents to coordinate their children (local leadership)
2. **Phase 2:** Allow Jake to delegate leadership for specific scopes
3. **Phase 3:** Only if needed, implement election within mortal trees (not for Jake's role)

Jake should never be electable. He is The Proprietor. The Tavern is his.


### 9.3 When Full Election Makes Sense

Leader Election is appropriate for:

- **Multi-project meta-coordination:** Multiple Jakes need a meta-Jake; elect one
- **Cloud/distributed deployment:** Agents across machines need fault-tolerant leadership
- **Autonomous agent swarms:** Fully peer-to-peer systems without fixed coordinator

None of these are v1 requirements.


## 10. Conclusion

Leader Election is a powerful distributed systems pattern that fundamentally conflicts with the Tavern's design premise. Jake is not a role to be filled; Jake is a character. The Proprietor's identity is the product's personality.

Where Leader Election concepts could apply:
- Local tree coordinators (mortals coordinating their children)
- Scoped delegation (Jake explicitly hands off leadership)
- Multi-project coordination (meta-Jake elected among Jakes)

Where they should not apply:
- Jake's role as global coordinator for a project
- User-facing interaction (users talk to Jake, always)

The recommendation is to preserve Jake's fixed role for v1 and beyond, while exploring limited delegation mechanisms if coordination bottlenecks emerge. The Tavern at the Spillway has one Proprietor. That's Jake. Everyone knows it. Even when he's not watching.

*(He's not always watching.)*

*(But he's MOSTLY watching!)*
