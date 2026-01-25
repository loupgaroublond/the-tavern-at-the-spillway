# Vertical Slices Architecture: Complete Analysis

This document contains the full research, rationale, and trade-off analysis for the Vertical Slices architecture proposal.


## 1. Research Findings: Current Architecture


### 1.1 Current Directory Structure (Horizontal Layers)

The TavernCore framework organizes code by technical responsibility:

```
Sources/TavernCore/
├── Agents/               # Agent protocol, Jake, MortalAgent, Registry, Spawner
├── Chat/                 # ChatMessage, ChatViewModel
├── Commitments/          # Commitment, CommitmentList, CommitmentVerifier
├── Coordination/         # TavernCoordinator
├── DocStore/             # Document, DocStore, AgentNode, AgentPersistence
├── Errors/               # TavernError, TavernErrorMessages
├── Logging/              # TavernLogger
├── Naming/               # NameGenerator, NamingTheme
├── Persistence/          # SessionStore
├── Project/              # TavernProject, ProjectManager
├── Registry/             # (empty or merged with Agents)
├── Testing/              # MockClaudeCode, TestFixtures
└── UI/                   # AgentListViewModel, AgentListItem
```

Each directory represents a technical layer:
- **Agents/**: Domain entities and identity management
- **Chat/**: Conversation state and view models
- **Commitments/**: Verification subsystem
- **Coordination/**: Glue between components
- **Persistence/**: Storage abstractions


### 1.2 How Features Cross Layers

**Spawn Agent Operation** touches:
- `Coordination/TavernCoordinator.swift` - entry point, UI state updates
- `Agents/AgentSpawner.swift` - creation logic
- `Agents/AgentRegistry.swift` - identity storage
- `Naming/NameGenerator.swift` - name assignment
- `UI/AgentListViewModel.swift` - list refresh
- `Chat/ChatViewModel.swift` - chat session creation
- `Persistence/SessionStore.swift` - session ID storage

**Send Message Operation** touches:
- `Chat/ChatViewModel.swift` - entry point, message append
- `Agents/Jake.swift` or `Agents/MortalAgent.swift` - SDK call
- `Persistence/SessionStore.swift` - session persistence
- `Errors/TavernErrorMessages.swift` - error mapping
- `Commitments/` - completion signal detection (for MortalAgent)

**Verify Commitment Operation** touches:
- `Agents/MortalAgent.swift` - completion signal detection
- `Commitments/CommitmentList.swift` - status tracking
- `Commitments/CommitmentVerifier.swift` - assertion execution
- `Commitments/Commitment.swift` - individual commitment state


### 1.3 Current Coupling Patterns

**Tight coupling within layers:**
- `AgentSpawner` depends on `AgentRegistry`, `NameGenerator`, and a ClaudeCode factory
- `TavernCoordinator` depends on `Jake`, `AgentSpawner`, `AgentListViewModel`
- `ChatViewModel` depends on `AnyAgent`, `ChatMessage`, `TavernError`

**Loose coupling between layers:**
- Layers communicate via protocols (`Agent`, `AssertionRunner`)
- Dependency injection is used throughout
- No circular dependencies detected

**Cross-cutting concerns:**
- `TavernLogger` is imported everywhere
- `os.log` patterns repeated across files
- Error handling follows consistent but informal patterns


### 1.4 File Sizes and Complexity

| File | Lines | Responsibility |
|------|-------|----------------|
| Jake.swift | 191 | SDK interaction, session management, character prompt |
| MortalAgent.swift | 275 | SDK interaction, state machine, commitment integration |
| TavernCoordinator.swift | 144 | Selection, spawn/dismiss delegation, view model cache |
| AgentSpawner.swift | 131 | Creation, registration, dismissal |
| ChatViewModel.swift | 259 | Message management, cogitation state, history loading |
| CommitmentVerifier.swift | 240 | Assertion execution, mock runner |
| SessionStore.swift | 123 | UserDefaults persistence |
| AgentRegistry.swift | 102 | Thread-safe identity storage |
| DocStore.swift | 204 | File-based document CRUD |

The largest files (Jake, MortalAgent, ChatViewModel, CommitmentVerifier) contain complete feature implementations within a single type. The layered structure already trends toward feature cohesion within files.


## 2. Identifying the Slices

A vertical slice represents a complete user operation from UI trigger to persistence. Based on the PRD and current implementation, these are the natural slices:


### 2.1 Core User Operations (Primary Slices)

**SpawnAgent**
- Trigger: User clicks spawn button or Jake decides to delegate
- Components: SpawnAgentHandler, AgentRegistration, NameAssignment, ChatViewModelFactory
- Persistence: SessionStore (agent session), AgentRegistry (identity)
- Tests: Spawn with assignment, name uniqueness, UI updates

**SendMessage**
- Trigger: User submits message in chat
- Components: SendMessageHandler, ConversationState, SDKBridge
- Persistence: SessionStore (session continuity), message history
- Tests: Message append, cogitation state, error handling, history reload

**DismissAgent**
- Trigger: User dismisses or agent completes
- Components: DismissAgentHandler, RegistryCleanup, SessionCleanup
- Persistence: SessionStore (clear), Registry (remove)
- Tests: Dismiss updates list, selection fallback, session cleared

**VerifyCommitment**
- Trigger: Agent signals completion
- Components: VerifyHandler, AssertionRunner, StatusUpdater
- Persistence: Commitment status (in-memory currently)
- Tests: Pass/fail flows, retry logic, state transitions

**SelectAgent**
- Trigger: User clicks agent in list
- Components: SelectAgentHandler, ChatViewModelCache, ListSelectionState
- Persistence: None (UI state only)
- Tests: Selection updates view model, Jake always selectable


### 2.2 Infrastructure Operations (Support Slices)

**LoadProject**
- Trigger: App launch or project open
- Components: ProjectLoader, JakeInitialization, SessionRestoration
- Persistence: Recent projects list, Jake session
- Tests: Fresh project, existing session, corrupt session recovery

**ResetConversation**
- Trigger: User clears chat
- Components: ResetHandler, SessionClearer
- Persistence: SessionStore (clear)
- Tests: Messages cleared, session reset, error cleared

**RecoverSession**
- Trigger: Corrupt session detected
- Components: RecoveryHandler, SessionMigration
- Persistence: SessionStore
- Tests: Recovery UI shown, fresh start works


### 2.3 Future Slices (from PRD)

**DelegateTask** (not yet implemented)
- Jake spawns agent with specific assignment and monitors completion

**VerifyAllCommitments** (not yet implemented)
- Batch verification before marking agent done

**ReapAgent** (not yet implemented)
- Fish-or-cut-bait termination

**PerseveranceMode** (not yet implemented)
- Auto-prompting background agents

**WorkQueue** (not yet implemented)
- Agent attachment to shared work queues


## 3. Proposed Directory Structure


### 3.1 Slice-Based Organization

```
Sources/TavernCore/
├── Features/
│   ├── SpawnAgent/
│   │   ├── SpawnAgentHandler.swift      # Business logic
│   │   ├── SpawnAgentViewModel.swift    # UI state (if separate from sheet)
│   │   ├── AgentRegistration.swift      # Registry operations for spawn
│   │   ├── NameAssignment.swift         # Name generation for spawn
│   │   └── SpawnAgentTests.swift        # (or in Tests/ mirroring structure)
│   │
│   ├── SendMessage/
│   │   ├── SendMessageHandler.swift     # Message flow logic
│   │   ├── ConversationState.swift      # In-progress message state
│   │   ├── CogitationManager.swift      # Thinking indicator logic
│   │   └── MessagePersistence.swift     # Session continuity
│   │
│   ├── DismissAgent/
│   │   ├── DismissAgentHandler.swift
│   │   ├── RegistryCleanup.swift
│   │   └── SessionCleanup.swift
│   │
│   ├── VerifyCommitment/
│   │   ├── VerifyHandler.swift
│   │   ├── AssertionRunner.swift        # Move from Commitments/
│   │   ├── VerificationResult.swift
│   │   └── MockAssertionRunner.swift
│   │
│   ├── SelectAgent/
│   │   ├── SelectAgentHandler.swift
│   │   └── ChatViewModelCache.swift
│   │
│   ├── LoadProject/
│   │   ├── ProjectLoader.swift
│   │   ├── JakeInitialization.swift
│   │   └── SessionRestoration.swift
│   │
│   └── AgentList/
│       ├── AgentListSlice.swift         # Combines list + selection
│       ├── AgentListItem.swift          # Move from UI/
│       └── AgentListViewModel.swift     # Move from UI/
│
├── Domain/
│   ├── Agent.swift                      # Protocol + AgentState
│   ├── Jake.swift                       # Jake implementation
│   ├── MortalAgent.swift                # MortalAgent implementation
│   ├── Commitment.swift                 # Commitment value type
│   └── CommitmentList.swift             # Thread-safe collection
│
├── Infrastructure/
│   ├── ClaudeSDK/
│   │   ├── SDKBridge.swift              # ClaudeCode wrapper
│   │   └── MockClaudeCode.swift
│   │
│   ├── Persistence/
│   │   ├── SessionStore.swift
│   │   ├── DocStore.swift
│   │   └── Document.swift
│   │
│   ├── Naming/
│   │   ├── NameGenerator.swift
│   │   └── NamingTheme.swift
│   │
│   └── Logging/
│       └── TavernLogger.swift
│
├── Errors/
│   ├── TavernError.swift
│   └── TavernErrorMessages.swift
│
└── Coordination/
    └── TavernCoordinator.swift          # Thin orchestrator dispatching to slices
```


### 3.2 What Goes Where

**Features/** - Vertical slices. Each folder is a complete operation.

**Domain/** - Pure domain entities shared across slices. No infrastructure dependencies. Agent, Commitment, AgentState live here because they are referenced by multiple slices.

**Infrastructure/** - Technical implementations. SDK wrappers, persistence, logging. Slices import from here but infrastructure never imports from Features.

**Coordination/** - Thin layer that dispatches user actions to appropriate slices. TavernCoordinator becomes a router, not an implementer.


## 4. How This Differs from Current Structure


### 4.1 Philosophical Shift

**Current (Layered):**
- "What is this code?" drives organization
- Agents are in Agents/, chat code is in Chat/
- To understand a feature, read across directories

**Proposed (Sliced):**
- "What does this code do?" drives organization
- Spawning code is in SpawnAgent/, messaging code is in SendMessage/
- To understand a feature, read one directory


### 4.2 Concrete File Movements

| Current Location | Proposed Location | Rationale |
|------------------|-------------------|-----------|
| Agents/AgentSpawner.swift | Features/SpawnAgent/SpawnAgentHandler.swift | Spawner IS the spawn handler |
| Agents/AgentRegistry.swift | Features/SpawnAgent/AgentRegistration.swift | Registry serves spawn/dismiss |
| Naming/NameGenerator.swift | Infrastructure/Naming/ | Shared by multiple slices |
| Chat/ChatViewModel.swift | Features/SendMessage/ (partially) | Message sending logic |
| Chat/ChatMessage.swift | Domain/ or Infrastructure/ | Data structure |
| Commitments/CommitmentVerifier.swift | Features/VerifyCommitment/ | Complete verification slice |
| UI/AgentListViewModel.swift | Features/AgentList/ | List is a feature |
| Coordination/TavernCoordinator.swift | Coordination/ (slimmed) | Becomes router only |


### 4.3 Code That Stays Put

Some code doesn't change location:
- `Jake.swift` and `MortalAgent.swift` stay in Domain/ as core entities
- `SessionStore.swift` stays in Infrastructure/ as shared persistence
- `TavernLogger.swift` stays in Infrastructure/ as shared utility
- `TavernError.swift` stays in Errors/ as shared error types


## 5. Trade-offs Considered


### 5.1 Duplication vs. Isolation

**Risk**: SpawnAgent and DismissAgent both need registry operations. Do they duplicate or share?

**Resolution**: Extract minimal shared types to Domain/ or Infrastructure/. AgentIdentity (id, name) is shared. Registration/cleanup logic stays in slices. Accept some duplication of patterns (not copy-paste code) for isolation benefit.


### 5.2 Slice Size

**Risk**: Some slices are tiny (SelectAgent is ~50 lines), others are large (SendMessage is ~300 lines).

**Resolution**: Accept variance. Tiny slices are fine. Large slices can be split into Handler + Helpers within the folder. The key is cohesion, not uniformity.


### 5.3 Cross-Slice Dependencies

**Risk**: What if SpawnAgent needs to immediately trigger SendMessage (e.g., "introduce yourself")?

**Resolution**:
1. Handler returns result, caller decides what to do next
2. Coordinator orchestrates multi-slice flows
3. Avoid direct slice-to-slice imports

**Example flow:**
```swift
// In TavernCoordinator
func spawnAndGreet(assignment: String) async throws {
    let agent = try await spawnAgentSlice.spawn(assignment: assignment)
    await sendMessageSlice.send(to: agent, message: "What's your assignment?")
}
```


### 5.4 Testing Granularity

**Current**: Unit tests mock layers (MockClaudeCode injected into Jake).

**Proposed**: Slice tests use real slice code with mocked infrastructure. Test the slice as a unit.

**Trade-off**: Fewer but more comprehensive tests. Easier to write, potentially slower to run.


### 5.5 IDE Navigation

**Current**: Cmd+Shift+O "Chat" finds all chat files grouped together.

**Proposed**: Cmd+Shift+O "Chat" finds ChatViewModel in SendMessage/, ChatMessage in Domain/.

**Mitigation**: Learn to search by feature name. "Spawn" finds SpawnAgent/. This mirrors how users think.


## 6. Implementation Complexity


### 6.1 Migration Effort Estimate

| Phase | Effort | Risk |
|-------|--------|------|
| Create Features/ structure | Low | Minimal (additive) |
| Move SpawnAgent slice | Medium | Tests validate |
| Move SendMessage slice | Medium | Core flow, needs care |
| Move VerifyCommitment slice | Low | Isolated subsystem |
| Slim TavernCoordinator | Medium | Behavior must match |
| Update imports everywhere | Low but tedious | Compiler catches issues |
| Verify all tests pass | Low | Tests are comprehensive |

**Total estimate**: 4-8 hours of focused work.


### 6.2 Risk Points

1. **ChatViewModel split**: Currently handles both message display and sending. May need to split into DisplayState and SendHandler.

2. **TavernCoordinator behavior**: Currently does selection, spawn, dismiss. Needs to remain thin router while preserving exact behavior.

3. **AgentRegistry thread safety**: Currently isolated in one file. If split across slices, thread safety boundaries must be clear.


### 6.3 Reversibility

High. The migration is mechanical (move files, update imports). If slices prove wrong, files can be moved back. No fundamental abstractions are destroyed.


## 7. Migration Path


### 7.1 Phase 1: Create Structure (Non-Breaking)

1. Create `Features/` directory
2. Create first slice: `SpawnAgent/`
3. Move SpawnAgentHandler (new file, copies logic from AgentSpawner)
4. Keep AgentSpawner as facade delegating to handler
5. Add tests for handler
6. Verify existing tests pass


### 7.2 Phase 2: Migrate Core Slices

1. Migrate SendMessage slice
2. Migrate DismissAgent slice
3. Migrate VerifyCommitment slice
4. Each migration: move code, update imports, run tests


### 7.3 Phase 3: Slim Coordinator

1. TavernCoordinator becomes thin router
2. Each method delegates to appropriate slice handler
3. Verify UI behavior unchanged


### 7.4 Phase 4: Clean Up Layers

1. Remove empty layer directories
2. Consolidate Domain/ and Infrastructure/
3. Update CLAUDE.md and architecture-v1.md


### 7.5 Incremental Approach

Alternatively, migrate one slice per PR:
- PR 1: SpawnAgent slice
- PR 2: DismissAgent slice
- PR 3: SendMessage slice
- etc.

Each PR is independently reviewable and revertible.


## 8. Open Questions


### 8.1 Where Does AnyAgent Live?

`AnyAgent` is a type-erased wrapper used by Registry and ViewModels. Options:
1. Domain/AnyAgent.swift (it's a domain type)
2. Infrastructure/TypeErasure/AnyAgent.swift (it's a Swift pattern)
3. Features/AgentList/AnyAgent.swift (it's used for lists)

**Recommendation**: Domain/. It represents agents, even if type-erased.


### 8.2 How Do Slices Share State?

Multiple slices need the agent list (SpawnAgent updates it, DismissAgent updates it, AgentList displays it).

Options:
1. **Shared State Container**: `AgentStateStore` in Infrastructure/, slices read/write
2. **Event-Based**: Slices emit events, listeners update state
3. **Coordinator Owns State**: TavernCoordinator holds agents, slices receive/return

**Recommendation**: Option 3 for v1. Coordinator is already @MainActor and owns Jake. It can own the agent collection too. Slices receive needed data as parameters.


### 8.3 Testing Infrastructure Within Slices

Should MockAssertionRunner live in Features/VerifyCommitment/ or Infrastructure/Testing/?

**Arguments for slice-local**:
- Only VerifyCommitment needs it
- Co-located with code it mocks

**Arguments for shared**:
- Avoids duplication if other slices need mocks
- Consistent with MockClaudeCode

**Recommendation**: Keep in Infrastructure/Testing/ for consistency. Slices can import from there.


### 8.4 Feature Flags and Slice Enablement

If we want to disable a slice (e.g., VerifyCommitment not ready for production), how?

Options:
1. Compiler flags: `#if ENABLE_COMMITMENTS`
2. Runtime flags: Check feature flag before calling slice
3. Coordinator routing: Skip slice dispatch if disabled

**Recommendation**: Option 2 or 3. Compiler flags make code hard to read. Runtime flags in coordinator are clean.


### 8.5 Async Boundaries

Current code mixes sync and async. Slices should be async-first or sync-first?

**Current pattern**:
- Registry operations are sync (DispatchQueue)
- Claude SDK calls are async
- UI updates are @MainActor

**Recommendation**: Slice handlers are async. Internal sync operations are implementation detail. This matches Swift concurrency direction.


## 9. PRD Alignment


### 9.1 Requirements Addressed

| PRD Requirement | Vertical Slices Impact |
|-----------------|------------------------|
| Multiple agents in parallel | Slices are independent, can execute concurrently |
| User engages any agent at any depth | SelectAgent slice handles focus changes |
| Deterministic verification | VerifyCommitment slice is complete and isolated |
| Doc store as central nervous system | Slices read/write via Infrastructure/Persistence/ |
| Test suite must pass | Slice-level tests are comprehensive and focused |
| Every feature testable | Each slice is a testable unit |
| Commitments verified independently | VerifyCommitment slice has no business logic dependencies |


### 9.2 Requirements Neutral

| PRD Requirement | Impact |
|-----------------|--------|
| Jake spawns mortal agents | Same capability, different code location |
| Session persistence | Same SessionStore, used by slices |
| Agent naming themes | Same NameGenerator in Infrastructure/ |


### 9.3 Requirements Complicated

| PRD Requirement | Challenge |
|-----------------|-----------|
| Sandboxing with overlays (future) | May need cross-slice coordination |
| Work queues (future) | Multiple slices interact with queue state |
| Agent-to-agent communication (future) | Unclear which slice owns message routing |


## 10. Comparison to Other Proposals


### 10.1 vs. Flat Coordinator (#01)

Flat Coordinator collapses types into one. Vertical Slices expands into many.

- Flat Coordinator: Simpler at small scale, harder to navigate at large scale
- Vertical Slices: More structure, easier to find specific features

Both address the "where is the code?" problem differently.


### 10.2 vs. CQRS (#12)

CQRS separates commands (mutations) from queries (reads). Vertical Slices can incorporate CQRS within slices.

- SpawnAgent is a command slice
- AgentList is a query slice
- Both patterns can coexist

Vertical Slices is more general; CQRS is a specific pattern slices might use.


### 10.3 vs. Domain-Driven Design (#14)

DDD focuses on bounded contexts and aggregates. Vertical Slices can exist within a DDD structure.

- Domain/ is the aggregate root
- Slices are use cases operating on aggregates
- Infrastructure/ is anti-corruption layer

Not competing approaches; complementary.


### 10.4 vs. Clean Architecture (#22)

Clean Architecture mandates dependency inversion with layers pointing inward. Vertical Slices cut through layers.

- Clean: Entities -> Use Cases -> Interface Adapters -> Frameworks
- Slices: Each feature contains all layers

Vertical Slices explicitly rejects strict layering in favor of feature cohesion.


## 11. Recommendation

Vertical Slices is a **good fit** for Tavern because:

1. **Features are distinct**: Spawn, Send, Verify, Dismiss are clearly separate operations
2. **Team is small**: One developer, so isolation between team members isn't primary driver
3. **Rapid iteration**: Features change frequently; co-locating change surfaces helps
4. **Testing priority**: Slice-level tests match PRD's emphasis on testability
5. **Future features are known**: PRD outlines many future features (work queues, perseverance mode) that map cleanly to slices

**Caution points**:

1. **Shared agent state**: Need clear ownership (Coordinator holds, slices borrow)
2. **Unfamiliar pattern**: Requires deliberate onboarding
3. **Over-slicing risk**: Not every helper needs its own folder

**Suggested approach**: Migrate SpawnAgent as proof-of-concept. If it feels right, continue. If friction is high, reconsider.


## 12. Appendix: Example Slice Implementation


### SpawnAgentHandler.swift

```swift
import Foundation

/// Handler for the SpawnAgent operation
/// Contains all logic to spawn a new mortal agent
public actor SpawnAgentHandler {

    private let claudeFactory: () -> ClaudeCode
    private let nameGenerator: NameGenerator

    public init(
        claudeFactory: @escaping () -> ClaudeCode,
        nameGenerator: NameGenerator
    ) {
        self.claudeFactory = claudeFactory
        self.nameGenerator = nameGenerator
    }

    /// Spawn a new agent with the given assignment
    /// - Parameter assignment: Task description
    /// - Returns: The spawned agent and its generated name
    public func spawn(assignment: String) async throws -> SpawnResult {
        let name = nameGenerator.nextNameOrFallback()
        let claude = claudeFactory()

        let agent = MortalAgent(
            name: name,
            assignment: assignment,
            claude: claude
        )

        // Note: Registration happens in caller (Coordinator owns registry)
        return SpawnResult(agent: agent, name: name)
    }
}

public struct SpawnResult {
    public let agent: MortalAgent
    public let name: String
}
```


### Integration with Coordinator

```swift
// TavernCoordinator.swift (slimmed)
@MainActor
public final class TavernCoordinator: ObservableObject {

    // Slice handlers
    private let spawnHandler: SpawnAgentHandler
    private let dismissHandler: DismissAgentHandler

    // Shared state (Coordinator owns)
    private var agents: [UUID: MortalAgent] = [:]

    public func spawnAgent(assignment: String) async throws -> MortalAgent {
        let result = try await spawnHandler.spawn(assignment: assignment)

        // Coordinator handles registration and UI updates
        agents[result.agent.id] = result.agent
        refreshAgentList()

        return result.agent
    }
}
```

This pattern keeps handlers focused and coordinator thin.
