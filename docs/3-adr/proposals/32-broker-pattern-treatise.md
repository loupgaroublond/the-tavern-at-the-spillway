# Broker Pattern Architecture: Complete Analysis

This document contains the full research, reasoning, and trade-off analysis for the Broker Pattern architecture proposal.


## Research Findings


### Current Architecture Analysis

The existing codebase uses a **direct method call** pattern for all communication:

1. **User to Agent**: `ChatViewModel.sendMessage()` calls `agent.send(text)` directly
2. **Agent to Claude**: `Jake.send()` and `MortalAgent.send()` call `claude.runSinglePrompt()` or `claude.resumeConversation()` directly
3. **Coordinator to Spawner**: `TavernCoordinator.spawnAgent()` calls `spawner.spawn(assignment:)` directly
4. **State observation**: SwiftUI's `@Published` properties on view models trigger UI updates reactively

Key files examined:

- `/Tavern/Sources/TavernCore/Coordination/TavernCoordinator.swift` - Central hub using direct method calls to spawner and registry
- `/Tavern/Sources/TavernCore/Chat/ChatViewModel.swift` - Wraps agents, calls `send()` directly, manages UI state
- `/Tavern/Sources/TavernCore/Agents/Jake.swift` - Calls ClaudeCode SDK directly, manages session state internally
- `/Tavern/Sources/TavernCore/Agents/MortalAgent.swift` - Similar pattern, with commitment verification logic embedded
- `/Tavern/Sources/TavernCore/Agents/AgentSpawner.swift` - Factory with direct registry calls for registration
- `/Tavern/Sources/TavernCore/Agents/AgentRegistry.swift` - Synchronous in-memory storage with DispatchQueue isolation

**Thread safety approach**: All mutable state uses `DispatchQueue`-based synchronization with `@unchecked Sendable` conformance. The `TavernCoordinator`, `ChatViewModel`, and `AgentListViewModel` are `@MainActor`-bound for UI safety.

**Current routing logic**: There is none. Messages go from user to specific agent and back. There is no inter-agent communication, no bubbling, no parent-child message passing.


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

**Section 5.2 - Attention Model:**
> - Notification bubbles when agents have questions
> - "Whack-a-mole" style jumping between conversations
> - User joins session - deterministic code injects "user joined" message
> - User leaves - agent knows not to pause for interaction

**Section 4.4 - Operating Modes:**
> - Chat mode - pings user when agent stops
> - Perseverance mode - system auto-prompts to continue, agent must explicitly request user attention

**Section 9.3 - Discovery Sharing:**
> Agents (even drones) prompted to notice oddities and share them via messaging, even while continuing main task.


### What the PRD Implies About Routing

The PRD describes several routing behaviors that require active decision-making:

1. **Context-dependent routing**: Whether a question goes to user or parent depends on user's current focus and agent depth
2. **Parent-controlled policies**: Parents decide how to aggregate/forward child notifications
3. **User presence awareness**: Agents behave differently based on whether user is watching
4. **Question classification**: Quick vs deep questions route differently
5. **Discovery broadcasting**: Observations shared laterally to siblings

These are not simple publish/subscribe patterns. They require an intelligent intermediary that understands:
- The agent hierarchy
- User attention state
- Per-parent notification preferences
- Message urgency and type
- Aggregation and batching rules


## How Broker Pattern Differs from Message Bus (Proposal 15)

The Message Bus and Broker Pattern are often confused because both centralize communication. The key differences:

| Aspect | Message Bus | Broker Pattern |
|--------|-------------|----------------|
| **Routing** | Topic-based subscription; consumers decide what to receive | Rule-based routing; broker decides where to send |
| **Role** | Passive relay; forwards to all matching subscribers | Active mediator; inspects and routes each message |
| **Coupling** | Publishers know topics, subscribers know topics | Only broker knows routing; agents just submit |
| **Transformation** | Typically none; message delivered as-is | Broker can modify, enrich, filter messages |
| **Ordering** | Per-topic ordering at best | Broker controls delivery order and timing |
| **Queuing** | Optional, per-topic | Central; broker manages all queues |
| **Configuration** | Subscription-time | Runtime routing rules |


### Message Bus Approach

In a message bus, agents publish to topics:

```swift
// Agent publishes without knowing who receives
bus.publish(QuestionMessage(question: "Need help", sourceAgentId: id))

// Multiple consumers subscribe to the topic
bus.subscribe(to: QuestionMessage.self) { msg in
    // Each subscriber receives all matching messages
}
```

The bus is passive: it forwards messages to all subscribers. Routing logic is distributed across subscribers who filter what they care about.


### Broker Pattern Approach

In a broker, agents submit messages for routing:

```swift
// Agent submits without knowing destination
broker.submit(QuestionMessage(question: "Need help", sourceAgentId: id))

// Broker's routing engine decides destination
func route(_ message: QuestionMessage) -> [Destination] {
    let parent = hierarchy.parent(of: message.sourceAgentId)
    let parentPrefs = preferences.get(parent.id)

    switch parentPrefs.questionHandling {
    case .immediate:
        return [.agent(parent.id)]
    case .aggregate:
        pendingQuestions[parent.id].append(message)
        scheduleDigest(for: parent.id)
        return []  // Held for batching
    case .escalate:
        return [.user]
    }
}
```

The broker is active: it owns the routing logic and makes decisions per-message.


### Which Fits Tavern Better?

The PRD's requirements lean toward Broker Pattern:

1. **Parent-controlled notification policies**: Parents configure how their children's questions are handled. This is per-parent routing configuration, not topic subscription.

2. **User attention awareness**: Routing depends on whether the user is currently viewing an agent. This is dynamic state that the broker tracks, not something subscribers filter.

3. **Question classification and aggregation**: Quick questions route immediately; deep questions may be batched. This is transformation and queuing, not just forwarding.

4. **Discovery broadcasting with filtering**: Siblings should receive discoveries, but not spam. The broker can deduplicate and rate-limit.

A Message Bus could implement these features through complex subscriber logic and filtering, but the Broker Pattern places this logic where it belongs: in a single, testable routing component.


## How Broker Pattern Maps to PRD Bubbling/Routing


### Bubbling Implementation

The broker maintains the agent hierarchy and traverses it when routing:

```swift
struct TavernBroker {
    private let hierarchy: AgentHierarchy
    private let preferences: ParentPreferences
    private let userAttention: UserAttentionTracker

    func route(_ question: QuestionMessage) -> RoutingDecision {
        let source = question.sourceAgentId
        let depth = hierarchy.depth(of: source)

        // Check if user is watching this agent directly
        if userAttention.isUserFocused(on: source) {
            return .deliverToUser(immediately: true)
        }

        // Walk up the hierarchy
        var current = source
        while let parent = hierarchy.parent(of: current) {
            let prefs = preferences.get(parent)

            switch prefs.childQuestionPolicy {
            case .absorb:
                return .deliverTo(parent, transform: addBubblingContext)
            case .forward:
                current = parent  // Continue bubbling
            case .aggregate(let interval):
                return .queue(for: parent, batchInterval: interval)
            }
        }

        // Reached top of hierarchy (Jake or user)
        return .deliverToUser(immediately: question.complexity == .quick)
    }
}
```


### Context-Dependent Routing

The broker tracks context that affects routing:

```swift
class UserAttentionTracker {
    private var focusedAgentId: UUID?
    private var openChatViewModels: Set<UUID>

    func userFocused(on agentId: UUID) {
        focusedAgentId = agentId
        // Notify broker that routing may change
        broker.contextChanged(.userFocus(agentId))
    }

    func userLeft(agentId: UUID) {
        if focusedAgentId == agentId {
            focusedAgentId = nil
        }
    }
}
```

This implements the PRD's "user joined/left" signaling through the broker, which adjusts routing accordingly.


### Parent Notification Preferences

Parents configure how their children's messages are handled:

```swift
enum ChildQuestionPolicy {
    case absorb        // Parent handles all child questions
    case forward       // Bubble continues to grandparent
    case aggregate(TimeInterval)  // Batch and summarize
}

enum ChildDiscoveryPolicy {
    case ignore        // Don't surface discoveries to parent
    case summarize     // Aggregate into periodic report
    case forward       // Immediate forwarding
}

struct ParentPreferences {
    var questionPolicy: ChildQuestionPolicy
    var discoveryPolicy: ChildDiscoveryPolicy
    var urgentBypass: Bool  // High-priority bypasses batching
}
```

These preferences are stored in the broker (or fetched from DocStore) and applied during routing.


