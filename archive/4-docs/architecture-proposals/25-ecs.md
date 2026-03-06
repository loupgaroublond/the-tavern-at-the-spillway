# Entity-Component-System (ECS) Architecture

**One-line summary:** Game-engine style composition where agents are entities (IDs), behaviors are components (pure data), and systems operate on entities with specific component combinations.


## Core Concept

The Entity-Component-System architecture decouples agent identity from agent behavior entirely. In ECS, an "agent" is simply a unique identifier (entity). All agent characteristics -- state, session data, commitments, communication -- are stored as separate components attached to that entity. Systems are stateless functions that query for entities with specific component combinations and process them.

This inverts the current object-oriented design. Instead of a `MortalAgent` class containing state, commitments, and Claude communication, you have: an entity ID, a `StateComponent`, a `CommitmentListComponent`, a `ClaudeSessionComponent`, etc. The `VerificationSystem` queries for entities that have both `StateComponent` (in verifying state) and `CommitmentListComponent`, then runs verification logic on them.

The power of ECS lies in composition and decoupling. New agent types emerge from different component combinations rather than inheritance hierarchies. A "Drone" isn't a new class -- it's an entity with `StateComponent` + `TaskComponent` but without `CommitmentListComponent`. Systems can be added, removed, or modified without touching entity definitions. This data-oriented approach also enables batch processing, parallel execution, and straightforward serialization.


## Key Components

```mermaid
graph TD
    subgraph "ECS Core"
        World[World / EntityManager]
        ES[Entity Storage]
        CS[Component Storage]
    end

    subgraph "Entities (IDs only)"
        E1[Entity: Jake]
        E2[Entity: Mortal-001]
        E3[Entity: Mortal-002]
        E4[Entity: Drone-001]
    end

    subgraph "Components (Pure Data)"
        SC[StateComponent]
        CC[ClaudeSessionComponent]
        CMT[CommitmentListComponent]
        NC[NameComponent]
        AC[AssignmentComponent]
        PC[ParentComponent]
        MC[MetricsComponent]
    end

    subgraph "Systems (Logic)"
        MS[MessageSystem]
        VS[VerificationSystem]
        SS[SpawnSystem]
        LS[LifecycleSystem]
        BS[BubblingSystem]
        RS[RenderSystem]
    end

    subgraph "UI Layer"
        UI[@MainActor Views]
        VM[ViewModels observe World]
    end

    World --> ES
    World --> CS
    ES --> E1
    ES --> E2
    ES --> E3
    ES --> E4

    E1 -.->|has| SC
    E1 -.->|has| CC
    E1 -.->|has| NC

    E2 -.->|has| SC
    E2 -.->|has| CC
    E2 -.->|has| CMT
    E2 -.->|has| NC
    E2 -.->|has| AC

    MS -->|queries| World
    VS -->|queries| World
    SS -->|modifies| World
    LS -->|modifies| World

    VM -->|observes| World
    UI --> VM
```


## Pros

- **Maximum composition flexibility:** Agent types are defined by component combinations, not inheritance; new behaviors emerge without new classes

- **Systems are isolated and testable:** Each system does one thing; verify `VerificationSystem` without instantiating a full agent

- **Batch processing efficiency:** Systems can process all matching entities in one pass (all verifying agents at once)

- **Trivial serialization:** Components are pure data structs; save/restore the entire world to disk without custom codable logic

- **Parallel-friendly:** Systems that operate on non-overlapping component sets can run concurrently

- **PRD alignment:** "Doc store is source of truth" maps naturally to component storage; entities are just IDs pointing to stored data

- **Decoupled evolution:** Add new systems (MetricsSystem, ViolationMonitorSystem) without modifying existing code


## Cons

- **Foreign paradigm for Swift:** ECS is native to Rust/C++ game engines; Swift lacks optimized ECS libraries

- **Over-engineering risk:** Tavern has tens of agents, not thousands; ECS shines at scale we may never need

- **Indirection overhead:** Finding "Jake's state" requires: look up entity ID, query component storage, get StateComponent; versus `jake.state`

- **Tooling gap:** No Swift ECS debugging tools; hard to inspect entity-component relationships at runtime

- **UI integration complexity:** SwiftUI expects observable objects; bridging ECS world state to `@Published` properties requires custom machinery

- **Learning curve:** Team must adopt game-engine thinking for a non-game application

- **Boilerplate explosion:** Every property becomes a component type; component registration, queries, and type-safe access all require ceremony


## When to Choose This Architecture

Choose ECS when:

1. **Agent types will multiply** -- If the PRD's vision of Drones, Monitor Daemons, and arbitrary expert types fully materializes, ECS handles composition better than deep inheritance

2. **Batch operations are common** -- If you frequently need to "verify all agents" or "update all metrics" or "persist all state", ECS queries are natural

3. **Serialization is paramount** -- The "doc store IS the filesystem" invariant maps perfectly to component storage; each component type = one file type

4. **You want plugin-style extensibility** -- New systems can be added by external code without modifying core; agent behaviors become configurable

5. **Performance at scale matters** -- If Tavern grows to manage hundreds of concurrent agents across multiple projects, ECS's cache-friendly data layout pays off


Do not choose this architecture if:

- Agent count will stay modest (under 50 concurrent)
- The team is not familiar with data-oriented design
- Rapid prototyping speed is more valuable than architectural purity
- Direct object-oriented API simplicity is preferred over composition flexibility
- SwiftUI integration simplicity is a high priority
