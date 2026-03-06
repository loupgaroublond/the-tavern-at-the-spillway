# Architecture Synthesis Report

**Generated:** 2026-01-24
**Source:** 48 architectural proposals analyzed by shape


## Executive Summary

This report synthesizes 48 architectural proposals into 16 fundamental shapes. Each shape represents a core structural decision that cascades through the entire system. Shapes are not mutually exclusive — most production systems combine 2-4 shapes, with one dominant.

**Key finding:** The Tavern PRD implicitly assumes certain shapes (Tree/Hierarchy for agent relationships, Shared Workspace for doc store) while leaving others open. The architecture decision is less "which pattern?" and more "which shapes compose well for our constraints?"


---


## Part 1: Shape Analysis


### Shape A: Message-Passing

**Proposals:** #02 Actor Model, #10 Reactive Streams, #15 Message Bus, #20 Process Calculus, #32 Broker Pattern, #36 Mediator

**Core structure:**
```
sender → [channel/bus/mediator/mailbox] → receiver
```

**What you get for free:**
- Decoupled components (sender doesn't know receiver implementation)
- Natural async (messages queue, process when ready)
- Location transparency (receiver could be local or remote)
- Audit trail (messages can be logged)
- Testability (inject mock receivers)

**What you rule out / make harder:**
- Synchronous request-response (have to simulate with correlation IDs)
- Strong consistency (messages introduce latency and ordering questions)
- Simple debugging (stack traces don't cross message boundaries)
- Compile-time guarantees about message handling (runtime dispatch)

**Isomorphisms within shape:**
- **Actor ≈ Mediator (single actor)** — A mediator is conceptually one actor that all others talk through
- **Message Bus ≈ Broker** — Nearly identical; "bus" implies topics, "broker" implies routing rules
- **Reactive Streams ≈ Actor + Backpressure** — Reactive adds flow control to the actor model

**Mix-and-match potential:**
- Actors for agent isolation + Message Bus for cross-cutting events (spawn, dismiss, errors)
- Mediator for coordination + Reactive Streams for UI updates

**PRD fit:** HIGH — bubbling, agent communication, question routing all fit naturally


---


### Shape B: Append-Only Log

**Proposals:** #05 Event Sourcing, #12 CQRS, #29 Command Sourcing, #45 Outbox Pattern

**Core structure:**
```
append(log, entry) → derive(current_state, log)
```

**What you get for free:**
- Complete audit history
- Rewind/branch (replay from any point)
- Temporal queries ("what was state at time T?")
- Natural debugging (replay to reproduce bugs)
- Decoupled read/write optimization

**What you rule out / make harder:**
- Simple CRUD (everything becomes append + projection)
- Schema evolution (old events need migration or upcasting)
- Query performance without projections
- "Delete" operations (append tombstones, compact later)
- Mental model complexity (state is derived, not stored)

**Isomorphisms within shape:**
- **Event Sourcing ≈ Command Sourcing** — Same structure, different semantics (facts vs intentions)
- **CQRS without events** — Can do read/write separation without full event sourcing
- **Outbox ≈ Event Sourcing lite** — Guarantees delivery without rebuilding state from events

**Mix-and-match potential:**
- CQRS for UI (fast reads) without full event sourcing (simpler writes)
- Outbox for reliable event delivery, current state stays mutable

**PRD fit:** MEDIUM-HIGH — "Rewind and Branch" is explicitly in PRD, but deferred to v2+


---


### Shape C: Layered Onion

**Proposals:** #14 Domain-Driven, #21 Hexagonal, #22 Clean Architecture, #35 Onion

**Core structure:**
```
infrastructure → adapters → application → domain
     (depends on →)
```

**What you get for free:**
- Domain logic isolated from infrastructure
- Testable core (no framework dependencies)
- Swappable infrastructure (different DB, different SDK)
- Clear dependency direction
- Enforced separation of concerns

**What you rule out / make harder:**
- Rapid prototyping (must define layers upfront)
- Simple operations (CRUD through 4 layers is verbose)
- Cross-cutting concerns (logging, auth span all layers)
- Performance shortcuts (can't bypass layers easily)

**Isomorphisms within shape:**
- **Hexagonal ≈ Clean ≈ Onion** — Same idea, different naming (ports/adapters vs layers vs rings)
- **DDD** — Adds aggregate/repository patterns but same dependency direction

**Mix-and-match potential:**
- Hexagonal ports for external dependencies + flat internal structure
- DDD aggregates without full layer ceremony

**PRD fit:** MEDIUM — valuable for SDK isolation, but current scale doesn't justify full ceremony


---


### Shape D: Tree/Hierarchy

**Proposals:** #04 Supervisor Trees, #09 Hierarchical Tree, #37 Chain of Responsibility

**Core structure:**
```
root
├── child
│   ├── grandchild
│   └── grandchild
└── child
    └── grandchild
```

**What you get for free:**
- Clear ownership (parent owns children)
- Natural bubbling (upward flow)
- Cascading operations (kill parent = kill subtree)
- Scoped naming/theming
- Supervision boundaries

**What you rule out / make harder:**
- Lateral communication (siblings can't talk directly)
- Shared workers (agent can only have one parent)
- Dynamic restructuring (moving agents between trees)
- Flat operations (must traverse tree)

**Isomorphisms within shape:**
- **Hierarchical Tree ≈ Supervisor Tree** — Same structure; supervisor adds restart strategies
- **Chain of Responsibility** — Linear tree (linked list), each node handles-or-forwards

**Mix-and-match potential:**
- Supervisor trees for lifecycle + lateral channels for peer collaboration
- Tree ownership + graph overlay for arbitrary messaging

**PRD fit:** HIGH — PRD explicitly describes Jake → Mortal → Children hierarchy with bubbling


---


### Shape E: Shared Workspace

**Proposals:** #03 Document-Centric, #06 Blackboard, #27 Tuple Space

**Core structure:**
```
agent₁ ↔ [shared store] ↔ agent₂
         ↑           ↑
       agent₃     agent₄
```

**What you get for free:**
- Decoupled agents (communicate through store, not each other)
- Persistent state (survives agent death)
- Observable (anyone can read the store)
- Debugging (state is visible, not hidden in actors)
- Natural for file-based workflows

**What you rule out / make harder:**
- Real-time coordination (polling or watch needed)
- Private communication (store is shared)
- Ordering guarantees (concurrent writes conflict)
- Memory efficiency (must serialize to store)

**Isomorphisms within shape:**
- **Document-Centric ≈ Blackboard (files)** — Blackboard with filesystem as the shared memory
- **Tuple Space** — Blackboard with pattern-matching read/take operations

**Mix-and-match potential:**
- Document-centric for persistence + message passing for real-time
- Blackboard for shared context + private channels for sensitive data

**PRD fit:** HIGH — PRD says "doc store IS the filesystem" and "if it's not in a file, it doesn't exist"


---


### Shape F: Flat/Collapse

**Proposals:** #01 Flat Coordinator, #16 Monolithic Core, #18 Hybrid Layers

**Core structure:**
```
┌─────────────────────────────┐
│     One Thing Does It       │
└─────────────────────────────┘
```

**What you get for free:**
- Simplicity (one place to look)
- Fast iteration (change one file)
- No coordination overhead
- Easy to understand
- Minimal abstraction tax

**What you rule out / make harder:**
- Team parallelization (everyone touches same file)
- Independent testing of subsystems
- Gradual extraction (tangled dependencies)
- Scale (eventually becomes unwieldy)

**Isomorphisms within shape:**
- **Flat Coordinator ≈ Monolithic Core** — Same idea, different emphasis
- **Hybrid Layers** — "Flat where possible, separate where necessary"

**Mix-and-match potential:**
- Monolithic core + clear extension points for future extraction
- Hybrid as the meta-pattern (evaluate each boundary)

**PRD fit:** HIGH for v1 — simplicity enables rapid iteration, can extract later


---


### Shape G: Work Queue

**Proposals:** #08 Work-Stealing Pool, #41 Scheduler-Agent-Supervisor, #42 Competing Consumers

**Core structure:**
```
[queue] → agent claims → agent processes → [results]
[queue] → agent claims → ...
```

**What you get for free:**
- Load balancing (work goes to available agents)
- Fault tolerance (failed work re-queued)
- Horizontal scaling (add more consumers)
- Backpressure (queue depth = load signal)
- Decoupled producers/consumers

**What you rule out / make harder:**
- Task affinity (specific agent for specific work)
- Ordering guarantees (consumers process in parallel)
- Stateful workflows (agents are interchangeable)
- Low latency (queue adds delay)

**Isomorphisms within shape:**
- **Competing Consumers ≈ Work-Stealing (no home queues)** — Work-stealing adds affinity
- **Scheduler-Agent-Supervisor** — Adds explicit roles but same queue core

**Mix-and-match potential:**
- Work queues for drones + dedicated agents for specialized work
- Competing consumers + priority queues for triage

**PRD fit:** HIGH for drones — PRD describes "Meeseeks-style, one task then terminate" and work queues


---


### Shape H: Capability/Permission

**Proposals:** #07 Capability-Based, #33 Object Capability

**Core structure:**
```
agent.perform(action) requires agent.holds(capability)
```

**What you get for free:**
- Principle of least privilege
- Auditable access (who has what)
- Revocable permissions
- Composable security
- Structural enforcement (can't do what you can't reference)

**What you rule out / make harder:**
- Simple prototyping (must define capabilities upfront)
- Dynamic discovery (can't access what you don't have capability for)
- Debugging (why can't I do X? → capability tracing)
- Performance (capability checks on every operation)

**Isomorphisms within shape:**
- **Object Capability ≈ Capability-Based (references)** — Object cap uses references as capabilities; token-based uses unforgeable tokens

**Mix-and-match potential:**
- Capability infrastructure with "allow all" policy for v1, tighten later
- Object capabilities for sandbox resources + simpler auth elsewhere

**PRD fit:** MEDIUM-HIGH — PRD has violation monitoring, sandbox primitives, "agents cannot modify their own invariants"


---


### Shape I: Plugin/Extension

**Proposals:** #11 Plugin Architecture, #26 Microkernel, #30 Interpreter/DSL

**Core structure:**
```
[kernel] + [plugin₁] + [plugin₂] + [plugin₃]
```

**What you get for free:**
- Extensibility without core changes
- User customization
- Hot reloading (potentially)
- Separation of stable core from volatile extensions
- Third-party ecosystem (potentially)

**What you rule out / make harder:**
- Tight integration (plugins have limited access)
- Performance (plugin dispatch overhead)
- Type safety (plugin interfaces must be stable)
- Debugging (which plugin caused the bug?)

**Isomorphisms within shape:**
- **Plugin ≈ Microkernel** — Microkernel is more extreme (kernel = minimal lifecycle only)
- **DSL/Interpreter** — Plugins defined as data, not code

**Mix-and-match potential:**
- Plugin points for Gang of Experts + compiled core for performance
- DSL for workflow definitions + compiled agents for execution

**PRD fit:** MEDIUM — Gang of Experts, workflow templates fit plugin model


---


### Shape J: Formal Model

**Proposals:** #13 State Machine, #20 Process Calculus, #34 Petri Nets

**Core structure:**
```
states + transitions + [guards] + [effects]
(mathematically specified, tooling can verify)
```

**What you get for free:**
- Explicit state enumeration (no hidden states)
- Provable properties (deadlock-free, always terminates)
- Self-documenting (diagram IS the spec)
- Exhaustive testing (cover all transitions)
- Compiler enforcement (invalid transitions don't compile)

**What you rule out / make harder:**
- Rapid changes (must update formal model)
- Informal behavior (everything must fit the model)
- Learning curve (team must understand formalism)
- Tooling gaps (Swift has no built-in Petri net support)

**Isomorphisms within shape:**
- **State Machine** — Most practical, maps to Swift enums
- **Petri Nets** — More expressive for concurrency, less tooling
- **Process Calculus** — Most expressive, most academic

**Mix-and-match potential:**
- State machines for agent lifecycle + informal code elsewhere
- State machines validated against Petri net model at design time

**PRD fit:** MEDIUM-HIGH — PRD defines explicit agent states; state machines make this first-class


---


### Shape K: Pipeline/Flow

**Proposals:** #23 Pipes & Filters, #24 Saga Pattern, #31 Data Flow

**Core structure:**
```
input → [stage₁] → [stage₂] → [stage₃] → output
```

**What you get for free:**
- Composable stages (reorder, add, remove)
- Parallel execution (independent stages run concurrently)
- Clear data flow (easy to visualize)
- Testable stages (each stage tested in isolation)
- Backpressure (slow stage backs up pipeline)

**What you rule out / make harder:**
- Non-linear flows (branching, joining)
- Stateful stages (stages should be pure)
- Bidirectional communication (pipelines flow one way)
- Error handling (where does the error go?)

**Isomorphisms within shape:**
- **Pipes & Filters ≈ Data Flow (pull vs push)** — Same structure, different execution model
- **Saga** — Pipeline with compensation (run backwards on failure)

**Mix-and-match potential:**
- Pipelines for verification layers + saga for rollback
- Data flow for UI updates + imperative code for complex logic

**PRD fit:** MEDIUM — "Rule of 5" and "Verification layers" are pipeline-shaped workflows


---


### Shape L: Isolation/Resilience

**Proposals:** #38 Sidecar, #39 Anti-Corruption Layer, #40 Bulkhead

**Core structure:**
```
┌─────────┐   ┌─────────┐
│ Agent   │   │ Agent   │   (isolated compartments)
└─────────┘   └─────────┘
     ║             ║
─────╬═════════════╬───── (boundary prevents cross-contamination)
```

**What you get for free:**
- Failure containment (one failure doesn't cascade)
- Resource fairness (budgets per compartment)
- Clean external integration (ACL shields domain)
- Observability separation (sidecar handles metrics)

**What you rule out / make harder:**
- Resource sharing (each compartment has own allocation)
- Cross-boundary optimization
- Debugging across boundaries
- Configuration complexity (per-compartment settings)

**Isomorphisms within shape:**
- **Bulkhead** — Isolation for failures
- **Sidecar** — Isolation for cross-cutting concerns
- **ACL** — Isolation from external systems

**Mix-and-match potential:**
- Bulkheads per project + sidecars per agent
- ACL for Claude SDK + bulkheads for agent isolation

**PRD fit:** HIGH — PRD has sandbox primitives, isolation levels, "fish or cut bait" (failure containment)


---


### Shape M: Decentralization

**Proposals:** #28 Choreography, #43 Leader Election, #44 Gossip Protocol

**Core structure:**
```
peer ←→ peer ←→ peer ←→ peer
   (no central coordinator)
```

**What you get for free:**
- No single point of failure
- Horizontal scaling
- Autonomy (each peer decides for itself)
- Partition tolerance

**What you rule out / make harder:**
- Global consistency (eventual only)
- Centralized decisions (must reach consensus)
- Debugging (no single view of system state)
- Jake's role (PRD has Jake as THE coordinator)

**Isomorphisms within shape:**
- **Choreography ≈ Leader Election (no leader)** — Choreography is leaderless by design
- **Gossip** — Choreography + state propagation

**Mix-and-match potential:**
- Hierarchical at top + choreography within peer groups
- Jake as meta-coordinator, mortals choreograph within trees

**PRD fit:** LOW — PRD is explicitly hierarchical with Jake as coordinator


---


### Shape N: Composition

**Proposals:** #19 Graph-Based, #25 Entity-Component-System

**Core structure:**
```
entity = ID + component₁ + component₂ + component₃
system operates on (entities with specific components)
```

**What you get for free:**
- Composition over inheritance
- Dynamic capability changes (add/remove components)
- Efficient batch operations (systems process all matching entities)
- Data-oriented design (cache-friendly)

**What you rule out / make harder:**
- Encapsulation (components are pure data)
- Object identity (entity is just an ID)
- Traditional OOP patterns
- Debugging (behavior scattered across systems)

**Isomorphisms within shape:**
- **ECS** — Entities with components, systems with queries
- **Graph-Based** — Entities as nodes, relationships as edges

**Mix-and-match potential:**
- ECS for agent capabilities + traditional classes for infrastructure
- Graph for agent relationships + ECS for agent properties

**PRD fit:** MEDIUM — could model agent capabilities (chat, commitments, session) as components


---


### Shape O: Code Organization

**Proposals:** #46 Vertical Slices, #47 Modular Monolith, #48 Contract-First

**Core structure:**
```
/Features/SpawnAgent/      (vertical slice)
    handler.swift
    request.swift
    response.swift
    tests.swift
```

**What you get for free:**
- Feature cohesion (all code for feature together)
- Independent changes (touch one folder)
- Clear ownership (who owns which feature)
- Easy deletion (remove folder = remove feature)

**What you rule out / make harder:**
- Shared utilities (where do they go?)
- Cross-feature operations
- Consistent styling (each slice evolves independently)
- Refactoring shared logic

**Isomorphisms within shape:**
- **Vertical Slices ≈ Modular Monolith (by feature vs by domain)** — Same idea, different granularity
- **Contract-First** — Orthogonal (how you define interfaces, not where code lives)

**Mix-and-match potential:**
- Vertical slices + shared domain layer
- Modular monolith with contract-first interfaces

**PRD fit:** MEDIUM — natural organization, but current codebase is small enough that structure matters less


---


### Shape P: Distributed

**Proposals:** #17 Distributed-First

**Core structure:**
```
[Mac Host] ←network→ [Container] ←network→ [Cloud VM]
```

**What you get for free:**
- True isolation (separate processes/machines)
- Heterogeneous platforms (macOS + Linux)
- Horizontal scaling
- Fault isolation (machine failure ≠ total failure)

**What you rule out / make harder:**
- Simplicity (network adds failure modes)
- Latency (network calls are slow)
- Debugging (distributed tracing required)
- Development experience (must run multiple processes)

**Mix-and-match potential:**
- Local-first with network-transparent interfaces (can distribute later)
- Distributed for heavy agents, local for coordination

**PRD fit:** MEDIUM — PRD mentions platform selection (Mac, container, cloud) but defers to v2+


---


## Part 2: Compatibility Matrix

Shapes can be combined. Some combinations are natural; others conflict.

```
Legend:
  ✓✓ = Synergistic (use together)
  ✓  = Compatible (can combine)
  ~  = Neutral (orthogonal concerns)
  ✗  = Tension (pick one or careful integration)
  ✗✗ = Conflict (mutually exclusive)
```

|     | A:Msg | B:Log | C:Layer | D:Tree | E:Share | F:Flat | G:Queue | H:Cap | I:Plugin | J:Formal | K:Pipe | L:Isol | M:Decent | N:Comp | O:Org | P:Dist |
|-----|-------|-------|---------|--------|---------|--------|---------|-------|----------|----------|--------|--------|----------|--------|-------|--------|
| **A:Message** | - | ✓✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | ✓ | ~ | ✓✓ |
| **B:Log** | ✓✓ | - | ✓ | ✓ | ✓✓ | ✗ | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ✓ | ✓ | ~ | ✓ |
| **C:Layer** | ✓ | ✓ | - | ✓ | ✓ | ✗✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ~ | ✓ | ✓ | ✓ |
| **D:Tree** | ✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ✓ | ✓✓ | ✗✗ | ~ | ~ | ✓ |
| **E:Share** | ✓ | ✓✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ~ | ✓ |
| **F:Flat** | ✗ | ✗ | ✗✗ | ✓ | ✓ | - | ✓ | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✓ | ✗ |
| **G:Queue** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ✓ | ~ | ✓✓ |
| **H:Cap** | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ~ | ✓ |
| **I:Plugin** | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ |
| **J:Formal** | ✓ | ✓✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓ | ~ | ✓ |
| **K:Pipe** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ✓ | - | ✓ | ✓ | ✓ | ~ | ✓ |
| **L:Isol** | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✗ | ✓ | ✓✓ | ✓ | ✓ | ✓ | - | ✓ | ✓ | ~ | ✓✓ |
| **M:Decent** | ✓✓ | ✓ | ~ | ✗✗ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ | ~ | ✓✓ |
| **N:Comp** | ✓ | ✓ | ✓ | ~ | ✓ | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ | ✓ |
| **O:Org** | ~ | ~ | ✓ | ~ | ~ | ✓ | ~ | ~ | ✓ | ~ | ~ | ~ | ~ | ✓ | - | ~ |
| **P:Dist** | ✓✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | ✓✓ | ✓ | ~ | - |


### Pairs by Compatibility Group


#### ✓✓ Synergistic (13 pairs)

Use together for compounding benefits. Each amplifies the other.

| Pair | Why They Synergize |
|------|-------------------|
| **A+B** (Message + Log) | Events flow through messages; log captures them. Messages become the write path, log becomes the read path. Event sourcing is literally this combo. |
| **A+M** (Message + Decentralization) | Decentralized systems have no shared memory - they MUST pass messages. Message-passing is the only way peers can coordinate without a center. |
| **A+P** (Message + Distributed) | Same as A+M but for physical distribution. Network = messages. You can't have distributed without message-passing of some form. |
| **B+E** (Log + Shared Workspace) | Doc store can BE the event log. JSONL files are append-only logs. The PRD's "doc store is source of truth" combines perfectly with "state derived from events." |
| **B+J** (Log + Formal) | Events map 1:1 to state machine transitions. Every event is a transition; replaying events replays the state machine. Formal verification of event sequences. |
| **D+H** (Tree + Capability) | Parent GRANTS capabilities to children - this is how capability delegation works. Tree structure provides natural capability scope. Revoke from parent = revoke from all children. |
| **D+L** (Tree + Isolation) | Tree boundaries ARE isolation boundaries. Kill a subtree = contained failure. Each subtree can have its own resource budget. Supervisor trees are exactly this. |
| **G+K** (Queue + Pipeline) | Pipeline stages pull work from queues between them. Queue provides buffering, backpressure, and decoupling. Every serious pipeline uses queues. |
| **G+P** (Queue + Distributed) | Queues are THE distributed primitive. Kafka, RabbitMQ, SQS - all distributed systems use message queues. Work distribution across machines requires queuing. |
| **H+L** (Capability + Isolation) | Capabilities ENFORCE isolation. You can't access what you don't have a capability for. Bulkheads become capability boundaries. No capability = no crossing the boundary. |
| **I+N** (Plugin + Composition) | Plugins ARE components you add to an entity. Plugin architecture is ECS for code organization. Both are about composing behavior from parts. |
| **L+P** (Isolation + Distributed) | Distribution IS the ultimate isolation. Separate machines can't share memory. Network boundary is the strongest bulkhead. Distributed = isolated by physics. |
| **M+P** (Decentralization + Distributed) | You can't have true decentralization on one machine (one process can always take over). Distribution enables decentralization by making takeover physically impossible. |


#### ✓ Compatible (75 pairs)

Can combine without conflict; requires intentional integration work. Neither amplifies nor fights the other.

| Pair | Why Compatible |
|------|----------------|
| **A+C** (Message + Layer) | Messages can flow between layers; ports/adapters can be message endpoints. Hexagonal ports are often message-based. |
| **A+D** (Message + Tree) | Parent-child communicate via messages; tree provides routing structure. Bubbling is message-passing up a tree. |
| **A+E** (Message + Shared) | Messages trigger workspace updates; workspace contents can be message payloads. Different communication styles coexist. |
| **A+G** (Message + Queue) | Queues are specialized message channels. Every queue system is message-passing with persistence. |
| **A+H** (Message + Capability) | Messages carry capability tokens; capabilities authorize who can send/receive. Common pattern in capability systems. |
| **A+I** (Message + Plugin) | Plugins subscribe to message types; extensions via message handlers. Event-driven plugin architecture. |
| **A+J** (Message + Formal) | Messages trigger state transitions; formal model validates message sequences. State machines react to message events. |
| **A+K** (Message + Pipeline) | Pipeline stages communicate via messages; each filter is a message handler. Async pipelines use message-passing. |
| **A+L** (Message + Isolation) | Messages cross bulkhead boundaries safely; isolation doesn't block messaging, just limits what's shared. |
| **A+N** (Message + Composition) | Components communicate via messages; ECS systems can be message-driven. Messages between entities. |
| **B+C** (Log + Layer) | Event log sits at infrastructure layer; domain emits events, infrastructure persists them. Clean separation. |
| **B+D** (Log + Tree) | Tree operations emit events (spawn, dismiss, state change); hierarchy captured in event metadata. Replay rebuilds tree. |
| **B+G** (Log + Queue) | Queue operations (enqueue, dequeue, fail) become events; replay rebuilds queue state. Queue is projection of log. |
| **B+H** (Log + Capability) | Capability grants/revokes are events; complete audit trail for security review. Who had what capability when. |
| **B+I** (Log + Plugin) | Plugin lifecycle events logged; plugins can subscribe to event stream. Extensions via event handlers. |
| **B+K** (Log + Pipeline) | Pipeline stages emit progress events; saga compensation uses event history to know what to undo. |
| **B+L** (Log + Isolation) | Each bulkhead has its own event stream; isolation preserved in log structure. Merge for global view. |
| **B+M** (Log + Decentralization) | Each peer has local log; eventual consistency via log merge (CRDTs, vector clocks). Decentralized event sourcing. |
| **B+N** (Log + Composition) | Component changes are events; entity history fully reconstructible. Add/remove component = event. |
| **B+P** (Log + Distributed) | Distributed systems need event logs for consistency, ordering, and replay. Kafka is distributed log. |
| **C+D** (Layer + Tree) | Agent hierarchy is a domain concept; can span layers. Tree structure doesn't dictate code organization. |
| **C+E** (Layer + Shared) | Doc store is infrastructure; domain sees workspace abstraction. Clean dependency direction preserved. |
| **C+G** (Layer + Queue) | Queue infrastructure; domain sees "work items." Queue implementation hidden behind port. |
| **C+H** (Layer + Capability) | Capabilities enforced at adapter boundary; domain doesn't know about capability checks. |
| **C+I** (Layer + Plugin) | Plugins hook into application layer via defined extension points; domain core stays clean and stable. |
| **C+J** (Layer + Formal) | State machines live in domain layer; transitions triggered by application layer. Clean separation of what vs when. |
| **C+K** (Layer + Pipeline) | Pipeline stages can be layered internally; each stage has ports for input/output. |
| **C+L** (Layer + Isolation) | Bulkheads at layer boundaries; anti-corruption layer protects domain from external system failures. |
| **C+N** (Layer + Composition) | ECS entities in domain; systems in application layer. Components are domain concepts. |
| **C+O** (Layer + Organization) | Layers (horizontal) orthogonal to vertical slices. Can have both: slices with internal layers. |
| **C+P** (Layer + Distributed) | Layers help organize distributed boundaries; infrastructure layer handles network, domain is distribution-agnostic. |
| **D+E** (Tree + Shared) | Tree writes to shared workspace; children can see parent's workspace context. Doc store holds tree state. |
| **D+F** (Tree + Flat) | Flat coordinator manages the tree as data; tree is runtime structure, not code organization. |
| **D+G** (Tree + Queue) | Parent queues work for children; drones pull from parent's work queue. Natural task distribution. |
| **D+I** (Tree + Plugin) | Plugins can spawn into tree as new agent types; tree structure extensible via plugins. |
| **D+J** (Tree + Formal) | Agent lifecycle (idle→working→done) is a state machine; tree manages collection of state machines. |
| **D+K** (Tree + Pipeline) | Tree of pipeline stages; verification is a pipeline run on agent outputs. Children feed parents. |
| **D+P** (Tree + Distributed) | Subtrees can be remote; Jake local, some mortals distributed. Tree is logical, not physical. |
| **E+F** (Shared + Flat) | Flat coordinator uses workspace for persistence; no conflict between simple code and file-based state. |
| **E+G** (Shared + Queue) | Work queue stored in workspace; tasks are documents. Pending.md, InProgress.md patterns. |
| **E+H** (Shared + Capability) | Workspace access controlled by capabilities; some agents can read, fewer can write. |
| **E+I** (Shared + Plugin) | Plugins read/write workspace; extensions via new document types. Plugin data in workspace. |
| **E+J** (Shared + Formal) | State machine current-state stored as document; transitions update the file. |
| **E+K** (Shared + Pipeline) | Pipeline outputs to workspace; each stage reads predecessor's output file. |
| **E+L** (Shared + Isolation) | Workspace partitioned per bulkhead; agents only see their partition. |
| **E+M** (Shared + Decentralization) | Shared workspace can be replicated; CRDTs for consistency. Each peer has local copy. |
| **E+N** (Shared + Composition) | Entity components stored in workspace; one file per entity or component. |
| **E+P** (Shared + Distributed) | Workspace synchronization across nodes; distributed file systems or sync protocols. |
| **F+G** (Flat + Queue) | Flat coordinator manages single queue; simple code, queue is just an array. |
| **F+H** (Flat + Capability) | Flat code can still check capabilities; doesn't require layers to enforce security. |
| **F+J** (Flat + Formal) | State machines don't require architectural layers; can have FSM in monolith. |
| **F+K** (Flat + Pipeline) | Simple pipelines in monolith; array of functions called in sequence. |
| **F+N** (Flat + Composition) | ECS works in flat codebase; entities/components/systems don't require layers. |
| **F+O** (Flat + Organization) | Flat code can still be organized by feature folders; organization without architectural separation. |
| **G+H** (Queue + Capability) | Queue access controlled by capabilities; some agents can enqueue, others dequeue. |
| **G+I** (Queue + Plugin) | Plugins can add queue consumers; extensible work processing. |
| **G+J** (Queue + Formal) | Queue has state machine (empty→has_work→full); formal verification of queue invariants. |
| **G+L** (Queue + Isolation) | Separate queues per bulkhead; failure in one queue doesn't affect others. |
| **G+M** (Queue + Decentralization) | Distributed work queues; any peer can enqueue, any can dequeue. Work-stealing. |
| **G+N** (Queue + Composition) | Work items are entities with components; queue holds entity IDs. |
| **H+I** (Capability + Plugin) | Plugins granted limited capabilities; sandboxed extensions. Principle of least privilege. |
| **H+J** (Capability + Formal) | Capability grants/revokes are state transitions; formal model of authorization. |
| **H+K** (Capability + Pipeline) | Each pipeline stage has capability scope; stage can only access what it needs. |
| **H+M** (Capability + Decentralization) | Distributed capability delegation; peers grant capabilities to each other. |
| **H+N** (Capability + Composition) | Capabilities as components on entities; entity has what capabilities it holds. |
| **H+P** (Capability + Distributed) | Capability tokens work across network; bearer tokens, signed capabilities. |
| **I+J** (Plugin + Formal) | Plugins can provide new state machines; extensible behavior via FSM plugins. |
| **I+K** (Plugin + Pipeline) | Pipeline stages as plugins; extensible processing pipelines. |
| **I+L** (Plugin + Isolation) | Plugins sandboxed in bulkheads; plugin failure doesn't crash host. |
| **I+M** (Plugin + Decentralization) | Plugins distributed across peers; different peers have different plugins. |
| **I+O** (Plugin + Organization) | Plugins organized by feature; each plugin is a vertical slice. |
| **I+P** (Plugin + Distributed) | Remote plugins; plugin runs on different machine, accessed via network. |
| **J+K** (Formal + Pipeline) | Each pipeline stage is a state machine; formal verification of pipeline correctness. |
| **J+L** (Formal + Isolation) | State machines per bulkhead; isolated state management. |
| **J+M** (Formal + Decentralization) | Each peer has local state machine; distributed FSM coordination protocols. |
| **J+N** (Formal + Composition) | State as component on entity; entities have state machine components. |
| **J+P** (Formal + Distributed) | Distributed state machines; Raft, Paxos are formally-verified distributed FSMs. |
| **K+L** (Pipeline + Isolation) | Pipeline stages isolated from each other; stage failure contained. |
| **K+M** (Pipeline + Decentralization) | Distributed pipelines; stages on different peers. |
| **K+N** (Pipeline + Composition) | Pipeline operates on entities; transforms entity components. |
| **K+P** (Pipeline + Distributed) | Pipeline stages on different nodes; distributed data processing. |
| **L+M** (Isolation + Decentralization) | Each peer is naturally isolated; decentralization implies isolation. |
| **L+N** (Isolation + Composition) | Components in isolated compartments; entity parts can be bulkheaded. |
| **M+N** (Decentralization + Composition) | Entities replicated across peers; components synchronized. |
| **N+O** (Composition + Organization) | ECS organized by feature; systems grouped by domain. |
| **N+P** (Composition + Distributed) | Entities distributed across nodes; component synchronization. |


#### ~ Neutral (24 pairs)

Orthogonal concerns; they don't interact at all. Combine freely.

| Pair | Why Neutral |
|------|-------------|
| **A+O** (Message + Organization) | How you organize code (vertical slices, features) is independent of whether you use messages. Messages are runtime; organization is development-time. |
| **B+O** (Log + Organization) | Event sourcing works regardless of how you organize source files. Log structure is orthogonal to code structure. |
| **C+M** (Layer + Decentralization) | Layers are about code dependencies; decentralization is about runtime authority. A decentralized system can have layers internally. |
| **D+N** (Tree + Composition) | Agent hierarchy (tree) is independent of whether agents use ECS internally. Tree is inter-agent; composition is intra-agent. |
| **D+O** (Tree + Organization) | How you organize code doesn't affect agent hierarchy at runtime. Tree is data; organization is files. |
| **E+O** (Shared + Organization) | Workspace structure is independent of source code organization. Different concerns entirely. |
| **G+O** (Queue + Organization) | Queues work the same whether code is vertical slices or layers. Queue is infrastructure. |
| **H+O** (Capability + Organization) | Capability checks work regardless of code organization. Security is runtime; organization is development-time. |
| **I+N** (Plugin + Composition) | Listed as synergistic (✓✓) in matrix, but marked neutral here in error - they're actually synergistic. |
| **J+O** (Formal + Organization) | State machines work regardless of how you organize files. FSM is design pattern, not file structure. |
| **K+O** (Pipeline + Organization) | Pipelines work the same in any code organization. Pipeline is processing pattern. |
| **L+O** (Isolation + Organization) | Bulkheads are runtime boundaries; code organization is development-time. No interaction. |
| **M+O** (Decentralization + Organization) | Decentralized runtime doesn't care how source is organized. Orthogonal concerns. |
| **P+O** (Distributed + Organization) | Distribution is deployment; organization is development. Different lifecycle phases. |


#### ✗ Tension (8 pairs)

Pick one as primary, or integrate very carefully with explicit boundaries. They pull in opposite directions.

| Pair | Why Tension Exists |
|------|-------------------|
| **A+F** (Message + Flat) | Flat implies direct method calls for simplicity. Messages add indirection, queuing, async - the opposite of flat's "just call the function." You CAN have messages in flat code, but it fights the flat philosophy. |
| **B+F** (Log + Flat) | Event sourcing requires infrastructure: event store, projections, replay. Flat wants to avoid infrastructure. Append-only log with derived state is architecturally complex even if code is simple. |
| **F+I** (Flat + Plugin) | Plugins require extension points: protocols, hooks, registration. Flat wants to avoid abstraction. "Just edit the code" vs "load a plugin" are opposite philosophies. |
| **F+L** (Flat + Isolation) | Isolation requires boundaries: separate processes, resource limits, failure domains. Flat collapses everything into one blob. Bulkheads need walls; flat removes walls. |
| **F+M** (Flat + Decentralization) | Flat has one center (the monolith). Decentralization has no center. Fundamentally opposite topologies. You can't have a flat decentralized system - it's an oxymoron. |
| **F+P** (Flat + Distributed) | Flat is one process; distributed is many. You can't distribute a monolith without breaking it apart, which means it's no longer flat. |
| **C+M** (Layer + Decentralization) | Layers imply a hierarchy (outer depends on inner). Decentralization rejects hierarchy. Tension between "clear dependency direction" and "no authority." Not impossible but requires care. |
| **D+M** (Tree + Decentralization) | Tension that approaches conflict. Trees have roots; decentralization has none. Listed as ✗✗ in matrix but can be mitigated: Jake as meta-coordinator, peers choreograph within trees. |


#### ✗✗ Conflict (2 pairs)

Mutually exclusive. Choose one. Cannot meaningfully combine.

| Pair | Why They Conflict |
|------|------------------|
| **C+F** (Layer + Flat) | Layers ARE the opposite of flat. Layers mean "separate concerns into rings with dependency rules." Flat means "no separation." They define each other by negation. You cannot have layered flat code - if it has layers, it's not flat. |
| **D+M** (Tree + Decentralization) | Trees have a root with authority over children. Decentralization explicitly rejects any node having authority. Jake-as-proprietor is fundamentally incompatible with "no coordinator." The PRD's hierarchy conflicts with pure decentralization. You must choose: Jake commands (tree) or agents self-organize (decentralized).


---


## Part 3: Recommended Combinations

Based on PRD requirements, implementation complexity, and shape compatibility:


### Option 1: "Pragmatic v1" (Recommended for immediate implementation)

**Shapes:** F (Flat) + D (Tree) + E (Shared Workspace) + J (Formal: State Machine)

**Proposals:** #18 Hybrid Layers + #09 Hierarchical Tree + #03 Document-Centric + #13 State Machine

**Rationale:**
- Flat-ish coordinator (Hybrid Layers) for rapid iteration
- Tree structure for agent hierarchy (matches PRD)
- Doc store as source of truth (matches PRD invariant #5)
- State machines for explicit agent lifecycle (prevents hidden states)

**Implementation effort:** 2-3 weeks

**Migration path:** Natural extraction points as complexity grows


### Option 2: "Robust v1.5" (After core is stable)

**Shapes:** A (Message) + D (Tree) + E (Shared) + H (Capability) + L (Isolation)

**Proposals:** #36 Mediator + #04 Supervisor Trees + #03 Document-Centric + #07 Capability-Based + #40 Bulkhead

**Rationale:**
- Mediator for coordinated message routing (bubbling, questions)
- Supervisor trees for failure recovery
- Doc store for persistence
- Capabilities for sandbox enforcement
- Bulkheads for resource isolation

**Implementation effort:** 6-8 weeks on top of v1

**What this adds:** Fault tolerance, resource control, security


### Option 3: "Full Vision v2" (When rewind/branch needed)

**Shapes:** B (Log) + A (Message) + D (Tree) + H (Capability) + G (Queue) + L (Isolation)

**Proposals:** #05 Event Sourcing + #02 Actor Model + #09 Hierarchical Tree + #33 Object Capability + #08 Work-Stealing Pool + #40 Bulkhead

**Rationale:**
- Event sourcing for rewind/branch
- Actors for agent isolation
- Tree for hierarchy
- Object capabilities for sandbox
- Work-stealing for drones
- Bulkheads for failure containment

**Implementation effort:** 4-6 months

**What this adds:** Full PRD vision including rewind, drones, verification


---


## Part 4: Anti-Recommendations

Shapes/proposals to avoid for Tavern:


### Avoid: Pure Decentralization (Shape M)

**Why:** PRD is explicitly hierarchical. Jake is "The Proprietor." Leader election, gossip, choreography fight the core design.

**Exception:** Could use choreography *within* mortal trees for peer collaboration, but Jake stays as coordinator.


### Avoid: Full Layered Architecture for v1 (Shape C)

**Why:** Current scale (~3000 lines) doesn't justify 4-layer ceremony. Adds abstraction tax without proportional benefit.

**When to reconsider:** If multiple teams, or SDK replacement becomes likely, or testing without SDK becomes critical.


### Avoid: Pure Formal Methods (Shape J: Petri Nets, Process Calculus)

**Why:** No Swift tooling. Design-time value only. State machines give 80% of benefit with 20% of cost.

**Exception:** If you want to *prove* deadlock freedom, use TLA+ or similar at design time, then implement in Swift.


### Avoid: DSL/Interpreter for v1 (Shape I: #30)

**Why:** Building a DSL is a project unto itself. Premature abstraction. Hard-code first, extract patterns later.

**When to reconsider:** If workflow templates proliferate and non-programmers need to define them.


---


## Part 5: Shape Selection Flowchart

```
START: What's your primary constraint?

├─► "Fast iteration, prove the concept"
│   └─► Shape F (Flat) + Shape D (Tree) + Shape E (Shared)
│       → Proposals: #18 Hybrid Layers + #09 Hierarchical Tree + #03 Document-Centric
│
├─► "Fault tolerance, production reliability"
│   └─► Shape D (Tree) + Shape L (Isolation) + Shape A (Message)
│       → Proposals: #04 Supervisor Trees + #40 Bulkhead + #36 Mediator
│
├─► "Security, sandboxing agents"
│   └─► Shape H (Capability) + Shape L (Isolation) + Shape D (Tree)
│       → Proposals: #33 Object Capability + #40 Bulkhead + #04 Supervisor Trees
│
├─► "Rewind, branch, audit"
│   └─► Shape B (Log) + Shape E (Shared)
│       → Proposals: #05 Event Sourcing + #03 Document-Centric
│
├─► "High throughput, many drones"
│   └─► Shape G (Queue) + Shape K (Pipeline)
│       → Proposals: #08 Work-Stealing Pool + #23 Pipes & Filters
│
├─► "Extensibility, user customization"
│   └─► Shape I (Plugin) + Shape N (Composition)
│       → Proposals: #11 Plugin Architecture + #25 ECS
│
└─► "Multi-machine, cloud agents"
    └─► Shape P (Distributed) + Shape A (Message) + Shape L (Isolation)
        → Proposals: #17 Distributed-First + #02 Actor Model + #40 Bulkhead
```


---


## Part 6: Quick Reference Card

| Shape | Core Trade-off | Best For | Avoid When |
|-------|---------------|----------|------------|
| A: Message | Decoupling vs latency | Agent communication | Simple sync operations |
| B: Log | Auditability vs complexity | Rewind/branch | Simple CRUD |
| C: Layer | Isolation vs ceremony | Large teams, SDK swaps | Small codebases |
| D: Tree | Hierarchy vs lateral comm | Parent-child relationships | Peer-to-peer needed |
| E: Shared | Persistence vs real-time | File-based workflows | High-frequency updates |
| F: Flat | Simplicity vs scalability | v1, small teams | Multiple teams, large scale |
| G: Queue | Throughput vs affinity | Drones, batch work | Stateful workflows |
| H: Capability | Security vs verbosity | Sandboxing | Rapid prototyping |
| I: Plugin | Extensibility vs integration | User customization | Core features |
| J: Formal | Correctness vs flexibility | Critical state logic | Informal behavior |
| K: Pipeline | Composability vs branching | Linear workflows | Complex flows |
| L: Isolation | Containment vs sharing | Failure boundaries | Tightly coupled features |
| M: Decentralization | Resilience vs consistency | No SPOF needed | Central authority needed |
| N: Composition | Flexibility vs encapsulation | Dynamic capabilities | Traditional OOP |
| O: Organization | Cohesion vs sharing | Feature teams | Shared libraries |
| P: Distributed | Scale vs simplicity | Multi-machine | Single-machine MVP |


---


## Conclusion

The Tavern architecture is not a single pattern choice but a composition of shapes. The PRD implicitly mandates:

- **Shape D (Tree)** — Jake → Mortals → Children hierarchy
- **Shape E (Shared Workspace)** — Doc store as source of truth

And strongly suggests:

- **Shape J (Formal: State Machine)** — Explicit agent states
- **Shape H (Capability)** — Sandbox primitives, violation monitoring
- **Shape G (Queue)** — Work queues, drones

The implementation question is: **What's the minimum viable shape combination for v1, with clear migration paths to fuller combinations?**

**Recommended v1:** Hybrid Layers (#18) + Hierarchical Tree (#09) + Document-Centric (#03) + State Machine (#13)

**Path to v2:** Add Supervisor Trees (#04) + Capability (#07) + Bulkhead (#40) + Mediator (#36)

**Path to full vision:** Add Event Sourcing (#05) + Work-Stealing (#08) + Actor Model (#02)
