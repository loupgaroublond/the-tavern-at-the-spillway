# Actor Model Architecture

**One-line summary:** Each agent is a Swift actor with its own isolated state and mailbox, using the language's built-in concurrency primitives for message passing and data isolation.


## Core Concept

The Actor Model architecture maps Tavern's agent concept directly onto Swift's native actor system. Each agent (Jake, MortalAgents, future Daemons) becomes a Swift `actor`, gaining automatic data race protection through actor isolation. Communication happens via async method calls, which Swift serializes into an implicit mailbox queue.

This approach leverages Swift 6's strict concurrency model to provide compile-time guarantees against data races. The current codebase uses `DispatchQueue`-based synchronization with `@unchecked Sendable` conformance, which is error-prone and requires manual discipline. With actors, the compiler enforces isolation boundaries, making thread safety structural rather than behavioral.

Agent state transitions (idle, working, waiting, verifying, done) become protected by actor isolation automatically. Inter-agent communication follows the natural async/await pattern, with the runtime managing scheduling and suspension. This eliminates the need for explicit queue management while providing superior safety guarantees.


## Key Components

```mermaid
graph TD
    subgraph "Swift Actor System"
        RT[Swift Runtime / Executor]
    end

    subgraph "Jake Actor"
        JA[actor Jake]
        JM[Mailbox: method calls]
        JS[Isolated State]
    end

    subgraph "MortalAgent Actors"
        MA1[actor MortalAgent]
        MA2[actor MortalAgent]
        MA3[actor MortalAgent]
    end

    subgraph "Coordinator Actor"
        TC[actor TavernCoordinator]
        REG[AgentRegistry]
    end

    subgraph "UI Layer"
        UI[@MainActor Views]
        VM[@MainActor ViewModels]
    end

    RT --> JA
    RT --> MA1
    RT --> MA2
    RT --> MA3
    RT --> TC

    UI --> VM
    VM -.->|async calls| TC
    VM -.->|async calls| JA

    TC --> REG
    TC -.->|spawn/dismiss| MA1
    TC -.->|spawn/dismiss| MA2

    JA -.->|delegate| TC
    MA1 -.->|report| TC
```


## Pros

- **Compile-time safety:** Swift enforces actor isolation at compile time, eliminating data race bugs by construction

- **Structured concurrency:** Async/await integrates naturally with actors, providing clear suspension points and cancellation propagation

- **Simpler mental model:** No manual queue management, no `@unchecked Sendable`, no sync/async dance

- **Native integration:** Aligns with SwiftUI's `@MainActor` for UI-bound state, creating a coherent concurrency story

- **Future-proof:** Swift's concurrency continues to evolve with better tooling, performance improvements, and ecosystem support

- **PRD alignment:** The "Working/Waiting/Done" state machine maps cleanly to actor method calls and state


## Cons

- **Reentrancy complexity:** Actors are reentrant by default; suspension points can interleave unexpectedly, requiring careful protocol design

- **Structured vs distributed:** Swift actors are in-process only; future multi-machine requirements would need separate distributed actor support

- **MainActor bottleneck:** UI-bound state must still coordinate through `@MainActor`, creating potential serialization points

- **Migration cost:** Existing `final class` agents require substantial refactoring to become actors

- **Performance characteristics:** Actor hop overhead is minimal but non-zero; high-frequency operations may notice

- **Debugging complexity:** Actor isolation can make debugging harder when tracking state across suspension points


## When to Choose This Architecture

Choose the Actor Model when:

1. **Data races are a primary concern** — The current `DispatchQueue` approach has already shown brittleness in tests and requires ongoing vigilance

2. **Agent count will grow** — The PRD envisions many concurrent agents; actors scale better than manual queue coordination

3. **Compile-time guarantees matter more than runtime flexibility** — You want the compiler to catch concurrency bugs

4. **The team is committed to Swift 6** — Modern Swift concurrency features (like `Sendable` checking) work best with actors

5. **Inter-agent communication will intensify** — The PRD mentions agent-to-agent messaging, bubbling, and coordination; actors provide clean primitives for this


Do not choose this architecture if:

- You need to support macOS versions older than 10.15 (actors require Combine/async-await runtime)
- Runtime flexibility for concurrency policies is essential
- The existing class-based approach with manual synchronization is working well enough
