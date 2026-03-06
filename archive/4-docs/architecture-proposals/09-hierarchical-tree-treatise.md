# Hierarchical Tree Architecture: Complete Analysis

This document contains the full research, trade-off analysis, and implementation planning for the Hierarchical Tree architecture proposal.


## Research Findings


### PRD Requirements That Drive This Architecture

The PRD (v1.2, 2026-01-21) contains explicit language supporting hierarchical tree structure:

**Section 4.1 Agent Types:**
> | **Mortal** | Task-scoped | Handles assignments, can spawn children, waits for input |

This directly states that mortal agents "can spawn children" — not just Jake, but any mortal agent.

**Section 6.2 Agent Spawn Configuration:**
> **Naming theme** belongs to tree root (Jake assigns when starting mortal tree). Children use same theme.

This confirms:
1. Jake creates "mortal trees" (not flat lists)
2. Naming themes are inherited from tree root
3. "Children" is explicit vocabulary

**Section 5.3 Bubbling:**
> - Can be upward (child → parent → grandparent → user)
> - Can be lateral (siblings collaborating)
> - Can be direct to user (with oversight)

This describes a tree-based escalation model. "Grandparent" implies at least three levels of depth.

**Section 7 Agent Naming:**
> Jake assigns a naming theme to each mortal agent tree. Names have familial resemblance so users intuit relationships.

Again, "mortal agent tree" — not "mortal agent list" or "mortal agent pool."

**Section 20 Success Criteria:**
> 4. Agents can spawn children and coordinate via doc store

This is a hard success criterion: agents spawning children is a v1 requirement.


### Current Implementation State

The current codebase (v1, 173 tests passing) has a flat structure:

**AgentSpawner (`Tavern/Sources/TavernCore/Agents/AgentSpawner.swift`):**
- Spawns agents into a flat `AgentRegistry`
- No parent-child relationship tracked
- `claudeFactory` creates independent `ClaudeCode` instances per agent
- No mechanism for an agent to spawn its own children

**AgentRegistry (`Tavern/Sources/TavernCore/Agents/AgentRegistry.swift`):**
- Simple `[UUID: AnyAgent]` dictionary
- Name uniqueness enforced globally
- No parent reference, no children collection
- `allAgents()` returns flat list

**MortalAgent (`Tavern/Sources/TavernCore/Agents/MortalAgent.swift`):**
- Has `assignment` but no `parent` reference
- Has `commitments` but no `children` collection
- No method like `spawn(child:)` or `spawnChild(assignment:)`
- State is self-contained (no awareness of tree position)

**TavernCoordinator (`Tavern/Sources/TavernCore/Coordination/TavernCoordinator.swift`):**
- Owns Jake directly
- Owns `AgentSpawner` for creating mortals
- Flat `chatViewModels: [UUID: ChatViewModel]` — no nesting
- Selection model is flat (one selected agent, regardless of depth)

**Key observation:** The current implementation supports Jake → Mortal (one level) but not Mortal → Child (deeper nesting). The infrastructure does not prevent deeper trees, but it also does not enable them.


### Design Transcripts Relevant to Hierarchy

**transcript_2026-01-21-2345.md (View Layer Discussion):**
> **[U]** Gangs are Erlang-style, you can spawn children of children of children.
>
> **[C]** Gang hierarchy — Jake spawns agents, those agents spawn gangs. Is it always two levels deep, or can gangs spawn sub-gangs recursively? Does the view system need to handle arbitrary depth?
>
> **[U]** Erlang-style. Arbitrary depth.

This confirms arbitrary depth is the intended model.

**reader_2026-01-19.md (Synthesis Document):**
> Mortal agents can have children, forming a tree structure per user request.

And later:
> - Agents can communicate upward (to parents), laterally (to siblings), or directly to user
> - Messages bubble up through hierarchy unless agent has permission for direct contact
> - Parent agents provide oversight for child-to-user communication

This describes a tree with explicit parent-child relationships and defined communication patterns.

**vocab_naming-themes_2026-01-19-1144.md:**
> When Jake spawns a mortal agent tree, he assigns a naming scheme.
> ...
> Store theme with mortal agent root so children use same scheme
> Path-style addressing (e.g., `Frodo/Sam/Rosie`) is not required for identity since names are globally unique, but may be useful for messaging and understanding hierarchy

Naming themes are tree-scoped, not agent-scoped.


## How This Maps to PRD Requirements


### Parent/Child Ownership

The PRD's "mortal agents can spawn children" requirement maps directly to hierarchical tree:

