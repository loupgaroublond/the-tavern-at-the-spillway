# Reactive Streams Architecture — Complete Treatise

This document contains my complete analysis of applying Reactive Streams patterns to the Tavern multi-agent orchestrator.


## Research Findings


### Current Codebase Analysis

The existing architecture uses a straightforward request-response pattern:

**Communication Flow (current):**
1. `ChatViewModel.sendMessage()` → `agent.send(message)` → `ClaudeCode.runSinglePrompt()` → response
2. `@Published` properties in view models trigger SwiftUI updates
3. Agent state transitions happen synchronously within serial dispatch queues

**Concurrency Model (current):**
- Serial `DispatchQueue` per agent for thread-safe state access
- `@MainActor` for all view models and coordinator
- `async/await` for API calls only
- No streaming; batch responses only

**Existing Combine Usage:**
- `ChatViewModel` imports Combine but only uses `@Published` (ObservableObject conformance)
- `MockClaudeCode` imports Combine but doesn't use any publishers
- No `PassthroughSubject`, `CurrentValueSubject`, or custom publishers anywhere

**Key Files and Their Patterns:**

| File | Pattern | Notes |
|------|---------|-------|
| `Jake.swift` | Request-response | `send()` is async, waits for full response |
| `MortalAgent.swift` | Request-response + state machine | Detects "DONE" in response text |
| `ChatViewModel.swift` | Imperative + @Published | No reactive composition |
| `TavernCoordinator.swift` | Imperative | Direct method calls, no streams |
| `AgentSpawner.swift` | Factory pattern | Creates agents, no event emission |


### PRD Requirements Mapping

**Invariant 4: "User attention is sacred"**

This is the primary driver for considering reactive streams. The PRD states:
- "Never force new content on user without consent"
- "Surface questions, don't interrupt"
- Notifications convey complexity so user knows what they're getting into

Reactive Streams addresses this through **demand-driven delivery**. The user's attention becomes a subscriber that pulls updates rather than having updates pushed onto them.

**Attention Model (Section 5.2):**
- Tabs for engaged agents
- Notification bubbles for questions
- "Whack-a-mole" jumping between conversations
- Zoom in/out mechanics

This maps to:
- Each open tab = active subscription with demand
- Notification bubbles = bounded buffer with badge count
- Zooming in = increasing demand from 0 to unbounded
- Zooming out = cancelling subscription (or reducing demand to 0)

**Bubbling (Section 5.3):**
- Upward: child → parent → grandparent → user
- Lateral: siblings collaborating
- Direct: agent to user with oversight

This is **stream composition**:
- Upward bubbling = `merge` of child streams through parent filter
- Lateral = `merge` of sibling streams (coordinated by parent)
- Direct = bypass operator with audit/tap for oversight

**Question Triage:**
- Quick vs deep classification
- Notifications convey complexity

This is **stream transformation**:
- `classify()` operator tags each question
- `partition()` splits into quick/deep streams
- Different backpressure policies per partition


### Swift Reactive Primitives

