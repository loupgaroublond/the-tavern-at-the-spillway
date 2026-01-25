# Graph-Based Architecture: Complete Analysis

This document contains the full research, analysis, and thinking behind the graph-based architecture proposal for Tavern.


## 1. Research Findings


### 1.1 Current Codebase State

The existing implementation uses an **implicit tree structure**:

- `TavernCoordinator` owns Jake and the `AgentSpawner`
- `AgentSpawner` creates `MortalAgent` instances and registers them in `AgentRegistry`
- `AgentRegistry` stores agents in flat dictionaries (`_agents: [UUID: AnyAgent]`, `_nameToId: [String: UUID]`)
- No explicit parent-child relationships are stored
- No agent-to-agent communication exists

**Key observation:** The current `AgentRegistry` is a flat lookup table, not a tree. The "tree" structure exists only conceptually in the spawn order and the naming themes. There is no `parentId` field, no `children` array, no relationship tracking whatsoever.

```swift
// From AgentRegistry.swift
private var _agents: [UUID: AnyAgent] = [:]
private var _nameToId: [String: UUID] = [:]
```

This is significant: transitioning to graphs does not require dismantling a tree structure because no tree structure actually exists in code. The architecture is closer to a graph with no edges than a tree.


### 1.2 PRD Requirements Analysis

The PRD (Section 5.3 "Bubbling") explicitly requires non-tree communication:

> "Routing is context-dependent, based on zoom level and user attention. CEO model..."
> - Can be upward (child -> parent -> grandparent -> user)
> - Can be lateral (siblings collaborating)
> - Can be direct to user (with oversight)

From the reader document (Section 9 "Agent Communication"):

> "Messaging is not just for bubbling up. Agents can message each other to collaborate on work."

From transcript_2026-01-19-1144.md:

> "[U] Agents know about peers, and can really message groups too, at any level. Sometimes we may have awareness boundaries, but those are explicit..."

**Conclusion:** The PRD mandates graph-like communication patterns. Trees cannot model lateral messaging without contortions (routing through common ancestors).


### 1.3 Existing Architecture Proposals Comparison

Reviewing the existing proposals:

| Proposal | Relationship Model | Lateral Support |
|----------|-------------------|-----------------|
| 01-Flat Coordinator | None (flat) | N/A |
| 02-Actor Model | Message passing | Yes (any-to-any) |
| 04-Supervisor Trees | Tree hierarchy | No (through supervisor) |
| 06-Blackboard | Shared state | Yes (implicit) |
| 08-Work Stealing Pool | Pool membership | Limited |

The graph-based approach most closely resembles the **Actor Model** (02) but differs in that edges are explicit, named, and queryable rather than implicit in message addresses. It also differs from **Blackboard** (06) in that communication is direct rather than mediated through shared state.


## 2. Graphs vs Trees: Architectural Implications


### 2.1 Tree Model Constraints

In a strict tree:
- Every agent except Jake has exactly one parent
- Communication flows up (to parent) or down (to children)
- Siblings cannot communicate directly
- Lateral collaboration requires routing through common ancestor

Example: Agent A1 wants to message sibling A2:
```
Tree path: A1 -> Parent A -> A2
```

This creates several problems:
1. Parent A must understand/route all sibling messages
2. Parent A becomes a bottleneck
3. Latency doubles for lateral communication
4. Parent A's failure blocks sibling communication


### 2.2 Graph Model Flexibility

In a graph:
- Agents can have multiple connections with different semantics
- Communication flows along edges of any type
- Lateral connections are first-class
- Jake is the hub (most connected) rather than root

Example: Agent A1 messages sibling A2:
```
Graph path: A1 -> A2 (direct collaboration edge)
```

But supervision still works:
```
Supervision path: A1 -> Parent A (supervision edge)
```


### 2.3 The Key Insight

**Trees are graphs with constraints.** A tree is a connected acyclic graph where each node has at most one incoming edge from a "parent."

