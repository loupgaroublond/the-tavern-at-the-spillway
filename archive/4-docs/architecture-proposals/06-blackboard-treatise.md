# Blackboard Architecture: Complete Analysis

This document contains the full research, analysis, and reasoning behind the Blackboard architecture proposal for Tavern.


## Research Findings


### Current Codebase Analysis

The Tavern codebase as of this analysis has the following relevant characteristics:

**Coordination Layer:**
- `TavernCoordinator` is the central hub for a single project (per-project, `@MainActor`)
- Owns Jake, AgentSpawner, and manages ChatViewModels
- Uses explicit selection/spawning APIs: `selectAgent()`, `spawnAgent()`, `dismissAgent()`
- No inter-agent communication mechanism exists yet

**Agent Model:**
- `Agent` protocol defines: `id`, `name`, `state`, `send()`, `resetConversation()`
- `AgentState` enum: `idle`, `working`, `waiting`, `verifying`, `done`
- `Jake` is eternal, per-project, with session persistence
- `MortalAgent` is task-scoped with commitments and verification

**Registry & Spawning:**
- `AgentRegistry` tracks agents by ID and name (thread-safe via DispatchQueue)
- `AgentSpawner` creates agents with themed names via `NameGenerator`
- Agents are currently independent -- no parent-child relationships in code
- No work queues implemented yet

**Persistence:**
- `DocStore` provides file-based document storage (markdown + YAML frontmatter)
- `SessionStore` handles session ID persistence (UserDefaults + native Claude storage)
- PRD states: "Doc store IS the filesystem. A file is a document."

**Key PRD Requirements:**
- Multiple agents working in parallel on a single project
- Agents work autonomously but surface questions intelligently
- Deterministic verification of agent commitments
- Document store as central nervous system
- Discovery sharing: agents notice oddities and share them
- User attention is sacred -- never force new content without consent


### Classical Blackboard Pattern

The blackboard architecture originated in the HEARSAY-II speech understanding system (1970s). Core elements:

1. **Blackboard** -- Global shared memory partitioned into information levels
2. **Knowledge Sources (KS)** -- Independent modules with expertise in specific domains
3. **Control Component** -- Scheduler that decides which KS runs next

Key characteristics:
- Knowledge sources are triggered by changes to blackboard regions they monitor
- KSs are opportunistic: they contribute when relevant data appears
- No fixed control flow; execution order emerges from data dependencies
- Supports incremental, collaborative problem-solving


### Mapping to Multi-Agent Coordination

The PRD's requirements map surprisingly well to blackboard concepts:

| PRD Concept | Blackboard Analog |
|-------------|-------------------|
| DocStore as central nervous system | Blackboard data structure |
| Agent types (Jake, Mortal, Drone) | Knowledge sources with different capabilities |
| Work queues | Blackboard task regions |
| Discovery sharing | Observation contributions to shared state |
| Deterministic verification | Control component validation checks |
| User attention management | Jake as human interface KS |


## Architectural Mapping


### Blackboard Structure

The blackboard would be organized as structured regions within the DocStore:

```
.tavern/
├── blackboard/
│   ├── tasks/
│   │   ├── task-001.md          # Task definition + status
│   │   ├── task-002.md
│   │   └── ...
│   ├── solutions/
│   │   ├── task-001/            # Per-task solution workspace
│   │   │   ├── design.md        # Architectural decisions
│   │   │   ├── implementation/  # Code artifacts
│   │   │   └── history.md       # Contribution log
│   │   └── ...
│   ├── observations/
│   │   ├── obs-001.md           # Discovered issues, opportunities
│   │   └── ...
│   ├── questions/
│   │   ├── q-001.md             # Blockers needing human input
│   │   └── ...
│   └── control/
│       ├── schedule.md          # Current activation queue
│       └── metrics.md           # Performance tracking
```


### Knowledge Source Types

Each agent type becomes a specialized knowledge source:

**Jake (Controller KS)**
- Monitors: questions/, observations/ for items needing escalation
- Contributes: tasks/ (new assignments), schedule.md (priority adjustments)
- Special role: Human interface, final arbiter

**Architect KS**
- Monitors: tasks/ for new work, solutions/ for design gaps
- Contributes: solutions/*/design.md, observations/ (architecture concerns)

**Implementer KS**
- Monitors: solutions/*/design.md for approved designs
- Contributes: solutions/*/implementation/, observations/ (implementation issues)

**Tester KS**
- Monitors: solutions/*/implementation/ for testable code
- Contributes: observations/ (test results, coverage gaps)

**Reviewer KS**
- Monitors: solutions/*/implementation/ for review-ready code
- Contributes: observations/ (style issues, bugs)


### Control Component

The scheduler determines knowledge source activation:

```swift
protocol ActivationCondition {
    func evaluate(blackboard: Blackboard) -> Float  // 0-1 activation weight
}

struct BlackboardController {
    let knowledgeSources: [KnowledgeSource]
    let blackboard: Blackboard

    func selectNext() -> KnowledgeSource? {
        // Evaluate all KS activation conditions
        // Return highest-weighted KS that isn't currently active
        knowledgeSources
            .filter { !$0.isActive }
            .max { $0.activation.evaluate(blackboard) < $1.activation.evaluate(blackboard) }
    }
}
```


## Trade-offs Analysis


### Strengths for Tavern

**Alignment with DocStore Philosophy**

The PRD is emphatic: "Doc store IS the filesystem." Blackboard architecture takes this literally -- all coordination happens through shared files. No hidden in-memory state that could desync. This is a profound alignment.

Current code already uses `DocStore` for persistence. Extending it to be the coordination medium requires incremental changes rather than a paradigm shift.

**Discovery Sharing is First-Class**

The PRD notes: "Agents (even drones) prompted to notice oddities and share them via messaging."

In blackboard architecture, this is natural. Any agent can write to the observations/ region at any time. Other agents see these contributions in their next activation. No explicit messaging protocol needed.

**Graceful Degradation**

If an Implementer KS hangs or crashes, the Tester KS can still run on whatever code exists. The Reviewer KS can still find issues. Jake can still surface questions to the user. Partial progress is the norm, not an exception.

**Observable by Design**

Debugging becomes file inspection. "What's the system doing?" Check `.tavern/blackboard/`. "Why did Agent X do Y?" Check the contribution history. Aligns with the Instrumentation Principle.


### Challenges for Tavern

**Conflict Resolution**

When two agents try to modify the same solution file simultaneously:
- Option A: File-level locking (simple but coarse)
- Option B: Append-only contributions with merge at read time (complex but concurrent)
- Option C: Ownership rules (e.g., only Architect can write design.md)

The PRD's changeset concept could help -- each agent works in its own overlay, and a merge step reconciles.

**Control Flow Opacity**

In explicit delegation (current architecture tendency), tracing is straightforward: Jake spawns Agent, Agent reports back. In blackboard, the sequence is: something changes, scheduler picks a KS, KS runs, something else changes. Reconstruction requires log analysis.

Mitigation: Detailed contribution logs in each blackboard region.

**Activation Scheduling**

Which agent should run next? Options:
- Priority-based (Architect before Implementer)
- Recency-based (most recently updated region triggers relevant KS)
- Need-based (KS with highest unsatisfied activation weight)

The control component becomes a critical design decision.

**Commitment Verification**

Current `CommitmentVerifier` assumes one agent claims "DONE" and verifications run. With blackboard, completion is distributed: Architect contributes design, Implementer contributes code, Tester contributes passing tests. When is the task "done"?

Possible approach: Define composite completion conditions in task definitions:
```yaml
completion_requires:
  - region: solutions/task-001/design.md
    condition: approved
  - region: solutions/task-001/implementation/
    condition: tests_pass
  - region: observations/
    condition: no_blocking_issues
```


## Implementation Complexity


### Phase 1: Foundation (Low complexity)

Extend DocStore to support blackboard regions:

```swift
struct BlackboardRegion {
    let path: String                    // e.g., "tasks/", "solutions/"
    let schema: DocumentSchema?         // Optional validation
    let accessControl: AccessPolicy     // Who can read/write
}

class Blackboard {
    let docStore: DocStore
    let regions: [BlackboardRegion]

    func write(_ document: Document, to region: String) throws { ... }
    func read(from region: String, matching: Query?) throws -> [Document] { ... }
    func watch(_ region: String, handler: @escaping (Change) -> Void) { ... }
}
```

This is an incremental extension of existing `DocStore` code.


### Phase 2: Knowledge Sources (Medium complexity)

Refactor agents to be activation-triggered:

```swift
protocol KnowledgeSource: Agent {
    var monitoredRegions: [String] { get }
    var activationCondition: ActivationCondition { get }

    func contribute(to blackboard: Blackboard) async throws
}

class ArchitectKS: KnowledgeSource {
    var monitoredRegions: ["tasks/", "solutions/"]

    var activationCondition: ActivationCondition {
        // Activate when new task without design, or design needs revision
        CompositeCondition([
            NewTaskWithoutDesign(),
            DesignFlagged()
        ])
    }

    func contribute(to blackboard: Blackboard) async throws {
        // Read relevant state
        // Generate contribution via Claude
        // Write to appropriate region
    }
}
```

Requires new protocols but builds on existing `Agent` structure.


### Phase 3: Control Component (High complexity)

The scheduler is the trickiest part:

```swift
actor BlackboardController {
    let blackboard: Blackboard
    var knowledgeSources: [KnowledgeSource] = []
    var activeKS: Set<UUID> = []

    func run() async {
        while true {
            // Wait for blackboard changes
            let changes = await blackboard.nextChanges()

            // Evaluate KS activations
            let candidates = knowledgeSources.filter { ks in
                !activeKS.contains(ks.id) &&
                ks.activationCondition.evaluate(blackboard) > 0.5
            }

            // Activate highest-priority KS
            if let next = candidates.max(by: { ... }) {
                activeKS.insert(next.id)
                Task {
                    try await next.contribute(to: blackboard)
                    activeKS.remove(next.id)
                }
            }
        }
    }
}
```

This requires careful concurrency handling, loop prevention, and metric collection.


### Estimated Effort

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Foundation | 1-2 weeks | Existing DocStore |
| Knowledge Sources | 2-3 weeks | Foundation, Agent refactor |
| Control Component | 2-4 weeks | Foundation, Knowledge Sources |
| Integration + Testing | 2-3 weeks | All phases |

**Total: 7-12 weeks** for a complete implementation.


## Migration Path from Current State


### Step 1: DocStore as Blackboard Substrate

The existing `DocStore` is already file-based with thread-safe operations. Add:
- Region concept (directory-based partitioning)
- Watch mechanism (file system events via FSEvents or Dispatch Source)
- Conflict handling (optimistic locking with version metadata)

Changes to `DocStore.swift`, new `BlackboardRegion.swift`.


### Step 2: Jake as First Knowledge Source

Refactor Jake to monitor blackboard regions:
- Instead of synchronous `send()`, Jake polls questions/ for user-facing items
- Responses write to appropriate regions rather than returning directly
- Maintains backward compatibility: `send()` can internally use blackboard

Gradual refactor of `Jake.swift`.


### Step 3: MortalAgent as Knowledge Source Template

Generalize `MortalAgent` to support activation-based execution:
- Current: Created with assignment, runs until done
- New: Created with monitored regions and activation condition
- Assignment becomes initial contribution to tasks/ region

New `KnowledgeSource` protocol, refactor of `MortalAgent.swift`.


### Step 4: TavernCoordinator as Controller

Replace direct spawn/dismiss with blackboard-mediated control:
- Spawning writes to tasks/, knowledge sources activate
- Dismissal removes from active set, KS deactivates
- Selection becomes navigation through blackboard state

Major refactor of `TavernCoordinator.swift`, new `BlackboardController.swift`.


### Backward Compatibility

The migration can preserve the existing API surface:
- `spawnAgent(assignment:)` internally writes to tasks/
- `send(message:)` internally writes to and polls blackboard
- UI continues to work through view models

Users see the same behavior; internals become blackboard-based.


## Open Questions


### Scheduling Strategy

What determines which knowledge source runs next?

Options:
1. **Priority levels** -- Architect > Implementer > Tester > Reviewer
2. **Urgency signals** -- Flagged items get immediate attention
3. **Round-robin with weights** -- Fair sharing with expertise bias
4. **ML-based** -- Learn optimal scheduling from outcomes

Recommendation: Start with priority levels + urgency signals. Add sophistication later.


### Granularity of Knowledge Sources

Should each spawned agent be a separate KS, or should there be fixed KS types that spawn workers?

Options:
1. **1:1 mapping** -- Each `MortalAgent` is a KS
2. **Type-based** -- One Architect KS that spawns Architect workers
3. **Hybrid** -- Core KS types plus ad-hoc KS for specific tasks

Recommendation: Type-based for predictability, with extension points.


### Human-in-the-Loop

How does the user interact with the blackboard?

Options:
1. **Through Jake only** -- User talks to Jake, Jake manages blackboard
2. **Direct access** -- User can read/write blackboard regions
3. **Hybrid** -- Jake for conversation, direct for file edits

The PRD's attention model suggests Option 3: user engages via Jake but can drill into any agent (i.e., any blackboard region).


### Commitment Verification

How do commitments work in a distributed-contribution model?

Options:
1. **Task-level** -- Each task has commitments, verified when task marked complete
2. **Region-level** -- Each region has invariants, verified on write
3. **Contribution-level** -- Each KS contribution has assertions

Recommendation: Task-level commitments with region invariants as validation layer.


### Session Persistence

Current `SessionStore` tracks per-agent sessions. With blackboard:
- Sessions might be unnecessary -- all state is in blackboard
- Or sessions track KS activation history
- Or sessions are per-task rather than per-agent

The blackboard itself could serve as the session record.


### Performance at Scale

With many agents watching many regions:
- File system watching overhead
- Blackboard size growth
- Query performance for activation evaluation

May need indexing, caching, or hierarchical blackboard structure for large projects.


## Comparison to Alternative Architectures


### vs. Hierarchical (Parent-Child)

| Aspect | Blackboard | Hierarchical |
|--------|-----------|--------------|
| Control flow | Emergent | Explicit |
| Failure isolation | High | Medium |
| Traceability | Requires logging | Built-in |
| Flexibility | High | Medium |
| Complexity | Higher | Lower |

Hierarchical is simpler but less flexible. Blackboard suits exploratory work.


### vs. Event-Driven (Pub/Sub)

| Aspect | Blackboard | Event-Driven |
|--------|-----------|--------------|
| State visibility | Full | Events only |
| Replay capability | Easy | Requires event store |
| Coupling | Low | Low |
| Ordering | Scheduler-controlled | Event order |

Blackboard provides richer state; event-driven is lighter weight.


### vs. Workflow/Pipeline

| Aspect | Blackboard | Pipeline |
|--------|-----------|----------|
| Task structure | Flexible | Fixed stages |
| Parallelism | Opportunistic | Stage-parallel |
| Backtracking | Natural | Difficult |
| Predictability | Lower | Higher |

Pipeline suits known processes; blackboard suits discovery.


## Conclusion

The Blackboard architecture is a strong candidate for Tavern's multi-agent coordination needs. Its alignment with the DocStore philosophy, support for emergent collaboration, and natural handling of discovery make it particularly well-suited to the creative, exploratory nature of software development tasks.

The main challenges -- conflict resolution, control flow opacity, and scheduler complexity -- are addressable through careful design. The migration path from current state is incremental rather than revolutionary.

Key recommendation: If Tavern's use cases emphasize collaborative problem-solving with diverse specialists over predictable sequential workflows, Blackboard is the right choice.
