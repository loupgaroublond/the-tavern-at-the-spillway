# Transcript: AgentRegistry Architecture & Component Separation

**Date:** 2026-01-25 01:08-01:48
**Session:** Architecture review, component responsibilities, 1:1 relationship analysis


## The Question

**[U]** "can you explain to me why we might need an agent registry in Tavern? also, is our architecture documentation up to date?"

*[T] User questioning the architectural separation — TavernProject, TavernCoordinator, AgentSpawner, and AgentRegistry all exist in 1:1 relationships. Is the indirection justified?*


## Why AgentRegistry Exists

**[C]** The AgentRegistry solves several architectural problems:

**1. Single Source of Truth for Agent Lifecycle**

Without a registry, agents would be scattered across the system. The UI needs to list agents, chat views need to look them up by ID, and the spawner needs to verify agents exist before dismissing. Registry centralizes this.

**2. Name Uniqueness**

Multiple agents with the same name would cause confusion and lookup collisions. Registry enforces uniqueness at registration time:
```swift
if _nameToId[agent.name] != nil {
    throw AgentRegistryError.nameAlreadyExists(agent.name)
}
```

**3. Thread Safety**

Agents can be spawned/dismissed from different threads while UI reads the agent list. Registry wraps all operations in a serial `DispatchQueue` to prevent race conditions.

**4. Type Erasure**

Swift can't store different Agent implementations (Jake, MortalAgent) in a single array. `AnyAgent` wrapper enables `[AnyAgent]` collections.

**5. Separation of Concerns**

Registry acts as a facade — spawner, coordinator, and UI all depend on it, not on each other:
```
TavernCoordinator → Spawner → Registry ← AgentListViewModel
                                        ← ChatViewModel
```


## Architecture Documentation Audit

**[C]** The docs are significantly outdated. Key gaps:

| Area | Docs Say | Reality |
|------|----------|---------|
| Project System | "Not implemented" | Fully implemented (`ProjectManager`, `TavernProject`) |
| Multi-window | Not mentioned | Core architecture with `WindowOpeningService` |
| Session History | Not mentioned | Per-project sessions via `ClaudeNativeSessionStorage` |
| UI Module | Not mentioned | `AgentListViewModel`, view model caching |
| App Entry Point | Brief mention | 630 lines with window management, delegates |

The docs describe the foundational architecture correctly, but the codebase has evolved with full multi-project support, per-project Jake sessions, window restoration, dock menu with recent projects, and agent state extensions.

**[U]** "write down both the reports"

**[C]** Created two files:
- `docs/agent-registry-analysis.md` — Explains what AgentRegistry does, how components use it, and the problems it solves
- `docs/architecture-audit.md` — Compares `architecture-v1.md` against the codebase with gap summary


## The 1:1 Relationship Chain

**[U]** "how does the agent registry map to the tavern coordinator? aren't they 1:1?"

**[C]** Yes, they're 1:1:1:1. The ownership chain is:

```
TavernProject (per directory)
    └── TavernCoordinator (1)
            └── AgentSpawner (1)
                    └── AgentRegistry (1)
```

From `TavernProject.swift:57-79`:
```swift
let registry = AgentRegistry()
let spawner = AgentSpawner(registry: registry, ...)
self.coordinator = TavernCoordinator(jake: jake, spawner: spawner)
```

Each project creates its own fresh stack. Agents in Project A are completely isolated from Project B.

**So why the indirection?**

The registry could theoretically live directly on the coordinator, but the separation gives:

1. **Single Responsibility** — Registry does one thing (track agents). Spawner handles creation/naming. Coordinator handles orchestration. Each can be tested independently.

2. **Testability** — Tests can create a registry without a spawner, or a spawner with a mock registry. See `AgentRegistryTests.swift` — 12+ tests on registry alone.

3. **Future flexibility** — If you ever wanted agents to span projects (shared pool), or a global registry with project-scoped views, the abstraction is already there.

