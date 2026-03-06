# Hybrid Layers Architecture: Complete Analysis

This document contains the full research, analysis, and design rationale for the Hybrid Layers architecture proposal.


## Research Findings


### Current Directory Structure

The TavernCore framework is organized into ten directories plus a root module file:

```
Sources/TavernCore/
├── TavernCore.swift          # Module exports
├── Agents/                   # Jake, MortalAgent, Agent protocol, AnyAgent, AgentRegistry, AgentSpawner
├── Chat/                     # ChatMessage, ChatViewModel
├── Commitments/              # Commitment, CommitmentList, CommitmentVerifier
├── Coordination/             # TavernCoordinator
├── DocStore/                 # DocStore, Document, AgentNode, AgentPersistence
├── Errors/                   # TavernError, TavernErrorMessages
├── Logging/                  # TavernLogger
├── Naming/                   # NameGenerator, NamingTheme
├── Persistence/              # SessionStore
├── Project/                  # TavernProject, ProjectManager
└── UI/                       # AgentListViewModel, AgentListItem
```


### Current Type Responsibilities

**Agents Directory (6 types)**

- `Agent` protocol: Common interface (id, name, state, send, resetConversation)
- `AgentState` enum: Lifecycle states (idle, working, waiting, verifying, done)
- `AnyAgent`: Type erasure for heterogeneous collections
- `Jake`: The Proprietor, eternal agent with system prompt and session continuity
- `MortalAgent`: Worker agent with assignment, commitments, and completion detection
- `AgentRegistry`: Thread-safe storage of agents by ID and name
- `AgentSpawner`: Factory that creates agents, generates names, manages lifecycle

**Coordination Directory (1 type)**

- `TavernCoordinator`: `@MainActor`, owns Jake and Spawner, manages selection, publishes view models

**Project Directory (2 types)**

- `TavernProject`: Represents an open directory, owns ClaudeCode and Coordinator
- `ProjectManager`: Singleton tracking all open projects and recent paths

**Chat Directory (2 types)**

- `ChatMessage`: Single message with role, content, message type
- `ChatViewModel`: `@MainActor`, wraps Agent, manages messages, handles send flow

**UI Directory (2 types)**

- `AgentListViewModel`: `@MainActor`, manages agent list and selection state
- `AgentListItem`: Display model for list entries

**Commitments Directory (3 types + 2 protocols)**

- `Commitment`: A verifiable assertion with description, assertion command, status
- `CommitmentStatus`: pending, verifying, passed, failed
- `CommitmentList`: Thread-safe collection of commitments
- `AssertionRunner` protocol: Abstraction for running shell commands
- `ShellAssertionRunner`: Production implementation using /bin/bash
- `MockAssertionRunner`: Test double for verification logic
- `CommitmentVerifier`: Runs assertions and updates commitment status

**Persistence Directory (1 type)**

- `SessionStore`: UserDefaults-based storage for session IDs per project/agent

**DocStore Directory (4 types)**

- `Document`: Markdown with YAML frontmatter
- `DocStore`: File-based CRUD for documents
- `AgentNode`: Serializes agent state to documents
- `AgentPersistence`: Save/restore agents via DocStore

**Naming Directory (2 types)**

- `NamingTheme`: Tiered lists of themed names (LOTR, Dune, etc.)
- `NameGenerator`: Thread-safe name generation with fallback

**Errors Directory (2 types)**

- `TavernError`: Sum type for all failure modes
- `TavernErrorMessages`: User-facing message generation

**Logging Directory (1 type)**

- `TavernLogger`: Static loggers for categories (agents, chat, coordination, claude)


### Coupling Analysis

I traced the dependencies and interactions between types to understand actual coupling:

**High Coupling Cluster: Coordination**

`TavernCoordinator` depends on:
- `Jake` (owns)
- `AgentSpawner` (owns)
- `AgentListViewModel` (creates, publishes)
- `ChatViewModel` (creates, caches)
- `AnyAgent` (queries from spawner)

`AgentSpawner` depends on:
- `AgentRegistry` (uses for registration)
- `NameGenerator` (uses for naming)
- `ClaudeCode` (factory for creating)
- `MortalAgent` (creates)

`AgentRegistry` depends on:
- `AnyAgent` (stores)
- `Agent` protocol (generic constraint)

