# Tavern v1 Architecture

A code inspection guide for the multi-agent orchestrator.


## Directory Structure

```
Tavern/
├── Package.swift              # SPM manifest
├── project.yml                # XcodeGen config
├── Sources/
│   ├── Tavern/                # SwiftUI App (thin shell)
│   │   ├── TavernApp.swift    # Entry point, dependency wiring
│   │   └── Views/
│   │       ├── ChatView.swift
│   │       └── AgentListView.swift
│   │
│   └── TavernCore/            # All business logic (testable, no UI)
│       ├── TavernCore.swift   # Module exports
│       ├── Agents/            # Agent system
│       ├── Chat/              # Chat view models
│       ├── Coordination/      # Orchestration
│       ├── Commitments/       # Verification system
│       ├── DocStore/          # File-based persistence
│       ├── Naming/            # Themed name generation
│       └── Testing/           # Mocks and fixtures
│
└── Tests/
    ├── TavernCoreTests/       # Unit tests for core
    └── TavernTests/           # Integration tests
```


## Module Dependency Graph

```
┌─────────────────────────────────────────────────────────────┐
│                        Tavern (App)                         │
│  TavernApp.swift creates coordinator, wires dependencies    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      TavernCore                             │
│  @_exported import ClaudeCodeSDK                            │
└─────────────────────────────────────────────────────────────┘
       │              │              │              │
       ▼              ▼              ▼              ▼
   Agents/       Coordination/    Chat/        DocStore/
       │              │              │
       └──────────────┼──────────────┘
                      ▼
              ClaudeCodeSDK (external)
```


## Core Types


### Agents (`Sources/TavernCore/Agents/`)

**`Agent` protocol** — Common interface for all agents.

```swift
public protocol Agent: AnyObject, Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var state: AgentState { get }
    func send(_ message: String) async throws -> String
    func resetConversation()
}
```

**`AgentState`** — Lifecycle states: `idle`, `working`, `waiting`, `verifying`, `done`.


**`Jake`** — The Proprietor. Eternal top-level agent.

- File: `Jake.swift`
- Has a static `systemPrompt` defining his character
- Uses `ClaudeCode` to communicate with Claude
- Maintains session ID for conversation continuity
- Thread-safe via `DispatchQueue`


**`MortalAgent`** — Worker agents spawned for tasks.

- File: `MortalAgent.swift`
- Has an `assignment` (their purpose)
- Has `CommitmentList` for verification before completion
- Signals completion via "DONE" in response
- Auto-transitions through: `idle` → `working` → `verifying` → `done`


**`AnyAgent`** — Type-erased wrapper for heterogeneous collections.


**`AgentRegistry`** — Thread-safe registry of all agents.

- File: `AgentRegistry.swift`
- Stores agents by ID and name
- Enforces name uniqueness


**`AgentSpawner`** — Factory for creating mortal agents.

- File: `AgentSpawner.swift`
- Depends on: `AgentRegistry`, `NameGenerator`, `ClaudeCode` factory
- Creates agents, registers them, handles dismissal


### Coordination (`Sources/TavernCore/Coordination/`)

**`TavernCoordinator`** — Central hub.

- File: `TavernCoordinator.swift`
- `@MainActor` (UI-bound)
- Owns: `Jake`, `AgentSpawner`
- Publishes: `agentListViewModel`, `activeChatViewModel`
- Handles: agent selection, spawning, dismissal


### Chat (`Sources/TavernCore/Chat/`)

**`ChatMessage`** — Single message with role (`.user` or `.agent`).

- File: `ChatMessage.swift`


**`ChatViewModel`** — View model for a conversation.

- File: `ChatViewModel.swift`
- `@MainActor` (UI-bound)
- Wraps any `Agent` via `AnyAgent`
- Manages: `messages`, `isCogitating`, `inputText`, `error`
- Has "cogitation verbs" for thinking indicator ("Pondering", "Scheming", etc.)


### Commitments (`Sources/TavernCore/Commitments/`)

**`Commitment`** — A verifiable assertion.

- File: `Commitment.swift`
- Contains: `description`, `assertion` (shell command), `status`
- Statuses: `pending`, `verifying`, `passed`, `failed`


**`CommitmentList`** — Thread-safe collection of commitments.

- File: `CommitmentList.swift`


**`CommitmentVerifier`** — Runs shell commands to verify assertions.

- File: `CommitmentVerifier.swift`
- Executes `assertion` via `/bin/bash -c`
- Success = exit code 0


### DocStore (`Sources/TavernCore/DocStore/`)

**`Document`** — Markdown with YAML frontmatter.

- File: `Document.swift`
- Contains: `id`, `title`, `metadata`, `content`, timestamps


**`DocStore`** — File-based document storage.

- File: `DocStore.swift`
- CRUD operations on markdown files
- Thread-safe via `DispatchQueue`


**`AgentNode`** — Document representing an agent's state.

- File: `AgentNode.swift`
- Serializes agent state to/from documents


**`AgentPersistence`** — Save/restore agents via DocStore.

- File: `AgentPersistence.swift`


### Naming (`Sources/TavernCore/Naming/`)

**`NamingTheme`** — Tiered list of themed names.

