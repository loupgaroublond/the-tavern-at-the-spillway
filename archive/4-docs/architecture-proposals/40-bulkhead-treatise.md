# Bulkhead Pattern Architecture: Complete Analysis

This document contains the full analysis and reasoning behind the Bulkhead architectural proposal for The Tavern at the Spillway.


## Research Findings


### Origin and Concept

The Bulkhead pattern originates from ship construction. Ships are divided into watertight compartments (bulkheads) so that if the hull is breached in one section, water floods only that compartment rather than the entire vessel. The Titanic famously had bulkheads, but they did not extend high enough - water overflowed from one compartment to the next.

In software, bulkheads serve the same purpose: isolate components so that failure in one does not cascade to others. The pattern is widely used in:

- **Microservices**: Thread pools per service prevent one slow service from exhausting threads for all
- **Cloud platforms**: Resource quotas per tenant prevent noisy neighbors
- **Databases**: Connection pools per application prevent one app from monopolizing connections
- **Kubernetes**: Resource requests/limits per pod prevent container resource starvation


### Current Codebase State

Reviewing the Tavern implementation reveals the following relevant structure:

**Project Isolation (Partial):**
- `TavernProject` represents an open project with its own `rootURL`
- Each project creates its own `ClaudeCode` instance via `createClaudeCode(for:)`
- Each project has its own `TavernCoordinator`, `Jake`, and `AgentSpawner`
- `ProjectManager` tracks multiple open projects

This provides some natural isolation - projects have separate coordinators. However:
- No resource limits are enforced per project
- All projects share the same API credentials and rate limits
- No mechanism prevents one project from consuming all tokens

**Agent Isolation (Minimal):**
- Agents use `DispatchQueue` for thread-safe property access
- Each agent has its own `ClaudeCode` instance (created by spawner)
- `AgentRegistry` is a flat collection within a project
- No token budgets or timeouts on individual agents

**Thread Model:**
- `TavernCoordinator`, `ChatViewModel`, `AgentListViewModel` are `@MainActor`
- Agent operations are async but not isolated from each other
- No explicit thread pools or executors per component

**Existing Failure Handling:**
- `TavernError.sessionCorrupt` for session issues
- `AgentRegistryError` for registry operations
- Errors propagate to callers; no containment
- Logging via `TavernLogger` categories


### PRD Requirements Analysis

**Section 4.6 - Sandbox Primitives:**

The PRD defines five orthogonal sandbox primitives:

1. **Changeset** - Overlay filesystem, protects original project
2. **Platform** - Where agent runs (Mac, container, cloud)
3. **Isolation** - VMs, containers, OS sandboxes
4. **Outputs** - Network access control
5. **Software** - OS choice

These primitives describe *what* to isolate. The Bulkhead pattern describes *how* to enforce isolation boundaries and manage resources within those boundaries.

**Section 12 - Fish or Cut Bait:**

PRD triggers for termination:
- Token budget exceeded
- Changeset is totally wrong
- Agent spinning
- Whole gang going down wrong path

Bulkheads define the containment boundary for "cutting bait." When you reap an agent, its bulkhead ensures the damage doesn't spread. When you reap a whole gang, the project bulkhead ensures other projects continue unaffected.

**Section 16 - Violation Monitoring:**

Configurable rules with responses: log, notify, pause, reap, warn.

Bulkheads provide the enforcement mechanism for violations related to resource consumption:
- "Exceeding token budgets" - enforced by agent bulkhead
- "Spawning more than N children" - enforced by project bulkhead
- "Accessing network when disallowed" - enforced by isolation bulkhead

**Section 21 - Performance Requirements:**

"Isolation - No operation may impact unrelated parts of the app. A search over massive history cannot cause scroll jank. A runaway agent cannot freeze the coordinator."

This is a direct statement of the Bulkhead principle. The PRD already demands isolation; the pattern provides the implementation approach.


### Relationship to Supervisor Trees

