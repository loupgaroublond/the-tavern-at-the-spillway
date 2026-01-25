# Mediator Pattern Architecture: Complete Analysis

This document contains the full research, rationale, and trade-off analysis for the Mediator Pattern architecture proposal.


## 1. Research Findings: Current Architecture


### 1.1 TavernCoordinator's Mediator-Like Qualities

The current `TavernCoordinator` (144 lines) already exhibits mediator characteristics:

**Owned Components (Colleagues):**
- `jake: Jake` - The eternal top-level agent
- `spawner: AgentSpawner` - Factory for mortal agents
- `agentListViewModel: AgentListViewModel` - UI state for agent list
- `activeChatViewModel: ChatViewModel` - Current conversation view
- `chatViewModels: [UUID: ChatViewModel]` - Cached view models per agent

**Coordination Methods:**
- `selectAgent(id:)` - Routes selection from UI to view models
- `spawnAgent(assignment:)` - Coordinates spawner, list update, selection
- `dismissAgent(id:)` - Coordinates cleanup, list update, selection fallback
- `refresh()` - Propagates refresh to all sub-components

**Key Pattern:** Components don't reference each other directly. `ChatViewModel` doesn't know about `AgentSpawner`. `AgentListViewModel` doesn't instantiate `ChatViewModel`. The coordinator owns all cross-component logic.


### 1.2 Where the Pattern is Incomplete

The current implementation has gaps that prevent it from being a full mediator:

**1. Agent-to-Agent Communication is Missing**
```swift
// MortalAgent.swift - No reference to parent or siblings
public final class MortalAgent: Agent {
    // No way to message another agent
    // No parent reference
    // No child spawning capability
}
```

**2. Bubbling Not Implemented**
The PRD (Section 5.3) describes bubbling: "Can be upward (child -> parent -> grandparent -> user)." There's no implementation. A mediator would own this routing logic.

**3. User Attention Management Missing**
PRD Section 5.2 describes the attention model: "Notification bubbles when agents have questions." No `UserAttentionManager` exists. A mediator would route notifications.

**4. Verification Results Not Routed**
When `CommitmentVerifier` completes, results stay in `MortalAgent`. A mediator would propagate verification events to parent agents and UI.


### 1.3 Component Communication Analysis

Current direct references (that bypass potential mediation):

| From | To | Mechanism | Should Mediate? |
|------|----|-----------|-----------------|
| Jake | ClaudeCode | Direct call | No (external API) |
| MortalAgent | ClaudeCode | Direct call | No (external API) |
| MortalAgent | CommitmentVerifier | Direct call | Possibly (results should propagate) |
| ChatViewModel | Agent | Direct call via `AnyAgent` | Yes (could route through mediator) |
| AgentListViewModel | AgentSpawner | Query `activeAgents` | Yes (should query mediator) |
| TavernProject | TavernCoordinator | Owns | No (lifecycle, not communication) |

Components that should communicate but don't:

| From | To | Why Needed |
|------|----|------------|
| MortalAgent | Parent Agent | Bubbling questions |
| MortalAgent | Sibling Agent | Lateral collaboration |
| Any Agent | User Attention Manager | Surface questions |
| CommitmentVerifier | Parent Agent | Report verification results |


### 1.4 Existing Object Graph

```
TavernProject
  └── TavernCoordinator (proto-mediator)
        ├── Jake
        │     └── (uses ClaudeCode, SessionStore)
        ├── AgentSpawner
        │     ├── AgentRegistry
        │     │     └── [MortalAgent, MortalAgent, ...]
        │     └── NameGenerator
        ├── AgentListViewModel
        └── [ChatViewModel, ChatViewModel, ...]
```

The `TavernCoordinator` sits at the right level to become a full mediator.


## 2. Comparison with Related Patterns


### 2.1 Mediator vs. Message Bus (#15)

