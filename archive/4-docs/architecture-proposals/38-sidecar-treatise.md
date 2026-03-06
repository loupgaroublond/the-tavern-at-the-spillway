# Sidecar Pattern Architecture: Complete Analysis

This document contains the full analysis and reasoning behind the Sidecar Pattern architectural proposal for The Tavern at the Spillway.


## Research Findings


### Current Codebase State

The existing Tavern implementation has the following structure relevant to sidecars:

**Agent Implementation:**
- `Jake` (Sources/TavernCore/Agents/Jake.swift): Top-level coordinator, owns session state, makes Claude SDK calls directly
- `MortalAgent` (Sources/TavernCore/Agents/MortalAgent.swift): Task-scoped workers with commitment verification built into the agent
- Both agents use `ClaudeCode` SDK directly, making calls in their `send()` methods
- State protected via `DispatchQueue` serial queues

**Current Operational Concerns (Mixed Into Agents):**
- Logging: `TavernLogger.agents.info()` calls scattered throughout agent methods
- Session management: Agents call `SessionStore` directly after responses
- State transitions: Mixed with response handling in `send()` methods
- Error handling: Agents catch and transform errors (`TavernError.sessionCorrupt`)

**What's NOT Implemented:**
- Token tracking: No code exists for counting tokens used
- Budget enforcement: No budget limits on agents
- Metrics collection: No timing measurements, no utilization calculation
- Violation monitoring: PRD Section 16 describes it, but no implementation
- Health checks: No mechanism to detect stuck/spinning agents

**Relevant Infrastructure:**
- `TavernLogger`: Four categories (agents, chat, coordination, claude) using os.log
- `CommitmentVerifier`: Shell-based assertion runner (already somewhat separated)
- `AgentRegistry`: Flat collection with name uniqueness, no operational metadata
- `TavernCoordinator`: Owns Jake and AgentSpawner, manages selection

**Key Code Patterns:**

From `MortalAgent.swift` - operational concerns mixed with business logic:
```swift
public func send(_ message: String) async throws -> String {
    TavernLogger.agents.info("[\(self.name)] send called, prompt length: \(message.count)")
    TavernLogger.agents.debug("[\(self.name)] state: \(self._state.rawValue) -> working")

    queue.sync { _state = .working }
    defer { updateStateAfterResponse() }

    var options = ClaudeCodeOptions()
    options.systemPrompt = systemPrompt

    let result: ClaudeCodeResult
    let currentSessionId: String? = queue.sync { _sessionId }

    // ... Claude SDK call ...

    // Extract response
    switch result {
    case .json(let resultMessage):
        queue.sync { _sessionId = resultMessage.sessionId }
        SessionStore.saveAgentSession(agentId: id, sessionId: resultMessage.sessionId)
        let response = resultMessage.result ?? ""
        TavernLogger.agents.info("[\(self.name)] received JSON response, length: \(response.count), sessionId: \(resultMessage.sessionId)")
        await checkForCompletionSignal(in: response)
        return response
    // ...
    }
}
```

Notice: Logging, state management, session persistence, and business logic all interleaved in one method.


### Sidecar Pattern in Practice

The sidecar pattern originated in container orchestration:

**Kubernetes Sidecars:**
- Envoy (Istio service mesh): Intercepts all network traffic, handles mTLS, load balancing, retries
- Fluentd/Fluent Bit: Collects logs from main container's stdout/files
- Vault Agent: Injects secrets, handles token renewal
- CloudSQL Proxy: Manages database connections with automatic auth

**Common Characteristics:**
1. **Co-located with primary**: Same pod, same lifecycle, share localhost network
2. **Intercepts traffic**: Sits in the data path, can observe/modify requests/responses
3. **Independently scalable**: Sidecar resource limits separate from main container
4. **Independently updatable**: Can upgrade sidecar without touching main container
5. **Purpose-specific**: One sidecar per concern (not a dumping ground)

**Applied to Process/Actor Systems:**

In non-container environments, sidecars manifest as:
- Wrapper objects that intercept method calls
- Proxy patterns that delegate after/before processing
- Observer/subscriber pairs with shared event bus
- Middleware chains in request processing pipelines


### Mapping Sidecar to Swift/Tavern

**Approach 1: Wrapper Pattern (Recommended)**