The Supervisor Trees proposal (04-supervisor-trees) focuses on *recovery* from failure. The Bulkhead pattern focuses on *containment* of failure. They are complementary:

| Aspect | Supervisor Trees | Bulkheads |
|--------|-----------------|-----------|
| Primary concern | Recovery | Containment |
| When triggered | After failure | Before/during failure |
| Action taken | Restart component | Limit blast radius |
| State management | Checkpoint/restore | Resource accounting |
| Hierarchy | Supervision tree | Isolation domains |

**Combined usage:**
1. Bulkhead detects agent exceeding token budget
2. Bulkhead prevents the agent from consuming more
3. Bulkhead notifies supervisor of violation
4. Supervisor decides: restart, escalate, or reap
5. If reaped, bulkhead releases resources back to pool


## What Are the Bulkheads?

Three primary bulkhead levels make sense for Tavern:


### Level 1: Project Bulkhead

Each `TavernProject` gets its own resource compartment:

```swift
struct ProjectBulkhead {
    let projectId: UUID

    // Resource limits
    let maxTokensPerHour: Int
    let maxConcurrentAgents: Int
    let maxPendingMessages: Int

    // Current usage
    private var tokensUsedThisHour: Int = 0
    private var activeAgentCount: Int = 0
    private var pendingMessageCount: Int = 0

    // Circuit breaker state
    private var circuitState: CircuitState = .closed

    func acquireAgentSlot() throws {
        guard activeAgentCount < maxConcurrentAgents else {
            throw BulkheadError.agentLimitExceeded(current: activeAgentCount, max: maxConcurrentAgents)
        }
        // ...
    }

    func consumeTokens(_ count: Int) throws {
        guard tokensUsedThisHour + count <= maxTokensPerHour else {
            throw BulkheadError.tokenBudgetExceeded(used: tokensUsedThisHour, requested: count, max: maxTokensPerHour)
        }
        // ...
    }
}
```

**What this protects:**
- Project A cannot exhaust API quota, starving Project B
- Project A cannot spawn unlimited agents, exhausting memory
- One project's slow operations cannot block another

**Trade-offs:**
- Requires per-project configuration (or sensible defaults)
- May leave capacity unused if one project is idle
- Need to handle "project needs more resources" gracefully


### Level 2: Agent Bulkhead

Each agent (mortal, drone) gets its own mini-compartment within the project:

```swift
struct AgentBulkhead {
    let agentId: UUID
    let parentProjectBulkhead: ProjectBulkhead

    // Per-agent limits (subset of project budget)
    let tokenBudget: Int  // Total for this agent's lifetime
    let maxOperationTimeout: Duration
    let maxChildAgents: Int

    // Current usage
    private var tokensConsumed: Int = 0
    private var operationStartTime: ContinuousClock.Instant?
    private var childCount: Int = 0

    func wrapOperation<T>(_ operation: () async throws -> T) async throws -> T {
        operationStartTime = .now

        return try await withThrowingTaskGroup(of: T.self) { group in
            // The actual operation
            group.addTask {
                try await operation()
            }

            // Timeout watchdog
            group.addTask {
                try await Task.sleep(for: maxOperationTimeout)
                throw BulkheadError.operationTimeout(agent: agentId, duration: maxOperationTimeout)
            }

            // First to complete wins
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
```

**What this protects:**
- One agent cannot consume the entire project's token budget
- Spinning agents are terminated by timeout
- Agent cannot spawn unlimited children (future drone support)

**Trade-offs:**
- Per-agent overhead for tracking
- Need to handle partial completion (agent timed out mid-work)
- Budget allocation decisions: equal shares? Priority-based?


### Level 3: Task Bulkhead (Optional)

For parallel work within an agent (e.g., agent spawns multiple drones for parallel verification):

```swift
struct TaskBulkhead {
    let taskId: UUID
    let parentAgentBulkhead: AgentBulkhead

    // Per-task limits (even smaller subset)
    let tokenShare: Int
    let taskTimeout: Duration

    // Isolation mechanism
    let changeset: ChangesetOverlay?  // If using overlay filesystem
    let sandboxProfile: SandboxProfile?  // If using OS sandbox
}
```