These three types (Coordinator, Spawner, Registry) share the same lifecycle (project open to close), operate on the same data (agents), and coordinate constantly. Every spawn goes: Coordinator -> Spawner -> Registry -> back to Coordinator. Every dismiss reverses this. The separation exists but provides no isolation benefit.

**High Coupling Cluster: Project**

`TavernProject` depends on:
- `TavernCoordinator` (creates, owns)
- `Jake` (creates)
- `AgentRegistry` (creates)
- `NameGenerator` (creates)
- `AgentSpawner` (creates)
- `ClaudeCode` (creates)
- `MockClaudeCode` (fallback)

`TavernProject.initialize()` is essentially the wiring logic that creates all the components and connects them. This is a 40-line method of pure dependency injection.

**Moderate Coupling: Agents**

`Jake` and `MortalAgent` are the actual domain objects. They depend on:
- `ClaudeCode` (injected)
- `SessionStore` (static calls)
- `CommitmentList` and `CommitmentVerifier` (MortalAgent only)

They do NOT depend on Coordinator, Spawner, or Registry. They are created by higher layers but live independently.

**Low Coupling: Commitments**

`CommitmentVerifier` depends on:
- `AssertionRunner` (protocol, injected)
- `CommitmentList` (parameter)
- `Commitment` (mutates)

`CommitmentList` and `Commitment` are data structures with no external dependencies. The verification system is self-contained.

**Low Coupling: Naming**

`NameGenerator` depends on:
- `NamingTheme` (owns)

No external dependencies. Pure utility layer.

**Low Coupling: Persistence**

`SessionStore` uses:
- `UserDefaults` (static)
- `ClaudeNativeSessionStorage` (creates)

No dependencies on other TavernCore types.

**Low Coupling: DocStore**

`DocStore` uses:
- `FileManager`
- `Document` (own type)

`AgentPersistence` uses:
- `DocStore`
- `AgentNode`
- Agent types

DocStore is a generic persistence layer. AgentPersistence adapts it to agents.

**Very Low Coupling: Errors, Logging**

`TavernError` and `TavernLogger` have no dependencies on other TavernCore types. They are pure utilities.


### Lifecycle Analysis

Understanding when types are created and destroyed reveals natural groupings:

| Type | Created When | Destroyed When | Lifecycle Owner |
|------|--------------|----------------|-----------------|
| Jake | Project opens | Project closes | TavernProject |
| MortalAgent | Spawn called | Dismiss called | AgentSpawner |
| TavernCoordinator | Project initializes | Project closes | TavernProject |
| AgentSpawner | Project initializes | Project closes | TavernProject |
| AgentRegistry | Project initializes | Project closes | TavernProject |
| NameGenerator | Project initializes | Project closes | TavernProject |
| AgentListViewModel | Coordinator created | Coordinator destroyed | TavernCoordinator |
| ChatViewModel | Agent selected (cached) | Agent dismissed | TavernCoordinator |
| CommitmentList | MortalAgent created | MortalAgent destroyed | MortalAgent |
| SessionStore | N/A (static) | N/A | Application |
| DocStore | TBD | TBD | TBD |

Key observation: Coordinator, Spawner, Registry, and NameGenerator share identical lifecycles. They are born together and die together. This is a strong signal they could be merged.


### Change Frequency Analysis

Looking at git history and the nature of each layer:

**Frequently Changing**
- `TavernCoordinator`: Every new UI interaction touches this
- `AgentSpawner`: Spawn configuration evolves
- `ChatViewModel`: Display logic iterates

**Moderately Changing**
- `Jake`, `MortalAgent`: Core logic stabilizing but still evolving
- `AgentListViewModel`: UI iteration

**Rarely Changing**
- `AgentRegistry`: Simple storage, stable interface
- `NameGenerator`, `NamingTheme`: Add themes, otherwise stable
- `SessionStore`: Stable after initial implementation
- `TavernLogger`: Add categories, otherwise stable
- `TavernError`: Add cases, otherwise stable

**Very Rarely Changing**
- `CommitmentVerifier`: Verification logic is stable once designed
- `DocStore`: Generic CRUD, stable

This suggests: merge frequently-changing coordination types (Coordinator, Spawner) while keeping stable infrastructure separate (Logging, Errors, Naming as data).


## Layer-by-Layer Analysis: Keep vs Merge


### Agents Directory