```swift
/// Sidecar wraps an agent, intercepting all Claude interactions
actor AgentSidecar<A: Agent> {
    private let agent: A
    private let metricsCollector: MetricsCollector
    private let budgetEnforcer: BudgetEnforcer
    private let violationMonitor: ViolationMonitor

    init(
        agent: A,
        budget: TokenBudget,
        violationRules: [ViolationRule]
    ) {
        self.agent = agent
        self.metricsCollector = MetricsCollector(agentId: agent.id)
        self.budgetEnforcer = BudgetEnforcer(budget: budget)
        self.violationMonitor = ViolationMonitor(rules: violationRules)
    }

    func send(_ message: String) async throws -> String {
        // Pre-request checks
        try budgetEnforcer.checkCanProceed()
        violationMonitor.recordPrompt(message)

        // Timing
        let startTime = ContinuousClock.now

        // Delegate to actual agent
        let response = try await agent.send(message)

        // Post-response processing
        let elapsed = ContinuousClock.now - startTime
        metricsCollector.recordCall(
            promptTokens: estimateTokens(message),
            responseTokens: estimateTokens(response),
            wallTime: elapsed
        )

        // Check response for violations
        try violationMonitor.checkResponse(response)

        return response
    }

    // Expose agent properties via forwarding
    var id: UUID { agent.id }
    var name: String { agent.name }
    var state: AgentState { agent.state }
}
```

**Approach 2: Protocol Composition**

```swift
protocol SidecarAware: Agent {
    var sidecar: AgentSidecar { get }
}

extension SidecarAware {
    func trackedSend(_ message: String) async throws -> String {
        try await sidecar.intercept {
            try await self.send(message)
        }
    }
}
```

**Approach 3: Middleware Chain**

```swift
typealias AgentMiddleware = (String, @escaping (String) async throws -> String) async throws -> String

func withMetrics(_ collector: MetricsCollector) -> AgentMiddleware {
    return { prompt, next in
        let start = ContinuousClock.now
        let response = try await next(prompt)
        collector.record(wallTime: ContinuousClock.now - start)
        return response
    }
}

func withBudget(_ enforcer: BudgetEnforcer) -> AgentMiddleware {
    return { prompt, next in
        try enforcer.checkBudget()
        let response = try await next(prompt)
        enforcer.deduct(prompt: prompt, response: response)
        return response
    }
}
```


## What Goes in Sidecar vs Main Agent


### Main Agent Responsibilities

Keep in the agent (business logic, LLM interaction):

| Responsibility | Why in Agent |
|---------------|--------------|
| System prompt construction | Domain-specific, defines agent personality |
| Claude SDK calls | Core capability, what the agent "does" |
| Response parsing | Business logic - understanding what Claude said |
| Conversation state | Agent's memory, continuity of interaction |
| Completion detection | Domain logic - recognizing "DONE" signals |
| Commitment management | Business rules about what constitutes success |
| Task mode decisions | Execute/delegate/plan decisions are business logic |

**Guiding Principle:** If it requires understanding the content of messages or making domain decisions, it stays in the agent.


### Sidecar Responsibilities

Move to sidecar (operational concerns, cross-cutting):

| Responsibility | Why in Sidecar |
|---------------|----------------|
| Token counting | Pure measurement, no domain knowledge needed |
| Budget tracking | Arithmetic on token counts, not content-aware |
| Wall clock timing | Measurement wrapper around any operation |
| Utilization calculation | Math on collected metrics |
| Violation rule evaluation | Policy enforcement, not domain logic |
| Health monitoring | Liveness checks, timeout detection |
| Metrics emission | Formatting/shipping data to observability systems |
| Rate limiting | Throttling, not understanding content |
| Request/response logging | Structured logging for debugging |
| Retry logic | Operational concern, agent shouldn't know about retries |

**Guiding Principle:** If it can be done without understanding message content, it belongs in the sidecar.


### Gray Areas and Recommendations

Some concerns could go either way:

**Session Persistence:**
- Currently in agent (calls `SessionStore.saveAgentSession`)
- Recommendation: Move to sidecar - it's about durability, not content
- Sidecar intercepts successful response, triggers save