```swift
// Current: flat spawning
let agent = try spawner.spawn(assignment: "refactor API")

// Hierarchical: child spawning
let child = try agent.spawnChild(assignment: "write tests")
```

Ownership semantics:
- When `agent` is dismissed, `child` is automatically dismissed
- `child`'s lifetime is bounded by `agent`'s lifetime
- `child` inherits `agent`'s naming theme (no separate theme assignment)


### Bubbling

PRD Section 5.3 describes three bubbling modes:

1. **Upward (child → parent → grandparent → user):**
   - Natural tree traversal: `child.parent.parent...` until reaching Jake, then user
   - Each parent can filter, aggregate, or escalate questions
   - Implemented as: child sets state to `.waiting`, parent is notified, parent decides action

2. **Lateral (siblings collaborating):**
   - Siblings share a parent reference: `sibling = parent.children.first(where: { $0.id != self.id })`
   - Parent acts as message broker between siblings
   - Or: direct sibling reference stored at spawn time

3. **Direct to user (with oversight):**
   - Agent has `canContactUserDirectly: Bool` flag set at spawn
   - If true, questions go directly to user notification queue
   - Parent is notified (oversight) but not blocking


### Naming Theme Inheritance

PRD Section 7: "Naming theme belongs to tree root."

Implementation:
- `NameGenerator` is stored per tree root (first mortal spawned by Jake)
- When mortal spawns child, child uses parent's `NameGenerator`
- All agents in subtree draw from same themed pool

```swift
class MortalAgent {
    let nameGenerator: NameGenerator  // inherited from tree root

    func spawnChild(assignment: String) -> MortalAgent {
        let name = nameGenerator.nextNameOrFallback()
        return MortalAgent(
            name: name,
            parent: self,
            nameGenerator: self.nameGenerator  // pass down
        )
    }
}
```


### Budget Cascading

PRD mentions token budgets in several places. In a hierarchical tree:

```swift
class MortalAgent {
    var tokenBudget: Int  // remaining tokens this agent can spend

    func spawnChild(assignment: String, budget: Int) throws -> MortalAgent {
        guard budget <= tokenBudget else {
            throw SpawnError.insufficientBudget
        }
        tokenBudget -= budget  // parent's budget decreases

        return MortalAgent(
            tokenBudget: budget,
            parent: self,
            ...
        )
    }
}
```

Budget flows down the tree. Spending rolls up (child's consumption decrements parent's remaining).


## Trade-offs Considered


### Tree Depth vs. Bubbling Latency

Deep trees (4+ levels) mean questions take longer to reach the user:
- Child → Parent (wait for parent to be free)
- Parent → Grandparent (wait for grandparent to be free)
- etc.

Mitigation options:
1. **Depth limits**: Warn or prevent trees deeper than N levels (configurable)
2. **Direct escalation mode**: Some questions bypass intermediate levels
3. **Priority queues**: Urgent questions jump parent's queue

Trade-off decision: Start with no limit, add configurable limit if latency becomes problematic in practice.


### Strict Ownership vs. Flexible Reassignment

Strict ownership: child dies when parent dies. No orphans, simple cleanup.

Flexible reassignment: reparent orphans to grandparent or Jake.

Arguments for strict:
- Simpler mental model
- Matches Erlang semantics
- Easier cleanup logic
- PRD doesn't mention reparenting

Arguments for flexible:
- More resilient to parent failures
- Child work isn't lost
- Matches some human org models

Trade-off decision: Strict ownership for v1. Reparenting is a v2 feature if needed.


### Flat Registry vs. Tree-Aware Registry

Option A: Keep flat `AgentRegistry`, add parent/children references to `MortalAgent`

Option B: Replace `AgentRegistry` with tree-aware `AgentTree` that manages hierarchy

Option A pros:
- Less refactoring
- Registry stays simple
- Tree logic in agents where it belongs

Option B pros:
- Single source of truth for relationships
- Easier subtree operations (dismiss subtree, budget subtree, etc.)
- Cleaner separation (agents do work, tree manages structure)

Trade-off decision: Hybrid approach. Keep `AgentRegistry` for identity/uniqueness, add `parentId` and `childIds` to agent metadata. Tree traversal is a query on registry, not a separate data structure.


### Sync vs. Async Bubbling

Synchronous bubbling: child blocks until question is answered all the way up and back.

Asynchronous bubbling: child posts question, continues with other work, receives answer later.

