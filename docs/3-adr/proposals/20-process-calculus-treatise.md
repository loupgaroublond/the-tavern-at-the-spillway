# Process Calculus Architecture: Complete Analysis

This document contains my complete research and thinking on applying process calculus (pi-calculus and CSP) to the Tavern multi-agent orchestrator. It is the companion to the 1-pager proposal.


## Research Findings


### Current Codebase Analysis

The existing Tavern architecture exhibits several patterns that could benefit from formalization:

**Thread Safety via DispatchQueue:**
Every major component uses a serial `DispatchQueue` for thread safety:
- `Jake.swift`: `DispatchQueue(label: "com.tavern.Jake")` protects `_sessionId`, `_projectPath`, `_isCogitating`
- `MortalAgent.swift`: `DispatchQueue(label: "com.tavern.MortalAgent")` protects `_state`, `_sessionId`
- `AgentRegistry.swift`: `DispatchQueue(label: "com.tavern.AgentRegistry")` protects `_agents`, `_nameToId`
- `CommitmentList.swift`: `DispatchQueue(label: "com.tavern.CommitmentList")` protects `_commitments`

This pattern is error-prone because:
1. It requires `@unchecked Sendable` conformance, disabling compiler safety checks
2. Each queue is independent; cross-component operations require careful coordination
3. Forgetting to wrap access in `queue.sync` causes silent data races

**Agent Protocol:**
```swift
public protocol Agent: AnyObject, Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var state: AgentState { get }
    func send(_ message: String) async throws -> String
    func resetConversation()
}
```

The `send` method is the primary communication channel. However, it conflates:
- User-to-agent messages
- Parent-to-child delegations
- Status reporting
- Error bubbling

In process calculus, these would be distinct channel types with different protocols.

**State Machine:**
```
AgentState: idle -> working -> waiting/verifying -> done
            ^                         |
            +-------------------------+
```

This state machine is encoded implicitly in method behavior rather than explicitly in types. Process calculus would make transitions explicit as channel communications.

**Coordinator as Central Hub:**
`TavernCoordinator` owns Jake, the spawner, and all view models. It routes all interactions:
```swift
func selectAgent(id:)
func spawnAgent(assignment:selectAfterSpawn:)
func dismissAgent(id:)
```

In CSP terms, the coordinator is a *monitor process* that serializes access to shared resources. However, it runs on `@MainActor`, creating a potential bottleneck.


### Pi-Calculus Primer

The pi-calculus (Robin Milner, 1992) is a process algebra for modeling concurrent computation. Key concepts:

**Processes:**
- `0` - the null process (does nothing)
- `P | Q` - parallel composition (P and Q run concurrently)
- `!P` - replication (infinite copies of P)
- `(nu x) P` - restriction (creates private channel x visible only in P)

**Actions:**
- `x(y).P` - receive on channel x, bind to y, continue as P
- `x<y>.P` - send y on channel x, continue as P
- `tau.P` - silent action (internal transition)

**Example - Simple Request/Response:**
```
Client = server<request>.server(response).0
Server = !server(req).server<handle(req)>.0
System = (nu server)(Client | Server)
```

**Key Properties:**
- **Mobility:** Channel names can be passed as messages (unlike CCS)
- **Scope extrusion:** Private channels can become shared through communication
- **Bisimulation:** Two processes are equivalent if an observer cannot distinguish them


### CSP Primer

Communicating Sequential Processes (Tony Hoare, 1978) focuses on synchronization:

**Events and Channels:**
- Processes synchronize on *events*
- Channels are typed paths for communication
- `c!v` sends value v on channel c
- `c?x` receives from channel c into x

**Operators:**
- `P [] Q` - external choice (environment decides)
- `P |~| Q` - internal choice (process decides)
- `P || Q` - parallel composition with synchronization
- `P ||| Q` - interleaving (no synchronization)
- `P ; Q` - sequential composition

**CSP vs Pi-Calculus:**
| Aspect | CSP | Pi-calculus |
|--------|-----|-------------|
| Focus | Synchronization | Mobility |
| Channels | Static | Dynamic (first-class) |
| Choice | Rich external/internal | Limited |
| Tools | FDR, PAT | Limited |
| Swift mapping | Closer to AsyncStream | Requires more abstraction |


### Swift Concurrency Mapping

Swift's structured concurrency provides building blocks that map to process calculus concepts:

**Actors as Processes:**
```swift
actor JakeProcess {
    // State is isolated
    private var sessionId: String?

    // Methods are serialized entry points
    func receive(_ message: String) async throws -> String { ... }
}
```