| Aspect | Mediator | Message Bus |
|--------|----------|-------------|
| **Coupling** | Components coupled to mediator interface | Components coupled to message types |
| **Routing** | Explicit code in mediator methods | Topic subscriptions, routing rules |
| **Discovery** | Mediator knows all colleagues | Publishers/subscribers are anonymous |
| **Flexibility** | Change routing by changing code | Change routing by changing config |
| **Type Safety** | Compile-time method calls | Runtime topic matching |
| **Debugging** | Breakpoint in mediator | Trace message flow through bus |
| **Scalability** | One mediator per scope | Bus can span processes |

**Key Difference:** The mediator has intimate knowledge of its colleagues and coordinates them explicitly. The bus decouples through topics and allows dynamic routing.

**When to Choose Mediator Over Bus:**
- Interaction patterns are stable and well-defined
- Compile-time type safety is important
- The system is single-process
- The team prefers explicit code over configuration


### 2.2 Mediator vs. Broker Pattern (#32)

| Aspect | Mediator | Broker |
|--------|----------|--------|
| **Role** | Coordinates known colleagues | Routes between arbitrary senders/receivers |
| **Transformation** | Typically none | Can transform messages in transit |
| **Queuing** | Usually synchronous | Can queue, batch, rate-limit |
| **Authorization** | Implicit in code | Explicit in routing rules |
| **State** | Owns colleague references | Owns routing configuration |
| **Error Handling** | Direct exceptions | Error routing rules |

**Key Difference:** The broker is an active intermediary that can transform, queue, and filter messages based on configurable rules. The mediator is a coordinator that calls methods on known objects.

**When to Choose Mediator Over Broker:**
- No need for message transformation or queuing
- Routing decisions are simple and code-based
- Components are known at compile time
- Cross-cutting concerns (auth, logging) handled elsewhere


### 2.3 Mediator vs. Flat Coordinator (#1)

These are closely related. Flat Coordinator proposes collapsing `TavernProject`, `TavernCoordinator`, `AgentSpawner`, and `AgentRegistry` into one type. Mediator proposes formalizing coordination patterns.

**Complementary, Not Competing:** You could apply Flat Coordinator (merge types) and then formalize the result as a Mediator. Or keep current types but have `TavernCoordinator` become a full mediator.

**Key Difference:** Flat Coordinator is about type structure. Mediator is about communication patterns.


## 3. PRD Requirements Mapping


### 3.1 Agent Communication (Section 4.1, 4.2)

**Requirement:** Agents have states (Working, Waiting, Done) and types (Jake, Mortal, Drone).

**Mediator Approach:** Mediator tracks agent states. State transitions route through mediator.

```swift
// Mediator handles state transitions
func agentDidTransition(_ agent: Agent, from oldState: AgentState, to newState: AgentState) {
    switch newState {
    case .waiting:
        routeQuestionToParent(agent)
    case .done:
        notifyParent(agent, completed: true)
        verifyCommitments(agent)
    case .failed:
        notifyParentOfFailure(agent)
    }
}
```


### 3.2 Bubbling (Section 5.3)

**Requirement:** "Routing is context-dependent, based on zoom level and user attention. Can be upward (child -> parent -> grandparent -> user). Can be lateral (siblings collaborating)."

**Mediator Approach:** Mediator owns the routing logic.

```swift
// Mediator implements bubbling
func routeQuestion(from agent: Agent, question: Question) {
    // Check if user is viewing this agent
    if userAttention.isViewing(agent.id) {
        presentDirectly(question, to: agent)
        return
    }

    // Bubble to parent
    if let parent = getParent(of: agent) {
        routeQuestion(from: parent, question: question.withContext(from: agent))
    } else {
        // Reached Jake, notify user
        userAttention.queue(question, for: agent)
    }
}
```


### 3.3 User Attention Model (Section 5.2)

**Requirement:** "User sees tabs/UX for agents they're engaged with. Notification bubbles when agents have questions."

**Mediator Approach:** Mediator owns `UserAttentionManager` as a colleague.

```swift
// Mediator coordinates attention
func userJoined(agentId: UUID) {
    injectMessage(to: agentId, content: "User joined session")
    userAttention.markEngaged(agentId)
}

func userLeft(agentId: UUID) {
    injectMessage(to: agentId, content: "User left session")
    userAttention.markDisengaged(agentId)
}
```