**Keep separate: YES**

Agents are the core domain concept. Jake and MortalAgent are the actual "things that do work." They should remain a first-class organizational unit.

However, the Agents directory currently contains `AgentRegistry` and `AgentSpawner`, which are coordination infrastructure. These should move out.

**Recommendation:** Keep Agent, AgentState, AnyAgent, Jake, MortalAgent. Move AgentRegistry and AgentSpawner to coordination.


### Coordination Directory + AgentSpawner + AgentRegistry

**Merge: YES**

`TavernCoordinator` is 145 lines. `AgentSpawner` is 132 lines. `AgentRegistry` is 103 lines. Together they are 380 lines, well within a single-file comfort zone.

They share:
- Same lifecycle (project open to close)
- Same data (agents)
- Same change triggers (spawn/dismiss/select operations)
- Constant coordination (every spawn touches all three)

The current separation requires:
- Factory injection (`claudeFactory`)
- Forwarding methods (`spawner.activeAgents`)
- Synchronized updates (coordinator caches view models, list view model queries spawner)

A merged `ProjectHub` (or `ProjectCoordinator`) eliminates all of this.

**Recommendation:** Merge TavernCoordinator + AgentSpawner + AgentRegistry into `ProjectHub`.


### Project Directory

**Analyze further**

`TavernProject` is primarily wiring logic that creates Coordinator, Jake, Spawner, Registry, NameGenerator. If we merge those into ProjectHub, TavernProject becomes a thin wrapper around ProjectHub.

`ProjectManager` is a singleton that tracks open projects. It is at a different level than per-project types.

**Recommendation:**
- Merge `TavernProject` initialization logic into `ProjectHub`. ProjectHub creates itself from a URL.
- Keep `ProjectManager` as application-level singleton.


### Chat Directory

**Keep separate: YES**

`ChatMessage` is a pure data type. `ChatViewModel` is a `@MainActor` view model with distinct UI responsibilities.

Chat is about the user interface to conversations. It wraps agents but does not own or manage them.

**Recommendation:** Keep Chat/ as-is. ChatViewModel remains separate from coordination.


### UI Directory

**Analyze further**

`AgentListViewModel` is tightly coupled to coordination:
- Created by TavernCoordinator
- Queries AgentSpawner.activeAgents
- Caches assignments from spawn calls
- Tracks selection state

`AgentListItem` is a pure display model.

**Recommendation:**
- Keep `AgentListItem` in UI/
- Move `AgentListViewModel` into ProjectHub or keep it owned by ProjectHub with a clear interface


### Commitments Directory

**Keep separate: YES**

Commitments represent a distinct domain: deterministic verification of agent claims. This is the "independent assertion verifies" requirement from the PRD.

The verification system has:
- Its own protocol (`AssertionRunner`)
- Its own test double (`MockAssertionRunner`)
- Its own state machine (pending -> verifying -> passed/failed)

It is used by `MortalAgent` but is not coupled to coordination.

**Recommendation:** Keep Commitments/ as-is. This is a natural seam.


### Persistence Directory

**Keep separate: YES**

`SessionStore` is a generic utility for storing session IDs in UserDefaults. It is stateless and static.

It does not depend on other TavernCore types (only ClaudeCodeSDK types).

**Recommendation:** Keep Persistence/ as-is.


### DocStore Directory

**Keep separate: YES**

`DocStore` is a generic markdown document store. It is reusable beyond agents.

`AgentPersistence` and `AgentNode` adapt DocStore to the agent domain. These could move to Agents/ if we wanted, but keeping them with DocStore is also reasonable.

**Recommendation:** Keep DocStore/ as-is for now. Consider moving AgentPersistence/AgentNode later.


### Naming Directory

**Keep separate: YES (but note simple)**

`NamingTheme` is pure data (arrays of strings). `NameGenerator` is a simple utility.

They are used by spawning logic but have no dependencies on other layers.

**Recommendation:** Keep Naming/ as-is. It is a leaf dependency.


### Errors Directory

**Keep separate: YES**

Error types are a cross-cutting concern. They are used throughout the codebase but depend on nothing.

**Recommendation:** Keep Errors/ as-is.


### Logging Directory

**Keep separate: YES**

Logging is a cross-cutting concern. `TavernLogger` provides static accessors to `os.log` loggers.

**Recommendation:** Keep Logging/ as-is.