PRD Section 4.2 Agent States describes:
> **Waiting for Input** — Needs human response (includes "blocked" — same state, different flavor)

This suggests sync: agent enters waiting state and stops until input received.

But PRD also says agents can work autonomously in "perseverance mode." This suggests async is possible.

Trade-off decision: Default to sync (agent waits). Add async option for agents that can "work around" pending questions.


## Implementation Complexity


### Changes Required to Current Codebase

**MortalAgent additions:**
```swift
public final class MortalAgent {
    // New properties
    public weak var parent: MortalAgent?
    public private(set) var children: [MortalAgent] = []
    public let treeRootId: UUID  // for theme lookup

    // New methods
    public func spawnChild(assignment: String) throws -> MortalAgent
    public func dismissChild(_ child: MortalAgent) throws
    public func dismissSubtree()  // recursive
    public func escalate(question: Question)  // bubble up
}
```

**AgentSpawner changes:**
- `spawn(assignment:)` becomes `spawnRootMortal(assignment:)` — only for Jake to call
- Remove direct access; spawning goes through parent agent

**AgentRegistry changes:**
- Add `parentId: UUID?` to agent metadata
- Add `childIds: [UUID]` to agent metadata (or derive from parent references)
- Add `subtree(rootId:) -> [AnyAgent]` for subtree queries

**TavernCoordinator changes:**
- `spawnAgent(assignment:)` becomes `spawnRootAgent(assignment:)` for Jake's direct children
- Add `selectedAgentPath: [UUID]` for breadcrumb navigation
- Add subtree dismissal support

**View layer changes:**
- `AgentListView` needs tree/flat toggle
- Indentation for nested agents
- Collapse/expand for subtrees
- Breadcrumb bar for deep navigation


### Estimated Effort

| Component | Effort | Notes |
|-----------|--------|-------|
| MortalAgent tree properties | 2 hours | Add parent/children, weak refs |
| spawnChild implementation | 4 hours | Including theme inheritance |
| dismissSubtree | 2 hours | Recursive cleanup |
| Registry tree metadata | 2 hours | Parent/child tracking |
| Bubbling infrastructure | 6 hours | Question routing, state transitions |
| AgentListView tree mode | 4 hours | Indentation, collapse |
| Tests for all above | 8 hours | ~40 new tests |
| **Total** | **~28 hours** | 3-4 working days |


### Test Coverage Requirements

New test categories needed:

1. **Tree structure tests:**
   - Parent-child relationships are established correctly
   - Tree depth limits are enforced (if any)
   - Subtree traversal returns correct agents
   - Orphan prevention (child cannot outlive parent)

2. **Lifecycle tests:**
   - Dismissing parent dismisses children
   - Dismissing root mortal dismisses entire tree
   - Child cannot spawn after parent is dismissed

3. **Theme inheritance tests:**
   - Children use parent's name generator
   - Names are globally unique across trees
   - Theme exhaustion works correctly in deep trees

4. **Bubbling tests:**
   - Question reaches parent
   - Question escalates through multiple levels
   - Direct-to-user mode bypasses hierarchy
   - Lateral messaging between siblings

5. **Budget tests:**
   - Child cannot exceed parent's remaining budget
   - Spending propagates up the tree
   - Budget exhaustion terminates subtree


## Migration Path from Current State


### Phase 1: Add Tree Properties (Non-Breaking)

Add optional `parentId` and `childIds` to `MortalAgent`. Existing code continues to work (all agents have `parentId = nil`).

```swift
// MortalAgent.swift
public weak var parent: MortalAgent?
public private(set) var children: [MortalAgent] = []
```

Tests: All existing tests pass. New tests for property accessors.


### Phase 2: Implement spawnChild (Additive)

Add `spawnChild(assignment:)` method. Existing `AgentSpawner.spawn()` still works for flat spawning.

```swift
public func spawnChild(assignment: String) throws -> MortalAgent {
    let name = nameGenerator?.nextNameOrFallback() ?? "Child-\(children.count)"
    let child = MortalAgent(
        name: name,
        assignment: assignment,
        claude: claudeFactory(),
        parent: self,
        nameGenerator: self.nameGenerator
    )
    children.append(child)
    try registry.register(child)
    return child
}
```

Tests: New tests for child spawning. Existing tests unaffected.


### Phase 3: Wire Theme Inheritance

Modify tree root creation to assign `NameGenerator`. Children inherit from parent.