**What this protects:**
- Parallel tasks cannot interfere with each other
- Failed task's changeset can be discarded without affecting siblings
- Task resources released on completion or timeout

**Trade-offs:**
- May be overkill for v1 (no parallel task execution yet)
- Changeset/sandbox overhead per task
- Coordination complexity for task results


### Level 0: Application Bulkhead (Implicit)

Above all projects, the application has global limits:

```swift
struct ApplicationBulkhead {
    // Global resource caps
    let maxTotalProjects: Int
    let maxTotalAgents: Int
    let globalTokenRateLimit: Int  // Protects API key

    // System protection
    let maxMemoryUsage: Int
    let maxDiskUsage: Int
}
```

This protects the host system from the Tavern application itself.


## Mapping to PRD Sandbox Primitives

The PRD's five sandbox primitives map to bulkhead enforcement points:

| Primitive | Bulkhead Enforcement |
|-----------|---------------------|
| **Changeset** | Task Bulkhead manages overlay lifecycle |
| **Platform** | Project Bulkhead tracks execution location |
| **Isolation** | Agent Bulkhead configures VM/container/sandbox |
| **Outputs** | Agent Bulkhead enforces network policy |
| **Software** | Task Bulkhead specifies OS environment |

The bulkhead is the *management layer* that configures, monitors, and enforces these primitives.


## Mapping to Fish-or-Cut-Bait

The PRD's Fish-or-Cut-Bait scenarios map to bulkhead actions:

**Token budget exceeded:**
```swift
func handleTokenBudgetExceeded(agent: MortalAgent, bulkhead: AgentBulkhead) {
    // Bulkhead has already prevented further API calls
    // Now decide what to do with the agent

    if bulkhead.canRequestMoreTokens() {
        // Ask parent bulkhead for more budget
        let request = TokenRequest(agent: agent.id, amount: 10000)
        if parentBulkhead.approve(request) {
            bulkhead.addTokens(10000)
            return  // Agent can continue
        }
    }

    // No more tokens available - fish or cut bait
    if agent.hasValuableProgress() {
        // Fish: checkpoint and pause
        agent.checkpoint()
        agent.markWaiting(reason: .budgetExhausted)
        notifyUser(agent, .budgetExhaustedNeedsDecision)
    } else {
        // Cut bait: reap and release resources
        bulkhead.release()
        supervisor.terminate(agent, reason: .budgetExceeded)
    }
}
```

**Changeset is totally wrong:**
```swift
func handleBadChangeset(agent: MortalAgent, changeset: Changeset) {
    // Task bulkhead contains the damage
    let taskBulkhead = agent.currentTaskBulkhead

    // Discard the changeset overlay
    taskBulkhead.discardChangeset()

    // Release task resources
    taskBulkhead.release()

    // Agent can try again with fresh bulkhead
    let newTaskBulkhead = agentBulkhead.allocateTaskBulkhead()
    agent.retryWithBulkhead(newTaskBulkhead)
}
```

**Agent spinning:**
```swift
func handleAgentTimeout(agent: MortalAgent) {
    // Agent bulkhead's timeout triggered

    // Cancel the operation
    agent.cancelCurrentOperation()

    // Check if this is chronic
    if agent.timeoutCount >= maxTimeoutsBeforeReap {
        // Cut bait
        agentBulkhead.release()
        supervisor.terminate(agent, reason: .chronicTimeouts)
    } else {
        // Fish: restart the operation with fresh timeout
        agent.incrementTimeoutCount()
        agent.retryCurrentOperation()
    }
}
```

