# Message Bus Architecture: Complete Analysis

This document contains the full research, reasoning, and trade-off analysis for the Message Bus architecture proposal.


## Research Findings


### Current Architecture Analysis

The existing codebase uses a **direct method call** pattern for all communication:

1. **User to Agent**: `ChatViewModel.sendMessage()` calls `agent.send(text)` directly
2. **Agent to Claude**: `Jake.send()` and `MortalAgent.send()` call `claude.runSinglePrompt()` or `claude.resumeConversation()`
3. **Coordinator to Spawner**: `TavernCoordinator.spawnAgent()` calls `spawner.spawn(assignment:)`
4. **State observation**: SwiftUI's `@Published` properties on view models trigger UI updates

Key files examined:
- `/Tavern/Sources/TavernCore/Coordination/TavernCoordinator.swift` - Central hub with direct ownership
- `/Tavern/Sources/TavernCore/Chat/ChatViewModel.swift` - Wraps agents, calls send() directly
- `/Tavern/Sources/TavernCore/Agents/Jake.swift` - Calls ClaudeCode SDK directly
- `/Tavern/Sources/TavernCore/Agents/MortalAgent.swift` - Similar direct SDK calls
- `/Tavern/Sources/TavernCore/Agents/AgentSpawner.swift` - Factory with direct registry calls
- `/Tavern/Sources/TavernCore/Agents/AgentRegistry.swift` - Synchronous in-memory storage

**Thread safety approach**: All mutable state uses `DispatchQueue`-based synchronization with `@unchecked Sendable` conformance. This is fragile and requires careful discipline.


### PRD Communication Requirements

From `docs/seed-design/prd_2026-01-19.md`:

**Section 5.3 - Bubbling:**
> Routing is context-dependent, based on zoom level and user attention. CEO model: delegate most things, pay closer attention to specific teams when needed.
>
> - Can be upward (child to parent to grandparent to user)
> - Can be lateral (siblings collaborating)
> - Can be direct to user (with oversight)
> - Parent failure can delay delivery (acknowledged)

**Section 5.5 - Question Triage:**
> - Questions classified as quick vs deep
> - Notifications convey complexity so user knows what they're getting into
> - Parent agent chooses notification approach for its children (popup vs periodic summary)

**Section 9.3 - Discovery Sharing:**
> Agents (even drones) prompted to notice oddities and share them via messaging, even while continuing main task. Can't enforce via deterministic hook - relies on prompt engineering encouraging curiosity + social behavior.

**Section 5.2 - Attention Model:**
> - "Whack-a-mole" style jumping between conversations
> - Notification bubbles when agents have questions
> - User joins session - deterministic code injects "user joined" message
> - User leaves - agent knows not to pause for interaction

**Section 4.4 - Operating Modes:**
> - Chat mode - pings user when agent stops
> - Perseverance mode - system auto-prompts to continue, agent must explicitly request user attention


### What the PRD Implies About Message Flow

The PRD describes several distinct message flows:

1. **User-directed messages**: User sends message to specific agent
2. **Agent responses**: Agent response to user (via parent chain or direct)
3. **Questions**: Agent needs input, routed based on context/urgency
4. **Status updates**: State transitions (working/waiting/done)
5. **Discovery messages**: Agent notices something, broadcasts to siblings/parent
6. **System events**: Spawn, dismiss, verification results
7. **Attention signals**: "User joined", "user left", presence indicators

The current architecture handles #1 and #2. The others are not yet implemented but are core to the PRD vision.


## How Message Bus Maps to PRD Requirements


### Bubbling Implementation

A message bus enables bubbling through **hierarchical routing**:

```swift
protocol TavernMessage {
    var id: UUID { get }
    var timestamp: Date { get }
    var sourceAgentId: UUID { get }
    var targetPolicy: TargetPolicy { get }
}

enum TargetPolicy {
    case direct(agentId: UUID)
    case parent                      // Route to immediate parent
    case bubbleToUser                // Route up chain until reaches user
    case bubbleWithTimeout(seconds: TimeInterval)  // Bubble, but stop if no parent responds in time
    case broadcast(scope: BroadcastScope)
    case siblings
}

struct QuestionMessage: TavernMessage {
    let question: String
    let complexity: QuestionComplexity  // .quick or .deep
    let sourceAgentId: UUID
    var targetPolicy: TargetPolicy = .bubbleToUser
}
```

The bus router maintains the agent hierarchy (from AgentRegistry or a new structure) and routes messages according to policy. Parent agents can intercept questions and decide whether to answer, forward, or aggregate.


### Question Triage Implementation

Parent agents subscribe to `QuestionMessage` from their children:

```swift
class ParentAgentMessageHandler {
    func handleChildQuestion(_ question: QuestionMessage) {
        switch question.complexity {
        case .quick:
            // Answer directly or forward immediately
            bus.publish(question.withPolicy(.direct(userId)))
        case .deep:
            // Aggregate into periodic summary
            pendingQuestions.append(question)
            scheduleDigestIfNeeded()
        }
    }
}
```

This implements the PRD's "Parent agent chooses notification approach" through configuration on the parent's message handler.


### Discovery Sharing Implementation

Discovery messages use broadcast targeting:

```swift
struct DiscoveryMessage: TavernMessage {
    let observation: String
    let sourceAgentId: UUID
    var targetPolicy: TargetPolicy = .broadcast(.siblings)
}

// Agent implementation
func noticeOddity(_ observation: String) {
    bus.publish(DiscoveryMessage(observation: observation, sourceAgentId: id))
}
```

Sibling agents subscribe to `DiscoveryMessage` and can act on discoveries without disrupting their main task.


### Attention Model Implementation

The bus enables the "user joined/left" signals cleanly:

```swift
struct UserPresenceMessage: TavernMessage {
    enum Event { case joined, left }
    let event: Event
    let agentId: UUID  // Which agent's chat the user is viewing
}

// When user opens an agent's chat
bus.publish(UserPresenceMessage(event: .joined, agentId: agent.id))

// Agent subscribes to its own presence messages
func handlePresenceChange(_ msg: UserPresenceMessage) {
    isUserPresent = (msg.event == .joined)
    // Adjust behavior: pause for interaction vs continue autonomously
}
```


## Trade-offs Considered


### Centralized vs Federated Bus

**Centralized (chosen)**: Single `TavernMessageBus` instance routes all messages. Simpler mental model, easier debugging, natural audit point.

**Federated**: Each project has its own bus, buses can bridge. More scalable for multi-project, but adds complexity. Deferred to future if needed.


### Typed Messages vs Generic Payload

**Typed messages (chosen)**: Each message type is a distinct Swift struct conforming to `TavernMessage`. Compile-time safety, clear contracts.

**Generic payload**: Single message type with JSON or dictionary payload. More flexible, but loses type safety and requires runtime parsing.


### Sync vs Async Delivery

**Async delivery (chosen)**: Messages are queued and delivered asynchronously. Better isolation, prevents cascading failures, natural for Swift concurrency.

**Sync delivery**: Immediate inline callback. Simpler debugging but creates coupling and potential deadlocks.


### Push vs Pull

**Push (chosen)**: Bus delivers messages to subscribers. Natural fit for reactive UI (SwiftUI).

**Pull**: Consumers poll for messages. Simpler implementation but less responsive and harder to integrate with SwiftUI.


### Persistence

**Optional persistence (chosen)**: Messages can optionally be persisted for replay/debugging. Aligns with PRD's rewind/branch requirements (Section 13).

The existing DocStore could be extended to store message logs per session/agent, enabling time-travel debugging.


## Implementation Complexity


### Core Bus Infrastructure

