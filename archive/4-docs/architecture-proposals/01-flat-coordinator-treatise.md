# Flat Coordinator Architecture: Complete Analysis

This document contains the full research, rationale, and trade-off analysis for the Flat Coordinator architecture proposal.


## 1. Research Findings: Current Architecture


### 1.1 The Four Coordination Types

The current architecture distributes coordination across four distinct types:

**TavernProject** (`Project/TavernProject.swift`, ~119 lines)
- Represents an open project directory
- Creates and owns `TavernCoordinator`
- Creates `ClaudeCode`, `AgentRegistry`, `NameGenerator`, `AgentSpawner`
- Wires all dependencies together in `initialize()`
- Lifecycle: created when project opens, destroyed when project closes

**TavernCoordinator** (`Coordination/TavernCoordinator.swift`, ~144 lines)
- Central hub for agent selection and UI state
- Owns Jake and AgentSpawner (injected)
- Manages `ChatViewModel` cache per agent
- Publishes `activeChatViewModel` and `agentListViewModel`
- Delegates spawning to AgentSpawner, then updates UI state

**AgentSpawner** (`Agents/AgentSpawner.swift`, ~131 lines)
- Factory for creating mortal agents
- Owns `AgentRegistry` and `NameGenerator` (injected)
- Creates `ClaudeCode` instances via factory callback
- Handles agent registration and dismissal
- Exposes `activeAgents` by querying registry

**AgentRegistry** (`Agents/AgentRegistry.swift`, ~102 lines)
- Thread-safe storage for agent identity
- Enforces name uniqueness
- Provides lookup by ID and name
- Pure data structure with no business logic


### 1.2 Dependency Chain

```
TavernProject creates:
  -> ClaudeCode (for Jake)
  -> AgentRegistry
  -> NameGenerator
  -> AgentSpawner (needs Registry, NameGenerator, ClaudeFactory)
  -> Jake (needs ClaudeCode)
  -> TavernCoordinator (needs Jake, Spawner)
```

This chain means `TavernProject.initialize()` is a 40-line method that wires everything together. Any change to dependencies requires touching this method.


### 1.3 Data Flow for Spawn Operation

When the user clicks "Spawn Agent":

1. `TavernCoordinator.spawnAgent(assignment:)` is called
2. Coordinator calls `spawner.spawn(assignment:)`
3. Spawner gets name from `nameGenerator.nextNameOrFallback()`
4. Spawner creates `ClaudeCode` via factory callback
5. Spawner creates `MortalAgent`
6. Spawner calls `registry.register(agent)`
7. Spawner returns agent to Coordinator
8. Coordinator caches assignment in `agentListViewModel`
9. Coordinator calls `agentListViewModel.agentsDidChange()`
10. AgentListViewModel calls `spawner.activeAgents` (which calls `registry.allAgents()`)
11. Coordinator optionally calls `selectAgent(id:)`
12. `selectAgent` updates `agentListViewModel.selectedAgentId`
13. `updateActiveChatViewModel()` creates or retrieves cached ChatViewModel

This 13-step flow traverses all four types for a single operation.


### 1.4 Thread Safety Model

- `AgentRegistry`: Serial `DispatchQueue` protects `_agents` and `_nameToId`
- `NameGenerator`: Serial `DispatchQueue` protects `_usedNames` and indices
- `TavernCoordinator`: `@MainActor` (UI-bound)
- `TavernProject`: `@MainActor` (UI-bound)
- `AgentSpawner`: `@unchecked Sendable` (no internal state beyond references)

The current split means registry operations are thread-safe but coordinator operations must happen on MainActor. Flat Coordinator would need to maintain this separation internally.


## 2. PRD Requirements Mapping


### 2.1 Core Requirements Addressed

| PRD Requirement | Current Implementation | Flat Coordinator Impact |
|-----------------|------------------------|-------------------------|
| Jake spawns mortal agents | Coordinator delegates to Spawner | Direct spawn method, no delegation |
| User sees agent list | AgentListViewModel refreshes from Spawner | ViewModel refreshes from internal state |
| User switches between chats | Coordinator updates activeChatViewModel | Same, but single owner |
| Agents have unique names | Registry enforces, Generator tracks | Internal `usedNames` set + validation |
| Session persistence | Each agent uses SessionStore | Unchanged |
| Commitments verified independently | MortalAgent owns CommitmentList | Unchanged |


### 2.2 Requirements That Flat Coordinator Simplifies

**Spawn configuration** (PRD 6.2): Parent specifies assignment, model selection, token budget, etc. With Flat Coordinator, all spawn options flow through a single method with clear ownership.