Actors provide:
- Process isolation (no shared mutable state)
- Serialized mailbox (implicit channel for method calls)
- Reentrancy (suspension points allow interleaving)

**AsyncStream as Channels:**
```swift
let (stream, continuation) = AsyncStream.makeStream(of: Message.self)

// Sender process
continuation.yield(message)

// Receiver process
for await msg in stream {
    process(msg)
}
```

Properties:
- Unbuffered or buffered
- Single consumer (unlike pi-calculus which allows multiple receivers)
- Back-pressure via `BufferingPolicy`

**Task Groups as Process Spawning:**
```swift
await withTaskGroup(of: Result.self) { group in
    // Spawn child processes
    group.addTask { await childProcess1() }
    group.addTask { await childProcess2() }

    // Join (await completion)
    for await result in group {
        collect(result)
    }
}
```

This is analogous to `(nu c1, c2)(P1 | P2)` with implicit join.

**Challenges:**

1. **No channel passing:** Swift's AsyncStream cannot be sent through another stream easily
2. **Single consumer:** AsyncStream is single-reader; pi-calculus allows multiple receivers
3. **No external choice:** Cannot await "first of these channels" without manual infrastructure
4. **Actor reentrancy:** Actors can interleave at suspension points, unlike CSP's atomic operations


## Mapping to PRD Requirements


### Agent Types and Channels

**Jake (Daemon):**
```
Jake = userChannel(msg).
       (delegate<assignment, responseChannel>.
        responseChannel(result).userChannel<result>.Jake
       + directHandle(msg).userChannel<response>.Jake)
```

Jake receives from user, either delegates or handles directly, sends response, loops.

**Mortal Agent:**
```
Mortal(assignment) =
    workChannel(task).
    (complete<result>.Done
    + needInput<question>.inputChannel(answer).Mortal(assignment)
    + delegate<subtask, childChannel>.childChannel(childResult).Mortal(assignment))
```

Mortal agents work until completion, request input, or delegate.

**Channel Types:**
| Channel | Direction | Payload |
|---------|-----------|---------|
| `user.inbox` | User -> Jake | String (message) |
| `user.outbox` | Jake -> User | String (response) |
| `delegation` | Parent -> Child | (assignment, responseChannel) |
| `completion` | Agent -> System | (agentId, result) |
| `question` | Agent -> User | (agentId, question) |
| `verification` | Agent <-> Verifier | (commitment, result) |


### Bubbling as Channel Hierarchies

The PRD specifies bubbling for questions and status:

```
Bubble(parent) =
    childQuestion(q).
    (canHandle(q) -> handle(q).0
    + !canHandle(q) -> parent<q>.Bubble(parent))
```

Each agent holds a reference to its parent's question channel. If it cannot handle a child's question, it forwards upward. This is natural in pi-calculus where channels are first-class values.

**Swift Implementation:**
```swift
struct AgentChannels {
    let inbox: AsyncStream<Message>
    let outbox: AsyncStream<Response>.Continuation
    let parentQuestions: AsyncStream<Question>.Continuation?
    let childChannels: [UUID: (inbox: AsyncStream<Assignment>.Continuation,
                               outbox: AsyncStream<Result>)]
}
```


### Commitment Verification as Process

```
Verifier =
    verifyRequest(commitment).
    runAssertion(commitment.assertion).
    (passed -> verifyResult<(commitment.id, .passed)>.Verifier
    + failed -> verifyResult<(commitment.id, .failed, reason)>.Verifier)
```

This makes verification synchronous from the agent's perspective: send commitment, await result.


### State Transitions as Channel Protocols

Instead of internal state machine:
```swift
enum AgentState { case idle, working, waiting, verifying, done }
```

Model as protocol on channels:
```
AgentProtocol =
    start.work*.
    (done.0
    + wait.input.AgentProtocol
    + verify.verified.AgentProtocol)
```

Where `*` means repetition. This makes the protocol explicit and checkable.


## Trade-offs Considered


### Formal Verification vs Pragmatic Testing

**Formal verification benefits:**
- Catches entire classes of bugs (deadlock, livelock, starvation)
- Documents invariants in executable form
- Scales to complex multi-agent scenarios

**Pragmatic testing benefits:**
- Faster development iteration
- Tests exercise actual code paths
- No translation gap between model and implementation