**Whole gang going wrong:**
```swift
func handleGangFailure(gang: [MortalAgent], reason: GangFailureReason) {
    // Multiple agents in the same task tree failing
    // Use project bulkhead to contain

    for agent in gang {
        // Release each agent's bulkhead
        agent.bulkhead.release()
        supervisor.terminate(agent, reason: reason)
    }

    // Return resources to project pool
    projectBulkhead.releaseGangResources(gang)

    // Notify user - this is a significant event
    notifyUser(.gangFailure(gang: gang, reason: reason))
}
```


## Trade-offs Considered


### Resource Fragmentation vs Fairness

**Problem:** If each project gets a fixed allocation (e.g., 100k tokens/hour), and one project is idle, those tokens go unused while another project might be starved.

**Options:**

A. **Fixed allocation** - Each project gets its limit, unused capacity is wasted
   - Pro: Simple, predictable
   - Con: Wasteful, inflexible

B. **Elastic allocation** - Projects can borrow from a shared pool
   - Pro: Better utilization
   - Con: Complex, potential for unfairness

C. **Priority-based allocation** - Some projects get priority access to shared pool
   - Pro: Important work gets resources
   - Con: Starvation of low-priority work

**Recommendation:** Start with fixed allocation (Option A) for v1. It's predictable and matches the PRD's emphasis on isolation. Add elasticity in v2 if utilization is a problem.


### Enforcement Granularity

**Problem:** How granular should bulkhead enforcement be?

**Options:**

A. **Check on every API call** - Most precise, highest overhead
B. **Periodic checking** - Less precise, lower overhead
C. **Threshold-based checking** - Check more frequently as limits approach