### 3.4 Commitment Verification (Section 4.7)

**Requirement:** "Commitment flow: Parent assigns task -> Child works -> Independent assertion verifies -> Only then is agent 'done'."

**Mediator Approach:** Verification results route through mediator.

```swift
// Mediator handles verification results
func verificationCompleted(for agent: MortalAgent, result: VerificationResult) {
    if result.allPassed {
        agent.markDone()
        notifyParent(agent, completed: true)
    } else {
        agent.continueWork(failedCommitments: result.failures)
        // Optionally escalate to user
        if result.criticalFailure {
            userAttention.escalate(agent, issue: result.description)
        }
    }
}
```


### 3.5 Agent Spawning (Section 6.2)

**Requirement:** "Parent specifies: assignment, sandbox config, model selection, token budget, commitments to prefill."

**Current Implementation:** `TavernCoordinator.spawnAgent(assignment:selectAfterSpawn:)` is minimal.

**Mediator Approach:** Mediator becomes the sole spawn entry point with full configuration.

```swift
struct SpawnConfiguration {
    let assignment: String
    let parentId: UUID?
    let model: ModelSelection
    let tokenBudget: Int?
    let sandboxConfig: SandboxConfig?
    let commitments: [Commitment]
    let onComplete: CompleteAction
}

func spawn(config: SpawnConfiguration) throws -> MortalAgent {
    let agent = createAgent(config)
    registerAgent(agent, parentId: config.parentId)
    notifyParent(config.parentId, childSpawned: agent)
    updateUI()
    return agent
}
```


## 4. Trade-offs Considered


### 4.1 Centralization vs. Distribution

**Argument for Centralization (Mediator):**
- All interaction logic in one place
- Easy to understand, test, and debug
- Changes to routing require changes to one file
- Compile-time type safety

**Argument Against:**
- Mediator can become a "god object"
- All changes bottleneck through one class
- Hard to parallelize development

**Recommendation:** At current scale (10-20 component types), centralization wins. Re-evaluate if component count exceeds 50.


### 4.2 Explicit Code vs. Configuration

**Argument for Explicit Code:**
- Debuggable with breakpoints
- Greppable (find all uses of a routing method)
- IDE support (autocomplete, refactoring)
- Compile-time error checking

**Argument for Configuration:**
- Runtime changes without recompilation
- Non-developers can modify routing
- Easier A/B testing of routing strategies

**Recommendation:** Tavern is a developer tool. Explicit code is the right choice. Users who want custom routing can fork.


### 4.3 Mediator Scope

**Option 1: Project-Scoped Mediator**
- One mediator per `TavernProject`
- Natural evolution of `TavernCoordinator`
- Matches current ownership model

**Option 2: Global Mediator**
- One mediator for entire app
- Coordinates cross-project concerns
- More complex but supports future multi-project features

**Option 3: Hierarchical Mediators**
- Global mediator for app-level coordination
- Project mediator for project-level coordination
- Agent mediator for agent-tree coordination

**Recommendation:** Start with project-scoped (Option 1). It's the natural evolution. Add hierarchy only when cross-project features are needed.


### 4.4 Colleague Registration

**Implicit Registration (Current):**
```swift
class TavernCoordinator {
    let jake: Jake  // Known at construction
    let spawner: AgentSpawner  // Known at construction
}
```

**Explicit Registration (Full Mediator):**
```swift
class TavernMediator {
    func register(_ colleague: Colleague) {
        colleagues[colleague.id] = colleague
    }
}
```

**Hybrid Approach:**
```swift
class TavernMediator {
    // Core colleagues (known at construction)
    let jake: Jake

    // Dynamic colleagues (registered at runtime)
    private var agents: [UUID: MortalAgent] = [:]

    func registerAgent(_ agent: MortalAgent, parentId: UUID?) {
        agents[agent.id] = agent
        parentRelationships[agent.id] = parentId
    }
}
```