This means:
- Graph infrastructure subsumes tree infrastructure
- Tree semantics can be enforced via edge-type rules
- Graphs provide flexibility without losing tree benefits

The question is not "tree or graph?" but "which constraints do we enforce?"


## 3. Mapping to PRD Requirements


### 3.1 Bubbling (PRD Section 5.3)

**Requirement:** Messages can bubble upward, laterally, or directly to user.

**Graph Solution:** Different edge types with different bubbling semantics:

```swift
enum EdgeType {
    case supervision   // Parent-child, bubbles up
    case collaboration // Peer-to-peer, direct
    case observation   // One-way monitoring
    case userDirect    // Agent to user (with oversight)
}
```

Bubbling algorithm:
1. Check if target is directly connected
2. If yes, use direct edge
3. If no, traverse supervision edges upward until target is reachable
4. Apply oversight rules based on edge type


### 3.2 Agent Spawning (PRD Section 6.2)

**Requirement:** Parent specifies spawn configuration.

**Graph Solution:** Spawning creates a supervision edge:

```swift
func spawn(assignment: String, parent: Agent) -> MortalAgent {
    let agent = createAgent(assignment)
    graph.addEdge(from: parent.id, to: agent.id, type: .supervision)
    return agent
}
```

The parent concept is preserved but encoded as an edge rather than a field.


### 3.3 Lateral Collaboration (PRD Section 5.3, Reader Section 9)

**Requirement:** Siblings can message each other for collaboration.

**Graph Solution:** Collaboration edges can be created dynamically:

```swift
func enableCollaboration(between a: Agent, and b: Agent) {
    graph.addEdge(from: a.id, to: b.id, type: .collaboration)
    graph.addEdge(from: b.id, to: a.id, type: .collaboration)
}
```


### 3.4 Jake as Coordinator (PRD Section 4.1)

**Requirement:** Jake oversees all agents.

**Graph Solution:** Jake has edges to all top-level mortals. His special status comes from connectivity, not position:

```swift
// Jake's edge count is always >= all other agents
// He can reach any agent in at most 2 hops
```


### 3.5 Observation Patterns (Reader Section 8 "Discovery Sharing")

**Requirement:** Agents notice oddities and share them.

**Graph Solution:** One-way observation edges:

```swift
// Drone observes architect's work for oddities
graph.addEdge(from: drone.id, to: architect.id, type: .observation)
```


## 4. Trade-offs Considered


### 4.1 Simplicity vs Expressiveness

**Tree:** Simpler model, easier to visualize, deterministic routing
**Graph:** More expressive, handles all PRD cases, but more complex

**Decision:** The PRD explicitly requires lateral messaging. Trees cannot model this cleanly. The added complexity is necessary.


### 4.2 Explicit vs Implicit Topology

**Explicit (chosen):** Edges are data structures, queryable, visualizable
**Implicit:** Agents just send messages to known names

**Decision:** Explicit topology enables:
- Visualization of agent relationships
- Permission enforcement at edge creation
- Routing algorithm inspection
- Topology-based scheduling decisions


### 4.3 Static vs Dynamic Edges

**Static:** Edges defined at spawn, immutable
**Dynamic:** Edges can be added/removed at runtime

**Decision:** Dynamic. The PRD describes agents forming collaboration relationships during work. These emerge and dissolve based on task needs.


### 4.4 Typed vs Untyped Edges

**Typed (chosen):** Each edge has a semantic type (supervision, collaboration, etc.)
**Untyped:** All edges are equivalent

**Decision:** Types enable different routing/permission rules per relationship type. A supervision edge implies responsibility; a collaboration edge implies equality.


## 5. Implementation Complexity Analysis


### 5.1 Data Structures

Core graph representation:

```swift
struct AgentGraph {
    var nodes: [UUID: AnyAgent]
    var edges: [UUID: [Edge]]  // Adjacency list

    struct Edge: Hashable {
        let target: UUID
        let type: EdgeType
        let permissions: EdgePermissions
    }
}
```

