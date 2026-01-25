# Domain-Driven Design Architecture: Complete Analysis

This document contains the full research, analysis, and reasoning behind the DDD architecture proposal for the Tavern multi-agent orchestrator.


## Research Findings


### Current Codebase Structure

The existing codebase organizes code by technical concern within `TavernCore/`:

```
TavernCore/
├── Agents/           # Jake, MortalAgent, Agent protocol, Registry, Spawner
├── Chat/             # ChatMessage, ChatViewModel
├── Commitments/      # Commitment, CommitmentList, CommitmentVerifier
├── Coordination/     # TavernCoordinator
├── DocStore/         # DocStore, Document, AgentNode, AgentPersistence
├── Errors/           # TavernError, TavernErrorMessages
├── Logging/          # TavernLogger
├── Naming/           # NamingTheme, NameGenerator
├── Persistence/      # SessionStore
├── Project/          # TavernProject, ProjectManager
├── Testing/          # MockClaudeCode, TestFixtures
└── UI/               # AgentListViewModel, AgentListItem
```

This structure reveals implicit domains that have naturally emerged:

1. **Agent Management**: `Jake`, `MortalAgent`, `Agent` protocol, `AgentState`, `AgentRegistry`, `AgentSpawner`
2. **Messaging/Chat**: `ChatMessage`, `ChatViewModel`, message content blocks
3. **Verification**: `Commitment`, `CommitmentList`, `CommitmentVerifier`, `AssertionRunner`
4. **Document Storage**: `DocStore`, `Document`, `AgentNode`, `AgentPersistence`
5. **Naming**: `NamingTheme`, `NameGenerator`
6. **Coordination/Orchestration**: `TavernCoordinator`, `TavernProject`, `ProjectManager`
7. **Session Persistence**: `SessionStore`, `ClaudeNativeSessionStorage` integration


### Current Cross-Cutting Concerns

Several concerns span multiple implicit domains:

- **Session IDs**: Used by `Jake`, `MortalAgent`, `SessionStore`, and `ChatViewModel` for history loading
- **ClaudeCode SDK**: Injected into agents, used by `TavernProject` factory methods
- **Thread Safety**: Each domain handles its own synchronization via `DispatchQueue`
- **Logging**: `TavernLogger` categories map roughly to domains (agents, chat, coordination, claude)
- **Errors**: `TavernError` is centralized but sparse; `AgentRegistryError`, `DocStoreError`, `AgentNodeError` are domain-specific


### Coupling Observations

Reading the implementation files reveals several coupling patterns:

1. **AgentSpawner depends on AgentRegistry and NameGenerator** - spawn operation touches three domains
2. **TavernCoordinator owns Jake, Spawner, and ChatViewModel cache** - orchestration owns agents and messaging state
3. **MortalAgent owns CommitmentList and CommitmentVerifier** - agent entity owns verification domain objects
4. **ChatViewModel calls SessionStore.loadJakeSessionHistory()** - messaging view model reaches into persistence
5. **AgentNode knows about Commitment** - persistence knows about verification domain


### PRD Requirements Mapping

Key PRD requirements and how DDD would address them:

| PRD Requirement | DDD Approach |
|----------------|--------------|
| **Commitment verification** (Invariant #3) | Verification Context owns commitment lifecycle; domain events notify Agent Context when verification completes |
| **Doc store is source of truth** (Invariant #5) | Document Context provides repository interface; other contexts persist through it |
| **Agents cannot modify their own invariants** (Invariant #6) | Verification Context is separate from Agent Context; agents cannot directly mutate verification rules |
| **Failures must be visible** (Invariant #7) | Domain events propagate failure conditions across contexts |
| **Multiple agents working in parallel** (Goal) | Agent Context manages concurrent agent lifecycle; Messaging Context handles per-agent conversations |
| **Deterministic verification** (Goal) | Verification Context encapsulates assertion execution, isolated from agent behavior |
| **Agent spawning** (Section 6.2) | Agent Management Context owns spawn configuration, delegates naming to Naming Context |
| **Progressive unlocks** (Section 8) | Naming Context tracks engagement metrics, unlocks content independently |


## Identified Bounded Contexts


### 1. Agent Management Context

**Responsibility**: Agent identity, lifecycle, state transitions, and registration.

**Aggregate Root**: `AgentAggregate`

**Entities**:
- `Jake` - Eternal coordinator agent (singleton per project)
- `MortalAgent` - Task-scoped worker agent

**Value Objects**:
- `AgentState` - Lifecycle state (idle, working, waiting, verifying, done)
- `AgentId` - Strong type wrapping UUID
- `Assignment` - Task description given to mortal agents

**Repository**: `AgentRepository`
- `save(agent:)` - Persist agent state
- `load(id:)` - Retrieve agent by ID
- `loadAll(projectId:)` - List agents for a project
- `delete(id:)` - Remove agent

**Domain Events**:
- `AgentSpawned(agentId, name, assignment)`
- `AgentStateChanged(agentId, oldState, newState)`
- `AgentDismissed(agentId)`
- `AgentCompletionAttempted(agentId)` - Triggers verification

**Internal Services**:
- None (spawning is an application service that coordinates with Naming Context)

**Invariants**:
- Agent names must be unique within a project
- Jake is always present (eternal)
- State transitions follow defined rules (e.g., cannot go from `done` to `working`)


### 2. Messaging Context

**Responsibility**: Conversation history, message flow, content block rendering.

**Aggregate Root**: `ConversationAggregate`

**Entities**:
- `Conversation` - A conversation session (maps to Claude session)
- `Message` - A single message in a conversation

**Value Objects**:
- `MessageContent` - Text, tool use, or tool result
- `ContentBlock` - Discriminated union of content types
- `ConversationId` - Strong type for conversation identity
- `MessageId` - Strong type for message identity

**Repository**: `MessageRepository`
- `save(conversation:)` - Persist conversation state
- `load(conversationId:)` - Retrieve conversation
- `appendMessage(conversationId:, message:)` - Add message to conversation
- `loadHistory(agentId:, projectPath:)` - Retrieve historical messages

**Domain Events**:
- `MessageSent(conversationId, messageId, role)`
- `ConversationStarted(conversationId, agentId)`
- `ConversationCleared(conversationId)`

**Notes**:
- Current `ChatViewModel` would become an application service that orchestrates between Messaging Context and Agent Management Context
- Session ID management moves to this context


### 3. Verification Context

**Responsibility**: Commitment definitions, assertion execution, verification lifecycle.

**Aggregate Root**: `CommitmentAggregate`

**Entities**:
- `Commitment` - A verifiable assertion with lifecycle

**Value Objects**:
- `CommitmentStatus` - pending, verifying, passed, failed
- `Assertion` - Shell command to verify commitment
- `AssertionResult` - Outcome of running an assertion
- `CommitmentId` - Strong type for commitment identity

**Repository**: `CommitmentRepository`
- `save(commitments:, agentId:)` - Persist commitments for an agent
- `load(agentId:)` - Retrieve commitments
- `updateStatus(commitmentId:, status:)` - Update single commitment

**Domain Services**:
- `VerificationService` - Runs assertions, manages verification workflow
  - `verify(commitment:)` - Execute single assertion
  - `verifyAll(agentId:)` - Execute all pending commitments

**Domain Events**:
- `CommitmentAdded(commitmentId, agentId, description)`
- `VerificationStarted(commitmentId)`
- `VerificationPassed(commitmentId)`
- `VerificationFailed(commitmentId, message)`
- `AllCommitmentsPassed(agentId)` - Signals agent can transition to done

**Invariants**:
- Commitments cannot be modified while verifying
- Verification results are immutable once set (retry creates new verification run)


### 4. Document Context

**Responsibility**: File-based persistence with markdown/YAML format.

**Aggregate Root**: `DocumentAggregate`

**Entities**:
- `Document` - A persisted document with frontmatter and content

**Value Objects**:
- `DocumentId` - String identifier
- `Frontmatter` - YAML metadata
- `DocumentContent` - Markdown body

**Repository**: `DocumentRepository`
- `create(document:)` - Create new document
- `read(id:)` - Retrieve document
- `update(document:)` - Update existing document
- `delete(id:)` - Remove document
- `listAll()` - Enumerate all documents
- `exists(id:)` - Check existence

**Notes**:
- This is infrastructure that other contexts use through their repositories
- The current `DocStore` becomes the implementation of `DocumentRepository`
- Other repositories (AgentRepository, CommitmentRepository) delegate to DocumentRepository


### 5. Naming Context

**Responsibility**: Themed name generation, progressive unlocks, uniqueness tracking.

**Aggregate Root**: None (stateless service with state stored externally)

**Entities**:
- `Theme` - A naming theme with tiered names

**Value Objects**:
- `ThemeId` - Theme identifier (lotr, dune, greek, etc.)
- `NamePool` - Available names within a tier
- `UsedNames` - Set of consumed names

**Domain Service**:
- `NamingService`
  - `generateName(themeId:, usedNames:)` - Get next available name
  - `reserveName(name:)` - Mark name as used
  - `releaseName(name:)` - Return name to pool
  - `remainingNames(themeId:)` - Count available names

**Notes**:
- Progressive unlock logic lives here
- Engagement metrics could be tracked here or in a separate Metrics Context


### 6. Shared Kernel

**Shared types used across contexts**:

- `ProjectId` - Identifies a project (URL or UUID)
- `AgentId` - Identifies an agent
- `Timestamp` - Consistent date/time handling
- Domain event base types
- Result/Error conventions


## Trade-offs Considered


### Aggregate Boundary Decisions

**Should MortalAgent own its CommitmentList?**

Current code: Yes, `MortalAgent` has a `commitments: CommitmentList` property.

DDD alternative: Agent Management Context references commitments by ID; Verification Context owns commitment state.

Trade-off: Keeping commitments on the agent is simpler but couples two domains. Separating them requires cross-context communication but allows verification logic to evolve independently.

**Recommendation**: Separate. Verification is complex enough (sandbox execution, retry logic, timeout handling) to warrant its own context.


**Should ChatViewModel own message history?**

Current code: Yes, `ChatViewModel` has `messages: [ChatMessage]` and calls `SessionStore.loadJakeSessionHistory()`.

DDD alternative: Messaging Context owns conversation history; ChatViewModel is a thin projection.

Trade-off: Current approach is simpler for UI binding. DDD approach decouples UI concerns from domain logic.

**Recommendation**: Separate. Message history is domain logic (persistence, rehydration, compaction) not view logic.


### Repository vs. Direct Storage

**Should repositories abstract over DocStore, or should each context manage its own files?**

Option A: Single DocumentRepository, other repositories delegate.
Option B: Each context has its own file-based repository.

Trade-off: Option A provides consistency and single source of truth. Option B allows contexts to optimize their storage format.

**Recommendation**: Option A. The PRD states "doc store IS the filesystem" and "one file per node." A single Document Context honors this.


### Domain Events vs. Direct Calls

**How should contexts communicate?**

Option A: Domain events (publish-subscribe, eventual consistency).
Option B: Application services orchestrate calls to multiple contexts.
Option C: Contexts call each other directly through interfaces.

Trade-off:
- Events provide loose coupling but introduce eventual consistency complexity.
- Application services centralize orchestration but can become bloated.
- Direct calls are simple but create coupling.

**Recommendation**: Hybrid. Use application services for synchronous operations (spawn agent). Use domain events for notifications (agent state changed, verification completed).


## Implementation Complexity


### High Complexity Areas

1. **Cross-Context Transactions**: Spawning an agent involves Agent Management, Naming, and potentially Messaging. Ensuring atomicity without distributed transactions requires careful saga or choreography patterns.

2. **Event Infrastructure**: Domain events need a dispatcher, subscribers, and potentially persistence for reliability. This is infrastructure code that doesn't exist yet.

3. **Repository Mapping**: Each context may have internal models that differ from persistence models. Mapping layers add boilerplate.

4. **Session ID Management**: Current code spreads session handling across Jake, MortalAgent, SessionStore, and ChatViewModel. Consolidating into Messaging Context requires careful migration.


### Moderate Complexity Areas

1. **Aggregate Design**: Defining aggregate boundaries requires domain expertise. Wrong boundaries lead to performance issues or invariant violations.

2. **Context Mapping**: Deciding which contexts talk to which, and through what interfaces, requires upfront design.

3. **Testing Strategy**: Each context needs its own test suite with mock repositories. Integration tests verify cross-context behavior.


### Low Complexity Areas

1. **Value Objects**: Simple to implement; improves type safety.

2. **Repository Interfaces**: Straightforward abstraction over current storage.

3. **Ubiquitous Language**: Naming consistency is a documentation/convention task.


## Migration Path from Current State


### Phase 1: Introduce Value Objects and Strong Types

**Effort**: Low
**Risk**: Low

- Create `AgentId`, `CommitmentId`, `ConversationId` types wrapping `UUID`
- Create `DocumentId` type wrapping `String`
- Update existing code to use strong types (compiler-assisted refactoring)

This phase improves type safety without changing architecture.


### Phase 2: Extract Repository Interfaces

**Effort**: Medium
**Risk**: Low

- Define `AgentRepository` protocol; `DocStore`-backed implementation
- Define `CommitmentRepository` protocol
- Define `MessageRepository` protocol
- Inject repositories into existing classes

This phase introduces abstraction without changing behavior.


### Phase 3: Define Bounded Context Modules

**Effort**: Medium
**Risk**: Medium

- Create Swift package targets for each context
- Move types into appropriate packages
- Establish public/internal visibility boundaries
- Define context interfaces (protocols exposed across boundaries)

This phase establishes architectural boundaries.


### Phase 4: Introduce Domain Events

**Effort**: High
**Risk**: Medium

- Build event dispatcher infrastructure
- Define domain event types
- Refactor cross-context communication to use events
- Add event persistence for reliability

This phase decouples contexts.


### Phase 5: Refactor Orchestration

**Effort**: High
**Risk**: High

- Extract application services from TavernCoordinator
- Move ChatViewModel logic into Messaging Context
- Consolidate session management
- Update UI to consume context interfaces

This phase completes the migration.


### Estimated Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1 | 1-2 days | 2 days |
| Phase 2 | 3-5 days | 7 days |
| Phase 3 | 5-7 days | 14 days |
| Phase 4 | 5-7 days | 21 days |
| Phase 5 | 7-10 days | 31 days |

Total: 4-5 weeks for full migration. Phases 1-2 can be done incrementally alongside feature work.


## Open Questions


### 1. Context Ownership of Jake

Jake is unique: eternal, per-project, coordinator role. Should Jake be:
- A special entity in Agent Management Context?
- A separate Jake Context?
- Part of Orchestration/Coordination Context?

Current code treats Jake as an agent with special behavior. DDD would likely keep Jake in Agent Management with explicit singleton semantics.


### 2. Where Does Orchestration Live?

TavernCoordinator currently orchestrates agents, UI state, and spawning. In DDD:
- Should orchestration be an application service layer above contexts?
- Should it be a dedicated Orchestration Context?

Application service layer seems appropriate: orchestration calls into contexts but doesn't own domain logic.


### 3. Event Sourcing Hybrid

The PRD mentions "rewind and branch" capability. This suggests event sourcing might be valuable:
- Should we event-source agent state transitions?
- Should we event-source message history?

This could be a future enhancement layered on top of DDD contexts.


### 4. Progressive Unlock Scope

Section 8 of the PRD describes progressive unlocks for naming themes, cogitation verbs, and Jake's vocabulary. Where does this live?
- Naming Context for themes
- Messaging Context for cogitation verbs
- Separate Engagement/Gamification Context?

Probably a separate Engagement Context if the feature grows, or distributed across existing contexts if small.


### 5. Multi-Project Boundaries

ProjectManager owns multiple TavernProjects. Each project has its own contexts. Are contexts:
- Instantiated per-project (current model)?
- Singletons with project-scoped data?

Per-project instantiation aligns with current code and keeps projects isolated.


## Comparison with Other Proposals


### vs. Flat Coordinator (01)

Flat Coordinator collapses coordination into one type. DDD expands it into multiple bounded contexts. These are opposite philosophies:
- Flat Coordinator: "Simple now, refactor later if needed"
- DDD: "Structured now, pay upfront for future flexibility"

DDD is appropriate if the domain is complex enough to justify boundaries. Flat Coordinator is appropriate if simplicity matters more than isolation.


### vs. Actor Model (02)

Actor Model focuses on concurrency through isolated actors. DDD focuses on domain boundaries through bounded contexts. They can coexist:
- Contexts could be implemented as actors
- Domain events map naturally to actor messages

Actor Model is orthogonal to DDD; they solve different problems.


### vs. Document-Centric (03)

Document-Centric makes files the organizing principle. DDD makes domains the organizing principle. In DDD, Document Context provides infrastructure that other contexts use.

These can coexist: Document Context implements file-as-document semantics; other contexts use it through repositories.


### vs. Event Sourced (05)

Event Sourcing stores state as event streams. DDD uses domain events for cross-context communication. They complement each other:
- DDD provides bounded contexts
- Event Sourcing provides the persistence model within contexts

Event Sourcing could be adopted within DDD contexts without changing context boundaries.


## Conclusion

Domain-Driven Design offers a principled way to organize the Tavern codebase around business capabilities rather than technical layers. The current codebase already exhibits implicit domain boundaries that DDD would make explicit.

**Strengths for Tavern**:
- Clear separation of verification logic from agent behavior (matches PRD invariant #3)
- Messaging isolated from agent lifecycle
- Naming as an independent concern (supports progressive unlocks)
- Repository abstraction over doc store (matches PRD "doc store is source of truth")

**Weaknesses for Tavern**:
- Significant upfront investment for v1 scope
- Ceremony may slow iteration during rapid prototyping
- Small team may not need formal boundaries

**Recommendation**: Consider a hybrid approach:
1. Adopt strong types and repository interfaces (low cost, high value)
2. Defer full context boundaries until complexity warrants
3. Use domain events for cross-component communication where coupling is problematic
4. Revisit full DDD migration when scaling beyond v1 scope

This gives many DDD benefits without full commitment to the ceremony.