```swift
// When Jake spawns a root mortal:
let theme = NamingTheme.random()
let nameGenerator = NameGenerator(theme: theme)
let rootMortal = MortalAgent(
    nameGenerator: nameGenerator,
    ...
)
```

Tests: Verify theme consistency within subtree.


### Phase 4: Implement Subtree Dismissal

Add recursive dismissal and wire into `dismissAgent()`.

```swift
public func dismissSubtree() {
    for child in children {
        child.dismissSubtree()
    }
    // Then dismiss self (handled by caller)
}
```

Tests: Verify cascade dismissal.


### Phase 5: Bubbling Infrastructure

Add question escalation. This is the most complex phase.

```swift
public func escalate(question: Question) async {
    if let parent = parent {
        await parent.receiveEscalation(from: self, question: question)
    } else {
        // Reached root — surface to coordinator/user
        await coordinator?.surfaceQuestion(from: self, question: question)
    }
}
```

Tests: Multi-level bubbling, timeout handling, direct-to-user mode.


### Phase 6: View Layer Updates

Update `AgentListView` for tree rendering. This can happen in parallel with phases 3-5.


## Open Questions


### Q1: How deep is too deep?

The PRD says "arbitrary depth" but practical limits exist:
- UI becomes unwieldy beyond 4-5 levels
- Bubbling latency increases with depth
- Name exhaustion happens faster in deep trees

**Proposal:** No hard limit in v1. Add `maxDepth` configuration in v2 if issues arise.


### Q2: Can mortals spawn mortals or only drones?

PRD Section 4.1 lists three agent types: Mortal, Drone, Monitor Daemon.

- Mortals "can spawn children" — but what type of children?
- Drones are "single task, cheap to fail"

**Interpretation:** Mortals can spawn mortals (for complex sub-delegation) or drones (for quick one-off tasks). The tree structure applies to both.


### Q3: What happens to in-flight work when parent dies?

If parent is dismissed while children are working:
- Option A: Children are killed immediately (strict ownership)
- Option B: Children finish current task, then die
- Option C: Children are orphaned to grandparent

PRD doesn't specify. **Proposal:** Option A for simplicity. Consider B for "graceful shutdown" in v2.


### Q4: How does tree structure interact with changesets?

PRD Section 4.6 describes changesets as overlay filesystems. If a subtree shares a changeset:
- Does dismissing the subtree discard the changeset?
- Can children have independent changesets?

**Proposal:** Changesets are agent-scoped, not tree-scoped. Dismissing an agent orphans its changeset for review/merge/discard decision.


### Q5: Do siblings share a ClaudeCode session or have independent sessions?

Current implementation: each agent has its own `ClaudeCode` instance.

Options:
- Independent (current): more isolation, more tokens, more context per agent
- Shared: siblings see each other's conversation, natural collaboration, less isolation

**Proposal:** Keep independent for v1. Shared sessions are a collaboration feature for v2.


## Comparison with Other Proposals


### vs. Flat Coordinator (01)

Flat Coordinator collapses coordination into one type. Hierarchical Tree distributes coordination through parent agents.

| Aspect | Flat Coordinator | Hierarchical Tree |
|--------|------------------|-------------------|
| Complexity | Lower | Higher |
| PRD alignment | Partial | Full |
| Scalability | Limited | Better |
| Delegation | Coordinator only | Any agent |
| Isolation | By agent | By subtree |


### vs. Supervisor Trees (04)

Supervisor Trees focus on failure recovery. Hierarchical Tree focuses on ownership and delegation.

Both can coexist: Supervisor Trees manage restart policies; Hierarchical Tree manages parent-child relationships. A supervisor could restart a subtree after its root fails.


### vs. Document-Centric (03)

Document-Centric puts the doc store at the center. Hierarchical Tree puts agent relationships at the center.

They're complementary: agents form a tree, but they store their state in the doc store. The tree structure could be persisted as documents with parent references.


## Recommendation

Implement Hierarchical Tree as the primary coordination architecture because:

1. **PRD explicitly describes this structure** — not implementing it means deviating from spec

2. **Bubbling requires parent references** — you cannot implement "child → parent → grandparent → user" without tree structure

3. **Theme inheritance requires tree awareness** — "theme belongs to tree root" requires knowing tree membership

4. **Current flat structure is a subset** — flat is just "all agents have Jake as parent." Migration adds depth, doesn't break existing behavior.

5. **Implementation complexity is bounded** — 28 hours estimated, with clear phases and test coverage

The main risk is depth complexity (deep trees being hard to manage), which can be mitigated with configurable limits and good UI for tree navigation.