**Complexity:**
- Node lookup: O(1)
- Edge enumeration for node: O(degree)
- Path finding: O(V + E) with BFS/DFS
- Cycle detection: O(V + E)

For expected scale (dozens of agents), these are negligible.


### 5.2 Routing Algorithm

Message routing requires path finding:

```swift
func route(from source: UUID, to target: UUID, via: EdgeType?) -> [UUID]? {
    // BFS respecting edge type constraints
    var queue: [(UUID, [UUID])] = [(source, [source])]
    var visited: Set<UUID> = []

    while let (current, path) = queue.first {
        queue.removeFirst()
        if current == target { return path }
        if visited.contains(current) { continue }
        visited.insert(current)

        for edge in edges[current] ?? [] {
            if via == nil || edge.type == via {
                queue.append((edge.target, path + [edge.target]))
            }
        }
    }
    return nil
}
```


### 5.3 Cycle Detection

To prevent infinite message loops:

```swift
func hasCycle(from node: UUID, following: EdgeType) -> Bool {
    var visited: Set<UUID> = []
    var stack: Set<UUID> = []
    return dfs(node, &visited, &stack, following)
}
```

This must run on edge creation to reject cycles.


### 5.4 Permission Enforcement

Each edge carries permissions:

```swift
struct EdgePermissions: OptionSet {
    let rawValue: Int
    static let send = EdgePermissions(rawValue: 1 << 0)
    static let receive = EdgePermissions(rawValue: 1 << 1)
    static let observe = EdgePermissions(rawValue: 1 << 2)
    static let supervise = EdgePermissions(rawValue: 1 << 3)
}
```


## 6. Migration Path from Current State


### 6.1 Phase 1: Add Graph Infrastructure (Non-Breaking)

Create `AgentGraph` alongside existing `AgentRegistry`:

```swift
public final class AgentGraph {
    private let registry: AgentRegistry  // Delegate node storage
    private var edges: [UUID: [Edge]] = [:]

    // Registry passthrough methods
    func agent(id: UUID) -> AnyAgent? { registry.agent(id: id) }

    // New graph methods
    func addEdge(from: UUID, to: UUID, type: EdgeType) { ... }
    func edges(from: UUID) -> [Edge] { ... }
}
```


### 6.2 Phase 2: Integrate with Spawner

Modify `AgentSpawner` to create supervision edges:

```swift
func spawn(assignment: String, parent: Agent? = nil) throws -> MortalAgent {
    let agent = try createAndRegister(assignment)
    if let parent = parent {
        graph.addEdge(from: parent.id, to: agent.id, type: .supervision)
    } else {
        // Top-level mortal, supervised by Jake
        graph.addEdge(from: jake.id, to: agent.id, type: .supervision)
    }
    return agent
}
```


### 6.3 Phase 3: Implement Messaging

Add message routing that uses graph topology:

```swift
extension AgentGraph {
    func send(_ message: AgentMessage, from: UUID, to: UUID) async throws {
        guard let path = route(from: from, to: to) else {
            throw GraphError.noPath(from: from, to: to)
        }
        // Route through intermediaries or deliver directly
        if path.count == 2 {
            try await deliverDirect(message, to: to)
        } else {
            try await routeThrough(message, path: path)
        }
    }
}
```


### 6.4 Phase 4: Enable Dynamic Edges

Allow agents to request collaboration connections:

```swift
// Agent A requests collaboration with Agent B
// Requires parent approval or Jake oversight
func requestCollaboration(from: UUID, to: UUID) async throws {
    let supervisor = closestCommonSupervisor(from, to)
    let approved = await supervisor.approveCollaboration(from, to)
    if approved {
        graph.addEdge(from: from, to: to, type: .collaboration)
        graph.addEdge(from: to, to: from, type: .collaboration)
    }
}
```


## 7. Open Questions


### 7.1 Edge Lifecycle