**Recommendation:** Option C. For tokens, check on every call (they're expensive operations anyway). For timeouts, use task watchdogs. For agent counts, check only on spawn.


### Bulkhead Lifecycle

**Problem:** When should bulkheads be created and destroyed?

**Options:**

A. **Static** - Bulkheads created at app start with fixed configuration
B. **Dynamic** - Bulkheads created/destroyed with their managed entity (project, agent)
C. **Pooled** - Bulkheads pre-created and assigned from a pool

**Recommendation:** Option B (dynamic) for project and agent bulkheads. They naturally align with entity lifecycles. The overhead is acceptable given that projects/agents are not created frequently.


### Circuit Breaker Integration

**Problem:** Should bulkheads include circuit breaker behavior (temporary failure mode)?

A circuit breaker tracks failure rates and "trips" when failures exceed a threshold, rejecting requests immediately rather than allowing them to fail repeatedly.

**Recommendation:** Yes, but only at the project level. If an agent exceeds 3 timeouts in 5 minutes, trip the circuit - temporarily block new work until human review. This prevents runaway resource consumption from repeated failures.

```swift
enum CircuitState {
    case closed      // Normal operation
    case open        // Rejecting requests, waiting for reset
    case halfOpen    // Allowing one request to test recovery
}

struct CircuitBreaker {
    var state: CircuitState = .closed
    var failureCount: Int = 0
    var lastFailureTime: ContinuousClock.Instant?

    let failureThreshold: Int = 3
    let windowDuration: Duration = .minutes(5)
    let resetTimeout: Duration = .minutes(1)

    mutating func recordFailure() {
        failureCount += 1
        lastFailureTime = .now

        if failureCount >= failureThreshold {
            state = .open
            Task {
                try? await Task.sleep(for: resetTimeout)
                self.state = .halfOpen
            }
        }
    }

    mutating func recordSuccess() {
        if state == .halfOpen {
            state = .closed
            failureCount = 0
        }
    }

    func shouldAllow() -> Bool {
        switch state {
        case .closed: return true
        case .open: return false
        case .halfOpen: return true  // Allow one request
        }
    }
}
```


### Error Propagation

**Problem:** How should bulkhead violations be reported?

**Options:**

A. **Throw immediately** - Caller must handle
B. **Return nil/failure** - Optional-based API
C. **Callback/delegate** - Async notification
D. **Combine/AsyncSequence** - Stream-based

**Recommendation:** Option A (throw) for synchronous enforcement, Option C (callback) for async monitoring. This matches the existing error handling patterns in the codebase.


## Implementation Complexity


### Required New Components

1. **BulkheadProtocol** (~50 LOC)
   - `acquire()`, `release()`, `consumeResource(_:)`
   - Configuration struct
   - Error types

2. **ProjectBulkhead** (~200 LOC)
   - Token tracking per hour
   - Agent count limits
   - Circuit breaker
   - Child agent bulkhead allocation

3. **AgentBulkhead** (~150 LOC)
   - Lifetime token budget
   - Operation timeout wrapper
   - Child task count

4. **TaskBulkhead** (~100 LOC) - Optional for v1
   - Per-task token share
   - Changeset association
   - Sandbox profile

5. **BulkheadMonitor** (~100 LOC)
   - Periodic usage reporting
   - Threshold warnings
   - Metrics integration

6. **ApplicationBulkhead** (~100 LOC)
   - Global limits
   - Project bulkhead factory
   - System protection


### Modifications to Existing Code

1. **TavernProject**
   - Add `projectBulkhead` property
   - Initialize bulkhead with project
   - Pass bulkhead to coordinator

2. **TavernCoordinator**
   - Consult bulkhead before spawning agents
   - Report agent termination to bulkhead

3. **AgentSpawner**
   - Allocate agent bulkhead from project pool
   - Release bulkhead on dismiss

4. **MortalAgent / Jake**
   - Wrap API calls with bulkhead.consumeTokens()
   - Report operation timing

5. **ClaudeCode wrapper**
   - Add token counting (extract from response)
   - Add timeout enforcement


### Estimated Effort

| Component | New LOC | Modified LOC | Complexity |
|-----------|---------|--------------|------------|
| Bulkhead primitives | 600 | - | Medium |
| Project integration | - | 100 | Low |
| Agent integration | - | 150 | Low |
| Monitoring | 100 | 50 | Low |
| Tests | 400 | 100 | Medium |
| **Total** | **1100** | **400** | - |

Timeline estimate: 1-2 weeks for a developer familiar with the codebase.


## Migration Path from Current State


### Phase 1: Project Bulkhead (Week 1)

1. Define `ProjectBulkhead` with token and agent limits
2. Modify `TavernProject` to create bulkhead
3. Modify `AgentSpawner.spawn()` to check agent limit
4. Add token tracking (log only, don't enforce yet)

At this point, you have visibility into per-project resource usage.


### Phase 2: Agent Bulkhead (Week 1-2)

1. Define `AgentBulkhead` with token budget and timeout
2. Modify `AgentSpawner` to allocate agent bulkheads
3. Wrap `MortalAgent.send()` with timeout enforcement
4. Enforce token budget (block when exceeded)

At this point, runaway agents are contained.


### Phase 3: Circuit Breaker (Week 2)

1. Add circuit breaker to `ProjectBulkhead`
2. Track failure events (timeouts, budget exceeded)
3. Trip circuit on repeated failures
4. Add UI indicator for tripped circuits

At this point, chronic failures are contained.


### Phase 4: Monitoring (Week 2)

1. Add `BulkheadMonitor` for periodic reporting
2. Log bulkhead state to `TavernLogger`
3. Add metrics for dashboard (future)

At this point, you have full observability.


### Rollback Strategy

Each phase can be rolled back:
- Phase 1: Remove bulkhead checks from spawner
- Phase 2: Remove timeout wrapper, disable budget enforcement
- Phase 3: Disable circuit breaker (leave tracking)
- Phase 4: Remove monitoring (leave bulkheads)

The key is that bulkheads are additive - they wrap existing behavior rather than replacing it.


## Open Questions


### 1. Default Budgets

What should the default token budgets be?

**Options:**
- A: Conservative defaults, user configures more
- B: Generous defaults, user configures less
- C: No defaults, require explicit configuration

**Recommendation:** Option A. Start conservative (e.g., 10k tokens/agent, 100k tokens/project/hour). Users who need more will configure it. This prevents accidental runaway costs.


### 2. Budget Source

Where should token budget information come from?

**Options:**
- A: Hard-coded in app
- B: Per-project configuration file (e.g., `tavern.yaml`)
- C: User preferences (global defaults)
- D: Combination of B and C

**Recommendation:** Option D. User preferences provide defaults, project config overrides. This matches the PRD's "doc store is source of truth" while allowing global preferences.


### 3. Cross-Project Token Sharing

Should projects be able to borrow tokens from each other?

**Recommendation:** No, at least for v1. Strict isolation is simpler and matches the PRD's emphasis on project independence. If a project needs more tokens, the user adjusts its budget.


### 4. Jake's Special Status

Should Jake have a separate bulkhead from mortal agents, or share the project pool?

**Options:**
- A: Jake has fixed allocation, mortals share the rest
- B: Jake competes with mortals equally
- C: Jake has unlimited budget (can't be token-starved)

**Recommendation:** Option A. Jake is eternal and critical; he should not compete with mortals for resources. A fixed allocation (e.g., 20% of project budget) ensures Jake is always responsive.


### 5. Timeout Handling

What happens when an agent operation times out mid-API-call?

**Options:**
- A: Cancel the API call (if possible)
- B: Let the call complete, but ignore the response
- C: Mark agent as timed out, let call complete in background

**Recommendation:** Option C for v1. Cancelling mid-call is complex (depends on SDK support). Letting the call complete avoids partial state issues. The agent is already marked as timed out, so even if the response comes later, it's handled appropriately.


### 6. Bulkhead Persistence

Should bulkhead state (token usage, timeout counts) persist across app restarts?

**Options:**
- A: No persistence, reset on restart
- B: Persist to doc store
- C: Persist to UserDefaults

**Recommendation:** Option B for token usage (to prevent gaming), Option A for circuit breaker state (fresh start on restart). This matches the PRD's "doc store is source of truth" principle.


### 7. Multi-User Considerations

If multiple users open the same project, should they share a bulkhead?

**Recommendation:** Yes, for v1. The project bulkhead is per-project, not per-user. This prevents escalation of resource consumption by opening the same project multiple times. Multi-user coordination is out of scope for v1.


### 8. Integration with Supervisor Trees

How should bulkheads interact with supervisors?

**Recommendation:**
1. Bulkhead violations are reported to the agent's supervisor
2. Supervisor decides on restart/escalate/reap
3. Bulkhead releases resources on supervisor's instruction
4. Supervisor cannot allocate resources beyond bulkhead limits

The supervisor handles lifecycle; the bulkhead handles resources. They communicate but have distinct responsibilities.


## Conclusion

The Bulkhead pattern provides a principled approach to the isolation requirements implicit in the PRD. While the PRD explicitly calls for "Isolation - No operation may impact unrelated parts of the app," it doesn't prescribe how to achieve this. Bulkheads provide the answer.

The pattern is particularly well-suited for Tavern because:

1. **Multi-project support is core**: The PRD emphasizes working with multiple projects simultaneously. Bulkheads ensure project independence.

2. **Resource constraints are real**: Token costs, API rate limits, and agent proliferation are practical concerns. Bulkheads provide explicit management.

3. **Fish-or-Cut-Bait needs boundaries**: The PRD's kill-and-restart philosophy requires knowing what to kill. Bulkheads define the blast radius.

4. **Sandbox primitives need enforcement**: The five sandbox primitives describe what to isolate; bulkheads describe how to manage and enforce that isolation.

The main implementation cost is per-entity overhead for tracking and enforcement. However, this overhead is proportional to the number of projects and agents, not the amount of work done, so it scales appropriately.

For v1, implementing project and agent bulkheads provides immediate value for multi-project isolation and runaway agent containment. Task bulkheads can be deferred until parallel execution is implemented.

Combined with Supervisor Trees, Bulkheads create a robust failure handling strategy: supervisors recover from failure, bulkheads prevent cascade. Together, they address the PRD's emphasis on reliability and isolation.