## Trade-offs Considered


### Centralization vs Distribution

**Centralized broker (chosen)**: Single routing component, single source of truth for routing rules, single point of configuration.

**Distributed routing**: Each agent has routing logic; more resilient but harder to debug and inconsistent.

**Rationale**: The PRD's routing requirements are inherently centralized (hierarchy, user attention, parent preferences). Distributing this logic would replicate the broker's state across agents.


### Synchronous vs Asynchronous Delivery

**Asynchronous (chosen)**: Messages are queued and delivered asynchronously. Enables batching, rate limiting, and non-blocking submission.

**Synchronous**: Immediate delivery with blocking. Simpler for request-response, but prevents batching and blocks senders.

**Rationale**: The PRD describes batching (periodic summaries) and non-blocking operation (agents continue working). Async is required.


### In-Memory vs Persistent Queue

**In-memory with optional persistence (chosen)**: Messages are queued in memory for speed; persistence is optional for durability.

**Persistent-first**: All messages written to disk before routing. More durable but slower.

**Rationale**: Most messages are ephemeral (agent responses). Persistence is valuable for audit logs and debugging, but not for every message. The broker can selectively persist based on message type.


### Broker as Actor vs Class with Queue

**Actor (chosen)**: Swift actor provides isolation guarantees and natural async integration.

**Class with DispatchQueue**: Matches existing codebase patterns but requires manual synchronization.

**Rationale**: The broker handles many concurrent messages from multiple agents. Actor isolation prevents data races without manual locking. This is a good opportunity to modernize the concurrency model.


## Implementation Complexity


### Core Broker Infrastructure

```swift
actor TavernBroker {
    private let hierarchy: AgentHierarchy
    private let preferences: PreferenceStore
    private let userAttention: UserAttentionTracker
    private let routingRules: RoutingEngine
    private var pendingQueues: [UUID: MessageQueue]
    private var subscriptions: [ObjectIdentifier: [Subscription]]

    func submit<M: BrokeredMessage>(_ message: M) async {
        let decision = routingRules.route(message,
            hierarchy: hierarchy,
            attention: userAttention,
            preferences: preferences)

        await execute(decision, for: message)
    }

    private func execute(_ decision: RoutingDecision, for message: some BrokeredMessage) async {
        switch decision {
        case .deliverTo(let destination, let transform):
            let transformed = transform?(message) ?? message
            await deliver(transformed, to: destination)

        case .deliverToUser(let immediately):
            if immediately {
                await notifyUser(message)
            } else {
                pendingUserMessages.append(message)
            }

        case .queue(let target, let interval):
            pendingQueues[target, default: MessageQueue()].enqueue(message)
            scheduleBatchDelivery(for: target, after: interval)

        case .drop(let reason):
            log.debug("Dropped message: \(reason)")
        }
    }
}
```

Estimated LOC: 400-600 for core broker, routing engine, and queue management.


### Routing Engine

```swift
struct RoutingEngine {
    var rules: [RoutingRule]

    func route<M: BrokeredMessage>(_ message: M,
                                    hierarchy: AgentHierarchy,
                                    attention: UserAttentionTracker,
                                    preferences: PreferenceStore) -> RoutingDecision {
        // Find first matching rule
        for rule in rules {
            if rule.matches(message) {
                return rule.decide(message, hierarchy, attention, preferences)
            }
        }
        return .drop(reason: "No matching rule")
    }
}

protocol RoutingRule {
    func matches(_ message: some BrokeredMessage) -> Bool
    func decide(_ message: some BrokeredMessage,
                _ hierarchy: AgentHierarchy,
                _ attention: UserAttentionTracker,
                _ preferences: PreferenceStore) -> RoutingDecision
}

// Example rule: bubble questions to parent
struct BubbleQuestionsRule: RoutingRule {
    func matches(_ message: some BrokeredMessage) -> Bool {
        message is QuestionMessage
    }

    func decide(_ message: some BrokeredMessage,
                _ hierarchy: AgentHierarchy,
                _ attention: UserAttentionTracker,
                _ preferences: PreferenceStore) -> RoutingDecision {
        // Implementation from earlier section
    }
}
```

Estimated LOC: 200-400 for routing engine and common rules.


### Message Types