**Error Transformation:**
- Currently in agent (`TavernError.sessionCorrupt`)
- Recommendation: Keep error creation in agent, but move recovery policy to sidecar
- Agent throws; sidecar decides retry/escalate/notify

**State Transitions:**
- Currently in agent (`queue.sync { _state = .working }`)
- Recommendation: Split - agent owns semantic state (working/waiting/done), sidecar owns operational state (healthy/degraded/failing)

**Logging:**
- Currently in agent (`TavernLogger.agents.info(...)`)
- Recommendation: Reduce agent logging to errors only; sidecar handles all info/debug logging
- Agent becomes quieter, easier to test without log noise


## Mapping to PRD Requirements


### Section 9: Metrics

PRD defines:
- Token time: waiting for LLM API responses
- Tool time: tool execution (tests, builds)
- Wall clock time: total elapsed
- Throttle time: excluded from metrics
- Utilization = Token time / Wall clock
- Saturation = (Token + Tool time) / Wall clock

**Sidecar Implementation:**

```swift
actor MetricsCollector {
    private var tokenTimeNanos: UInt64 = 0
    private var toolTimeNanos: UInt64 = 0
    private var wallClockStartNanos: UInt64 = 0
    private var throttleTimeNanos: UInt64 = 0

    func recordClaudeCall(duration: Duration, wasThrottled: Bool) {
        if wasThrottled {
            throttleTimeNanos += duration.components.nanoseconds
        } else {
            tokenTimeNanos += duration.components.nanoseconds
        }
    }

    func recordToolExecution(duration: Duration) {
        toolTimeNanos += duration.components.nanoseconds
    }

    var utilization: Double {
        let wallClock = wallClockTime - throttleTime
        guard wallClock > 0 else { return 0 }
        return Double(tokenTimeNanos) / Double(wallClock)
    }

    var saturation: Double {
        let wallClock = wallClockTime - throttleTime
        guard wallClock > 0 else { return 0 }
        return Double(tokenTimeNanos + toolTimeNanos) / Double(wallClock)
    }
}
```

The sidecar wraps every Claude call and tool execution, making these measurements automatic:

```swift
func send(_ message: String) async throws -> String {
    let start = ContinuousClock.now

    do {
        let response = try await agent.send(message)
        metricsCollector.recordClaudeCall(
            duration: ContinuousClock.now - start,
            wasThrottled: false
        )
        return response
    } catch let error as ClaudeThrottleError {
        metricsCollector.recordClaudeCall(
            duration: ContinuousClock.now - start,
            wasThrottled: true
        )
        throw error
    }
}
```


### Section 16: Violation Monitoring

PRD defines configurable violations:
- Modifying files outside designated directories
- Exceeding token budgets
- Spawning more than N children
- Accessing network when disallowed
- Running commands on blocklist

**Sidecar Implementation:**

```swift
struct ViolationRule: Sendable {
    let id: String
    let check: @Sendable (AgentAction) -> ViolationResult
    let response: ViolationResponse
}

enum ViolationResponse {
    case warn         // Log and continue
    case pause        // Stop agent, await user decision
    case reap         // Terminate agent immediately
    case notifyParent // Bubble to parent agent
}

actor ViolationMonitor {
    private let rules: [ViolationRule]
    private var violations: [Violation] = []

    func checkAction(_ action: AgentAction) throws -> ViolationDecision {
        for rule in rules {
            switch rule.check(action) {
            case .violation(let details):
                let violation = Violation(
                    ruleId: rule.id,
                    details: details,
                    timestamp: Date()
                )
                violations.append(violation)

                switch rule.response {
                case .warn:
                    TavernLogger.agents.warning("Violation: \(details)")
                case .pause:
                    return .pauseAgent(reason: details)
                case .reap:
                    throw ViolationError.terminated(reason: details)
                case .notifyParent:
                    return .escalate(reason: details)
                }
            case .allowed:
                continue
            }
        }
        return .proceed
    }
}
```

The sidecar applies rules before and after agent actions:

```swift
func send(_ message: String) async throws -> String {
    // Pre-send violation check (e.g., budget exceeded)
    let preDecision = try await violationMonitor.checkAction(
        .sendPrompt(tokens: estimateTokens(message))
    )
    if case .pauseAgent = preDecision {
        throw AgentPausedError()
    }

    let response = try await agent.send(message)

    // Post-send violation check (e.g., response contains forbidden content)
    let postDecision = try await violationMonitor.checkAction(
        .receivedResponse(content: response)
    )
    // Handle post decision...

    return response
}
```