**Agent dismissal**: Currently requires Coordinator -> Spawner -> Registry chain plus view model cleanup. Flat Coordinator handles in one method.

**Agent list refresh**: Currently AgentListViewModel queries Spawner which queries Registry. Flat Coordinator provides agents directly.


### 2.3 Requirements That Become Harder

**Future extraction**: If we later need `AgentRegistry` as a shared library (e.g., for distributed agents), extraction from Flat Coordinator is harder than from the current separate type.

**Plugin architecture**: If third-party code needs to provide custom spawning logic, injecting a custom Spawner is cleaner than subclassing ProjectCoordinator.


## 3. Trade-offs Considered


### 3.1 Cohesion vs. Separation

**Argument for current separation**: Each type has a single responsibility. Registry stores agents. Spawner creates agents. Coordinator manages UI state. This follows classic SOLID principles.

**Counter-argument**: These responsibilities are tightly coupled in practice. Every spawn requires all four types. Every dismiss requires all four types. The "single responsibility" framing obscures that they are parts of one conceptual operation.

**Flat Coordinator position**: The true single responsibility is "coordinate everything for this project." The current separation is artificial at this scale.


### 3.2 Testability

**Current approach**: Each type can be unit tested in isolation. MockAgentRegistry for testing Spawner. MockAgentSpawner for testing Coordinator.

**Flat Coordinator approach**: One MockProjectCoordinator replaces four mocks. Individual methods are tested, not types.

**Trade-off**: Current approach has better isolation but more test setup complexity. Flat Coordinator has simpler setup but less granular isolation.

**Recommendation**: At current codebase size, simpler setup wins. If codebase grows 5x, reconsider.


### 3.3 File Size

**Current**: 4 files totaling ~496 lines
**Flat Coordinator**: Estimated 1 file at 400-500 lines (less due to removed wiring/forwarding)

**Concern**: 500-line files are harder to navigate.

**Mitigation**: Use `// MARK:` sections aggressively. Consider extracting pure helper functions (not types) for complex logic.


### 3.4 Actor Isolation

**Current**: `@MainActor` on Coordinator/Project, `DispatchQueue` on Registry/Generator.

**Flat Coordinator challenge**: Must maintain both isolation strategies. Options:

1. **Internal isolation helpers**: Private methods that synchronize on queue for registry operations, called from `@MainActor` methods.
2. **Actor for storage**: Nested `AgentStorage` actor owns agent dictionary.
3. **Eliminate need**: If spawn/dismiss only happen from MainActor anyway, simplify to `@MainActor` only with synchronous internal access.

**Recommendation**: Option 1 (internal isolation helpers) mirrors current pattern with least disruption.


## 4. Implementation Complexity


### 4.1 Estimated Effort

**Phase 1: Merge Coordinator + Spawner** (2-3 hours)
- Move Spawner's spawn/dismiss logic into Coordinator
- Remove Spawner type
- Update TavernProject to wire directly

**Phase 2: Merge Registry** (1-2 hours)
- Move agent storage into Coordinator
- Add internal queue-protected accessors
- Remove Registry type

**Phase 3: Merge into TavernProject** (1-2 hours)
- Rename `TavernProject` to `ProjectCoordinator`
- Move all initialization inline
- Remove separate coordinator property

**Phase 4: Update tests** (2-4 hours)
- Create `MockProjectCoordinator`
- Update all tests using removed types
- Verify coverage maintained

**Total: 6-11 hours**


### 4.2 Risk Assessment

**Low risk**: All current tests pass after each phase. Incremental migration.

**Medium risk**: Thread safety bugs during Registry merge. Mitigation: Add stress tests for concurrent spawn/dismiss before and after.

**Low risk**: UI regressions. All UI code talks to Coordinator already; interface stays same.


## 5. Migration Path


### 5.1 Phase 1: Absorb AgentSpawner

```swift
// Before
public init(jake: Jake, spawner: AgentSpawner) {
    self.spawner = spawner
    // ...
}

// After
public init(jake: Jake, registry: AgentRegistry, nameGenerator: NameGenerator, claudeFactory: @escaping () -> ClaudeCode) {
    self.registry = registry
    self.nameGenerator = nameGenerator
    self.claudeFactory = claudeFactory
    // ...
}

// Spawn moves inline
public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
    let name = nameGenerator.nextNameOrFallback()
    let claude = claudeFactory()
    let agent = MortalAgent(name: name, assignment: assignment, claude: claude)
    try registry.register(agent)
    // ... UI updates ...
}
```