**Recommendation:** Use process calculus for design-time reasoning about agent protocols, but rely on runtime tests for implementation correctness. The formal model is a specification, not a proof.


### Channel Granularity

**Fine-grained (one channel per message type):**
```swift
struct AgentChannels {
    let textMessages: AsyncStream<String>
    let delegations: AsyncStream<Delegation>
    let completions: AsyncStream<Completion>
    let questions: AsyncStream<Question>
    // etc.
}
```

**Coarse-grained (one channel, discriminated union):**
```swift
enum AgentMessage {
    case text(String)
    case delegation(Delegation)
    case completion(Completion)
    case question(Question)
}

struct AgentChannels {
    let messages: AsyncStream<AgentMessage>
}
```

**Trade-off:**
- Fine-grained enables selective waiting and clearer protocols
- Coarse-grained is simpler to manage and closer to current `send(_:)` API

**Recommendation:** Start coarse-grained for v1, refine as protocol complexity grows.


### Synchronous vs Asynchronous Channels

**Synchronous (CSP-style):**
- Sender blocks until receiver is ready
- Natural synchronization points
- Can cause deadlock if not careful

**Asynchronous (buffered):**
- Sender continues immediately
- Requires buffer management
- Matches Swift's AsyncStream default behavior

**Recommendation:** Use asynchronous channels with bounded buffers. Swift's AsyncStream supports `BufferingPolicy.bounded(capacity:)` for back-pressure.


### Actor Reentrancy

Swift actors are reentrant: when an actor awaits, other calls can interleave. This breaks CSP's assumption of atomic process actions.

**Options:**
1. **Accept reentrancy:** Design protocols to be reentrant-safe
2. **Use serial executors:** `@globalActor` with serial executor serializes all access
3. **Explicit guards:** Use state machines to reject interleaved calls

**Recommendation:** Accept reentrancy but design channel protocols to be order-independent. Use state machine to reject invalid transitions.


## Implementation Complexity


### Effort Estimation

| Component | Complexity | Effort |
|-----------|------------|--------|
| Channel infrastructure | Medium | 2-3 days |
| Jake refactor to channels | Medium | 2-3 days |
| MortalAgent refactor | Medium | 2-3 days |
| Coordinator refactor | High | 3-5 days |
| Bubbling implementation | High | 3-5 days |
| Verification channel | Low | 1 day |
| Testing infrastructure | Medium | 2-3 days |
| **Total** | | **15-25 days** |


### New Abstractions Required

**Channel<T>:**
```swift
actor Channel<T: Sendable> {
    private var buffer: [T] = []
    private var waiters: [CheckedContinuation<T, Never>] = []

    func send(_ value: T) async {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: value)
        } else {
            buffer.append(value)
        }
    }

    func receive() async -> T {
        if let value = buffer.first {
            buffer.removeFirst()
            return value
        } else {
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
}
```

**ChannelSet (for external choice):**
```swift
func select<T>(_ channels: [AsyncStream<T>]) async -> (index: Int, value: T) {
    // Return first available message from any channel
}
```

This is non-trivial to implement correctly in Swift.

**ProcessRegistry:**
```swift
actor ProcessRegistry {
    private var processes: [UUID: any Process] = [:]
    private var channels: [ChannelID: AnyChannel] = [:]

    func spawn<P: Process>(_ process: P, channels: ChannelConfig) -> ProcessHandle
    func terminate(_ handle: ProcessHandle)
    func createChannel<T>(_ type: T.Type) -> Channel<T>
}
```


### Migration Strategy

**Phase 1: Introduce Channel Abstraction (non-breaking)**
- Create `Channel<T>` type alongside existing code
- Add channel-based variants of `send(_:)` as parallel API
- Test both paths work correctly

**Phase 2: Migrate Jake**
- Jake becomes an actor with explicit input/output channels
- `ChatViewModel` connects to Jake's channels
- Validate with existing tests

**Phase 3: Migrate MortalAgent**
- Add delegation channel for spawning children
- Add completion channel for signaling done
- Update spawner to provision channels

**Phase 4: Add Bubbling**
- Implement parent-channel passing
- Add question forwarding logic
- Test multi-level hierarchies

**Phase 5: Formalize Protocols**
- Document channel protocols in CSP/pi-calculus notation
- Add runtime protocol violation detection
- Consider static analysis tooling


## Migration Path from Current State


### Incremental Approach

The current architecture uses `DispatchQueue`-based synchronization. Migration can proceed incrementally:

**Step 1: Actor Wrapper**