```swift
// Core protocol
protocol TavernMessage: Identifiable, Sendable {
    var id: UUID { get }
    var timestamp: Date { get }
    var sourceAgentId: UUID { get }
    var targetPolicy: TargetPolicy { get }
}

// Bus implementation
actor TavernMessageBus {
    private var subscriptions: [ObjectIdentifier: [MessageSubscription]] = [:]
    private var router: MessageRouter

    func publish<M: TavernMessage>(_ message: M) async {
        let targets = router.resolve(message)
        for target in targets {
            await target.receive(message)
        }
    }

    func subscribe<M: TavernMessage>(
        to messageType: M.Type,
        handler: @escaping (M) async -> Void
    ) -> SubscriptionToken {
        // Register handler for message type
    }
}
```

Estimated LOC: 300-500 for core bus, router, and subscription management.


### Message Type Definitions

Each message type requires a struct:

```swift
struct AgentResponseMessage: TavernMessage { ... }
struct QuestionMessage: TavernMessage { ... }
struct StateChangeMessage: TavernMessage { ... }
struct DiscoveryMessage: TavernMessage { ... }
struct UserPresenceMessage: TavernMessage { ... }
struct SpawnMessage: TavernMessage { ... }
struct DismissMessage: TavernMessage { ... }
struct VerificationResultMessage: TavernMessage { ... }
```

Estimated: 10-15 message types initially, ~50-100 LOC each.


### Router Configuration

```swift
struct MessageRouter {
    private var agentHierarchy: AgentHierarchy
    private var routingRules: [RoutingRule]

    func resolve<M: TavernMessage>(_ message: M) -> [MessageTarget] {
        switch message.targetPolicy {
        case .direct(let id): return [.agent(id)]
        case .parent: return [.agent(agentHierarchy.parent(of: message.sourceAgentId))]
        case .bubbleToUser: return resolveBubble(from: message.sourceAgentId)
        case .broadcast(let scope): return resolveBroadcast(scope, from: message.sourceAgentId)
        case .siblings: return agentHierarchy.siblings(of: message.sourceAgentId).map { .agent($0) }
        }
    }
}
```

Estimated: 200-400 LOC for routing logic.


### Integration Points

Components that need modification:

1. **Jake.swift**: Publish `AgentResponseMessage`, subscribe to `UserPresenceMessage`
2. **MortalAgent.swift**: Same as Jake, plus publish `QuestionMessage`, `DiscoveryMessage`
3. **TavernCoordinator.swift**: Publish `SpawnMessage`, `DismissMessage`, subscribe to state changes
4. **ChatViewModel.swift**: Subscribe to agent messages instead of direct observation
5. **AgentListViewModel.swift**: Subscribe to state change messages
6. **CommitmentVerifier.swift**: Publish `VerificationResultMessage`

Estimated migration: 2-3 days of focused refactoring.


## Migration Path from Current State


### Phase 1: Introduce Bus Infrastructure (Non-breaking)

1. Create `TavernMessageBus`, `TavernMessage` protocol, basic message types
2. Create `MessageRouter` with simple direct routing
3. Add bus instance to `TavernCoordinator`
4. Add logging subscriber for observability

**All existing code continues working; bus exists alongside direct calls.**


### Phase 2: Dual-Mode Components

1. Modify agents to publish messages AND continue direct returns
2. Modify view models to optionally subscribe to bus
3. Verify behavior matches with either path
4. Add tests for bus-based message flow

**Both paths work; bus path can be feature-flagged.**


### Phase 3: Bus-First Communication

1. Switch ChatViewModel to bus subscription as primary
2. Add bubbling support to router
3. Implement question triage message handling
4. Remove duplicate direct call paths

**Bus becomes primary; direct calls removed.**


### Phase 4: Advanced Features

1. Add discovery sharing with sibling broadcast
2. Implement user presence notifications
3. Add message persistence for debugging/rewind
4. Implement per-parent notification policies


## Open Questions


### 1. Bus Threading Model

Should the bus be a Swift actor (as sketched above) or use DispatchQueue like other components?

**Actor pros**: Compile-time safety, natural async integration
**DispatchQueue pros**: Consistency with existing codebase, simpler mental model for team