**Recommendation:** Hybrid approach. Core components are constructor-injected; dynamic agents are registered.


## 5. Implementation Complexity


### 5.1 Evolution from Current State

The path from current `TavernCoordinator` to full `TavernMediator` is incremental:

**Phase 1: Formalize Mediator Interface (2-3 hours)**
- Extract `Colleague` protocol
- Add `TavernMediator` protocol
- Make `TavernCoordinator` conform

```swift
protocol Colleague: AnyObject, Identifiable {
    var id: UUID { get }
    func setMediator(_ mediator: TavernMediator)
}

protocol TavernMediator: AnyObject {
    func send(_ message: MediatorMessage, from sender: UUID)
    func register(_ colleague: Colleague)
}
```

**Phase 2: Add Parent-Child Tracking (2-3 hours)**
- Add `parentRelationships: [UUID: UUID?]`
- Track hierarchy when spawning
- Implement `getParent(of:)` and `getChildren(of:)`

**Phase 3: Implement Bubbling (3-4 hours)**
- Add `Question` type
- Implement `routeQuestion(from:question:)`
- Wire agent question detection to mediator

**Phase 4: Add User Attention Manager (3-4 hours)**
- Create `UserAttentionManager` as colleague
- Implement notification queuing
- Wire bubbling to attention manager

**Phase 5: Route Verification Results (2-3 hours)**
- Wire `CommitmentVerifier` completion to mediator
- Implement `verificationCompleted(for:result:)`
- Propagate results to parent agents

**Total Estimate: 12-17 hours**


### 5.2 New Types Required

**MediatorMessage (Enum):**
```swift
enum MediatorMessage {
    case question(Question)
    case stateChange(from: AgentState, to: AgentState)
    case verificationResult(VerificationResult)
    case spawn(SpawnConfiguration)
    case dismiss(reason: String?)
    case userJoined
    case userLeft
}
```

**Question:**
```swift
struct Question {
    let id: UUID
    let content: String
    let complexity: Complexity  // quick vs deep
    let originAgentId: UUID
    let bubblePath: [UUID]

    enum Complexity { case quick, deep }
}
```

**VerificationResult:**
```swift
struct VerificationResult {
    let agentId: UUID
    let commitments: [Commitment]
    var allPassed: Bool { commitments.allSatisfy { $0.status == .passed } }
    var failures: [Commitment] { commitments.filter { $0.status == .failed } }
}
```


### 5.3 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Mediator becomes god object | Medium | High | Strict MARK sections, consider sub-mediators |
| Performance bottleneck | Low | Medium | Profile message routing; optimize hot paths |
| Thread safety issues | Medium | High | Keep mediator `@MainActor`; async for long ops |
| Breaking existing tests | Medium | Low | Incremental migration with compatibility shim |
| Scope creep | High | Medium | Define mediator boundary upfront; resist "while we're here" |


## 6. Migration Path


### 6.1 Compatibility Shim

During migration, existing code can work unchanged:

```swift
// Shim: TavernCoordinator delegates to mediator
class TavernCoordinator: ObservableObject {
    private let mediator: TavernMediator

    // Existing public interface continues to work
    public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
        // Delegate to mediator
        return try mediator.spawn(SpawnConfiguration(
            assignment: assignment,
            parentId: nil,
            model: .default,
            tokenBudget: nil,
            sandboxConfig: nil,
            commitments: [],
            onComplete: selectAfterSpawn ? .select : .ignore
        ))
    }
}
```


### 6.2 Test Strategy

**Unit Tests for Mediator:**
```swift
func testQuestionBubblesFromChildToParent() async {
    let mediator = MockTavernMediator()
    let parent = MockAgent(id: UUID())
    let child = MockAgent(id: UUID())

    mediator.registerAgent(parent, parentId: nil)
    mediator.registerAgent(child, parentId: parent.id)

    let question = Question(content: "Help?", complexity: .quick)
    mediator.send(.question(question), from: child.id)

    XCTAssertEqual(parent.receivedQuestions.count, 1)
}
```