Wrap existing classes in actors to gain isolation:
```swift
actor JakeActor {
    private let jake: Jake

    func send(_ message: String) async throws -> String {
        try await jake.send(message)
    }
}
```

This is non-breaking but adds a layer.

**Step 2: Explicit Channels**

Replace direct method calls with channel sends:
```swift
// Before
let response = try await jake.send(message)

// After
await jakeInbox.send(.userMessage(message))
let response = await jakeOutbox.receive()
```

**Step 3: Protocol Documentation**

Write down the expected message sequences in CSP:
```
UserSession = userInput -> sendToJake -> jakeResponse -> display -> UserSession
JakeLoop = receiveMessage -> (delegate + handle) -> sendResponse -> JakeLoop
```

**Step 4: Runtime Checks**

Add protocol monitors that flag violations:
```swift
actor ProtocolMonitor {
    enum State { case awaitingInput, processing, awaitingResponse }
    var state: State = .awaitingInput

    func transition(on event: Event) throws {
        switch (state, event) {
        case (.awaitingInput, .messageReceived): state = .processing
        case (.processing, .delegated): state = .awaitingResponse
        case (.processing, .responded): state = .awaitingInput
        case (.awaitingResponse, .childCompleted): state = .processing
        default: throw ProtocolViolation(state: state, event: event)
        }
    }
}
```


### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Performance regression | Medium | Medium | Benchmark before/after; optimize hot paths |
| Increased complexity | High | Medium | Good documentation; team training |
| Subtle channel semantics bugs | Medium | High | Extensive testing; formal reasoning |
| Migration breaks existing features | Low | High | Incremental migration; extensive regression tests |
| Over-engineering for v1 | High | Low | Start simple; add formalism when needed |


## Open Questions


### 1. Channel Naming and Discovery

How do processes find each other's channels?

**Options:**
- Central registry (like current AgentRegistry)
- Parent passes channels to children at spawn
- Named channels with lookup service

**Leaning toward:** Parent-passed channels with registry fallback.


### 2. Error Handling in Channel Operations

What happens when a channel operation fails?

**Options:**
- Channels never fail (design invariant)
- Channels can close; processes handle closure
- Errors propagate as special messages

**Leaning toward:** Channels can close; processes handle `nil` from receive as termination signal.


### 3. Backpressure and Buffers

How do we handle fast senders and slow receivers?

**Options:**
- Unbounded buffers (risk memory issues)
- Bounded buffers with blocking send
- Bounded buffers with dropped messages

**Leaning toward:** Bounded buffers with async back-pressure (sender waits for space).


### 4. Tool Support for Verification

Can we get any formal verification tooling?

**Options:**
- Manual reasoning (current approach)
- Translate to PROMELA for SPIN model checker
- Build custom Swift DSL with checking
- Wait for better Swift concurrency tooling

**Leaning toward:** Manual reasoning with runtime monitors for v1; investigate translation for complex protocols later.


### 5. Integration with DocStore

The PRD emphasizes "doc store is source of truth." How do channels interact?

**Possible design:**
- Channels are ephemeral (in-memory only)
- Channel events are logged to doc store for audit
- Some channels back to files (work queues)

**Leaning toward:** Channels ephemeral with optional logging; work queues are doc-store-backed channels.


### 6. UI Integration

The UI is `@MainActor`. How do channels cross the actor boundary?

**Options:**
- MainActor holds channel ends
- Dedicated bridge actor
- AsyncSequence passthrough

**Leaning toward:** ChatViewModel holds channel continuations; receives flow through AsyncSequence to UI.


## Conclusion

Process Calculus architecture offers powerful abstractions for reasoning about agent communication and concurrency. The formalism maps well to Swift's structured concurrency primitives, with some gaps around external choice and channel mobility.

**Strengths for Tavern:**
- Makes agent protocols explicit and checkable
- Provides clean model for bubbling and delegation
- Aligns with PRD's emphasis on independent verification

**Weaknesses:**
- Steep learning curve for team
- No production Swift tooling for formal verification
- May be over-engineering for v1's simpler requirements

**Recommendation:** Consider Process Calculus for v2+ when agent protocols become complex enough to warrant formal specification. For v1, the Actor Model (proposal 02) provides similar isolation benefits with less conceptual overhead.

If pursuing this architecture:
1. Start with channel abstraction library
2. Migrate Jake as proof of concept
3. Document protocols in CSP notation
4. Build runtime protocol monitors
5. Defer formal verification tooling to later phase