### Section 12: Fish or Cut Bait

PRD triggers for kill-and-restart:
1. Token budget exceeded
2. Changeset is totally wrong
3. Agent spinning
4. Whole gang going down wrong path

**Sidecar Implementation:**

```swift
actor AgentSidecar<A: Agent> {
    private var consecutiveErrors: Int = 0
    private var lastActivityTime: ContinuousClock.Instant?
    private let spinningThreshold: Duration = .seconds(60)

    func checkHealth() async -> HealthStatus {
        // Check for spinning (no progress for threshold period)
        if let lastActivity = lastActivityTime,
           ContinuousClock.now - lastActivity > spinningThreshold {
            return .spinning
        }

        // Check for error spiral
        if consecutiveErrors >= 3 {
            return .failing
        }

        // Check budget
        if budgetEnforcer.isExhausted {
            return .budgetExceeded
        }

        return .healthy
    }

    func send(_ message: String) async throws -> String {
        defer { lastActivityTime = ContinuousClock.now }

        do {
            let response = try await agent.send(message)
            consecutiveErrors = 0
            return response
        } catch {
            consecutiveErrors += 1
            throw error
        }
    }
}
```

A `HealthMonitorDaemon` periodically checks all sidecars:

```swift
actor HealthMonitorDaemon {
    func checkAllAgents() async {
        for (agentId, sidecar) in registry.allSidecars() {
            let health = await sidecar.checkHealth()
            switch health {
            case .healthy:
                continue
            case .spinning, .failing, .budgetExceeded:
                await coordinator.fishOrCutBait(agentId: agentId, reason: health)
            }
        }
    }
}
```


## Trade-offs Considered


### Interception Granularity

**Option A: Coarse-grained (wrap `send()` only)**
- Pros: Simple, minimal code change, easy to understand
- Cons: Can't intercept tool calls, can't see inside agent's decision-making

**Option B: Fine-grained (intercept every Claude SDK call)**
- Pros: Full visibility, can track tool time separately
- Cons: Requires changes to agent internals or SDK modification

**Recommendation:** Start coarse-grained. The current agents only have one entry point (`send()`). As tool calling becomes more complex, move to fine-grained interception by injecting a `MonitoredClaudeCode` wrapper.


### Sidecar Cardinality

**Option A: One sidecar per agent (1:1)**
- Pros: Clean isolation, agent-specific configuration
- Cons: Object proliferation, more memory

**Option B: Shared sidecar pool**
- Pros: Fewer objects, shared resources
- Cons: Complex routing, harder to reason about

**Option C: One sidecar type per agent type**
- Pros: Jake gets `JakeSidecar` with different rules than mortal agents
- Cons: Type proliferation

**Recommendation:** Start with 1:1 using generic `AgentSidecar<A>`. Specialize only if Jake needs fundamentally different operational concerns (likely not - metrics and violations are universal).


### Sidecar Lifecycle

**Option A: Sidecar owns agent lifecycle**
- Sidecar creates agent, destroys agent
- Sidecar is the external-facing entity

**Option B: Parallel lifecycle (coordinator manages both)**
- Coordinator creates agent and sidecar together
- Coordinator destroys both together
- Both are peers in the system

**Option C: Agent owns sidecar**
- Agent creates its own sidecar
- Self-monitoring pattern

**Recommendation:** Option A (sidecar owns agent). This ensures all agent access goes through the sidecar, preventing bypass. The coordinator interacts with sidecars, not raw agents.


### State Durability

**Problem:** If the app crashes, sidecar state (token counts, timing, violation history) is lost.

**Options:**
1. Accept loss - recalculate on restart from persisted agent state
2. Periodic sidecar state snapshots to disk
3. Event-sourced metrics - replay events to reconstruct state
4. Hybrid - persist aggregate metrics, lose fine-grained timing

**Recommendation:** For v1, accept loss and recalculate. Token budgets can be reset per-session; historical metrics aren't critical for operation. Add persistence when dashboards need historical data.


## Implementation Complexity