```swift
protocol BrokeredMessage: Identifiable, Sendable {
    var id: UUID { get }
    var timestamp: Date { get }
    var sourceAgentId: UUID { get }
    var priority: MessagePriority { get }
}

struct QuestionMessage: BrokeredMessage {
    let id = UUID()
    let timestamp = Date()
    let sourceAgentId: UUID
    let priority: MessagePriority
    let question: String
    let complexity: QuestionComplexity
}

struct DiscoveryMessage: BrokeredMessage { ... }
struct StateChangeMessage: BrokeredMessage { ... }
struct ResponseMessage: BrokeredMessage { ... }
struct UserPresenceMessage: BrokeredMessage { ... }
```

Estimated: 10-15 message types, ~30-50 LOC each.


### Integration Points

Components requiring modification:

1. **Jake.swift**: Submit messages through broker instead of returning directly; receive routed messages
2. **MortalAgent.swift**: Same as Jake; submit questions, discoveries; receive routed responses
3. **TavernCoordinator.swift**: Initialize and own the broker; forward spawn/dismiss events
4. **ChatViewModel.swift**: Receive messages from broker subscription; submit user messages to broker
5. **AgentListViewModel.swift**: Subscribe to state change messages from broker
6. **CommitmentVerifier.swift**: Submit verification results through broker

Estimated migration: 3-5 days of focused refactoring for full integration.


## Migration Path from Current State


### Phase 1: Introduce Broker Infrastructure (Non-breaking)

1. Create `TavernBroker` actor with basic message types
2. Create `RoutingEngine` with simple direct routing rules
3. Add broker instance to `TavernCoordinator` without using it
4. Add logging subscriber for observability

**Existing code continues working unchanged.**


### Phase 2: Parallel Routing for Observation

1. Modify agents to submit messages to broker AND return directly
2. Broker logs all messages but does not affect delivery
3. Compare broker's routing decisions against actual behavior
4. Validate routing rules match intended behavior

**Broker observes but does not control.**


### Phase 3: Broker-Controlled Response Delivery

1. Switch agent response delivery to go through broker
2. ChatViewModel receives responses from broker subscription
3. Implement user presence tracking and attention-based routing
4. Remove direct response returns from agents

**Broker controls agent-to-user communication.**


### Phase 4: Full Brokered Communication

1. Implement question bubbling with parent preferences
2. Add discovery message broadcasting
3. Implement batching and aggregation
4. Add cross-cutting concerns (metrics, authorization)
5. Remove all direct inter-component messaging

**Broker is sole communication channel.**


### Phase 5: Advanced Features

1. Message persistence for audit and rewind
2. Dynamic routing rule updates
3. Rate limiting and circuit breaking
4. Integration with monitoring daemons


## Comparison with Other Proposals


### vs Message Bus (15)

Message Bus uses topic-based pub/sub with passive routing; Broker uses rule-based active routing.

**Key difference**: Message Bus distributes routing logic to subscribers; Broker centralizes it.

**When to prefer Message Bus**: Simple broadcast patterns, minimal transformation, subscribers know what they want.

**When to prefer Broker**: Complex routing rules, context-dependent decisions, message transformation.

**For Tavern**: Broker is better aligned with PRD's parent-controlled policies and context-dependent bubbling.


### vs Flat Coordinator (01)

Flat Coordinator centralizes lifecycle management; Broker centralizes communication.

**Combine**: A Flat Coordinator could use a Broker for all messaging while handling lifecycle internally. The coordinator spawns agents; the broker routes their messages.


### vs Actor Model (02)

Actor Model provides isolation through Swift actors; Broker provides communication mediation.

**Combine**: The broker itself can be an actor (as proposed). Agents as actors submit to the broker actor. This combines actor isolation with brokered routing.


### vs Supervisor Trees (04)

Supervisor Trees define parent-child relationships for failure handling; Broker uses hierarchy for routing.

**Combine**: The supervision hierarchy and the routing hierarchy are the same. The broker uses supervisor tree structure for bubbling. When an agent fails, the supervisor restarts it; when it has a question, the broker routes it.


### vs Document-Centric (03)

Document-Centric stores state in files; Broker handles ephemeral messaging.

**Combine**: Parent notification preferences stored in DocStore; broker reads them. Message persistence writes to DocStore. The doc store is the source of truth for routing configuration.


### vs Event Sourcing (05)

Event Sourcing persists all state changes; Broker routes ephemeral messages.

