# Actor Model Architecture: Complete Analysis

This document contains the full research, analysis, and thinking behind the Actor Model architecture proposal for the Tavern multi-agent orchestrator.


## Table of Contents

1. [Research Findings](#research-findings)
2. [How Swift Actors Map to Agent Concepts](#how-swift-actors-map-to-agent-concepts)
3. [PRD Requirements Mapping](#prd-requirements-mapping)
4. [Trade-offs Analysis](#trade-offs-analysis)
5. [Implementation Complexity](#implementation-complexity)
6. [Migration Path](#migration-path)
7. [Open Questions](#open-questions)


---


## Research Findings

### Current Implementation Analysis

The existing codebase uses a class-based agent model with manual thread safety via `DispatchQueue`:

**Jake.swift:**
```swift
public final class Jake: Agent, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.tavern.Jake")
    private var _sessionId: String?
    private var _projectPath: String?
    private var _isCogitating: Bool = false

    public var sessionId: String? {
        queue.sync { _sessionId }
    }
}
```

**MortalAgent.swift:**
```swift
public final class MortalAgent: Agent, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.tavern.MortalAgent")
    private var _state: AgentState = .idle
    private var _sessionId: String?
}
```

**AgentRegistry.swift:**
```swift
public final class AgentRegistry: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.tavern.AgentRegistry")
    private var _agents: [UUID: AnyAgent] = [:]
    private var _nameToId: [String: UUID] = [:]
}
```

**CommitmentList.swift:**
```swift
public final class CommitmentList: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.tavern.CommitmentList")
    private var _commitments: [Commitment] = []
}
```

**Patterns observed:**

1. Every stateful class has its own `DispatchQueue` for synchronization
2. All use `@unchecked Sendable` conformance (compiler cannot verify thread safety)
3. State access follows `queue.sync { _propertyName }` pattern
4. Mutable state is prefixed with underscore (`_state`, `_sessionId`)
5. Public accessors wrap synchronized reads


**Problems with current approach:**

1. **Manual discipline required:** Developer must remember to synchronize every access
2. **No compile-time verification:** `@unchecked Sendable` bypasses Swift's safety checks
3. **Potential deadlocks:** Nested queue access can deadlock if not careful
4. **Performance overhead:** Each property access incurs queue synchronization cost
5. **Scattered concurrency logic:** Thread safety is implemented per-class, not centralized


### Agent Protocol Analysis

```swift
public protocol Agent: AnyObject, Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var state: AgentState { get }
    func send(_ message: String) async throws -> String
    func resetConversation()
}
```

Key observations:

- Protocol requires `Sendable` conformance (correct)
- `send` is already async (good fit for actors)
- `resetConversation` is synchronous (would need to become async in actor model)
- State properties are read-only in protocol (simplifies actor design)


### UI Layer Integration

```swift
@MainActor
public final class TavernCoordinator: ObservableObject { ... }

@MainActor
public final class ChatViewModel: ObservableObject { ... }

@MainActor
public final class TavernProject: ObservableObject { ... }
```

UI-bound types correctly use `@MainActor` isolation. This establishes a clear boundary where:

- ViewModels run on main actor
- Agents can run on their own actors
- Cross-actor communication uses async/await


### Agent State Machine

```swift
public enum AgentState: String, Equatable, Sendable {
    case idle
    case working
    case waiting
    case verifying
    case done
}
```

The state machine is well-defined and `Sendable`. State transitions happen in response to:

1. `send()` call (idle -> working)
2. Response received (working -> idle/waiting/verifying/done)
3. Explicit method calls (`markWaiting()`, `markDone()`)
4. Verification completion (verifying -> done/idle)


---


## How Swift Actors Map to Agent Concepts


### Conceptual Alignment

| Tavern Concept | Swift Actor Equivalent |
|----------------|------------------------|
| Agent | `actor` type |
| Agent state | Actor-isolated properties |
| `send()` method | `async` actor method |
| State transitions | Isolated state mutation |
| Agent registry | `actor AgentRegistry` |
| Thread-safe collections | Actor-isolated dictionaries |
| Message queue | Implicit mailbox (runtime-managed) |


### Actor-Based Agent Protocol

```swift
// New protocol for actor-based agents
public protocol ActorAgent: Actor, Identifiable {
    nonisolated var id: UUID { get }
    nonisolated var name: String { get }

    var state: AgentState { get }

    func send(_ message: String) async throws -> String
    func resetConversation() async
}
```

Key changes:

1. Inherits from `Actor` instead of requiring `Sendable`
2. `id` and `name` are `nonisolated` (immutable, safe to access anywhere)
3. `resetConversation()` becomes `async` (required for actor method calls)
4. `state` is isolated (accessed via `await` from outside)


### Jake as Actor

```swift
public actor Jake: ActorAgent {
    public nonisolated let id: UUID
    public nonisolated let name: String = "Jake"

    private let claude: ClaudeCode
    private var sessionId: String?
    private var projectPath: String?
    private var isCogitating: Bool = false

    public var state: AgentState {
        isCogitating ? .working : .idle
    }

    public init(id: UUID = UUID(), claude: ClaudeCode, loadSavedSession: Bool = true) {
        self.id = id
        self.claude = claude
        // ... initialization
    }

    public func send(_ message: String) async throws -> String {
        isCogitating = true
        defer { isCogitating = false }

        // No queue.sync needed - actor isolation handles it
        let result: ClaudeCodeResult
        if let sessionId = sessionId {
            result = try await claude.resumeConversation(...)
        } else {
            result = try await claude.runSinglePrompt(...)
        }

        // State mutation is automatically safe
        switch result {
        case .json(let resultMessage):
            self.sessionId = resultMessage.sessionId
            // ...
        }
    }

    public func resetConversation() async {
        sessionId = nil
        // ...
    }
}
```

**Benefits:**

- No `DispatchQueue` needed
- No `@unchecked Sendable`
- No underscore-prefixed properties
- Compiler verifies all state access is safe
- Cleaner, more readable code


### MortalAgent as Actor

```swift
public actor MortalAgent: ActorAgent {
    public nonisolated let id: UUID
    public nonisolated let name: String
    public nonisolated let assignment: String

    private let claude: ClaudeCode
    private let commitments: CommitmentList  // Would also become actor
    private let verifier: CommitmentVerifier

    private var _state: AgentState = .idle
    private var sessionId: String?

    public var state: AgentState { _state }

    public func send(_ message: String) async throws -> String {
        _state = .working
        defer { updateStateAfterResponse() }

        // Direct state access - no synchronization needed
        // ...
    }

    private func checkForCompletionSignal(in response: String) async {
        if response.uppercased().contains("DONE") {
            await handleCompletionAttempt()
        } else if response.uppercased().contains("WAITING") {
            _state = .waiting
        }
    }

    private func handleCompletionAttempt() async {
        if await commitments.count == 0 || await commitments.allPassed {
            _state = .done
            return
        }

        _state = .verifying
        let allPassed = try await verifier.verifyAll(in: commitments)
        _state = allPassed ? .done : .idle
    }
}
```


### AgentRegistry as Actor

```swift
public actor AgentRegistry {
    private var agents: [UUID: any ActorAgent] = [:]
    private var nameToId: [String: UUID] = [:]

    public func register(_ agent: some ActorAgent) throws {
        guard nameToId[agent.name] == nil else {
            throw AgentRegistryError.nameAlreadyExists(agent.name)
        }
        agents[agent.id] = agent
        nameToId[agent.name] = agent.id
    }

    public func remove(id: UUID) throws {
        guard let agent = agents[id] else {
            throw AgentRegistryError.agentNotFound(id)
        }
        nameToId.removeValue(forKey: agent.name)
        agents.removeValue(forKey: id)
    }

    public func agent(id: UUID) -> (any ActorAgent)? {
        agents[id]
    }

    public var count: Int { agents.count }
    public var allAgents: [any ActorAgent] { Array(agents.values) }
}
```


### TavernCoordinator Integration

The coordinator bridges `@MainActor` (UI) and agent actors:

```swift
@MainActor
public final class TavernCoordinator: ObservableObject {
    @Published public private(set) var agentListViewModel: AgentListViewModel
    @Published public private(set) var activeChatViewModel: ChatViewModel

    private let jake: Jake  // Actor
    private let registry: AgentRegistry  // Actor

    public func spawnAgent(assignment: String) async throws -> MortalAgent {
        // Cross-actor call to registry
        let agent = MortalAgent(...)
        try await registry.register(agent)
        // ...
    }

    public func selectAgent(id: UUID) async {
        // Must await actor method calls
        if let agent = await registry.agent(id: id) {
            // ...
        }
    }
}
```


---


## PRD Requirements Mapping


### Invariant Analysis

| PRD Invariant | Actor Model Impact |
|---------------|-------------------|
| Test suite must pass | Actors are fully testable; async tests are standard |
| Every feature testable | Actor isolation makes testing cleaner |
| Commitments verified independently | `CommitmentVerifier` works same way |
| User attention is sacred | UI isolation via `@MainActor` unchanged |
| Doc store is source of truth | Orthogonal to actor model |
| Agents cannot modify own invariants | Actor encapsulation enforces this |
| Failures must be visible | Error propagation via `throws` unchanged |
| Original project files protected | Orthogonal to actor model |


### Agent Types Mapping

| PRD Agent Type | Actor Implementation |
|----------------|---------------------|
| Jake (Daemon) | `actor Jake` - long-lived, always present |
| Mortal | `actor MortalAgent` - task-scoped lifecycle |
| Drone | `actor DroneAgent` - lightweight, quick tasks |
| Monitor Daemon | `actor MonitorDaemon` - background observers |


### Agent States Mapping

```
Working ──────► Waiting for Input ──────► Done
    │                   │                   ▲
    │                   ▼                   │
    └──────► Waiting for Wakeup ───────────┘
                        │
                        ▼
                  Failed/Reaped
```

Actor implementation:

```swift
public actor MortalAgent {
    private var _state: AgentState = .idle

    // State transitions are atomic within actor
    func transitionTo(_ newState: AgentState) {
        // Log transition
        TavernLogger.agents.info("[\(name)] \(_state) -> \(newState)")
        _state = newState
    }

    func handleResponse(_ response: String) async {
        if isCompletionSignal(response) {
            transitionTo(.verifying)
            let passed = await verifyCommitments()
            transitionTo(passed ? .done : .idle)
        } else if isWaitingSignal(response) {
            transitionTo(.waiting)
        }
    }
}
```


### Operating Modes

**Chat mode:**
- ViewModels observe agent state via `await agent.state`
- State changes trigger UI updates through `@Published` properties

**Perseverance mode:**
- Background task calls `await agent.send()` repeatedly
- Actor isolation ensures safe concurrent access


### Attention Model

```swift
actor MortalAgent {
    private var userPresent: Bool = false

    func userJoined() {
        userPresent = true
        // Agent knows to pause for interaction
    }

    func userLeft() {
        userPresent = false
        // Agent continues autonomously
    }
}
```


### Bubbling Communication

```swift
protocol BubblingAgent: ActorAgent {
    var parent: (any BubblingAgent)? { get }

    func receiveFromChild(_ message: AgentMessage) async
    func bubbleToParent(_ message: AgentMessage) async
}

actor MortalAgent: BubblingAgent {
    weak var parent: (any BubblingAgent)?

    func bubbleToParent(_ message: AgentMessage) async {
        if let parent = parent {
            await parent.receiveFromChild(message)
        } else {
            // Reached top - notify user
            await notifyUser(message)
        }
    }
}
```


### Metrics (PRD Section 9)

Actors naturally support timing metrics:

```swift
actor MortalAgent {
    private var tokenTimeAccumulator: TimeInterval = 0
    private var toolTimeAccumulator: TimeInterval = 0
    private var workStartTime: Date?

    func send(_ message: String) async throws -> String {
        workStartTime = Date()
        defer {
            if let start = workStartTime {
                // Metrics calculated automatically
            }
        }

        let tokenStart = Date()
        let result = try await claude.send(message)
        tokenTimeAccumulator += Date().timeIntervalSince(tokenStart)

        return result
    }
}
```


---


## Trade-offs Analysis


### Actor Reentrancy

**The Problem:**

Swift actors are reentrant. When an actor method `await`s, other method calls can execute:

```swift
actor Counter {
    var value = 0

    func increment() async {
        let current = value
        await someAsyncWork()  // ⚠️ Suspension point
        value = current + 1     // May clobber concurrent increment!
    }
}
```

**Mitigation for Tavern:**

1. **State transitions should be atomic:**
```swift
actor MortalAgent {
    func transitionTo(_ newState: AgentState) {
        // No await between read and write
        _state = newState
    }
}
```

2. **Use task isolation for complex operations:**
```swift
actor MortalAgent {
    private var currentTask: Task<Void, Never>?

    func startWork() async {
        // Cancel previous work
        currentTask?.cancel()

        currentTask = Task {
            // Work happens in isolated task
            await performWork()
        }
    }
}
```

3. **Design for reentrancy:**
```swift
actor Jake {
    private var isCogitating: Bool = false

    func send(_ message: String) async throws -> String {
        guard !isCogitating else {
            throw TavernError.alreadyWorking
        }
        isCogitating = true
        defer { isCogitating = false }

        // Even if reentered, guard prevents double-work
        return try await claude.send(message)
    }
}
```


### MainActor Coordination

**Current approach:**
```swift
@MainActor
class TavernCoordinator: ObservableObject {
    func selectAgent(id: UUID) {
        // Synchronous, runs on main thread
    }
}
```

**Actor approach:**
```swift
@MainActor
class TavernCoordinator: ObservableObject {
    private let registry: AgentRegistry  // Actor

    func selectAgent(id: UUID) async {
        // Must await actor call
        if let agent = await registry.agent(id: id) {
            // Update UI state
        }
    }
}
```

**Consideration:** UI methods that call actor methods must become async. SwiftUI handles this via `.task` modifiers.


### Type Erasure Challenges

Current code uses `AnyAgent` for heterogeneous collections:

```swift
public final class AnyAgent: Agent, @unchecked Sendable {
    private let _send: (String) async throws -> String
    // ...
}
```

**Actor challenge:** Actors cannot be type-erased the same way. Solutions:

1. **Use existential types:**
```swift
private var agents: [UUID: any ActorAgent] = [:]
```

2. **Protocol with associated types:**
```swift
protocol ActorAgent: Actor {
    func send(_ message: String) async throws -> String
}

// Access via: await (agent as any ActorAgent).send(message)
```

3. **Wrapper actor pattern:**
```swift
actor AnyActorAgent {
    private let wrapped: any ActorAgent

    func send(_ message: String) async throws -> String {
        try await wrapped.send(message)
    }
}
```


### Performance Characteristics

**Actor hop overhead:**
- Each cross-actor call has minimal overhead (~nanoseconds)
- Non-issue for Tavern's use case (LLM calls take seconds)

**Mailbox serialization:**
- Actor methods are serialized per-actor
- Jake can only process one message at a time (intentional)
- Multiple mortal agents run truly in parallel (different actors)

**Memory:**
- Actors have slightly more overhead than classes
- Non-issue given agent count (tens, not thousands)


---


## Implementation Complexity


### Effort Estimation

| Component | Current LOC | Migration Effort | Notes |
|-----------|-------------|------------------|-------|
| Jake | 191 | Medium | Convert class to actor, remove queues |
| MortalAgent | 275 | Medium | Convert class to actor, async state methods |
| AgentRegistry | 102 | Low | Straightforward actor conversion |
| AgentSpawner | 131 | Low | Mainly call-site changes |
| CommitmentList | 191 | Low | Can stay class or become actor |
| TavernCoordinator | 144 | Medium | Add async to actor-calling methods |
| ChatViewModel | 259 | Low | Already @MainActor, add Task wrappers |
| TavernProject | 118 | Low | Initialization becomes async |


### Testing Changes

Current test pattern:
```swift
func testAgentTransitionsToWorking() async throws {
    let mock = MockClaudeCode()
    mock.queueJSONResponse(result: "Hello", sessionId: "test")

    let agent = MortalAgent(name: "Test", assignment: "Do stuff", claude: mock)
    XCTAssertEqual(agent.state, .idle)

    _ = try await agent.send("Go")
    XCTAssertEqual(agent.state, .idle)  // Back to idle after
}
```

Actor test pattern:
```swift
func testAgentTransitionsToWorking() async throws {
    let mock = MockClaudeCode()
    mock.queueJSONResponse(result: "Hello", sessionId: "test")

    let agent = MortalAgent(name: "Test", assignment: "Do stuff", claude: mock)
    let initialState = await agent.state
    XCTAssertEqual(initialState, .idle)

    _ = try await agent.send("Go")
    let finalState = await agent.state
    XCTAssertEqual(finalState, .idle)  // Back to idle after
}
```

**Key change:** State access requires `await`.


### Mock Infrastructure

```swift
actor MockActorClaudeCode: ClaudeCode {
    private var responses: [ClaudeCodeResult] = []
    private var capturedPrompts: [String] = []

    func queueResponse(_ result: ClaudeCodeResult) {
        responses.append(result)
    }

    func runSinglePrompt(prompt: String, ...) async throws -> ClaudeCodeResult {
        capturedPrompts.append(prompt)
        guard !responses.isEmpty else {
            throw MockError.noResponseQueued
        }
        return responses.removeFirst()
    }
}
```


---


## Migration Path


### Phase 1: Foundation (1-2 days)

1. Create new `ActorAgent` protocol alongside existing `Agent`
2. Create actor versions of core types that don't break existing code
3. Update tests to support both patterns


### Phase 2: Agent Migration (2-3 days)

1. Convert `AgentRegistry` to actor
2. Convert `Jake` to actor
3. Convert `MortalAgent` to actor
4. Update `AgentSpawner` to work with actor agents


### Phase 3: Coordination (1-2 days)

1. Update `TavernCoordinator` methods to be async where needed
2. Update `ChatViewModel` to use Task wrappers for async calls
3. Update `AgentListViewModel` similarly


### Phase 4: Cleanup (1 day)

1. Remove old `Agent` protocol
2. Remove `AnyAgent` type-erasure
3. Remove `DispatchQueue` synchronization code
4. Remove `@unchecked Sendable` conformances


### Phase 5: Verification (1 day)

1. Run full test suite
2. Stress testing for concurrent agent operations
3. UI responsiveness testing


### Total Estimated Effort: 6-9 days


### Rollback Strategy

If issues arise during migration:

1. Actor and class implementations can coexist temporarily
2. Protocol abstraction allows gradual migration
3. Git branches isolate experimental work


---


## Open Questions


### 1. Custom Executor for Agents?

Should agents share a custom executor for better control over scheduling?

```swift
actor Jake {
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        TavernExecutor.shared.asUnownedSerialExecutor()
    }
}
```

**Pros:** Control over priority, debugging, metrics
**Cons:** Complexity, may not be needed


### 2. Global Actor for Agent Coordination?

Should there be a `@TavernActor` global actor for shared state?

```swift
@globalActor
actor TavernActor {
    static let shared = TavernActor()
}

@TavernActor
class SomeSharedState { ... }
```

**Pros:** Unified isolation for cross-cutting concerns
**Cons:** May become bottleneck


### 3. Distributed Actors for Future Multi-Machine?

The PRD mentions potential distributed/replicated doc store. Should we design for distributed actors now?

```swift
distributed actor MortalAgent {
    // Would require ActorSystem setup
}
```

**Recommendation:** Defer. In-process actors first, distributed later if needed.


### 4. Actor-Based CommitmentList?

Should `CommitmentList` become an actor, or remain a class with its current queue-based synchronization?

**Arguments for actor:**
- Consistency with rest of system
- Cleaner code

**Arguments for class:**
- Simpler for value-like semantics
- Can use `Sendable` struct instead


### 5. How to Handle ClaudeCode?

`ClaudeCode` (the SDK) is a protocol with class implementations. Should it become actor-based?

**Recommendation:** Leave as-is. It's an external dependency that works with async/await already. Agents wrap it.


### 6. Error Handling Across Actor Boundaries

How should errors propagate when an agent calls another agent?

```swift
actor Parent {
    func delegateTask() async throws {
        let child = await spawn(...)
        try await child.work()  // Error propagates naturally
    }
}
```

**Recommendation:** Use standard Swift error handling. Actor boundaries don't change error semantics.


### 7. State Observation

How do ViewModels observe actor state changes?

**Option A: Polling**
```swift
@MainActor
class ChatViewModel {
    func observeAgent() {
        Task {
            while true {
                state = await agent.state
                try await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
```

**Option B: Callbacks**
```swift
actor MortalAgent {
    private var observers: [@Sendable (AgentState) -> Void] = []

    func addObserver(_ callback: @escaping @Sendable (AgentState) -> Void) {
        observers.append(callback)
    }

    private func notifyObservers() {
        for observer in observers {
            observer(_state)
        }
    }
}
```

**Option C: AsyncStream**
```swift
actor MortalAgent {
    private var stateContinuation: AsyncStream<AgentState>.Continuation?

    var stateStream: AsyncStream<AgentState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
        }
    }
}
```

**Recommendation:** AsyncStream is most idiomatic for Swift concurrency.


---


## Conclusion

The Actor Model architecture provides a compelling upgrade path for Tavern's concurrency model. By leveraging Swift's built-in actor isolation, we eliminate the error-prone manual synchronization currently spread across the codebase. The migration is substantial but tractable, with clear phases and rollback options.

Key benefits:
- Compile-time safety instead of runtime discipline
- Cleaner code without queue management
- Better alignment with Swift's direction
- Natural fit for the agent mental model

Key risks:
- Reentrancy requires careful protocol design
- Migration touches many files
- Some patterns (type erasure) require rethinking

The actor model is well-suited for Tavern's needs: moderate concurrency (tens of agents, not thousands), async I/O-bound work (LLM calls), and clear isolation boundaries between agents.