### Minimal Viable Sidecar

The simplest useful sidecar:

```swift
final class MinimalSidecar<A: Agent>: @unchecked Sendable {
    private let agent: A
    private let queue = DispatchQueue(label: "sidecar")
    private var totalTokens: Int = 0
    private var budget: Int

    init(agent: A, tokenBudget: Int) {
        self.agent = agent
        self.budget = tokenBudget
    }

    func send(_ message: String) async throws -> String {
        let estimatedPromptTokens = message.count / 4 // rough estimate

        // Budget check
        let remaining = queue.sync { budget - totalTokens }
        if estimatedPromptTokens > remaining {
            throw BudgetExceededError()
        }

        let response = try await agent.send(message)

        // Update token count
        let estimatedResponseTokens = response.count / 4
        queue.sync {
            totalTokens += estimatedPromptTokens + estimatedResponseTokens
        }

        return response
    }
}
```

**Effort estimate:** ~2 hours to implement, test, and integrate with existing agents.


### Full-Featured Sidecar

Complete implementation with all PRD concerns:

```swift
actor AgentSidecar<A: Agent> {
    // Core
    private let agent: A

    // Metrics
    private let metrics: MetricsCollector

    // Budget
    private let budget: BudgetEnforcer

    // Violations
    private let violations: ViolationMonitor

    // Health
    private var consecutiveErrors: Int = 0
    private var lastActivity: ContinuousClock.Instant?

    // Configuration
    private let config: SidecarConfig

    struct SidecarConfig {
        var tokenBudget: Int
        var violationRules: [ViolationRule]
        var spinningThreshold: Duration
        var maxConsecutiveErrors: Int
    }

    // Full send implementation
    func send(_ message: String) async throws -> String {
        // Pre-checks
        try budget.checkCanProceed(estimatedTokens: estimateTokens(message))
        try await violations.checkAction(.sendPrompt(content: message))

        // Timing
        let start = ContinuousClock.now

        // Execute
        do {
            let response = try await agent.send(message)

            // Record success
            let elapsed = ContinuousClock.now - start
            await metrics.recordCall(
                promptTokens: estimateTokens(message),
                responseTokens: estimateTokens(response),
                wallTime: elapsed,
                wasThrottled: false
            )
            budget.deduct(
                promptTokens: estimateTokens(message),
                responseTokens: estimateTokens(response)
            )
            consecutiveErrors = 0
            lastActivity = ContinuousClock.now

            // Post-checks
            try await violations.checkAction(.receivedResponse(content: response))

            return response

        } catch {
            consecutiveErrors += 1
            let elapsed = ContinuousClock.now - start
            await metrics.recordError(error: error, wallTime: elapsed)
            throw error
        }
    }

    // Health check for external monitoring
    func healthCheck() -> HealthStatus {
        if let last = lastActivity,
           ContinuousClock.now - last > config.spinningThreshold {
            return .spinning
        }
        if consecutiveErrors >= config.maxConsecutiveErrors {
            return .errorSpiral
        }
        if budget.isExhausted {
            return .budgetExceeded
        }
        return .healthy
    }

    // Metrics exposure
    var utilization: Double { get async { await metrics.utilization } }
    var saturation: Double { get async { await metrics.saturation } }
    var tokenUsage: TokenUsage { budget.currentUsage }
    var violationHistory: [Violation] { get async { await violations.history } }
}
```

**Effort estimate:** ~2-3 days for full implementation with tests.


### Integration Points

**AgentSpawner changes:**
```swift
func spawn(assignment: String) throws -> AgentSidecar<MortalAgent> {
    let agent = MortalAgent(name: name, assignment: assignment, claude: claudeFactory())
    let sidecar = AgentSidecar(
        agent: agent,
        config: SidecarConfig(
            tokenBudget: defaultBudget,
            violationRules: projectRules,
            spinningThreshold: .seconds(60),
            maxConsecutiveErrors: 3
        )
    )
    try registry.register(sidecar) // Registry now tracks sidecars
    return sidecar
}
```

**TavernCoordinator changes:**
```swift
// Change type from Jake to AgentSidecar<Jake>
public let jake: AgentSidecar<Jake>

// ChatViewModel wraps sidecar, not raw agent
self.jakeChatViewModel = ChatViewModel(sidecar: jakeSidecar)
```