## PRD Requirements Mapping

The PRD specifies several architectural concerns. Here is how Hybrid Layers addresses them:

**Invariant 3: Commitments must be verified independently**

Hybrid Layers keeps Commitments/ as a separate layer. The verification system (CommitmentVerifier, AssertionRunner protocol) is independent of coordination. This ensures verification logic can be tested and reasoned about in isolation.

**Invariant 5: Doc store is source of truth**

DocStore/ remains separate. The file-based storage is a natural seam. AgentPersistence adapts it to agents without coupling DocStore to agent internals.

**Invariant 7: Failures must be visible**

TavernError and TavernLogger remain separate. Error handling and logging are cross-cutting concerns that should not be merged into domain layers.

**Section 4.1: Agent Types**

Jake and MortalAgent remain in the Agents layer. The Agent protocol defines the common interface. This domain layer is preserved.

**Section 4.2: Agent States**

AgentState enum remains with agents. State transitions are agent-level concerns.

**Section 6.2: Agent Spawn Configuration**

Spawning logic moves into ProjectHub. The spawn configuration (assignment, model selection, token budget) is handled by a single type rather than coordinating between Coordinator and Spawner.

**Section 17: Testability Requirements**

- Agents can be tested with MockClaudeCode (no change)
- Commitments can be tested with MockAssertionRunner (no change)
- ProjectHub can be tested as a unit, replacing the need to mock Coordinator + Spawner + Registry separately
- DocStore can be tested with temp directories (no change)


## Trade-offs Considered


### Trade-off 1: Merged vs Separate View Models

**Option A:** Merge AgentListViewModel into ProjectHub

Pros: Single source of truth for agent list and selection
Cons: Mixes `@MainActor` view model concerns with coordination logic

**Option B:** Keep AgentListViewModel separate but owned by ProjectHub

Pros: Clear separation of display logic
Cons: Still need to synchronize (agent list refresh after spawn)

**Decision:** Option B. Keep AgentListViewModel as a separate type but owned by ProjectHub. The synchronization is manageable (call refreshItems after spawn/dismiss).


### Trade-off 2: Where Does Jake Live?

**Option A:** Jake owned by ProjectHub

Pros: All coordination in one place
Cons: Jake is logically different from mortal agents (eternal vs spawned)

**Option B:** Jake created by ProjectHub but semantically "above" it

Pros: Matches PRD mental model (Jake is the Proprietor, not just another agent)
Cons: Complicates ownership (who creates Jake? who owns the reference?)

**Decision:** Option A for simplicity. Jake is created by ProjectHub and lives there. The distinction between Jake and mortals is captured in the type system (Jake class vs MortalAgent class), not in ownership.


### Trade-off 3: NameGenerator Location

**Option A:** NameGenerator owned by ProjectHub

Pros: Name generation is part of spawn flow
Cons: NameGenerator is a generic utility, not project-specific

**Option B:** NameGenerator as static utility

Pros: Can be reused across contexts
Cons: Loses thread-safety guarantees, harder to test

**Option C:** NameGenerator injected into ProjectHub

Pros: Testable, decoupled
Cons: More wiring

**Decision:** Option A. NameGenerator is created by ProjectHub. It is per-project because each project could have a different naming theme. Testing can create ProjectHub with a pre-configured NameGenerator.


### Trade-off 4: Testing Strategy

**Before (current architecture):**
- Mock AgentRegistry to test AgentSpawner
- Mock AgentSpawner to test TavernCoordinator
- Mock both to test TavernProject
- Integration tests wire everything together

**After (Hybrid Layers):**
- ProjectHub tested as unit with MockClaudeCode
- AgentListViewModel tested with mock ProjectHub or real ProjectHub
- Integration tests remain similar

The trade-off is: fewer unit test boundaries in the coordination layer, but the boundaries that remain (Agents, Commitments, Persistence) are more meaningful.


## Implementation Complexity


### Step 1: Create ProjectHub

1. Create new file `Sources/TavernCore/Coordination/ProjectHub.swift`
2. Copy methods from TavernCoordinator
3. Move agent storage from AgentRegistry inline
4. Move spawn logic from AgentSpawner inline
5. Add NameGenerator as owned property
6. Add ClaudeCode factory as closure property

Estimated: 400-500 lines


### Step 2: Update TavernProject