### 5.2 Phase 2: Absorb AgentRegistry

```swift
// Private storage with queue
private let agentQueue = DispatchQueue(label: "com.tavern.ProjectCoordinator.agents")
private var _agents: [UUID: AnyAgent] = [:]
private var _nameToId: [String: UUID] = [:]

// Internal helpers
private func registerAgent(_ agent: MortalAgent) throws {
    try agentQueue.sync {
        guard _nameToId[agent.name] == nil else {
            throw AgentRegistryError.nameAlreadyExists(agent.name)
        }
        _agents[agent.id] = AnyAgent(agent)
        _nameToId[agent.name] = agent.id
    }
}
```


### 5.3 Phase 3: Rename and Consolidate

```swift
// Final form
@MainActor
public final class ProjectCoordinator: ObservableObject, Identifiable {
    // Project identity
    public let id: UUID
    public let rootURL: URL

    // Agents
    public let jake: Jake
    private var mortalAgents: [UUID: MortalAgent] = [:]
    private var usedNames: Set<String> = []

    // Naming
    private var namingTheme: NamingTheme
    private var tierIndex: Int = 0
    private var nameIndex: Int = 0

    // UI State
    @Published public private(set) var agentListViewModel: AgentListViewModel
    @Published public private(set) var activeChatViewModel: ChatViewModel

    // View model cache
    private var chatViewModels: [UUID: ChatViewModel] = [:]

    // External
    private let claudeFactory: () -> ClaudeCode

    // MARK: - Initialization
    // MARK: - Agent Spawning
    // MARK: - Agent Dismissal
    // MARK: - Agent Lookup
    // MARK: - Selection
    // MARK: - Naming
}
```


## 6. Open Questions


### 6.1 Name Generator Lifecycle

**Question**: Should name generation be per-project or global?

**Current**: Per-project (each project gets fresh NameGenerator).

**Flat Coordinator**: Same, but clearer. Names are project-scoped.

**Open**: If we later want global uniqueness (agent names unique across all projects), Flat Coordinator makes this harder. Low priority concern.


### 6.2 AgentListViewModel Ownership

**Question**: Should AgentListViewModel be owned by ProjectCoordinator or be a computed property?

**Current**: Owned, created in init, mutated via methods.

**Alternative**: Compute `items` from internal state each time. Simpler but potentially slower.

**Recommendation**: Keep owned for now. If performance is never an issue, consider computed later.


### 6.3 Thread Safety Strategy

**Question**: Queue-based isolation (current) or actor-based isolation (modern Swift)?

**Current**: DispatchQueue for Registry/Generator.

**Flat Coordinator option**: Use internal `actor AgentStorage` for agent dictionary.

**Trade-off**: Actor is more idiomatic Swift 6 but requires `await` for lookups. DispatchQueue is synchronous.

**Recommendation**: Start with DispatchQueue (matches current pattern). Migrate to actor if Swift concurrency becomes dominant pattern.


### 6.4 Error Handling

**Question**: Who owns error presentation in spawn failures?

**Current**: Coordinator catches errors from Spawner, doesn't present.

**Flat Coordinator**: Same, but clearer that ProjectCoordinator is the right place to add error presentation.


## 7. Alternatives Not Chosen


### 7.1 Keep Current Architecture

**Why considered**: "If it ain't broke, don't fix it."

**Why rejected**: The current architecture is functional but adds cognitive overhead. Every new feature requires understanding four types. The overhead will compound as features are added.


### 7.2 Merge Only Spawner + Registry

**Why considered**: Partial collapse keeps Coordinator focused on UI.

**Why rejected**: The boundary between "create/track agents" and "manage UI for agents" is artificial. They change together. Might as well unify completely.


### 7.3 Extract to Separate Package

**Why considered**: Force clean interfaces via package boundaries.

**Why rejected**: Premature. We don't have multiple consumers. Would add build complexity without benefit.


## 8. Conclusion

The Flat Coordinator architecture trades explicit type separation for operational simplicity. At the current scale (4 types, ~500 lines total, one consumer), the benefits outweigh the costs.

Key decision factors:
- **Team size**: Small team benefits from fewer abstractions
- **Project phase**: Early-stage project benefits from fast iteration
- **Coupling reality**: The four types are already tightly coupled in practice
- **Future extraction**: Unlikely to need Registry as separate library

Recommended action: Proceed with Flat Coordinator migration in four phases over 1-2 development sessions. Maintain test coverage throughout. Re-evaluate if the codebase grows significantly or if extraction needs emerge.