**ChatViewModel changes:**
```swift
// Send goes through sidecar
func sendMessage() async {
    let response = try await sidecar.send(text) // sidecar.send, not agent.send
    // ...
}

// Expose metrics
var utilization: Double { get async { await sidecar.utilization } }
```


## Migration Path from Current State


### Phase 1: Introduce Sidecar Infrastructure (1-2 days)

1. Create `Sources/TavernCore/Sidecar/` directory
2. Implement `AgentSidecar` with minimal functionality (just forwarding)
3. Add `SidecarConfig` for configuration
4. Update `AgentSpawner` to wrap new agents in sidecars
5. Tests pass with sidecars as transparent proxies

**Verification:** All existing tests pass; app behavior unchanged.


### Phase 2: Add Metrics Collection (1 day)

1. Implement `MetricsCollector` actor
2. Add timing instrumentation to `AgentSidecar.send()`
3. Expose `utilization` and `saturation` properties
4. Add metrics tests

**Verification:** Can query sidecar for metrics; values are plausible.


### Phase 3: Add Budget Enforcement (1 day)

1. Implement `BudgetEnforcer`
2. Add token estimation (start with character-count heuristic)
3. Integrate budget checks into `AgentSidecar.send()`
4. Add `BudgetExceededError`
5. Tests for budget enforcement

**Verification:** Agents stop when budget exhausted.


### Phase 4: Add Violation Monitoring (1-2 days)

1. Implement `ViolationMonitor` actor
2. Define `ViolationRule` protocol and initial rules
3. Integrate violation checks into sidecar
4. Implement response actions (warn, pause, reap)
5. Tests for each violation response type

**Verification:** Violation rules trigger appropriate responses.


### Phase 5: Add Health Monitoring (1 day)

1. Add health check to `AgentSidecar`
2. Implement `HealthMonitorDaemon`
3. Integrate with "Fish or Cut Bait" flow
4. Tests for health check triggers

**Verification:** Spinning/failing agents are detected and handled.


### Phase 6: Remove Agent-Side Operational Code (1 day)

1. Remove logging from agent `send()` methods (keep error logging)
2. Move session persistence to sidecar
3. Clean up agent code to be purely business logic
4. Update agent tests to not expect logging side effects

**Verification:** Agent code is cleaner; all operational concerns in sidecars.


### Phase 7: UI Integration (1 day)

1. Expose sidecar metrics through `ChatViewModel`
2. Add utilization/saturation display (optional for v1)
3. Add budget remaining indicator
4. Add violation alert UI

**Verification:** Users can see operational status of agents.


## Open Questions


### 1. Token Estimation Accuracy

The sidecar needs to know token counts for budget enforcement. Options:
- **Character heuristic**: `tokens ~ characters / 4` (fast, inaccurate)
- **Tokenizer library**: Use tiktoken or similar (accurate, adds dependency)
- **Claude API response**: Extract token counts from response metadata (accurate, after-the-fact)

Recommendation: Start with heuristic; switch to API response parsing when ClaudeCodeSDK exposes token usage. Budget enforcement can be conservative (overestimate).


### 2. Sidecar Configuration Source

Where do violation rules and budgets come from?
- **Hardcoded defaults**: Simple but inflexible
- **Project configuration file**: `.tavern/config.json` or similar
- **Document store**: Rules as documents, editable in-app
- **Agent spawn parameters**: Caller specifies at spawn time

Recommendation: Spawn parameters for v1 (caller specifies); add file-based defaults later.


### 3. Metrics Persistence and Aggregation

How long do we keep metrics? Where do they go?
- **In-memory only**: Lost on app restart
- **Per-session files**: Write to `.tavern/metrics/session-<id>.json`
- **Aggregate to dashboard**: Emit to metrics service

Recommendation: In-memory for v1; add file persistence when dashboard work begins.


### 4. Sidecar for Jake vs Mortal Agents