- File: `NamingTheme.swift`
- Built-in themes: `.lotr`, `.dune`, `.greek`, `.norse`, `.arthurian`
- Tiers for priority (heroes first, then secondary characters)


**`NameGenerator`** — Generates unique names.

- File: `NameGenerator.swift`
- Tracks used names
- Falls back to "Agent-N" when theme exhausted


### Testing (`Sources/TavernCore/Testing/`)

**`MockClaudeCode`** — Test double for `ClaudeCode`.

- File: `MockClaudeCode.swift`
- Queue responses, capture sent prompts
- Simulate errors, delays


**`TestFixtures`** — Factory for test objects.

- File: `TestFixtures.swift`


## Data Flow


### Message Flow (User → Agent → Response)

```
User types message
        │
        ▼
ChatView.sendMessage()
        │
        ▼
ChatViewModel.sendMessage()
    ├── Appends user message
    ├── Sets isCogitating = true
    │
    ▼
agent.send(text)
        │
        ▼
Jake/MortalAgent.send()
    ├── Sets state = .working
    ├── Calls ClaudeCode SDK
    │       ├── runSinglePrompt (new conversation)
    │       └── resumeConversation (existing session)
    ├── Extracts sessionId for continuity
    │
    ▼
Response returned
        │
        ▼
ChatViewModel receives response
    ├── Appends agent message
    ├── Sets isCogitating = false
    │
    ▼
SwiftUI updates ChatView
```


### Agent Spawning Flow

```
TavernCoordinator.spawnAgent(assignment:)
        │
        ▼
AgentSpawner.spawn(assignment:)
    ├── NameGenerator.nextNameOrFallback()
    ├── claudeFactory() → new ClaudeCode
    ├── Creates MortalAgent
    ├── AgentRegistry.register()
    │
    ▼
TavernCoordinator
    ├── Caches assignment for display
    ├── Refreshes agent list
    ├── Optionally selects new agent
```


### Commitment Verification Flow

```
MortalAgent response contains "DONE"
        │
        ▼
checkForCompletionSignal()
        │
        ▼
handleCompletionAttempt()
    ├── If no commitments: state = .done
    │
    ├── Else: state = .verifying
    │         │
    │         ▼
    │   CommitmentVerifier.verifyAll()
    │         │
    │         ├── For each commitment:
    │         │     Process.run(bash -c assertion)
    │         │     exit 0 → .passed
    │         │     exit !0 → .failed
    │         │
    │         ▼
    │   All passed? → state = .done
    │   Any failed? → state = .idle (agent must fix)
```


## Thread Safety Model

All mutable state is protected by serial `DispatchQueue`:

| Type | Queue Label | Protected State |
|------|-------------|-----------------|
| Jake | `com.tavern.Jake` | `_sessionId`, `_isCogitating` |
| MortalAgent | `com.tavern.MortalAgent` | `_state`, `_sessionId` |
| AgentRegistry | `com.tavern.AgentRegistry` | `_agents`, `_nameToId` |
| NameGenerator | `com.tavern.NameGenerator` | `_usedNames`, indices |
| CommitmentList | `com.tavern.CommitmentList` | `_commitments` |
| DocStore | `com.tavern.DocStore` | file operations |
| MockClaudeCode | `com.tavern.MockClaudeCode` | all mock state |

UI-bound types (`TavernCoordinator`, `ChatViewModel`, `AgentListViewModel`) use `@MainActor`.


## Entry Point

**`TavernApp.swift`** wires everything:

```swift
@main
struct TavernApp: App {
    @StateObject private var coordinator = TavernApp.createCoordinator()

    private static func createCoordinator() -> TavernCoordinator {
        let claude = try ClaudeCodeClient()      // Real SDK
        let jake = Jake(claude: claude)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            claudeFactory: { MockClaudeCode() }  // TODO: Real Claude for spawned agents
        )
        return TavernCoordinator(jake: jake, spawner: spawner)
    }
}
```

Note: Currently spawned agents use `MockClaudeCode` — marked TODO for real implementation.


## Testing Strategy

**Unit Tests** (`TavernCoreTests/`):
- All core logic is in `TavernCore` with no UI dependencies
- `MockClaudeCode` allows testing without API calls
- Inject mocks via constructor (dependency injection pattern)

**Key Test Files**:
- Agent state transitions
- Registry operations
- Name generation exhaustion
- Commitment verification
- DocStore CRUD

**Example Test Pattern**:

```swift
func testAgentTransitionsToWorking() async throws {
    let mock = MockClaudeCode()
    mock.queueJSONResponse(result: "Hello", sessionId: "test")

    let agent = MortalAgent(name: "Test", assignment: "Do stuff", claude: mock)
    XCTAssertEqual(agent.state, .idle)

    _ = try await agent.send("Go")
    // State was .working during call, back to .idle after
    XCTAssertEqual(agent.state, .idle)
}
```


## What's Not Implemented Yet

Per `v1-implementation-plan.md`, these are deferred:

- **Project root configuration** — Jake runs from undefined directory
- **Real Claude for spawned agents** — Currently mock
- **Sandboxing/overlays** — Agents have full access
- **Persistent agent recovery** — Agents lost on app restart
- **Streaming responses** — Batch only
- **Multi-agent coordination** — Jake doesn't delegate yet