**Recommendation**: Use actor. The bus is a good place to start modernizing the concurrency model.


### 2. Message Persistence Format

If messages are persisted for rewind/debugging, what format?

**Options**:
- JSON files in DocStore (consistent with existing pattern)
- SQLite for queryability
- Append-only log file for performance

**Recommendation**: JSON in DocStore initially. Can optimize later if needed.


### 3. Subscription Lifecycle

How are subscriptions managed when components are deallocated?

**Options**:
- Manual unsubscribe with tokens
- Weak references with automatic cleanup
- Scoped subscriptions tied to component lifetime

**Recommendation**: Subscription tokens with clear ownership. Explicit is better than magic.


### 4. Error Propagation

When a subscriber fails to process a message, what happens?

**Options**:
- Ignore and log
- Retry with backoff
- Dead-letter queue for manual review
- Propagate error to publisher

**Recommendation**: Log and continue for v1. Add dead-letter queue if silent failures become a problem.


### 5. Message Ordering

Are messages guaranteed to be delivered in order?

**Options**:
- FIFO per source (natural with actor)
- Total ordering via sequence numbers
- No guarantees (eventual consistency)

**Recommendation**: FIFO per source is sufficient for PRD requirements. Total ordering adds unnecessary complexity.


### 6. Integration with Event Sourcing

If the team also considers Event Sourcing (proposal 05), can the bus serve as the event log?

**Yes, partially**: Messages can be persisted as events, but event sourcing requires additional infrastructure (projections, snapshots, replay). The bus provides the transport; event sourcing adds the storage and replay semantics.


## Comparison with Other Proposals


### vs Flat Coordinator (01)

Flat Coordinator collapses coordination into one type; Message Bus distributes it via messaging. These are opposites.

**Combine**: A Flat Coordinator could use a bus for inter-agent communication while keeping internal coordination methods. The bus handles external messaging; the coordinator handles internal lifecycle.


### vs Actor Model (02)

Actor Model uses Swift actors for isolation; Message Bus uses explicit message passing.

**Combine**: Actors ARE a message bus at the language level. A TavernMessageBus implemented as an actor gets both benefits. The question is whether to use explicit message types (bus) or implicit method calls (pure actor).

**Recommendation**: Use actors for the bus implementation, but define explicit message types for observability and routing flexibility.


### vs Document-Centric (03)

Document-Centric stores state in docs; Message Bus routes ephemeral messages.

**Combine**: Messages can be persisted to DocStore for durability. The bus handles transport; DocStore handles persistence. This aligns with the PRD's "doc store is source of truth" while adding real-time messaging.


### vs Supervisor Trees (04)

Supervisor Trees define parent-child relationships for failure handling; Message Bus defines routing topology.

**Combine**: The bus router uses the supervisor tree to resolve `.parent` and `.bubbleToUser` policies. The tree structure enables the routing; the bus provides the transport.


### vs Event Sourcing (05)

Event Sourcing persists all state changes as events; Message Bus routes runtime messages.

**Combine**: The bus can persist messages as events. Event projections can be implemented as message subscribers. This is a natural synergy if both patterns are desired.


## Recommendation

The Message Bus architecture is a strong fit for Tavern's PRD requirements, particularly:

- Bubbling (Section 5.3)
- Question triage (Section 5.5)
- Discovery sharing (Section 9.3)
- Attention model (Section 5.2)

However, it adds significant complexity for v1, which focuses on basic chat and spawning.

**Suggested approach**:

1. **v1**: Continue with direct calls. Get basic functionality working.
2. **v1.5**: Introduce bus infrastructure as non-breaking addition. Add logging subscriber for observability.
3. **v2**: Migrate inter-agent communication to bus. Implement bubbling and question triage.
4. **v3**: Add persistence, advanced routing, and integration with other patterns (actors, event sourcing).

This phased approach gets the benefits of message-based architecture without blocking the MVP.