4. **Dependency injection** — The spawner receives its registry; it doesn't create it. Makes mocking trivial.

**[C]** That said, for the current architecture where everything is 1:1 per-project, you *could* collapse them. It's a tradeoff between simplicity (fewer objects) vs. separation of concerns (cleaner boundaries). The current design favors the latter.


## The Singleton Question

**[U]** "isn't the tavern coordinator a singleton in the app?"

**[C]** No, `TavernCoordinator` is **not** a singleton. The singleton is `ProjectManager`.

```
ProjectManager.shared (singleton)
    └── openProjects: [TavernProject]
            ├── TavernProject (~/project-a/)
            │       └── coordinator: TavernCoordinator (1)
            │               └── spawner → registry
            │
            └── TavernProject (~/project-b/)
                    └── coordinator: TavernCoordinator (2)
                            └── spawner → registry
```

Each open project gets its own coordinator. The app supports **multi-window** — you can have multiple projects open simultaneously, each in its own window with its own Jake and agent pool.

From `ProjectManager.swift:43-46`:
```swift
// Check if already open
if let existing = openProjects.first(where: { $0.rootURL == url }) {
    return existing
}
```

So if you open the same directory twice, you get the existing project (and its coordinator). But different directories = different coordinators.


## TavernProject vs TavernCoordinator Separation

**[U]** "does it make sense to delegate this out from the tavern project in the first place?"

**[C]** Good question. Let me look at what each layer actually does.

**TavernProject:**
- Holds `rootURL`
- Factory: creates ClaudeCode, Jake, registry, spawner, coordinator
- Tracks initialization state (`isReady`, `initializationError`)

**TavernCoordinator:**
- Owns Jake + spawner
- Manages chat view models
- Handles agent selection
- Orchestrates spawn/dismiss

TavernProject is essentially a thin wrapper — it's a factory + URL holder. The coordinator could absorb this:

```swift
// Instead of:
let project = TavernProject(rootURL: url)
await project.initialize()
project.coordinator?.spawn(...)

// Could be:
let coordinator = TavernCoordinator(rootURL: url)
await coordinator.initialize()
coordinator.spawn(...)
```

**Arguments for collapsing:**
- Less indirection
- Coordinator already knows about the project implicitly (Jake's `projectPath`)
- TavernProject doesn't do much after initialization

**Arguments for keeping separate:**
- TavernProject is the *identity* (keyed by URL in ProjectManager)
- Coordinator is the *behavior*
- Initialization failure handling is cleaner as a separate concern
- Could have a coordinator without a project (testing, scratchpad mode)

**[C]** My take: The separation feels like anticipatory design. If you're never going to have a coordinator without a project, or a project with multiple coordinators, then the abstraction isn't paying for itself. You could merge them and split later if needed.

The current structure isn't *wrong*, but it's one layer more than strictly necessary for what the app does today.


---

## Synthesis

___

[S] **Architecture Questioning as Design Process**

This session demonstrates probing the existing architecture for justification. The user didn't demand changes — they asked "why?"

The answers revealed:

1. **Some separations have concrete value** — AgentRegistry's thread safety, type erasure, and testability justify its existence as a separate type

2. **Some separations are speculative** — TavernProject as a factory separate from TavernCoordinator anticipates flexibility that may never be needed

3. **1:1 relationships are a code smell** — When every X has exactly one Y, and every Y has exactly one X, the separation may be over-engineering

4. **Multi-instance patterns justify shared types** — Multiple projects (each with coordinator + registry + spawner) mean shared abstractions pay off more than in a single-instance app

The session didn't result in code changes, but it documented the architectural rationale. When requirements change (e.g., "we need global agent pools"), these answers will determine which separations were prescient and which were premature.

**Key insight:** Not every question needs to end in a decision. Sometimes "here's why it is this way" is the right answer, even if "it could be simpler" is also true.