1. Replace creation of Coordinator, Registry, Spawner, NameGenerator with ProjectHub creation
2. Pass rootURL to ProjectHub initializer
3. Remove intermediate wiring

Result: TavernProject shrinks to ~50 lines


### Step 3: Move Files

1. Move AgentSpawner.swift to archive or delete
2. Move AgentRegistry.swift to archive or delete
3. Keep Agent.swift, Jake.swift, MortalAgent.swift, AnyAgent.swift in Agents/


### Step 4: Update Tests

1. Tests that mocked AgentRegistry now test ProjectHub directly
2. Tests that mocked AgentSpawner now test ProjectHub directly
3. TavernCoordinator tests become ProjectHub tests

Estimated: ~100 lines of test changes


### Step 5: Update Documentation

1. Update architecture-v1.md to reflect new structure
2. Update object ownership diagram
3. Update module dependency graph


## Migration Path from Current State


### Phase 1: Consolidate Coordination (Low Risk)

1. Create ProjectHub with all coordination logic
2. Make TavernProject, TavernCoordinator, AgentSpawner, AgentRegistry forward to ProjectHub
3. Run tests, ensure green
4. Remove forwarding types one at a time, updating references
5. Run tests after each removal

This approach allows rollback at any step.


### Phase 2: Verify Preserved Separations

1. Ensure Commitments/ has no new dependencies on ProjectHub
2. Ensure Agents/ (Jake, MortalAgent) have no dependencies on ProjectHub
3. Ensure Persistence/ has no dependencies on ProjectHub
4. Write explicit dependency tests if needed


### Phase 3: Document Rationale

1. Add comments in ProjectHub explaining why it exists
2. Add comments in Agents/, Commitments/, DocStore/ explaining why they are separate
3. Update CLAUDE.md with architectural notes


## Open Questions


### Q1: Should ChatViewModel be part of ProjectHub?

ChatViewModel is `@MainActor` and is cached per-agent. Currently TavernCoordinator creates and caches them.

Arguments for merging: Simplifies cache management
Arguments against: ChatViewModel is view-layer, ProjectHub is coordination-layer

**Tentative answer:** Keep ChatViewModel separate. ProjectHub owns the cache (dictionary) but ChatViewModel is its own type. This matches how ProjectHub owns AgentListViewModel.


### Q2: What about multi-project interactions?

The PRD mentions "multi-project / Jake-per-project" as an open question. If agents ever need to coordinate across projects, the current per-project isolation might be too strong.

**Tentative answer:** Design for current requirements (isolated projects). If cross-project coordination emerges, it will likely be at a higher level than ProjectHub (e.g., an application-level coordinator).


### Q3: Should DocStore be injected into ProjectHub?

Currently DocStore is not connected to the coordination layer. If we want agents to persist to DocStore, ProjectHub might need a DocStore reference.

**Tentative answer:** Not yet. DocStore usage is not implemented in v1. When it is, we can inject a DocStore instance into ProjectHub or have ProjectHub create one.


### Q4: What is the long-term vision for Naming?

The PRD describes naming themes assigned per mortal tree (not per project). Currently we use one NameGenerator per project with one theme.

**Tentative answer:** Keep NameGenerator per-project for now. When we implement mortal agent trees with children, each tree root will get its own NameGenerator with a theme assigned by Jake.


## Summary

Hybrid Layers proposes:

**Merge:**
- TavernCoordinator + AgentSpawner + AgentRegistry + part of TavernProject into ProjectHub

**Keep Separate:**
- Agents/ (Jake, MortalAgent, Agent protocol)
- Commitments/ (verification domain)
- Chat/ (view layer)
- DocStore/ (persistence infrastructure)
- Persistence/ (session storage)
- Naming/ (utility)
- Errors/ (cross-cutting)
- Logging/ (cross-cutting)
- Project/ProjectManager (application-level)

The result is a codebase where the boundaries reflect actual system boundaries. The coordination layer becomes a single cohesive unit. The domain layers (Agents, Commitments) remain independently testable. The infrastructure layers (Persistence, DocStore, Naming, Logging, Errors) remain stable and reusable.

This is not the simplest architecture (that would be Flat Coordinator merging everything). It is not the most separated architecture (that would be keeping all current boundaries). It is the architecture that best matches the actual coupling and change patterns observed in the codebase.
