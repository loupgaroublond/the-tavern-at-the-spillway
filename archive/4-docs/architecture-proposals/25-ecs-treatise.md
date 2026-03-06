# Entity-Component-System Architecture: Complete Analysis

This document contains the full research, analysis, and thinking behind the Entity-Component-System (ECS) architecture proposal for the Tavern multi-agent orchestrator.


## Table of Contents

1. [Research Findings](#research-findings)
2. [Component Decomposition](#component-decomposition)
3. [System Design](#system-design)
4. [PRD Requirements Mapping](#prd-requirements-mapping)
5. [Trade-offs Analysis](#trade-offs-analysis)
6. [Implementation Complexity](#implementation-complexity)
7. [Migration Path](#migration-path)
8. [Open Questions](#open-questions)


---


## Research Findings


### Current Implementation Analysis

The existing codebase uses a traditional object-oriented approach where each agent type is a class containing both data and behavior:

**Jake.swift:**
```swift
public final class Jake: Agent, @unchecked Sendable {
    public let id: UUID
    public let name: String = "Jake"

    private let claude: ClaudeCode
    private let queue = DispatchQueue(label: "com.tavern.Jake")

    private var _sessionId: String?
    private var _projectPath: String?
    private var _isCogitating: Bool = false

    public var state: AgentState {
        queue.sync { _isCogitating ? .working : .idle }
    }

    public func send(_ message: String) async throws -> String {
        // Claude communication logic embedded in class
    }
}
```

**MortalAgent.swift:**
```swift
public final class MortalAgent: Agent, @unchecked Sendable {
    public let id: UUID
    public let name: String
    public let assignment: String

    private let claude: ClaudeCode
    private let queue = DispatchQueue(label: "com.tavern.MortalAgent")
    public let commitments: CommitmentList
    public let verifier: CommitmentVerifier

    private var _state: AgentState = .idle
    private var _sessionId: String?

    public func send(_ message: String) async throws -> String { ... }
    private func checkForCompletionSignal(in response: String) async { ... }
    private func handleCompletionAttempt() async { ... }
}
```

**Patterns observed:**

1. **Data and behavior intertwined:** Each class contains both state storage and operational logic
2. **Inheritance through protocol:** `Agent` protocol defines common interface
3. **Hardcoded composition:** `MortalAgent` always has commitments; `Jake` never does
4. **Thread safety per-object:** Each class manages its own `DispatchQueue`
5. **Rigid type hierarchy:** Adding new agent types requires new classes


### ECS Origin and Philosophy

Entity-Component-System emerged from game development (Unity, Unreal Engine, Bevy) to solve problems with deep inheritance hierarchies:

**Traditional OOP problem:**
```
GameObject
├── Character
│   ├── Player
│   │   ├── Warrior
│   │   └── Mage
│   └── NPC
│       ├── Friendly
│       └── Enemy
└── Item
    ├── Weapon
    └── Consumable
```

What if you need a "Friendly NPC that is also a Warrior who can be picked up as an Item"? Inheritance breaks down.

**ECS solution:**
- Entity: Just an ID (uint64)
- Components: Pure data structs (Position, Health, AI, Inventory)
- Systems: Functions that operate on entities with specific components

```swift
// "Friendly Warrior NPC" = Entity with these components:
entity.addComponent(PositionComponent(x: 10, y: 20))
entity.addComponent(HealthComponent(max: 100, current: 100))
entity.addComponent(AIComponent(behavior: .friendly))
entity.addComponent(CombatComponent(class: .warrior))
entity.addComponent(PickupableComponent())
```


### Mapping to Tavern's Domain

The current Tavern agent types can be decomposed:

| Current Type | Entity + Components |
|--------------|---------------------|
| Jake | Entity + NameComponent("Jake") + StateComponent + ClaudeSessionComponent + SystemPromptComponent(jake_prompt) |
| MortalAgent | Entity + NameComponent + StateComponent + ClaudeSessionComponent + AssignmentComponent + CommitmentListComponent |
| Future Drone | Entity + NameComponent + StateComponent + ClaudeSessionComponent + TaskComponent (no commitments) |
| Future Monitor | Entity + NameComponent + StateComponent + MonitorConfigComponent + MetricsComponent |

**Key insight:** The distinction between Jake and MortalAgent is largely which components they have, not fundamentally different behavior.


### Swift ECS Landscape

Swift lacks mature ECS frameworks. Options:

1. **FirebladeECS** - Swift ECS library, but limited adoption
2. **Custom implementation** - Full control, more work
3. **Data-oriented structs** - ECS-lite without full framework

Given Tavern's modest scale, a custom lightweight ECS is feasible.


---


## Component Decomposition

Breaking down current agent properties into discrete components:


### Core Components

**IdentityComponent** (immutable, required for all entities)
```swift
struct IdentityComponent: Component {
    let id: UUID
    let name: String
    let createdAt: Date
}
```

**StateComponent** (mutable, tracks lifecycle)
```swift
struct StateComponent: Component {
    var state: AgentState  // idle, working, waiting, verifying, done
    var lastTransitionAt: Date
    var transitionHistory: [AgentState]  // for debugging
}
```

**AssignmentComponent** (immutable for MortalAgents)
```swift
struct AssignmentComponent: Component {
    let assignment: String
    let priority: Int
    let createdAt: Date
}
```


### Communication Components

**ClaudeSessionComponent** (mutable, manages SDK interaction)
```swift
struct ClaudeSessionComponent: Component {
    var sessionId: String?
    var projectPath: String?
    var messageCount: Int
    var lastMessageAt: Date?
}
```

**SystemPromptComponent** (immutable, agent personality)
```swift
struct SystemPromptComponent: Component {
    let prompt: String
    let version: Int
}
```


### Verification Components

**CommitmentListComponent** (mutable, tracks commitments)
```swift
struct CommitmentListComponent: Component {
    var commitments: [Commitment]

    var allPassed: Bool {
        commitments.allSatisfy { $0.status == .passed }
    }

    var hasPending: Bool {
        commitments.contains { $0.status == .pending }
    }
}
```


### Hierarchy Components

**ParentComponent** (optional, links to parent agent)
```swift
struct ParentComponent: Component {
    let parentId: UUID
    var bubblePolicy: BubblePolicy  // immediate, batch, filter
}

enum BubblePolicy {
    case immediate
    case batched(interval: TimeInterval)
    case filtered(categories: Set<MessageCategory>)
}
```

**ChildrenComponent** (optional, tracks spawned agents)
```swift
struct ChildrenComponent: Component {
    var childIds: [UUID]
    let namingTheme: NamingTheme
}
```


### Metrics Components

**MetricsComponent** (mutable, PRD section 9)
```swift
struct MetricsComponent: Component {
    var tokenTime: TimeInterval
    var toolTime: TimeInterval
    var wallClockTime: TimeInterval
    var throttleTime: TimeInterval

    var utilization: Double {
        guard wallClockTime > 0 else { return 0 }
        return tokenTime / wallClockTime
    }

    var saturation: Double {
        guard wallClockTime > 0 else { return 0 }
        return (tokenTime + toolTime) / wallClockTime
    }
}
```


### Operating Mode Components

**PerseveranceComponent** (optional, enables background mode)
```swift
struct PerseveranceComponent: Component {
    var isActive: Bool
    var prodInterval: TimeInterval
    var lastProdAt: Date?
    var consecutiveProds: Int
}
```

**UserPresenceComponent** (mutable, attention tracking)
```swift
struct UserPresenceComponent: Component {
    var isPresent: Bool
    var joinedAt: Date?
    var lastInteractionAt: Date?
}
```


### Component Summary Table

| Component | Jake | MortalAgent | Drone | Monitor |
|-----------|------|-------------|-------|---------|
| IdentityComponent | yes | yes | yes | yes |
| StateComponent | yes | yes | yes | yes |
| ClaudeSessionComponent | yes | yes | yes | no |
| SystemPromptComponent | yes | yes | yes | no |
| AssignmentComponent | no | yes | yes | no |
| CommitmentListComponent | no | yes | no | no |
| ParentComponent | no | yes | yes | no |
| ChildrenComponent | yes | optional | no | no |
| MetricsComponent | yes | yes | yes | yes |
| PerseveranceComponent | no | optional | optional | yes |
| UserPresenceComponent | yes | yes | no | no |
| MonitorConfigComponent | no | no | no | yes |


---


## System Design

Systems are stateless functions that query the World for entities with specific component combinations and operate on them.


### MessageSystem

Handles sending messages to agents and processing responses.

```swift
class MessageSystem: System {
    func update(world: World, deltaTime: TimeInterval) {
        // Query for entities that need to send messages
        let pendingMessages = world.query(
            has: [StateComponent.self, ClaudeSessionComponent.self],
            where: { entity in
                entity.get(StateComponent.self)?.state == .working
            }
        )

        for entity in pendingMessages {
            guard let session = entity.get(ClaudeSessionComponent.self),
                  let message = entity.get(PendingMessageComponent.self) else {
                continue
            }

            Task {
                do {
                    let response = try await sendToClause(
                        sessionId: session.sessionId,
                        message: message.content
                    )
                    world.update(entity.id) { entity in
                        entity.set(ClaudeSessionComponent(
                            sessionId: response.sessionId,
                            projectPath: session.projectPath,
                            messageCount: session.messageCount + 1,
                            lastMessageAt: Date()
                        ))
                        entity.remove(PendingMessageComponent.self)
                        entity.set(PendingResponseComponent(content: response.text))
                    }
                } catch {
                    world.update(entity.id) { entity in
                        entity.set(ErrorComponent(error: error))
                    }
                }
            }
        }
    }
}
```


### VerificationSystem

Processes agents in verification state.

```swift
class VerificationSystem: System {
    let verifier: CommitmentVerifier

    func update(world: World, deltaTime: TimeInterval) {
        // Query for entities in verifying state with commitments
        let verifyingEntities = world.query(
            has: [StateComponent.self, CommitmentListComponent.self],
            where: { entity in
                entity.get(StateComponent.self)?.state == .verifying
            }
        )

        for entity in verifyingEntities {
            guard var commitments = entity.get(CommitmentListComponent.self) else {
                continue
            }

            Task {
                let allPassed = try await verifier.verifyAll(commitments.commitments)

                world.update(entity.id) { entity in
                    var state = entity.get(StateComponent.self)!
                    state.state = allPassed ? .done : .idle
                    entity.set(state)
                }
            }
        }
    }
}
```


### SpawnSystem

Handles creating new agent entities.

```swift
class SpawnSystem: System {
    let nameGenerator: NameGenerator

    func update(world: World, deltaTime: TimeInterval) {
        // Query for spawn requests
        let spawnRequests = world.query(has: [SpawnRequestComponent.self])

        for request in spawnRequests {
            guard let req = request.get(SpawnRequestComponent.self) else {
                continue
            }

            // Create new entity
            let entity = world.createEntity()

            // Add required components
            let name = nameGenerator.nextNameOrFallback()
            entity.set(IdentityComponent(id: entity.id, name: name, createdAt: Date()))
            entity.set(StateComponent(state: .idle, lastTransitionAt: Date(), transitionHistory: []))
            entity.set(AssignmentComponent(assignment: req.assignment, priority: req.priority, createdAt: Date()))
            entity.set(ClaudeSessionComponent(sessionId: nil, projectPath: req.projectPath, messageCount: 0, lastMessageAt: nil))
            entity.set(SystemPromptComponent(prompt: generatePrompt(name: name, assignment: req.assignment), version: 1))

            // Add commitments if requested
            if req.includeCommitments {
                entity.set(CommitmentListComponent(commitments: []))
            }

            // Link to parent
            if let parentId = req.parentId {
                entity.set(ParentComponent(parentId: parentId, bubblePolicy: .immediate))

                // Update parent's children list
                world.update(parentId) { parent in
                    var children = parent.get(ChildrenComponent.self) ?? ChildrenComponent(childIds: [], namingTheme: .lotr)
                    children.childIds.append(entity.id)
                    parent.set(children)
                }
            }

            // Remove the spawn request
            world.destroyEntity(request.id)
        }
    }
}
```


### LifecycleSystem

Manages agent state transitions and cleanup.

```swift
class LifecycleSystem: System {
    func update(world: World, deltaTime: TimeInterval) {
        // Handle completion signals
        let pendingResponses = world.query(has: [PendingResponseComponent.self, StateComponent.self])

        for entity in pendingResponses {
            guard let response = entity.get(PendingResponseComponent.self),
                  var state = entity.get(StateComponent.self) else {
                continue
            }

            let upperResponse = response.content.uppercased()

            if upperResponse.contains("DONE") || upperResponse.contains("COMPLETED") {
                // Check if has commitments
                if entity.has(CommitmentListComponent.self) {
                    state.state = .verifying
                } else {
                    state.state = .done
                }
            } else if upperResponse.contains("WAITING") {
                state.state = .waiting
            } else {
                state.state = .idle
            }

            state.lastTransitionAt = Date()
            state.transitionHistory.append(state.state)

            world.update(entity.id) { e in
                e.set(state)
                e.remove(PendingResponseComponent.self)
            }
        }

        // Reap done agents (if configured)
        let doneAgents = world.query(
            has: [StateComponent.self],
            where: { $0.get(StateComponent.self)?.state == .done }
        )

        for entity in doneAgents {
            // Check if should auto-reap
            if let reapConfig = entity.get(AutoReapComponent.self), reapConfig.reapOnDone {
                cleanupAgent(entity, world: world)
            }
        }
    }

    private func cleanupAgent(_ entity: Entity, world: World) {
        // Remove from parent's children list
        if let parent = entity.get(ParentComponent.self) {
            world.update(parent.parentId) { p in
                var children = p.get(ChildrenComponent.self)!
                children.childIds.removeAll { $0 == entity.id }
                p.set(children)
            }
        }

        world.destroyEntity(entity.id)
    }
}
```


### BubblingSystem

Handles message propagation up the agent hierarchy.

```swift
class BubblingSystem: System {
    func update(world: World, deltaTime: TimeInterval) {
        // Query for entities with outbound bubbles
        let bubblers = world.query(has: [OutboundBubbleComponent.self, ParentComponent.self])

        for entity in bubblers {
            guard let bubble = entity.get(OutboundBubbleComponent.self),
                  let parent = entity.get(ParentComponent.self) else {
                continue
            }

            // Route based on policy
            switch parent.bubblePolicy {
            case .immediate:
                deliverBubble(bubble, to: parent.parentId, world: world)

            case .batched(let interval):
                // Queue for batch delivery
                queueBubble(bubble, for: parent.parentId, world: world)

            case .filtered(let categories):
                if categories.contains(bubble.category) {
                    deliverBubble(bubble, to: parent.parentId, world: world)
                }
            }

            world.update(entity.id) { e in
                e.remove(OutboundBubbleComponent.self)
            }
        }
    }
}
```


### MetricsSystem

Collects and aggregates performance metrics.

```swift
class MetricsSystem: System {
    func update(world: World, deltaTime: TimeInterval) {
        let activeAgents = world.query(
            has: [StateComponent.self, MetricsComponent.self],
            where: { $0.get(StateComponent.self)?.state == .working }
        )

        for entity in activeAgents {
            world.update(entity.id) { e in
                var metrics = e.get(MetricsComponent.self)!
                metrics.wallClockTime += deltaTime
                e.set(metrics)
            }
        }

        // Calculate aggregate metrics
        let allMetrics = world.query(has: [MetricsComponent.self])
        let totalSaturation = allMetrics.compactMap { $0.get(MetricsComponent.self)?.saturation }.reduce(0, +)
        let saturatedCount = allMetrics.filter { ($0.get(MetricsComponent.self)?.saturation ?? 0) > 0.5 }.count

        // Update global metrics component
        world.setSingleton(GlobalMetrics(
            totalAgents: allMetrics.count,
            saturatedAgents: saturatedCount,
            amplificationFactor: Double(saturatedCount)
        ))
    }
}
```


### RenderSystem (UI Bridge)

Bridges ECS world to SwiftUI ViewModels.

```swift
class RenderSystem: System {
    weak var coordinator: TavernCoordinator?

    func update(world: World, deltaTime: TimeInterval) {
        // Build agent list for UI
        let allAgents = world.query(has: [IdentityComponent.self, StateComponent.self])

        let agentItems: [AgentListItem] = allAgents.compactMap { entity in
            guard let identity = entity.get(IdentityComponent.self),
                  let state = entity.get(StateComponent.self) else {
                return nil
            }

            let assignment = entity.get(AssignmentComponent.self)?.assignment

            return AgentListItem(
                id: identity.id,
                name: identity.name,
                state: state.state,
                assignment: assignment
            )
        }

        Task { @MainActor in
            coordinator?.updateAgentList(agentItems)
        }
    }
}
```


### System Execution Order

Systems run in a defined order each frame/tick:

```swift
class ECSLoop {
    let systems: [System] = [
        SpawnSystem(),          // 1. Create new entities first
        MessageSystem(),        // 2. Send/receive messages
        LifecycleSystem(),      // 3. Process state transitions
        VerificationSystem(),   // 4. Verify commitments
        BubblingSystem(),       // 5. Propagate messages
        MetricsSystem(),        // 6. Update metrics
        RenderSystem(),         // 7. Update UI last
    ]

    func tick(world: World, deltaTime: TimeInterval) {
        for system in systems {
            system.update(world: world, deltaTime: deltaTime)
        }
    }
}
```


---


## PRD Requirements Mapping


### Invariant Analysis

| PRD Invariant | ECS Implementation |
|---------------|-------------------|
| Test suite must pass | Systems are pure functions; trivial to test in isolation |
| Every feature testable | Component queries are deterministic and inspectable |
| Commitments verified independently | VerificationSystem operates only on CommitmentListComponent |
| User attention is sacred | UserPresenceComponent tracks engagement; RenderSystem bridges to UI |
| Doc store is source of truth | Components serialize directly to files; entity = file path |
| Agents cannot modify own invariants | Systems enforce rules; components are passive data |
| Failures must be visible | ErrorComponent attached to entities; monitored by systems |
| Original project files protected | Orthogonal to ECS; handled by changeset layer |


### Agent Types Mapping (PRD Section 4.1)

| PRD Type | ECS Entity Definition |
|----------|----------------------|
| Jake (Daemon) | IdentityComponent + StateComponent + ClaudeSessionComponent + ChildrenComponent + SystemPromptComponent(jake) |
| Mortal | IdentityComponent + StateComponent + ClaudeSessionComponent + AssignmentComponent + CommitmentListComponent + ParentComponent |
| Drone | IdentityComponent + StateComponent + ClaudeSessionComponent + TaskComponent + AutoReapComponent |
| Monitor Daemon | IdentityComponent + StateComponent + MonitorConfigComponent + MetricsComponent |


### Agent States Mapping (PRD Section 4.2)

```
Working ──────► Waiting for Input ──────► Done
    │                   │                   ▲
    │                   ▼                   │
    └──────► Waiting for Wakeup ───────────┘
                        │
                        ▼
                  Failed/Reaped
```

ECS StateComponent:

```swift
struct StateComponent: Component {
    enum State: String {
        case idle           // Ready for work
        case working        // Processing
        case waiting        // Waiting for input
        case waitingWakeup  // Perseverance mode idle
        case verifying      // Checking commitments
        case done           // Complete
        case failed         // Error state
    }

    var state: State
    var previousState: State?
    var stateEnteredAt: Date
}
```

LifecycleSystem handles transitions based on:
- MessageSystem output (working -> waiting/done)
- VerificationSystem output (verifying -> done/idle)
- PerseveranceSystem prods (waitingWakeup -> working)


### Task Modes Mapping (PRD Section 4.3)

Modes are components that modify system behavior:

```swift
struct ExecuteMode: Component {}
struct DelegateMode: Component { let targetEntityId: UUID }
struct PlanMode: Component { let depth: Int }
struct BreakupMode: Component { let subtasks: [String] }
struct UnifyMode: Component { let childResults: [UUID: String] }
```

LifecycleSystem checks for mode components when processing state transitions.


### Operating Modes (PRD Section 4.4)

```swift
struct ChatModeComponent: Component {
    var isActive: Bool
    var windowId: UUID
}

struct PerseveranceModeComponent: Component {
    var isActive: Bool
    var prodInterval: TimeInterval
    var maxConsecutiveProds: Int
}
```


### Sandbox Primitives (PRD Section 4.6)

Each primitive becomes a component:

```swift
struct ChangesetComponent: Component {
    let overlayPath: String
    var modifiedFiles: [String]
}

struct PlatformComponent: Component {
    let platform: Platform  // mac, container, cloud
}

struct IsolationComponent: Component {
    let type: IsolationType  // vm, container, sandbox
    let canTrash: Bool
}

struct OutputsComponent: Component {
    let networkAccess: NetworkPolicy
}

struct SoftwareComponent: Component {
    let os: OperatingSystem
    let requiredTools: [String]
}
```


### Metrics (PRD Section 9)

MetricsComponent directly implements PRD metrics:

```swift
struct MetricsComponent: Component {
    // Time categories
    var tokenTime: TimeInterval      // Waiting for LLM
    var toolTime: TimeInterval       // Tool execution
    var wallClockTime: TimeInterval  // Total elapsed
    var throttleTime: TimeInterval   // Excluded (rate limits)

    // Derived metrics
    var utilization: Double {
        tokenTime / wallClockTime
    }

    var saturation: Double {
        (tokenTime + toolTime) / wallClockTime
    }

    // Human metrics tracked globally
    // Agent wait time = wallClockTime - tokenTime - toolTime
}
```

GlobalMetrics singleton tracks system-wide amplification.


### Workflows (PRD Section 10)

Workflows become entity templates:

```swift
struct WorkflowTemplateComponent: Component {
    let name: String
    let pattern: WorkflowPattern

    enum WorkflowPattern {
        case ruleOfFive(iterations: Int)
        case verificationLayers([VerificationLayer])
        case custom([WorkflowStep])
    }
}

// Applying workflow creates entities
func applyWorkflow(_ template: WorkflowTemplateComponent, to task: String, world: World) {
    switch template.pattern {
    case .ruleOfFive(let iterations):
        for i in 0..<iterations {
            let entity = world.createEntity()
            entity.set(AssignmentComponent(assignment: task, priority: i, createdAt: Date()))
            entity.set(WorkflowStepComponent(stepIndex: i, totalSteps: iterations))
            // ... add other components
        }
    // ...
    }
}
```


### Violation Monitoring (PRD Section 16)

```swift
struct ViolationRulesComponent: Component {
    var rules: [ViolationRule]
}

struct ViolationRule {
    let type: ViolationType
    let threshold: Any
    let action: ViolationAction
}

enum ViolationType {
    case modifyOutsideDirectory(allowedPaths: [String])
    case tokenBudgetExceeded(max: Int)
    case tooManyChildren(max: Int)
    case networkAccessWhenDisallowed
    case blockedCommand(patterns: [String])
}

enum ViolationAction {
    case log
    case notify(parentId: UUID)
    case pause
    case reap
    case warn
}
```

ViolationMonitorSystem checks all entities with ViolationRulesComponent.


---


## Trade-offs Analysis


### Composition Flexibility vs Complexity

**Benefit:** New agent types without new classes

```swift
// Traditional: Need new class
class DroneAgent: MortalAgent { ... }

// ECS: Just different components
func createDrone(world: World, task: String) -> Entity {
    let entity = world.createEntity()
    entity.set(IdentityComponent(...))
    entity.set(StateComponent(...))
    entity.set(TaskComponent(task: task))
    entity.set(AutoReapComponent(reapOnDone: true))
    // No CommitmentListComponent - drones don't verify
    return entity
}
```

**Cost:** Property access becomes verbose

```swift
// Traditional
let state = agent.state

// ECS
let state = world.entity(id)?.get(StateComponent.self)?.state
```


### Data Locality vs Familiarity

**Benefit:** Cache-friendly iteration

```swift
// ECS: All StateComponents stored contiguously
let states = world.componentStorage(StateComponent.self)
for state in states {
    // CPU cache loves this
}
```

**Cost:** Unfamiliar to most Swift developers

Game developers understand ECS instinctively. App developers may struggle with "where is the Agent object?"


### Serialization Simplicity vs Runtime Ceremony

**Benefit:** Save/load entire world trivially

```swift
// Save
let worldData = try encoder.encode(world.allComponents())
try worldData.write(to: saveFile)

// Load
let worldData = try Data(contentsOf: saveFile)
let components = try decoder.decode(AllComponents.self, from: worldData)
world.loadComponents(components)
```

**Cost:** Type registration and query ceremony

```swift
// Must register all component types
world.registerComponent(StateComponent.self)
world.registerComponent(IdentityComponent.self)
world.registerComponent(ClaudeSessionComponent.self)
// ... for every component type

// Queries require explicit type lists
let query = world.query(
    has: [StateComponent.self, ClaudeSessionComponent.self],
    not: [CommitmentListComponent.self]
)
```


### Testability vs Indirection

**Benefit:** Test systems in isolation

```swift
func testVerificationSystem() {
    let world = World()
    let entity = world.createEntity()
    entity.set(StateComponent(state: .verifying, ...))
    entity.set(CommitmentListComponent(commitments: [
        Commitment(description: "test", assertion: "true", status: .pending)
    ]))

    let system = VerificationSystem(verifier: MockVerifier(allPass: true))
    system.update(world: world, deltaTime: 0)

    XCTAssertEqual(entity.get(StateComponent.self)?.state, .done)
}
```

**Cost:** Harder to debug "whole agent" behavior

When something goes wrong, you must inspect multiple components across multiple systems rather than stepping through one class's methods.


### Parallel Execution vs Coordination Complexity

**Benefit:** Systems can run in parallel

```swift
// These systems touch non-overlapping components
await withTaskGroup(of: Void.self) { group in
    group.addTask { metricsSystem.update(world: world, deltaTime: dt) }
    group.addTask { loggingSystem.update(world: world, deltaTime: dt) }
}
```

**Cost:** Must carefully track component access patterns

If two systems both read AND write StateComponent, they cannot run in parallel without synchronization.


---


## Implementation Complexity


### Core ECS Infrastructure

**World class:**
```swift
class World {
    private var entities: [UUID: Entity] = [:]
    private var componentStores: [ObjectIdentifier: Any] = [:]

    func createEntity() -> Entity
    func destroyEntity(_ id: UUID)
    func entity(_ id: UUID) -> Entity?

    func query(has: [Component.Type], not: [Component.Type] = [], where: ((Entity) -> Bool)? = nil) -> [Entity]

    func registerComponent<C: Component>(_ type: C.Type)
    func componentStorage<C: Component>(_ type: C.Type) -> ComponentStorage<C>
}
```

**Estimated LOC:** ~300-400 for basic World implementation


### Component Storage

```swift
class ComponentStorage<C: Component> {
    private var components: [UUID: C] = [:]

    func get(_ entityId: UUID) -> C?
    func set(_ entityId: UUID, _ component: C)
    func remove(_ entityId: UUID)
    func all() -> [C]
}
```

**Estimated LOC:** ~100 per storage type, or generic ~150


### System Protocol

```swift
protocol System {
    func update(world: World, deltaTime: TimeInterval)
}
```

**Estimated LOC per system:**
- MessageSystem: ~150
- VerificationSystem: ~80
- SpawnSystem: ~100
- LifecycleSystem: ~120
- BubblingSystem: ~100
- MetricsSystem: ~80
- RenderSystem: ~60


### Effort Estimation

| Component | Estimated LOC | Effort |
|-----------|---------------|--------|
| World infrastructure | 400 | 2-3 days |
| Component types (15+) | 500 | 1-2 days |
| Core systems (7) | 700 | 3-4 days |
| UI bridge | 200 | 1 day |
| Migration of existing logic | -- | 2-3 days |
| Tests | 600 | 2 days |

**Total: ~2400 LOC, 11-15 days**


### Comparison to Current Codebase

| Current File | LOC | ECS Equivalent |
|--------------|-----|----------------|
| Jake.swift | 191 | JakeComponents + MessageSystem portion |
| MortalAgent.swift | 275 | MortalComponents + LifecycleSystem portion |
| AgentRegistry.swift | 102 | World.query() |
| AgentSpawner.swift | 131 | SpawnSystem |
| TavernCoordinator.swift | 144 | RenderSystem + coordination logic |
| CommitmentList.swift | 191 | CommitmentListComponent |
| CommitmentVerifier.swift | ~80 | VerificationSystem |

Current core agent code: ~1100 LOC
ECS equivalent: ~2400 LOC (including infrastructure)

**Trade-off:** 2x code for greater flexibility and testability.


---


## Migration Path


### Phase 1: Infrastructure (3-4 days)

1. Create World class with basic entity management
2. Create Component protocol and ComponentStorage
3. Create System protocol
4. Write unit tests for core infrastructure


### Phase 2: Component Definition (1-2 days)

1. Define all component types based on analysis above
2. Ensure all components are Codable
3. Write serialization tests


### Phase 3: System Implementation (4-5 days)

Implement systems in dependency order:

1. **SpawnSystem** - Create entities (no dependencies)
2. **LifecycleSystem** - State transitions (depends on SpawnSystem output)
3. **MessageSystem** - Claude communication (depends on entity existence)
4. **VerificationSystem** - Commitment checking (depends on state transitions)
5. **BubblingSystem** - Message routing (depends on hierarchy)
6. **MetricsSystem** - Statistics (read-only, depends on all above)
7. **RenderSystem** - UI bridge (last, depends on all state)


### Phase 4: Migration (2-3 days)

1. Create ECS-based entity creation that mirrors current agent creation
2. Run both systems in parallel during transition
3. Verify parity via integration tests
4. Switch UI to read from ECS world


### Phase 5: Cleanup (1 day)

1. Remove old class-based agent implementations
2. Update documentation
3. Final test pass


### Rollback Strategy

- Keep old implementation in separate files during migration
- Feature flag to switch between OOP and ECS modes
- Git branches for clean rollback


---


## Open Questions


### 1. Tick Rate

How often should the ECS loop run?

**Options:**
- Event-driven (tick on user input or async completion)
- Fixed interval (60 Hz game-style)
- Hybrid (immediate for UI, batched for background)

**Recommendation:** Event-driven for v1, with debouncing for rapid events.


### 2. Thread Safety

How do we handle concurrent component access?

**Options:**
- Single-threaded world (simplest)
- Reader-writer locks per component storage
- Copy-on-write snapshots
- Full actor isolation for World

**Recommendation:** Start single-threaded; World access only from one thread/actor. Systems that need async (MessageSystem) dispatch to Task and update World on completion.


### 3. Query Caching

Should queries be cached?

```swift
// Expensive if done every tick
let verifying = world.query(has: [StateComponent.self], where: { $0.state == .verifying })
```

**Options:**
- No caching (simple, correct)
- Cached queries with invalidation on component changes
- Archetype-based storage (automatic query optimization)

**Recommendation:** No caching initially; profile and optimize if needed.


### 4. Component Granularity

How fine-grained should components be?

**Coarse:**
```swift
struct AgentComponent: Component {
    var state: AgentState
    var sessionId: String?
    var assignment: String?
    var commitments: [Commitment]
}
```

**Fine:**
```swift
struct StateComponent { var state: AgentState }
struct SessionComponent { var sessionId: String? }
struct AssignmentComponent { var assignment: String }
struct CommitmentListComponent { var commitments: [Commitment] }
```

**Recommendation:** Fine-grained for maximum composition flexibility, but group truly inseparable data (e.g., identity fields).


### 5. UI Bridge Pattern

How does SwiftUI observe ECS world changes?

**Options:**

A. Polling with timer:
```swift
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    viewModel.refresh(from: world)
}
```

B. Change notifications:
```swift
world.onChange { entities in
    Task { @MainActor in
        viewModel.update(entities)
    }
}
```

C. Reactive streams:
```swift
world.entitiesPublisher
    .receive(on: DispatchQueue.main)
    .sink { viewModel.entities = $0 }
```

**Recommendation:** Option B (change notifications) for responsiveness without polling overhead.


### 6. Singleton Components

How do we handle "global" state like Jake?

**Options:**

A. Special entity:
```swift
let jakeEntity = world.createEntity()
world.setSingleton("jake", jakeEntity.id)
```

B. Singleton component:
```swift
struct JakeIdentifier: SingletonComponent {
    let entityId: UUID
}
```

C. Query by component:
```swift
let jake = world.query(has: [JakeMarkerComponent.self]).first
```

**Recommendation:** Option C (marker component) maintains pure ECS while allowing Jake to be found.


### 7. Integration with DocStore

The PRD states "doc store IS the filesystem". How does ECS integrate?

**Proposal:** Component storage IS file storage.

```
.tavern/
├── entities/
│   ├── {uuid1}/
│   │   ├── identity.json
│   │   ├── state.json
│   │   └── session.json
│   └── {uuid2}/
│       ├── identity.json
│       ├── state.json
│       ├── assignment.json
│       └── commitments.json
└── singletons/
    └── global_metrics.json
```

World loads from disk on startup, persists on changes. This aligns perfectly with the PRD invariant.


### 8. Error Handling

How do systems report errors?

**Proposal:** ErrorComponent attached to entities, monitored by ErrorSystem.

```swift
struct ErrorComponent: Component {
    let error: Error
    let system: String
    let timestamp: Date
}

class ErrorSystem: System {
    func update(world: World, deltaTime: TimeInterval) {
        let errors = world.query(has: [ErrorComponent.self])
        for entity in errors {
            TavernLogger.agents.error("[ECS] Entity \(entity.id) error: \(entity.get(ErrorComponent.self)!.error)")
            // Bubble to parent or notify user
        }
    }
}
```


---


## Conclusion

The Entity-Component-System architecture offers a radically different approach to Tavern's agent management. Instead of objects with behaviors, we have data bags operated on by systems. This inversion has significant advantages:

**Strengths:**
- Composition over inheritance solves the "what kind of agent is this?" problem
- Systems are trivially testable in isolation
- Serialization becomes straightforward
- Perfect alignment with "doc store is source of truth"
- Future agent types require zero new classes

**Weaknesses:**
- Unfamiliar paradigm for Swift developers
- Significant infrastructure investment
- Indirection makes debugging harder
- Over-engineered for current scale (tens of agents)
- SwiftUI integration requires custom bridging

**Verdict:** ECS is a strong choice if Tavern's vision of many agent types with varied capabilities fully materializes. For the current scope (Jake + MortalAgents with optional commitments), ECS adds complexity without proportional benefit. However, if the PRD's Drones, Monitor Daemons, and configurable expert types become reality, ECS provides the composition flexibility to handle them elegantly.

The migration path is tractable (~2 weeks) but represents a fundamental shift in how the codebase thinks about agents. This is the right architecture if data orientation, batch processing, and maximum composition flexibility are priorities. It is not the right architecture if simplicity and Swift idiomaticity are paramount.