**Combine (Apple's implementation):**

```swift
// Publisher protocol
public protocol Publisher {
    associatedtype Output
    associatedtype Failure: Error
    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure
}

// Subscriber protocol with demand
public protocol Subscriber {
    associatedtype Input
    associatedtype Failure: Error
    func receive(subscription: Subscription)
    func receive(_ input: Input) -> Subscribers.Demand  // Key: returns demand
    func receive(completion: Subscribers.Completion<Failure>)
}
```

Key operators for Tavern:
- `merge()` — combine agent streams
- `filter()` — question triage
- `debounce()` — prevent rapid-fire notifications
- `buffer()` — hold questions during zoom-out
- `flatMap()` — spawn child subscriptions

**AsyncSequence (Swift 5.5+):**

```swift
public protocol AsyncSequence {
    associatedtype AsyncIterator: AsyncIteratorProtocol
    associatedtype Element where AsyncIterator.Element == Element
    func makeAsyncIterator() -> AsyncIterator
}
```

AsyncSequence is pull-based (inherently backpressure-aware) and integrates better with Swift concurrency:

```swift
for await question in agent.questions {
    // Automatically applies backpressure — next question
    // isn't pulled until this iteration completes
    await display(question)
}
```

**Comparison:**

| Aspect | Combine | AsyncSequence |
|--------|---------|---------------|
| Backpressure | Explicit demand signaling | Implicit via pull iteration |
| Threading | Scheduler-based | Swift concurrency (Task, Actor) |
| Error handling | Typed failures | `throws` |
| Operators | Rich operator library | Growing, but fewer built-in |
| Apple direction | Maintenance mode | Active development |
| Testing | TestScheduler patterns | Actor isolation testing |


## How This Maps to Attention/Backpressure


### The Attention Budget Model

Think of user attention as a **limited resource with explicit budget**:

```swift
actor UserAttention {
    private var budget: Int = 0
    private var pendingQuestions: [AgentQuestion] = []

    // User opens a chat slot
    func allocate(slots: Int) async {
        budget += slots
        await deliverPending()
    }

    // User closes a chat
    func deallocate(slots: Int) {
        budget = max(0, budget - slots)
    }

    // Agents submit questions
    func receive(_ question: AgentQuestion) async {
        if budget > 0 {
            budget -= 1
            await deliver(question)
        } else {
            pendingQuestions.append(question)
            // Badge count updates, but no interruption
        }
    }
}
```

This is backpressure: the `budget` is the subscriber's demand, and questions buffer when demand is exhausted.


### Stream Types for Tavern

**AgentEventStream:**
```swift
enum AgentEvent {
    case statusChange(AgentState)
    case question(Question, urgency: QuestionUrgency)
    case completion(Commitment)
    case discovery(String)  // Oddities noticed during work
    case error(Error)
}

// Each agent publishes its events
protocol AgentPublisher {
    var events: AsyncStream<AgentEvent> { get }
}
```

**QuestionStream (bubbled up):**
```swift
struct BubbledQuestion {
    let originalAgent: AgentID
    let parentChain: [AgentID]
    let question: Question
    let urgency: QuestionUrgency
    let timestamp: Date
}

// Jake merges all child streams
func mergeChildQuestions(_ children: [AgentPublisher]) -> AsyncStream<BubbledQuestion> {
    // merge + map to add parent chain
}
```

**NotificationStream (to user):**
```swift
enum UserNotification {
    case badge(agentId: AgentID, count: Int)
    case popup(question: BubbledQuestion)
    case statusUpdate(agentId: AgentID, status: String)
}

// Subject for UI binding
@MainActor
class NotificationManager: ObservableObject {
    @Published var notifications: [UserNotification] = []
    @Published var badgeCounts: [AgentID: Int] = [:]

    private var subscription: AnyCancellable?

    func subscribe(to stream: AsyncStream<UserNotification>, demand: Int) {
        // Pull only `demand` items, buffer rest
    }
}
```


### Implementing Bubbling with Streams

```swift
class MortalAgentReactive: AgentPublisher {
    let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation
    private var childSubscriptions: [AnyCancellable] = []

    init(/* deps */) {
        (events, continuation) = AsyncStream.makeStream()
    }

    func addChild(_ child: AgentPublisher) {
        // Subscribe to child events, forward with transformation
        Task {
            for await event in child.events {
                switch event {
                case .question(let q, let urgency):
                    // Decide: handle locally or bubble up
                    if canHandleLocally(q) {
                        await handleQuestion(q)
                    } else {
                        continuation.yield(.question(q, urgency: urgency))
                    }
                case .discovery(let text):
                    // Always bubble discoveries
                    continuation.yield(.discovery("[from \(child.name)] \(text)"))
                default:
                    break  // Status changes stay local
                }
            }
        }
    }
}
```


### Jake as the Stream Hub

```swift
actor Jake: AgentPublisher {
    let events: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    // Merged stream of all mortal agents
    private var mortalQuestions: AsyncStream<BubbledQuestion>

    // Triage: quick questions go to popup, deep go to badge
    func triageQuestions() async {
        for await question in mortalQuestions {
            let urgency = await classifyUrgency(question)
            switch urgency {
            case .quick:
                continuation.yield(.question(question.question, urgency: .quick))
            case .deep:
                // Buffer, increment badge, don't interrupt
                await bufferForLater(question)
            }
        }
    }
}
```


## Trade-offs Considered


### Complexity vs Benefit

**Complexity costs:**
- Every developer must understand reactive paradigm
- Debugging subscriptions and backpressure is non-trivial
- Testing requires understanding of virtual schedulers or actor isolation
- Stack traces through operators are hard to read

**Benefits:**
- Attention management is declarative, not imperative
- Composition scales — adding new routing logic is adding operators
- Streaming responses (when available) integrate naturally
- Backpressure prevents notification storms automatically

**Verdict:** The complexity is justified if and only if:
1. The system scales to many concurrent agents (10+)
2. Streaming responses become available
3. Simpler patterns (polling, event callbacks) prove inadequate


### Combine vs AsyncSequence

**Combine advantages:**
- Rich operator library (150+ operators)
- `@Published` integrates with SwiftUI
- Well-documented patterns
- Backpressure is explicit via `Subscribers.Demand`

**AsyncSequence advantages:**
- Native to Swift concurrency model
- Simpler mental model (just a for loop)
- Better stack traces
- Actor isolation for thread safety
- Apple's future direction

**Recommendation:** Use AsyncSequence for the core stream types, with minimal Combine bridging for SwiftUI integration:

```swift
// Core: AsyncSequence
actor Agent {
    var events: AsyncStream<AgentEvent> { /* ... */ }
}

// Bridge: Combine for SwiftUI
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []

    func observe(_ agent: Agent) {
        Task {
            for await event in agent.events {
                handleEvent(event)  // Updates @Published
            }
        }
    }
}
```


### Pull vs Push Models

**Current (push-ish):**
- Agent receives prompt → processes → pushes response to view model
- View model pushes to SwiftUI via `@Published`
- No explicit demand signaling

**Reactive (pull):**
- Subscriber requests demand
- Publisher emits only what's demanded
- Excess buffers or drops (based on policy)

**Hybrid approach:**
- Agents push to buffers (AsyncStream continuation)
- UI pulls from buffers at its own pace
- Badge counts reflect buffer depth

This hybrid respects that we can't pause Claude mid-response (push from API), but we can control delivery to user (pull from buffer).


### Buffer Policies

When user attention is exhausted, what happens to new questions?

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `.unbounded` | Buffer everything | Never lose questions |
| `.bufferingNewest(n)` | Keep last N, drop old | Fresh info matters more |
| `.bufferingOldest(n)` | Keep first N, drop new | FIFO priority |
| `.customPolicy` | Domain-specific logic | Urgency-based retention |

**Recommendation for Tavern:**
- Questions: Unbounded buffer (never lose a question)
- Status updates: Bufferring newest (latest state is what matters)
- Discoveries: Unbounded (oddities shouldn't be lost)


## Implementation Complexity


### Minimal Reactive Layer

If we commit to reactive streams, here's the minimal implementation:

**New types needed:**

```swift
// Core event types
enum AgentEvent: Sendable { /* ... */ }
enum UserNotification: Sendable { /* ... */ }

// Stream wrapper for agents
protocol AgentPublisher: Sendable {
    var events: AsyncStream<AgentEvent> { get }
}

// Stream merger for Jake
actor StreamHub {
    private var childStreams: [AsyncStream<AgentEvent>] = []
    func mergedQuestions() -> AsyncStream<BubbledQuestion>
}

// Demand manager for user attention
actor AttentionBudget {
    func allocate(_ slots: Int)
    func deallocate(_ slots: Int)
    func receive(_ notification: UserNotification) async -> DeliveryDecision
}
```

**Changes to existing types:**

| Type | Change |
|------|--------|
| `Agent` protocol | Add `var events: AsyncStream<AgentEvent>` |
| `Jake` | Become `StreamHub` host |
| `MortalAgent` | Emit events via continuation |
| `TavernCoordinator` | Manage `AttentionBudget` |
| `ChatViewModel` | Subscribe to agent event streams |
| `AgentListViewModel` | Derive from merged status stream |

**Estimated effort:** 2-3 weeks for a senior Swift developer familiar with async/await.


### Testing Strategy

**Unit tests for streams:**

```swift
func testQuestionBubbling() async {
    let child = TestAgent()
    let parent = TestAgent()
    parent.addChild(child)

    // Emit question from child
    child.emit(.question(Question(text: "Help?"), urgency: .quick))

    // Verify it bubbles to parent
    var events: [AgentEvent] = []
    for await event in parent.events.prefix(1) {
        events.append(event)
    }

    XCTAssertEqual(events.count, 1)
    if case .question(let q, _) = events[0] {
        XCTAssertEqual(q.text, "Help?")
    }
}
```

**Integration tests for backpressure:**

```swift
func testBackpressureBuffering() async {
    let attention = AttentionBudget()
    await attention.allocate(1)  // One slot

    // Emit 3 questions
    for i in 1...3 {
        await attention.receive(.popup(question: q(i)))
    }

    // First should deliver immediately
    XCTAssertEqual(await attention.deliveredCount, 1)
    // Others should buffer
    XCTAssertEqual(await attention.bufferedCount, 2)

    // Allocate more budget
    await attention.allocate(1)
    XCTAssertEqual(await attention.deliveredCount, 2)
}
```


## Migration Path from Current State


### Phase 1: Add Stream Infrastructure (Non-Breaking)

1. Create `AgentEvent` enum and `AgentPublisher` protocol
2. Add `AsyncStream<AgentEvent>` to `Agent` protocol as optional
3. Jake and MortalAgent emit events in parallel with existing paths
4. Nothing consumes the streams yet — existing code unchanged

**Risk:** Zero. Additive only.


### Phase 2: Bridge to UI (Parallel Path)

1. Create `StreamingChatViewModel` alongside existing `ChatViewModel`
2. New view model subscribes to agent event stream
3. Add feature flag to switch between implementations
4. Test both paths in parallel

**Risk:** Low. Old path is fallback.


### Phase 3: Add Attention Management

1. Implement `AttentionBudget` actor
2. Route notifications through budget manager
3. Add badge count UI based on buffer depth
4. Update notification delivery to respect demand

**Risk:** Medium. Changes notification behavior.


### Phase 4: Full Migration

1. Remove old `ChatViewModel` once streaming is stable
2. Make event streams required on `Agent` protocol
3. Remove parallel code paths
4. Clean up feature flags

**Risk:** Medium. Full commitment to new pattern.


### Rollback Strategy

Each phase has a clear rollback:
- Phase 1: Delete new types
- Phase 2: Delete new view model, revert feature flag
- Phase 3: Bypass budget manager, deliver all notifications
- Phase 4: This is the point of no return


## Open Questions


### 1. How does backpressure interact with ClaudeCodeSDK?

The SDK currently returns batch responses. We cannot apply backpressure to Claude mid-response. Backpressure only applies **between** responses:

- User is overwhelmed → agent can still finish current response
- Backpressure prevents **starting** the next turn until user catches up
- This may require SDK changes or a wrapper that gates new prompts

**Proposed solution:** Agent checks user demand before sending next prompt. If demand is zero, agent enters "waiting for attention" state.


### 2. What happens to buffered questions if agent is dismissed?

Options:
1. Drop them (user chose to dismiss)
2. Deliver immediately (last chance)
3. Archive to doc store (persistent record)

**Proposed solution:** Archive to doc store with "dismissed" flag. User can review later if they want.


### 3. How does lateral agent communication work with streams?

Siblings need to communicate without going through parent. Options:
1. Direct stream subscription between siblings
2. Shared "lateral" stream managed by parent
3. Message-passing actor pattern (not streams)

**Proposed solution:** Hybrid. Siblings can subscribe to each other's discovery streams. Formal requests go through parent.


### 4. Does streaming response support change the calculus?

If ClaudeCodeSDK adds streaming (likely, given industry trend), reactive streams become much more valuable:
- Token-by-token delivery needs backpressure
- UI can display partial responses
- User can interrupt mid-response

**Recommendation:** Design for streaming even if implementing batch-only first.


### 5. How does perseverance mode interact with backpressure?

In perseverance mode, system auto-prompts to continue. If user attention is exhausted:
- Should perseverance continue? (Agent works in background)
- Or should agent wait for attention budget?

**Proposed solution:** Perseverance continues regardless of attention budget. Questions buffer. Agent only pauses on explicit tool call for user attention.


## Conclusion

Reactive Streams is a powerful pattern that maps well to the Tavern's attention management requirements. The core insight — user attention as a subscriber with demand — is elegant and directly addresses Invariant 4.

However, the current v1 scope (batch responses, single-digit agent counts) doesn't demand this complexity. The implementation cost is significant, and the benefits only materialize at scale.

**Recommendation:**
- **For v1:** Use simpler patterns (polling, event callbacks, badge counts)
- **Design for reactive:** Keep interfaces compatible with future streaming
- **Trigger for migration:** When agent count exceeds 5 concurrent OR streaming responses become available

The migration path is well-defined and low-risk through phased introduction. This architecture remains a strong candidate for v2 or whenever scale demands it.
