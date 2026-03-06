# Monolithic Core Architecture — Full Treatise


## Research Findings


### Current State Analysis

The existing codebase contains significant structural complexity:

**Class count with state synchronization:**
- `Jake` — DispatchQueue for `_sessionId`, `_projectPath`, `_isCogitating`
- `MortalAgent` — DispatchQueue for `_state`, `_sessionId`
- `AgentRegistry` — DispatchQueue for `_agents`, `_nameToId`
- `NameGenerator` — DispatchQueue for `_usedNames`, indices
- `CommitmentList` — DispatchQueue for `_commitments`
- `DocStore` — DispatchQueue for file operations
- `MockClaudeCode` — DispatchQueue for mock state
- `SessionStore` — UserDefaults (implicit synchronization)

**ViewModel layer:**
- `TavernCoordinator` — @MainActor, owns Jake + Spawner + ViewModels
- `ChatViewModel` — @MainActor, per-agent message history
- `AgentListViewModel` — @MainActor, agent list + selection

**Project layer:**
- `TavernProject` — @MainActor, owns coordinator + ClaudeCode
- `ProjectManager` — @MainActor singleton, tracks open projects


### What All This Complexity Buys Us

Looking at actual capabilities:

1. **Multi-project support** — Can open multiple projects in separate windows
2. **Agent spawning** — Can create mortal agents with themed names
3. **Session persistence** — Jake's conversation survives app restart
4. **Chat history** — Messages displayed per-agent
5. **Commitment verification** — Shell commands run to verify completion

