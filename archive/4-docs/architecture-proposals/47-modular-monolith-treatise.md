# Modular Monolith Architecture - Full Treatise


## Research Findings


### Current Codebase Module Candidates

The existing TavernCore directory structure reveals natural module boundaries:

```
TavernCore/
├── Agents/           → AgentsModule
│   ├── Agent.swift
│   ├── AnyAgent.swift
│   ├── Jake.swift
│   ├── MortalAgent.swift
│   ├── AgentRegistry.swift
│   └── AgentSpawner.swift
│
├── Chat/             → ChatModule
│   ├── ChatMessage.swift
│   └── ChatViewModel.swift
│
├── Commitments/      → VerificationModule
│   ├── Commitment.swift
│   ├── CommitmentList.swift
│   └── CommitmentVerifier.swift
│
├── Coordination/     → (absorbed into AgentsModule or becomes thin orchestration layer)
│   └── TavernCoordinator.swift
│
├── DocStore/         → PersistenceModule
│   ├── Document.swift
│   ├── DocStore.swift
│   ├── AgentNode.swift
│   └── AgentPersistence.swift
│
├── Errors/           → Shared (cross-cutting concern)
│   ├── TavernError.swift
│   └── TavernErrorMessages.swift
│
├── Logging/          → Shared (cross-cutting concern)
│   └── TavernLogger.swift
│
├── Naming/           → AgentsModule (or separate NamingModule)
│   ├── NamingTheme.swift
│   └── NameGenerator.swift
│
├── Persistence/      → PersistenceModule
│   └── SessionStore.swift
│
├── Project/          → Application Shell (not a module)
│   ├── TavernProject.swift
│   └── ProjectManager.swift
│
├── Registry/         → AgentsModule
│   └── (currently empty or merged with Agents/)
│
├── Testing/          → Test Support (not deployed)
│   ├── MockClaudeCode.swift
│   └── TestFixtures.swift
│
└── UI/               → ChatModule (bridge layer)
    ├── AgentListItem.swift
    └── AgentListViewModel.swift
```


### Identified Modules

After analyzing the code and PRD, these modules emerge:

**1. AgentsModule**
- Owns: Agent protocol, Jake, MortalAgent, AgentRegistry, AgentSpawner, NameGenerator
- Exports: `AgentOrchestration` (spawning), `AgentQuery` (lookups), `AgentData` (immutable view)
- Depends on: PersistenceModule (session storage), External ClaudeCodeSDK
- Private: All implementation classes, state machine logic, registry internals

**2. ChatModule**
- Owns: ChatViewModel, ChatMessage, message history management
- Exports: `ChatService` (send/receive), `MessageHistory` (query)
- Depends on: AgentsModule (to get agent references), PersistenceModule (history storage)
- Private: View model internals, cogitation state, input handling

**3. VerificationModule**
- Owns: Commitment, CommitmentList, CommitmentVerifier, assertion runners
- Exports: `CommitmentVerification` (verify), `AssertionRunner` protocol
- Depends on: Nothing (pure verification logic)
- Private: Shell execution, verification state machine

**4. PersistenceModule**
- Owns: SessionStore, DocStore, Document, AgentNode, AgentPersistence
- Exports: `SessionPersistence` (session CRUD), `DocumentStorage` (doc CRUD)
- Depends on: Nothing (wraps external storage)
- Private: File layout, serialization, UserDefaults keys


### Module Interface Analysis

Looking at current cross-cutting dependencies:

**Jake.swift imports:**
- Foundation, ClaudeCodeSDK, os.log
- Uses: SessionStore (load/save session)
- Needs to export: send() method, state, sessionId

**MortalAgent.swift imports:**
- Foundation, ClaudeCodeSDK, os.log
- Uses: SessionStore, CommitmentList, CommitmentVerifier
- Cross-module calls: verification after completion

**ChatViewModel.swift imports:**
- Foundation, Combine, os.log, ClaudeCodeSDK
- Uses: AnyAgent (wraps Jake or MortalAgent), SessionStore (history loading)
- Cross-module calls: agent.send(), SessionStore.loadJakeSessionHistory()

**TavernCoordinator.swift imports:**
- Foundation, os.log
- Uses: Jake, AgentSpawner, ChatViewModel, AgentListViewModel
- Orchestrates across: AgentsModule, ChatModule


### What "Module" Means in Swift

Swift doesn't have a first-class "module" concept beyond SPM packages. Options for enforcing boundaries:

**Option A: Multiple SPM Packages**
```
LocalPackages/
├── AgentsModule/
│   ├── Package.swift
│   └── Sources/
├── ChatModule/
├── VerificationModule/
├── PersistenceModule/
└── TavernShared/  (errors, logging)
```
- Pros: True compile-time isolation, can't accidentally import private types
- Cons: More build complexity, dependency management overhead

**Option B: Single Package with Internal Discipline**
```
TavernCore/
├── Agents/
│   ├── Public/
│   │   └── AgentOrchestration.swift  (protocol)
│   └── Internal/
│       └── Jake.swift  (implementation)
```
- Pros: Simple build, single dependency
- Cons: Requires developer discipline, no compile-time enforcement

**Option C: Hybrid - Modules as Extensions**
```
TavernCore/
├── TavernCore.swift  (main module entry)
├── Agents/
│   ├── AgentsModule.swift  (public facade)
│   └── ... (internal files)
```
- Pros: Clear entry points, moderate isolation
- Cons: Still single package, discipline required


### How This Differs from Monolithic Core (#16)

The Monolithic Core proposal advocates collapsing everything into a single `TavernCore` class with agents as data structs. Key differences:

| Aspect | Monolithic Core (#16) | Modular Monolith (#47) |
|--------|----------------------|------------------------|
| **Agent representation** | Structs with no behavior | Classes with encapsulated behavior |
| **State ownership** | One class owns all state | Each module owns its domain state |
| **Thread safety** | Eliminated (MainActor only) | Preserved within modules |
| **Testing granularity** | Test the monolith | Test each module interface |
| **Refactoring path** | Refactor when needed | Pre-structured for extraction |
| **Number of files** | Minimal (~5 total) | Many (~20+), organized by module |
| **Protocol usage** | Minimal | Heavy (module interfaces) |
| **Future extraction** | Major refactor required | Surgical extraction possible |

**The key philosophical difference:** Monolithic Core says "collapse until you hit a wall." Modular Monolith says "structure for the future while deploying simply."

Monolithic Core is appropriate if:
- You believe the current complexity is over-engineering
- You want to ship v1 with minimal structure
- You're comfortable refactoring from flat to structured later

Modular Monolith is appropriate if:
- You believe the current structure is correct but needs cleaner boundaries
- You want to preserve the ability to extract modules
- You prefer upfront structure over later refactoring


## Module Communication Patterns


### Sync Protocol Calls (Primary)

Most module-to-module communication is synchronous protocol calls:

```swift
// AgentsModule exposes
public protocol AgentOrchestration {
    func spawn(assignment: String) throws -> AgentHandle
    func dismiss(id: UUID) throws
    func send(_ message: String, to agentId: UUID) async throws -> String
}

// ChatModule uses it
class ChatViewModel {
    private let agents: AgentOrchestration  // injected

    func sendMessage() async {
        let response = try await agents.send(inputText, to: agentId)
        // handle response
    }
}
```

Benefits:
- Type-safe at compile time
- Debuggable with standard tools
- No serialization overhead


### Event/Delegate Pattern (For Notifications)

When modules need to notify others of state changes without tight coupling:

```swift
// AgentsModule defines
public protocol AgentEventDelegate: AnyObject {
    func agentDidChangeState(_ agentId: UUID, newState: AgentState)
    func agentDidComplete(_ agentId: UUID, result: AgentResult)
}

// AgentsModule implementation
class AgentSpawnerImpl {
    weak var delegate: AgentEventDelegate?

    func handleAgentCompletion(_ agent: MortalAgent) {
        delegate?.agentDidComplete(agent.id, result: agent.result)
    }
}

// ChatModule implements delegate
extension ChatModule: AgentEventDelegate {
    func agentDidComplete(_ agentId: UUID, result: AgentResult) {
        // Update UI, add completion message
    }
}
```


### Shared Types (Value Types Only)

Modules share data via value types, never reference types:

```swift
// Shared across all modules
public struct AgentData: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let state: AgentState
    public let assignment: String?
    public let isJake: Bool
}

public enum AgentState: String, Sendable {
    case idle, working, waiting, verifying, done
}

public struct ChatMessage: Identifiable, Sendable {
    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date
    public let messageType: MessageType
}
```

This prevents modules from holding references to each other's internal objects.


## Trade-offs Considered


### Protocol Overhead vs Flexibility

Every module interface is a protocol. This adds:
- One protocol definition per capability
- Implementations must conform
- Tests need mock implementations

But enables:
- Swapping implementations (mock for tests, real for production)
- Future extraction to services
- Clear documentation of module capabilities


### Boundary Placement

Considered alternatives for module boundaries:

**Option: Verification inside AgentsModule**
- Pro: Agents and their commitments are tightly coupled
- Con: Verification logic is independently testable and could be extracted

**Decision: Separate VerificationModule**
- Matches PRD's "deterministic shell around non-deterministic agents"
- Verification could run in isolated environment for security
- Clean interface: `verify(commitment:) -> Bool`

**Option: Chat as part of AgentsModule**
- Pro: Messages go to agents, feels related
- Con: UI/ViewModel concerns are different from agent orchestration

**Decision: Separate ChatModule**
- UI bridge logic shouldn't be mixed with agent lifecycle
- Message history is its own domain
- Different change frequency (UI evolves faster than agent model)


### Cross-Cutting Concerns

Some concerns span all modules:

**Logging (TavernLogger)**
- Used by every module
- Solution: Shared utility, not a module. Imported everywhere.

**Error Types (TavernError)**
- Thrown by multiple modules
- Solution: Shared type in a `TavernShared` package/namespace

**Testing Support**
- MockClaudeCode, TestFixtures used in tests
- Solution: Separate test target, not part of production modules


## Implementation Complexity


### File Count Comparison

| Approach | Estimated Files | Notes |
|----------|-----------------|-------|
| Current | ~28 | Mixed concerns within directories |
| Monolithic Core | ~5-8 | Collapsed into few files |
| Modular Monolith | ~35-40 | More protocols, clearer separation |

The increase comes from:
- Protocol definitions for each module API
- Facade classes that implement protocols and delegate to internals
- Clearer separation of public vs internal types


### Module Structure Template

Each module follows this pattern:

```
AgentsModule/
├── Public/
│   ├── AgentOrchestration.swift   # Protocol definition
│   ├── AgentData.swift            # Exported value types
│   └── AgentsModuleFacade.swift   # Factory/entry point
├── Internal/
│   ├── Jake.swift
│   ├── MortalAgent.swift
│   ├── AgentRegistry.swift
│   ├── AgentSpawner.swift
│   └── NameGenerator.swift
└── Tests/
    ├── AgentSpawnerTests.swift
    └── MockAgentOrchestration.swift
```


### Dependency Injection Setup

Modules are wired at application startup:

```swift
// TavernApp.swift or similar
@MainActor
func createModules(projectPath: String, claude: ClaudeCode) -> ModuleContainer {
    // Create modules bottom-up (dependencies first)
    let persistence = PersistenceModuleFacade(
        sessionStore: SessionStore(),
        docStore: try! DocStore(rootDirectory: projectPath)
    )

    let verification = VerificationModuleFacade(
        runner: ShellAssertionRunner()
    )

    let agents = AgentsModuleFacade(
        claude: claude,
        persistence: persistence,
        verification: verification
    )

    let chat = ChatModuleFacade(
        agents: agents,
        persistence: persistence
    )

    return ModuleContainer(
        agents: agents,
        chat: chat,
        verification: verification,
        persistence: persistence
    )
}
```


## Migration Path from Current State


### Phase 1: Define Module Interfaces

Without changing implementation, define the protocols:

1. Create `AgentOrchestration` protocol based on `AgentSpawner` + `TavernCoordinator` methods
2. Create `ChatService` protocol based on `ChatViewModel` public methods
3. Create `CommitmentVerification` protocol based on `CommitmentVerifier`
4. Create `SessionPersistence` protocol based on `SessionStore`

This is additive - existing code keeps working.


### Phase 2: Create Facade Implementations

Each module gets a facade that implements the protocol and delegates:

```swift
public class AgentsModuleFacade: AgentOrchestration {
    private let spawner: AgentSpawner
    private let registry: AgentRegistry

    public func spawn(assignment: String) throws -> AgentHandle {
        let agent = try spawner.spawn(assignment: assignment)
        return AgentHandle(id: agent.id, name: agent.name)
    }
}
```


### Phase 3: Inject Protocols Instead of Implementations

Update consuming code to accept protocols:

```swift
// Before
class ChatViewModel {
    let agent: AnyAgent  // concrete type
}

// After
class ChatViewModel {
    let agentService: AgentOrchestration  // protocol
}
```


### Phase 4: Reorganize Files

Move files into module directories. Mark implementation types as `internal`. This is mechanical reorganization once phases 1-3 are complete.


### Phase 5: Extract to Packages (Optional)

If stronger isolation is needed:

1. Create `LocalPackages/AgentsModule/`
2. Move Public/ files, update import paths
3. Repeat for each module

This makes boundary violations a compile error.


### Rollback Points

Each phase is independently deployable:
- After Phase 1: Protocols exist but aren't used. Safe.
- After Phase 2: Facades exist alongside old code. Safe.
- After Phase 3: Using protocols but same behavior. Safe.
- After Phase 4: Files reorganized but same functionality. Safe.

If any phase reveals problems, stop there. Partial modularization is still valuable.


## Open Questions


### How Does ClaudeCodeSDK Fit?

Currently Jake and MortalAgent import ClaudeCodeSDK directly. Options:

**Option A: SDK stays at module edge**
- AgentsModule imports SDK, uses it internally
- Other modules never see SDK types
- Pro: Simple, matches current code
- Con: AgentsModule is coupled to specific SDK

**Option B: Abstract SDK behind port**
- Define `LLMPort` protocol in AgentsModule
- `ClaudeCodeAdapter` implements it
- Pro: Could swap LLM backends
- Con: Extra indirection

**Recommendation:** Option A for v1. The SDK is a local fork we control. Abstraction can be added later if needed. Don't pay the complexity cost until there's a second LLM backend.


### Where Does TavernCoordinator Go?

TavernCoordinator currently orchestrates across agents and chat. Options:

**Option A: Absorbed into AgentsModule**
- Agent lifecycle coordination is AgentsModule's job
- Chat creation can be a separate concern

**Option B: Becomes the "Application Shell"**
- TavernCoordinator becomes thin orchestration that wires modules
- Lives outside any module, at the application level

**Recommendation:** Option B. The coordinator's job is to wire modules together, which is application-level concern. It should call module protocols, not implement them.


### Per-Project Module Instances?

Currently each TavernProject has its own coordinator, Jake, etc. In modular terms:

```swift
class TavernProject {
    let modules: ModuleContainer  // Each project gets its own module instances
}
```

Modules are not singletons. Each project instantiates its own set. The ProjectManager holds projects, not modules.


### How Do Modules Share Threading Model?

Current code uses:
- @MainActor for ViewModels and coordinators
- DispatchQueue for agent state protection

In modular design:
- Module APIs are @MainActor (called from UI)
- Module internals manage their own threading
- Cross-module data is Sendable value types

This matches current approach but makes it explicit per-module.


### What About the Naming Module?

NameGenerator is currently tightly coupled to AgentSpawner. Options:

**Option A: Keep in AgentsModule**
- Names are assigned at spawn time
- Natural coupling

**Option B: Separate NamingModule**
- Themes could be extended independently
- Progressive unlock logic is its own concern

**Recommendation:** Option A for v1. If naming gets complex enough to warrant separation, extract later. Currently it's ~150 lines.


## Comparison with Related Architectures


### vs Hexagonal (#21)

Hexagonal focuses on ports and adapters for external systems. Modular Monolith focuses on internal organization. They can be combined:
- Each module has its own ports for external dependencies
- Modules communicate via protocols (like internal ports)

Key difference: Hexagonal doesn't prescribe internal structure. Modular Monolith is about that internal structure.


### vs Clean Architecture (#22)

Clean Architecture has concentric layers (entities, use cases, adapters). Modular Monolith has vertical slices (agents, chat, verification). They can be combined:
- Each module could use Clean Architecture internally
- Modules represent bounded contexts, not layers

Key difference: Clean Architecture is about dependency direction. Modular Monolith is about domain boundaries.


### vs Microkernel (#26)

Microkernel has a minimal kernel with loadable modules. Modular Monolith has regular modules with clear interfaces. Difference:
- Microkernel: Kernel provides message passing, modules provide all capability
- Modular Monolith: Modules are statically linked, communicate directly

Microkernel is more flexible but more complex. Modular Monolith is simpler but less radically extensible.


## Recommendation

The Modular Monolith is well-suited for Tavern because:

1. **The current codebase already shows module-shaped structure** - Directories like `Agents/`, `Chat/`, `Commitments/` are natural module boundaries waiting to be formalized

2. **The PRD anticipates future extraction** - Sandboxing, containers, and distributed agents are mentioned. Having module interfaces ready makes this easier

3. **Testing requirements align** - "Every feature must be testable" is easier with module interfaces than with a collapsed monolith

4. **Team discipline is manageable** - With 1-3 developers, maintaining interface boundaries is achievable

5. **The migration path is incremental** - Each phase adds value and is reversible

However, if the team decides the current structure is over-engineered and wants to move faster, the Monolithic Core (#16) is a valid alternative that trades future flexibility for present simplicity.

**Key insight:** The choice between Modular Monolith and Monolithic Core is philosophical. Do you structure for the future you expect, or optimize for the present you have? Neither is wrong; they're different bets on how the project will evolve.