**Integration Tests:**
```swift
func testSpawnedAgentCanBubbleToJake() async {
    let coordinator = makeCoordinator()
    let agent = try coordinator.spawnAgent(assignment: "Test")

    // Simulate agent raising question
    await agent.raiseQuestion("Need clarification")

    // Verify Jake (or UI) received it
    XCTAssertTrue(coordinator.pendingQuestions.count > 0)
}
```


## 7. Open Questions


### 7.1 Message Ordering

**Question:** Should the mediator guarantee message ordering?

**Current Thinking:** Yes, within a single agent's message stream. No, across agents (they're independent).

**Implementation:** Process messages per-agent in order; allow concurrent processing across agents.


### 7.2 Error Propagation

**Question:** How should errors in message handling propagate?

**Options:**
1. Throw from mediator methods (caller handles)
2. Log and continue (fire-and-forget)
3. Route errors as messages (error becomes data)

**Recommendation:** Option 3 for inter-agent errors (they become visible). Option 1 for API errors (immediate feedback).


### 7.3 Mediator Observability

**Question:** Should the mediator publish its own state for debugging?

**Current Thinking:** Yes. Add:
- `@Published var messageLog: [MediatorMessage]` (recent messages, ring buffer)
- `@Published var agentHierarchy: [UUID: AgentNode]` (tree view)

This enables a "mediator inspector" UI for debugging.


### 7.4 Async vs. Sync Message Delivery

**Question:** Should `send(_:from:)` be async?

**Current Thinking:** No. Keep it sync for simplicity. Individual handlers can spawn Tasks if needed.

**Exception:** Verification requires async. The mediator can spawn a Task internally:
```swift
func send(_ message: MediatorMessage, from sender: UUID) {
    switch message {
    case .verificationResult(let result):
        Task { await handleVerification(result) }
    default:
        handleSync(message, from: sender)
    }
}
```


### 7.5 Mediator Lifecycle

**Question:** What happens when the mediator is deallocated?

**Current Thinking:** Mediator outlives all colleagues (owned by project). Colleagues hold weak references to mediator. No special cleanup needed.


## 8. Alternatives Not Chosen


### 8.1 Direct Agent References

**Approach:** Agents hold references to parent/children directly.

**Why Rejected:** Creates coupling between agents. Adding new communication patterns requires modifying all agents. Mediator centralizes this logic.


### 8.2 Observer Pattern

**Approach:** Components observe each other via `NotificationCenter` or Combine.

**Why Rejected:** Too loosely coupled. Hard to trace message flow. No central point for routing logic.


### 8.3 Full Event Sourcing

**Approach:** All interactions become events; mediator is replaced by event log + projections.

**Why Rejected:** Overkill for current requirements. Can evolve to event sourcing later if audit trail becomes important.


### 8.4 Keep Current Architecture

**Approach:** Don't formalize mediator; add features ad-hoc.

**Why Rejected:** The PRD requires bubbling, attention management, and agent communication. These need a coordination layer. Current architecture is missing it.


## 9. Conclusion

The Mediator Pattern is a natural evolution of `TavernCoordinator`. The current architecture already follows the pattern informally; formalization adds:

1. **Agent hierarchy tracking** for bubbling
2. **User attention management** for notification
3. **Verification result routing** for commitments
4. **Typed message passing** for extensibility

The migration is incremental and low-risk. Each phase adds a discrete capability. Tests can be added alongside.

**Recommendation:** Proceed with Mediator Pattern. It aligns with PRD requirements, leverages existing architecture, and provides a clear path to implementing missing features (bubbling, attention, verification routing).

**Key Decision Factors:**
- Current architecture is 70% of the way there
- PRD explicitly requires features that need a mediator
- Compile-time type safety is valuable
- Team size is small; centralization is manageable
- Single-process design matches mediator assumptions

**Next Steps:**
1. Review this treatise with stakeholders
2. Prototype Phase 1 (formalize interface)
3. Validate with simple bubbling test case
4. Proceed with remaining phases