Notably absent from v1:
- Parallel agent execution (agents run sequentially)
- Background processing (everything is request-response)
- Agent-to-agent communication (not implemented)
- Real delegation from Jake (Jake spawns but doesn't coordinate)


### Thread Safety Analysis

Every DispatchQueue in the codebase protects mutable state from concurrent access. But examining the actual call patterns:

- `Jake.send()` is called from `ChatViewModel.sendMessage()`, which runs on MainActor
- `MortalAgent.send()` — same pattern
- `AgentRegistry.register()` — called from `AgentSpawner.spawn()`, called from `TavernCoordinator.spawnAgent()` — MainActor
- `NameGenerator.nextNameOrFallback()` — same chain, MainActor

**The thread safety infrastructure protects against concurrent access that never actually happens.** Everything flows through @MainActor-bound coordinators.


## What Can Be Collapsed

### Definitely Collapsible

**AgentRegistry + NameGenerator into TavernCore**

The registry is just two dictionaries:
```swift
private var _agents: [UUID: AnyAgent] = [:]
private var _nameToId: [String: UUID] = [:]
```

NameGenerator is a list with an index. Both can be inline state in the coordinator.


**AgentSpawner into TavernCore**

The spawner is 132 lines that:
1. Generate a name
2. Create a ClaudeCode instance
3. Create a MortalAgent
4. Register it

This is straightforward procedural code that doesn't need its own class.


**Jake + MortalAgent into AgentData struct**

Agents currently have:
- Identity (id, name)
- Configuration (assignment, systemPrompt)
- Session state (sessionId, projectPath)
- Lifecycle state (state enum)
- Commitments list

All of this can be a struct. The coordinator holds the collection and performs operations on behalf of agents.

```swift
struct AgentData: Identifiable {
    let id: UUID
    let name: String
    let isJake: Bool
    var sessionId: String?
    var state: AgentState
    var commitments: [Commitment]
    let assignment: String?
}
```


**ChatViewModel into TavernCore**

ChatViewModel currently:
- Stores messages array
- Manages cogitation state
- Handles send/receive flow
- Stores input text

All except input text (which is view-local) can be coordinator state.


**AgentListViewModel into TavernCore**

This is 120 lines that maintain `items: [AgentListItem]` and `selectedAgentId`. The refresh logic reads from spawner.activeAgents and formats for display. Trivially inlined.


### Must Stay Separate

**TavernProject — Keep but Simplify**

Multi-project support is real and valuable. The window-per-project model is correct. But TavernProject can become much thinner:

```swift
@MainActor
class TavernProject: Identifiable {
    let id: UUID
    let rootURL: URL
    var core: TavernCore  // The monolith

    init(rootURL: URL) async throws {
        self.core = try await TavernCore(projectPath: rootURL.path)
    }
}
```


**ProjectManager — Keep**

Managing multiple open projects and recent projects list is orthogonal to agent orchestration. Keep as separate singleton.


**CommitmentVerifier — Keep**

Running shell commands is inherently async and involves Process management. This is a real boundary worth preserving. The monolith calls verifier, verifier calls shell.


**ClaudeCode SDK — Keep (Obviously)**

This is external. We call it; we don't control it.


**SessionStore — Collapse into TavernCore**

The SessionStore is just UserDefaults wrappers with path encoding. 50 lines of utility functions. Can be private helpers in TavernCore.


## Trade-offs Considered


### Single File vs Multiple Files

A monolithic architecture doesn't require a single file. The key insight is single ownership and single thread, not single source file.

Possible organization:
```
TavernCore/
├── TavernCore.swift         # Main class, public API
├── TavernCore+Agents.swift  # Agent CRUD operations
├── TavernCore+Chat.swift    # Message handling
├── TavernCore+Session.swift # Session persistence
└── AgentData.swift          # Struct definitions
```

Swift extensions allow splitting by concern while maintaining single-class semantics.


### Loss of Protocol-Based Testing

Current design allows injecting `MockClaudeCode` because agents take a `ClaudeCode` parameter. In a monolith, we'd need:

```swift
class TavernCore {
    private let claudeFactory: () -> ClaudeCode

    init(projectPath: String, claudeFactory: (() -> ClaudeCode)? = nil) {
        self.claudeFactory = claudeFactory ?? {
            try! ClaudeCodeClient(...)
        }
    }
}
```

Testing still works, just at the coordinator level rather than per-agent.


### State Observation Changes

Currently, `@Published` properties on ViewModels trigger SwiftUI updates. In a monolith:

```swift
@MainActor
class TavernCore: ObservableObject {
    @Published var agents: [AgentData] = []
    @Published var messages: [UUID: [ChatMessage]] = [:]  // keyed by agent
    @Published var selectedAgentId: UUID?
    @Published var cogitatingAgentId: UUID?
    // ...
}
```

SwiftUI still observes. The difference is one observed object instead of many.


### Handling Jake's Special Status

Jake is eternal, always present, has a character prompt. In the monolith:

```swift
@MainActor
class TavernCore: ObservableObject {
    private(set) var jake: AgentData  // Always exists, never removed
    @Published var mortalAgents: [AgentData] = []

    var allAgents: [AgentData] {
        [jake] + mortalAgents
    }
}
```

Jake's specialness is just a separate stored property. No subclassing, no protocol variance.


## Implementation Complexity

The monolithic approach is substantially simpler to implement:

**Lines of code comparison (estimated):**

| Component | Current | Monolithic |
|-----------|---------|------------|
| Agent types (Jake, MortalAgent, Agent, AnyAgent) | ~450 | ~50 (struct) |
| Registry + Spawner | ~230 | ~0 (inline) |
| ViewModels (3 classes) | ~380 | ~0 (inline) |
| TavernCore/Coordinator | ~145 | ~400 |
| **Total orchestration** | **~1200** | **~450** |

The reduction comes from:
- No thread synchronization code (DispatchQueues, sync blocks)
- No protocol conformance boilerplate
- No type erasure (AnyAgent)
- No delegation/notification patterns
- No view model bridging


## Migration Path from Current State


### Phase 1: Unify ViewModels into Coordinator

Keep existing agent classes but move:
- `ChatViewModel` state into `TavernCoordinator`
- `AgentListViewModel` state into `TavernCoordinator`

Views observe coordinator directly. This is low-risk and immediately simplifies the object graph.


### Phase 2: Inline AgentSpawner

Move spawning logic into coordinator. Remove AgentSpawner class. NameGenerator and AgentRegistry become private coordinator state.


### Phase 3: Convert Agents to Structs

Replace `Jake` and `MortalAgent` classes with `AgentData` struct. Coordinator manages agent lifecycle. Remove all DispatchQueues from agent code.


### Phase 4: Consolidate Session Storage

Inline SessionStore helpers into coordinator. Single place manages all persistence.


### Rollback Safety

Each phase is independently testable and reversible. If Phase 3 reveals a need for agent-level encapsulation, we can stop there with ViewModels unified but agents as objects.


## Open Questions


### How Does Streaming Fit?

The PRD mentions streaming responses as "not implemented yet." With agents as objects, streaming would be:

```swift
class MortalAgent {
    func send(_ message: String) -> AsyncThrowingStream<String, Error>
}
```

With agents as data, streaming becomes coordinator-level:

```swift
class TavernCore {
    func sendToAgent(_ agentId: UUID, _ message: String) -> AsyncThrowingStream<String, Error> {
        // Update cogitatingAgentId
        // Yield chunks as they arrive
        // Update messages array progressively
    }
}
```

Both work. The monolith version is actually cleaner because streaming state (which agent, how much received) naturally lives in the coordinator.


### How Do Background Agents Work?

The PRD describes "Perseverance mode" where agents work in background. This seems to conflict with single-threaded coordination.

Analysis: Background execution means "not blocking the UI," not "running on a different thread." An agent in background is still:
1. Waiting for Claude API response (async, not blocking)
2. Periodically auto-prompted (timer triggers coordinator method)
3. Results merged when ready

The coordinator can handle this:

```swift
@MainActor
class TavernCore {
    private var backgroundTasks: [UUID: Task<Void, Error>] = [:]

    func startBackgroundWork(agentId: UUID) {
        backgroundTasks[agentId] = Task {
            while !isCancelled {
                await sendToAgent(agentId, "[auto-continue]")
                try await Task.sleep(...)
            }
        }
    }
}
```

Swift's `Task` handles the actual concurrency. The coordinator manages the tasks. No agent-level threads needed.


### What About 50 Agents?

The PRD describes "amplification" — many saturated agents working in parallel. Does a monolith scale?

**CPU-bound work:** Agents don't do CPU work. They wait for Claude API. The bottleneck is API calls, not local computation.

**Memory:** 50 agents = 50 AgentData structs + 50 message arrays. Trivial memory footprint.

**UI updates:** 50 agents all finishing simultaneously = 50 @Published updates. SwiftUI coalesces these. Non-issue.

**API concurrency:** The monolith can fire 50 concurrent API requests:

```swift
await withTaskGroup(of: Void.self) { group in
    for agent in readyAgents {
        group.addTask {
            await self.sendToAgent(agent.id, "[continue]")
        }
    }
}
```

The coordinator doesn't do the work; it orchestrates. Orchestration is inherently sequential (decide what to do), execution is parallelized (do it).


### When Does This Break?

The monolith breaks when:

1. **Agent logic diverges significantly** — If different agent types need fundamentally different state machines, a single coordinator becomes a switch-case mess.

2. **Performance isolation required** — If one agent's work must not impact another's responsiveness, you need separate execution contexts.

3. **Team scale** — 5+ developers working simultaneously on orchestration logic creates merge conflict hell.

None of these apply to current v1 scope. They might apply to v2. Refactoring from simple-to-complex is easier than complex-to-simple.


## Recommendation

The monolithic approach is appropriate for v1 given:

1. Current implementation is already effectively single-threaded (all coordination flows through @MainActor)

2. Thread-safety infrastructure adds complexity without providing actual protection

3. v1 scope is narrow: chat with Jake, spawn agents, basic UI

4. Team size is small

5. Requirements are still evolving (many "TBD" items in PRD)

The migration path is incremental and reversible. Start with Phase 1 (unify ViewModels) and evaluate whether to continue.

**Key principle:** The current architecture anticipates needs that haven't materialized. A monolith addresses the needs that exist. When new needs arise, refactor to address them specifically rather than preemptively.