When should edges be removed?
- When an agent is dismissed? (Yes, clearly)
- When a task completes? (Maybe - collaboration edges?)
- When an agent enters hibernation? (Probably not)

**Tentative answer:** Supervision edges die with the supervised agent. Collaboration edges have explicit lifetimes tied to task scope.


### 7.2 Message Guarantees

What delivery guarantees do edges provide?
- At-least-once?
- At-most-once?
- Exactly-once?

**Tentative answer:** At-least-once with idempotency requirements on receivers. The DocStore backing provides durability.


### 7.3 Graph Persistence

Should the graph topology persist across app restarts?
- Session IDs persist for Jake (per-project)
- Agent sessions persist (UserDefaults)
- But agent instances don't survive restart

**Tentative answer:** Graph topology persists to DocStore as part of agent node documents. On restart, graph is reconstructed from persisted nodes.


### 7.4 Visualization

How do we display the graph in UI?
- Force-directed layout?
- Hierarchical layout (preserving tree-like appearance where applicable)?
- Custom layout based on agent types?

**Tentative answer:** Default to hierarchical layout based on supervision edges. Show collaboration edges as additional connections. User can switch to force-directed view.


### 7.5 Cycle Handling

What happens when cycles would be useful?
- A observes B, B observes C, C observes A (monitoring ring)
- This is a cycle but semantically valid for observation

**Tentative answer:** Cycle prevention applies only to message-routing edges. Observation edges (one-way, no message replies expected) can form cycles.


## 8. Comparison with Other Proposals


### 8.1 vs Supervisor Trees (04)

**Supervisor Trees** enforce strict hierarchy with restart semantics. Graphs subsume this:
- Supervision edges = supervisor-child relationships
- Restart policies attach to supervision edges
- But lateral collaboration is impossible in pure supervisor trees

**When to prefer Supervisor Trees:** If "let it crash" reliability is paramount and lateral messaging is not needed.


### 8.2 vs Blackboard (06)

**Blackboard** uses shared state for implicit communication. Graphs use explicit channels:
- Blackboard: Agents write to shared regions, others observe changes
- Graph: Agents send messages through explicit edges

**When to prefer Blackboard:** If discovery/emergent collaboration is more important than explicit coordination.


### 8.3 vs Actor Model (02)

**Actor Model** allows any-to-any messaging by address. Graphs add structure:
- Actor Model: Any actor can send to any address
- Graph: Messaging requires explicit edge (or edge creation)

**When to prefer Actor Model:** If fully dynamic, unconstrained messaging is desired. Graphs are actors with guardrails.


## 9. Recommendation

The graph-based architecture is well-suited for Tavern because:

1. **PRD mandates it** -- Lateral messaging, flexible bubbling, and direct-to-user patterns require non-tree structure

2. **Current code is compatible** -- `AgentRegistry` is already flat; adding edges is additive

3. **Typed edges provide flexibility with safety** -- Different relationship semantics without abandoning structure

4. **Migration is incremental** -- Can be built in phases without breaking existing functionality

5. **Subsumes tree semantics** -- Supervision edges recreate hierarchy where needed

The main risk is **complexity creep** -- graphs can model anything, which means they can become anything. Mitigation: strict edge type definitions, cycle prevention for routing edges, and clear documentation of permitted topologies.


## 10. Summary

| Aspect | Current State | Graph Proposal |
|--------|---------------|----------------|
| Agent storage | Flat dictionary | Nodes in graph |
| Relationships | Implicit (none stored) | Explicit typed edges |
| Communication | None implemented | Edge-based routing |
| Hierarchy | Conceptual only | Supervision edges |
| Lateral messaging | Not possible | Collaboration edges |
| Observation | Not possible | Observation edges |
| Complexity | Low | Medium |
| PRD alignment | Partial | Full |

The graph-based architecture provides the expressive power needed for Tavern's multi-directional communication requirements while maintaining structural clarity through typed edges and explicit topology.