Should Jake have a sidecar? Jake is:
- Eternal (doesn't terminate)
- Budget-unlimited? Or should Jake have a budget too?
- Less likely to violate rules (trusted)

Recommendation: Yes, Jake gets a sidecar. Even if budget is unlimited, metrics collection is valuable. Uniform architecture is easier to reason about.


### 5. Handling Streaming Responses

Current agents use batch responses, but PRD mentions streaming. How does sidecar handle streaming?
- **Option A**: Buffer entire stream, process at end (loses streaming benefit)
- **Option B**: Intercept stream, emit metrics progressively (complex)
- **Option C**: Streaming adds a separate path through sidecar

Recommendation: Defer streaming consideration. Current implementation is batch-only; when streaming is added, extend sidecar with streaming-aware interception.


### 6. Testing Strategy

How do we test the sidecar layer?
- **Unit tests**: Mock agent, verify sidecar behavior
- **Integration tests**: Real agent through sidecar
- **Property tests**: Sidecar should never change response content

Recommendation: Unit tests with `MockAgent` (similar to existing `MockClaudeCode`). Property test: `sidecar.send(x) == agent.send(x)` when budget available and no violations.


### 7. Error Propagation vs Transformation

Should sidecar transform errors or propagate them?
- **Propagate**: Agent errors pass through unchanged
- **Transform**: Sidecar wraps errors with operational context (`BudgetExceededDuringCall`, `ViolationDetected`)
- **Both**: Propagate agent errors, add sidecar-specific errors for operational failures

Recommendation: Both. Agent errors pass through; sidecar adds its own error types for budget/violation/health failures. This preserves error semantics while adding operational context.


### 8. Sidecar Observability

How do we observe the sidecars themselves?
- **Logging**: Sidecar logs all intercepts
- **Metrics about metrics**: Meta-metrics (sidecar overhead, interception count)
- **Dashboard**: UI showing all sidecars and their health

Recommendation: Logging for v1; add sidecar-level dashboard when scaling beyond a few agents.


## Alternative Approaches Considered


### Aspect-Oriented Programming (AOP)

Use Swift macros or runtime interception to inject metrics/monitoring code.

**Pros:** No code changes to agents; cross-cutting by definition
**Cons:** Swift doesn't have mature AOP support; macros are compile-time only; runtime swizzling is fragile

**Verdict:** Rejected. Swift's type system prefers explicit composition over implicit interception.


### Decorator Pattern

Chain of decorators wrapping the agent.

```swift
let agent = MortalAgent(...)
let withMetrics = MetricsDecorator(agent)
let withBudget = BudgetDecorator(withMetrics)
let withViolations = ViolationDecorator(withBudget)
```

**Pros:** Flexible composition; familiar pattern
**Cons:** Order-dependent; each decorator only sees its immediate wrapped object; hard to share state

**Verdict:** Sidecar is effectively a flattened decorator. The sidecar approach is preferred because it makes all concerns visible in one place rather than hidden in a chain.


### Event-Driven Monitoring

Agents emit events; separate monitoring service subscribes.

```swift
agent.onSend.subscribe { prompt in metrics.recordPrompt(prompt) }
agent.onResponse.subscribe { response in metrics.recordResponse(response) }
```

**Pros:** Decoupled; agents don't know about monitoring
**Cons:** Can't enforce (only observe); budget check can't block; async event delivery

**Verdict:** Good for pure observation; insufficient for enforcement (budget checks must block). Could complement sidecar pattern for non-blocking concerns.


### Built-in Monitoring (Current Path)

Add metrics/violations/budget code directly to agents.

**Pros:** No new abstractions; everything in one place
**Cons:** Agents become complex; hard to test business logic in isolation; operational code duplicated across agent types

**Verdict:** This is where the codebase is heading without intervention. Sidecar pattern prevents this coupling.


## Conclusion

The Sidecar Pattern provides a clean architectural boundary between LLM business logic (what agents do) and operational concerns (how we monitor/control them). For Tavern, where the PRD explicitly requires metrics (Section 9), violation monitoring (Section 16), and "Fish or Cut Bait" handling (Section 12), sidecars offer a natural home for all this functionality without polluting agent code.

The migration path is incremental - start with transparent forwarding, add concerns one at a time, verify at each step. The implementation complexity is moderate (2-3 days for full implementation), and the testing story is straightforward (mock agents, verify sidecar behavior).

The main trade-off is object proliferation (every agent gets a companion sidecar) and the discipline required to ensure all agent access goes through sidecars. These are manageable costs for the clarity and testability benefits.