**Combine**: The broker can write messages as events to an event store. This provides audit trail and replay capability. Not all messages need persistence, but the broker decides which do.


### vs Hierarchical Tree (09)

Hierarchical Tree organizes agents in parent-child relationships; Broker routes based on that hierarchy.

**Combine**: These are complementary. Hierarchical Tree defines the structure; Broker implements communication within it.


## Open Questions


### 1. Broker Resilience

What happens when the broker fails?

**Options**:
- All communication stops (accept the centralization risk)
- Messages queue locally in agents until broker recovers
- Hot standby broker takes over
- Fallback to direct communication

**Recommendation**: Accept that broker failure stops communication for v1. Add local queuing in Phase 2 if this becomes a real concern. The broker as a Swift actor in the same process is unlikely to fail independently.


### 2. Routing Rule Storage

Where are routing rules stored?

**Options**:
- Hardcoded in `RoutingEngine`
- Configuration file loaded at startup
- DocStore documents that can be updated at runtime
- Per-agent preferences in agent metadata

**Recommendation**: Hardcode default rules; load parent preferences from DocStore. This balances simplicity with configurability.


### 3. Message Retention

How long are messages retained in the broker?

**Options**:
- Fire and forget (no retention)
- Retain until acknowledged by destination
- Retain for N minutes for debugging
- Persist to DocStore for audit

**Recommendation**: Fire and forget for ephemeral messages; optional persistence for audit-worthy messages (questions, discoveries). Retention adds complexity and memory pressure.


### 4. Backpressure

What happens when destinations cannot consume messages?

**Options**:
- Drop oldest messages
- Drop newest messages
- Block sender
- Apply per-destination rate limits

**Recommendation**: Drop oldest for aggregated messages (summaries replace older ones); block sender for critical messages (should be rare). Rate limiting prevents runaway agents.


### 5. Message Priorities

How are priorities handled?

**Options**:
- Single FIFO queue
- Priority queues per destination
- Urgent bypass (high priority skips queue)
- Priority affects batching (urgent prevents aggregation)

**Recommendation**: Priority affects batching. Urgent messages bypass aggregation; normal messages can be batched. This matches PRD's "quick vs deep" question classification.


### 6. Testing Strategy

How is broker routing tested?

**Options**:
- Unit test routing engine with mock hierarchy/attention
- Integration test with real agents
- Property-based testing for routing rule coverage

**Recommendation**: All three. Unit tests verify individual rules; integration tests verify end-to-end; property tests find edge cases in rule interactions.


## Recommendation

The Broker Pattern is a strong fit for Tavern's PRD requirements, particularly the complex routing described in Section 5.3 (bubbling) and Section 5.5 (question triage). It provides:

1. **Centralized routing logic** that can be tested and debugged in one place
2. **Context-dependent routing** based on user attention and parent preferences
3. **Message transformation and batching** for periodic summaries
4. **Cross-cutting concerns** (logging, metrics) applied uniformly

The main risks are:

1. **Single point of failure** - mitigated by in-process actor stability
2. **Added complexity** - mitigated by phased migration
3. **Latency overhead** - mitigated by async processing and batching benefits

**Suggested approach**:

1. **v1**: Continue with direct calls. Get basic functionality working.
2. **v1.5**: Introduce broker infrastructure with logging-only mode. Observe message patterns.
3. **v2**: Enable broker-controlled response delivery. Implement user presence tracking.
4. **v2.5**: Add parent preferences and question bubbling. Implement batching.
5. **v3**: Full brokered communication. Add persistence and advanced features.

This phased approach validates the broker's value incrementally without blocking the MVP.


## Appendix: Swift Actor Implementation Considerations

Swift actors provide several benefits for the broker:

1. **Isolation**: No manual synchronization; actor-isolated state is safe
2. **Reentrancy**: Async methods can await without blocking the actor
3. **Integration**: Natural fit with Swift concurrency and async/await

Potential issues:

1. **Actor hopping**: Crossing actor boundaries has overhead; minimize hops
2. **Priority inversion**: Low-priority work can block high-priority work; use task priorities
3. **Debugging**: Actor isolation can make debugging harder; add logging

The broker as an actor is a good pattern because:
- It naturally handles concurrent message submission
- Its internal state (queues, routing tables) is protected
- Async delivery aligns with message passing semantics
