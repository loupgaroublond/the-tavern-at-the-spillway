# Hexagonal Architecture for Tavern: Complete Analysis

This document captures all research, thinking, and recommendations for applying Hexagonal Architecture (Ports & Adapters) to the Tavern multi-agent orchestrator.


## Research Findings


### Current Codebase State

The codebase already exhibits proto-hexagonal patterns, though not consistently applied:

**Existing Protocol Abstractions (Potential Ports):**
- `ClaudeCode` - Already an abstraction over the SDK, with `MockClaudeCode` as a test adapter
- `AssertionRunner` - Protocol for running shell assertions, with `ShellAssertionRunner` and `MockAssertionRunner`
- `Agent` - Protocol defining common agent interface, enabling `AnyAgent` type erasure

**Direct Infrastructure Dependencies (Candidates for Port Extraction):**
- `Jake.swift` imports `ClaudeCodeSDK` directly (line 2)
- `MortalAgent.swift` imports `ClaudeCodeSDK` directly
- `SessionStore` uses `UserDefaults.standard` as a singleton
- `TavernProject` calls `ClaudeCodeClient(configuration:)` directly
- `DocStore` wraps `FileManager` directly
- `CommitmentVerifier` depends on `Process` for shell execution

**Current Testing Strategy:**
- `MockClaudeCode` demonstrates the pattern: inject mock via constructor
- Tests exist for core logic without API calls
- Pattern is established but not systematically applied


### PRD Alignment Analysis

Key PRD requirements and how hexagonal addresses them:

| PRD Requirement | Hexagonal Solution |
|-----------------|-------------------|
| "Commitments must be verified independently" | Verification logic in domain; `AssertionRunner` port abstracts execution |
| "Every feature must be testable" | All external deps behind ports; pure domain logic is trivially testable |
| "Doc store is source of truth" | `PersistencePort` abstracts storage; domain doesn't know if it's files or DB |
| "Deterministic shell around non-deterministic agents" | Port layer IS the deterministic shell |
| "Agents cannot modify their own invariants" | Rules layer is domain; agents interact only through defined ports |
| "Test suite must pass before any feature ships" | Hexagonal's mock-friendly design enables comprehensive testing |
| "Sandbox isolation orthogonal to git/worktrees" | `SandboxPort` abstracts all isolation strategies |


### Module Dependency Analysis

Current dependency flow:
```
TavernApp (UI)
    └── TavernCore
            ├── Agents (Jake, MortalAgent)
            │       └── ClaudeCodeSDK
            ├── Coordination (TavernCoordinator, AgentSpawner)
            │       └── ClaudeCodeSDK
            ├── Persistence (SessionStore, DocStore)
            │       └── Foundation (UserDefaults, FileManager)
            ├── Commitments (CommitmentVerifier)
            │       └── Foundation (Process)
            └── Chat (ChatViewModel)
                    └── ClaudeCodeSDK (via ClaudeStoredMessage)
```

Problems:
1. `ClaudeCodeSDK` is imported in 6+ files
2. `SessionStore` uses global singleton `UserDefaults.standard`
3. `DocStore` directly instantiates `FileManager.default`
4. No clear boundary between "what can be mocked" and "what must be real"


## Port Inventory


### Driving Ports (Inbound)

These define how external actors can invoke domain operations.

**1. AgentOrchestrationPort**
```swift
public protocol AgentOrchestrationPort: Sendable {
    func spawnAgent(assignment: String) async throws -> AgentIdentity
    func dismissAgent(id: UUID) async throws
    func selectAgent(id: UUID) async
    var activeAgents: [AgentIdentity] { get async }
}
```
Implemented by: `TavernCoordinator`
Driven by: SwiftUI views, test harnesses, future CLI


**2. ChatPort**
```swift
public protocol ChatPort: Sendable {
    func sendMessage(_ text: String, to agentId: UUID) async throws -> ChatResponse
    func loadHistory(for agentId: UUID) async -> [ChatMessage]
    func clearConversation(for agentId: UUID) async
}
```
Implemented by: Domain service wrapping agent interactions
Driven by: ChatView, tests


**3. ProjectLifecyclePort**
```swift
public protocol ProjectLifecyclePort: Sendable {
    func openProject(at url: URL) async throws -> ProjectIdentity
    func closeProject(id: UUID) async
    var openProjects: [ProjectIdentity] { get async }
}
```
Implemented by: `ProjectManager`
Driven by: App-level UI, window management


### Driven Ports (Outbound)

These define how the domain reaches external systems.

**4. LLMPort**
```swift
public protocol LLMPort: Sendable {
    func send(
        prompt: String,
        systemPrompt: String?,
        sessionId: String?
    ) async throws -> LLMResponse

    func resumeSession(
        sessionId: String,
        prompt: String,
        systemPrompt: String?
    ) async throws -> LLMResponse
}

public struct LLMResponse: Sendable {
    public let text: String
    public let sessionId: String
    public let contentBlocks: [ContentBlock]
    public let cost: Decimal?
}
```
Current implementation: `ClaudeCodeAdapter` wrapping `ClaudeCodeClient`
Future: Could support local models, GPT, Gemini


**5. SessionPersistencePort**
```swift
public protocol SessionPersistencePort: Sendable {
    func saveSession(id: String, for scope: SessionScope) async
    func loadSession(for scope: SessionScope) async -> String?
    func clearSession(for scope: SessionScope) async
    func loadSessionHistory(for scope: SessionScope) async -> [StoredMessage]
}

public enum SessionScope: Sendable {
    case jake(projectPath: String)
    case agent(agentId: UUID)
}
```
Current implementation: `UserDefaultsSessionAdapter`
Alternative: Could use DocStore, SQLite, or external service


**6. DocumentPersistencePort**
```swift
public protocol DocumentPersistencePort: Sendable {
    func save(_ document: Document) async throws
    func load(id: String) async throws -> Document
    func delete(id: String) async throws
    func list() async throws -> [String]
}
```
Current implementation: `FileSystemDocAdapter` (wraps current DocStore)
Future: Could support cloud sync, distributed storage


**7. ProcessExecutionPort**
```swift
public protocol ProcessExecutionPort: Sendable {
    func execute(
        command: String,
        workingDirectory: URL?,
        timeout: Duration?
    ) async throws -> ProcessResult
}

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
}
```
Current implementation: `ShellProcessAdapter`
Note: `AssertionRunner` becomes a thin wrapper or merges into this


**8. SandboxPort (Future)**
```swift
public protocol SandboxPort: Sendable {
    func createChangeset(baseDirectory: URL) async throws -> ChangesetHandle
    func applyChangeset(_ handle: ChangesetHandle) async throws
    func discardChangeset(_ handle: ChangesetHandle) async throws
    func diff(_ handle: ChangesetHandle) async throws -> ChangesetDiff
}
```
Deferred for v1 per PRD, but architecture leaves room


## Adapter Inventory


### Primary (Driving) Adapters

**SwiftUI Adapter Layer**
- `ContentView` → calls `AgentOrchestrationPort`
- `ChatView` → calls `ChatPort`
- `WelcomeView` → calls `ProjectLifecyclePort`

These are thin shells that translate UI events into port calls.


**Test Adapter Layer**
- `MockAgentOrchestration` → implements `AgentOrchestrationPort` for UI testing
- Direct domain instantiation → for unit testing domain logic


### Secondary (Driven) Adapters

**ClaudeCodeAdapter**
```swift
public final class ClaudeCodeAdapter: LLMPort, @unchecked Sendable {
    private let client: ClaudeCode

    public init(configuration: ClaudeCodeConfiguration) throws {
        self.client = try ClaudeCodeClient(configuration: configuration)
    }

    public func send(...) async throws -> LLMResponse {
        // Translate to/from ClaudeCodeSDK types
    }
}
```


**UserDefaultsSessionAdapter**
```swift
public final class UserDefaultsSessionAdapter: SessionPersistencePort, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "com.tavern") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    // Implement port methods using UserDefaults
}
```


**FileSystemDocAdapter**
```swift
public final class FileSystemDocAdapter: DocumentPersistencePort, @unchecked Sendable {
    private let fileManager: FileManager
    private let rootDirectory: URL

    // Wraps existing DocStore logic
}
```


**MockLLMAdapter (for testing)**
```swift
public final class MockLLMAdapter: LLMPort, @unchecked Sendable {
    public var queuedResponses: [LLMResponse] = []
    public var sentPrompts: [String] = []
    // etc. - similar to current MockClaudeCode
}
```


## Trade-offs Considered


### Indirection vs Clarity

**Cost:** Following code flow requires more jumping. `Jake.send()` → `LLMPort.send()` → `ClaudeCodeAdapter.send()` → `ClaudeCodeClient.runSinglePrompt()`.

**Benefit:** Each layer has one job. Jake knows nothing about JSON output formats. Adapter knows nothing about agent states. Clean separation of concerns.

**Verdict:** Worth it. The domain is complex enough that protecting it from infrastructure churn pays dividends.


### Protocol Proliferation

**Cost:** 8 ports = 8 protocols = lots of ceremony. Simple operations (save session ID) require protocol conformance.

**Benefit:** Every external dependency is explicit and documented. Impossible to accidentally couple to infrastructure.

**Mitigation:** Group related operations into cohesive ports. `SessionPersistencePort` handles all session concerns rather than having `SaveSessionPort`, `LoadSessionPort`, etc.


### Async Boundaries

**Cost:** Swift's `Sendable` requirements at port boundaries can force awkward designs. Passing `@MainActor` view models through ports is problematic.

**Mitigation:**
1. Ports operate on value types (`AgentIdentity`, `LLMResponse`) not reference types
2. `@MainActor` stays in the driving adapter layer (SwiftUI), not in ports
3. Domain objects that need thread safety use internal `DispatchQueue` (existing pattern)

**Example transformation:**
```swift
// Before: TavernCoordinator returns MortalAgent (reference type)
public func spawnAgent(assignment: String) throws -> MortalAgent

// After: Port returns AgentIdentity (value type)
public func spawnAgent(assignment: String) async throws -> AgentIdentity

// AgentIdentity is Sendable and carries the essential data
public struct AgentIdentity: Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let assignment: String
}
```


### Over-Abstraction Risk

**Concern:** Is `UserDefaults.standard` worth abstracting? It's stable, simple, and unlikely to change.

**Counter-argument:**
1. Testing without clearing global state requires abstraction anyway
2. Consistency is valuable - one pattern, applied everywhere
3. Migration scenarios exist (e.g., move to DocStore for cross-device sync)

**Verdict:** Abstract everything, but keep adapter implementations thin.


## Implementation Complexity


### Estimated Effort by Phase

**Phase 1: Port Protocol Definition** (1-2 days)
- Define all 8 port protocols in `Sources/TavernCore/Ports/`
- Create supporting value types (`LLMResponse`, `AgentIdentity`, etc.)
- No behavior changes yet

**Phase 2: Adapter Extraction** (2-3 days)
- Create `Sources/TavernCore/Adapters/` directory
- Move `MockClaudeCode` → `MockLLMAdapter`
- Create `ClaudeCodeAdapter` implementing `LLMPort`
- Create `UserDefaultsSessionAdapter`
- Create `FileSystemDocAdapter`
- Create `ShellProcessAdapter`

**Phase 3: Domain Refactoring** (3-4 days)
- Jake receives `LLMPort` instead of `ClaudeCode`
- MortalAgent receives `LLMPort` and `SessionPersistencePort`
- TavernCoordinator receives `AgentOrchestrationPort` (or becomes it)
- CommitmentVerifier receives `ProcessExecutionPort`
- Update all initializers to inject ports

**Phase 4: Test Migration** (1-2 days)
- Update existing tests to use port-based mocks
- Add integration tests that wire real adapters
- Verify test coverage maintained

**Total:** 7-11 days of focused work


### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking tests during migration | Medium | Medium | Migrate one component at a time; run tests after each |
| Sendable violations at boundaries | High | Low | Design ports around value types from start |
| Performance overhead from indirection | Low | Low | Swift's protocol witness tables are efficient |
| Scope creep adding "nice to have" ports | Medium | Medium | Strict adherence to "extract what exists, no new features" |


## Migration Path from Current State


### Step 0: Prepare

- [ ] Create `Sources/TavernCore/Ports/` directory
- [ ] Create `Sources/TavernCore/Adapters/` directory
- [ ] Document current test coverage baseline


### Step 1: Extract LLMPort (Highest Value)

This is the most impactful extraction because `ClaudeCodeSDK` is imported everywhere.

```swift
// Sources/TavernCore/Ports/LLMPort.swift
public protocol LLMPort: Sendable {
    func send(prompt: String, systemPrompt: String?, sessionId: String?) async throws -> LLMResponse
    func resume(sessionId: String, prompt: String, systemPrompt: String?) async throws -> LLMResponse
}
```

```swift
// Sources/TavernCore/Adapters/ClaudeCodeAdapter.swift
public final class ClaudeCodeAdapter: LLMPort, @unchecked Sendable {
    private let client: ClaudeCode
    // ... implementation
}
```

Update order:
1. Create `LLMPort` and `LLMResponse`
2. Create `ClaudeCodeAdapter`
3. Update `Jake.init` to accept `LLMPort`
4. Update `MortalAgent.init` to accept `LLMPort`
5. Update `TavernProject` to create adapter and inject
6. Convert `MockClaudeCode` to `MockLLMAdapter`
7. Update all tests


### Step 2: Extract SessionPersistencePort

```swift
public protocol SessionPersistencePort: Sendable { ... }
```

- Move `SessionStore` static methods into `UserDefaultsSessionAdapter`
- Inject adapter into Jake and MortalAgent
- Update tests to use mock adapter


### Step 3: Extract ProcessExecutionPort

```swift
public protocol ProcessExecutionPort: Sendable { ... }
```

- `ShellAssertionRunner` becomes `ShellProcessAdapter`
- `MockAssertionRunner` becomes `MockProcessAdapter`
- `CommitmentVerifier` receives port in constructor
- Existing pattern is already close to this


### Step 4: Extract DocumentPersistencePort

```swift
public protocol DocumentPersistencePort: Sendable { ... }
```

- `DocStore` becomes `FileSystemDocAdapter`
- Domain types that use DocStore receive port instead


### Step 5: Define Driving Ports

Once driven ports are stable:
- Formalize `AgentOrchestrationPort` interface
- Formalize `ChatPort` interface
- Create documentation for driving adapter implementers


## Open Questions


### Q1: Should ports be synchronous or asynchronous?

**Options:**
- A) All ports are `async` for consistency
- B) Ports match their adapter's nature (sync for UserDefaults, async for LLM)

**Recommendation:** Option A. Even if an adapter is sync internally, making the port async:
- Future-proofs for async adapter implementations
- Aligns with Swift concurrency best practices
- Small overhead for sync operations


### Q2: Where do port protocols live?

**Options:**
- A) Single `Ports.swift` file
- B) One file per port in `Ports/` directory
- C) Co-located with domain types that use them

**Recommendation:** Option B. One file per port keeps things organized and enables clear imports.


### Q3: Should driving and driven ports be distinguished by naming convention?

**Options:**
- A) All named `*Port` (current proposal)
- B) Driving = `*Use Case`, Driven = `*Port`
- C) Driving = `*Input`, Driven = `*Output`

**Recommendation:** Option A. Swift doesn't need Hungarian notation; the module structure (`Ports/Driving/`, `Ports/Driven/`) or documentation suffices.


### Q4: How to handle port failures?

**Options:**
- A) Ports throw, adapters translate infrastructure errors to domain errors
- B) Ports return `Result<T, PortError>`, domain handles explicitly
- C) Ports define error protocols, adapters throw conforming errors

**Recommendation:** Option C. Define:
```swift
public protocol LLMError: Error {
    var isRecoverable: Bool { get }
    var localizedDescription: String { get }
}
```

Adapters throw concrete types conforming to `LLMError`. Domain can handle generically.


### Q5: What about the ClaudeNativeSessionStorage dependency?

The `SessionStore.loadJakeSessionHistory()` method uses `ClaudeNativeSessionStorage` from the SDK to load full message history.

**Options:**
- A) Include history loading in `LLMPort`
- B) Separate `SessionHistoryPort` for reading historical messages
- C) Include in `SessionPersistencePort` (awkward - persistence shouldn't need SDK types)

**Recommendation:** Option B. Clean separation:
- `SessionPersistencePort` handles IDs
- `SessionHistoryPort` handles full message retrieval
- Only `ClaudeHistoryAdapter` needs SDK import


### Q6: How to handle TavernProject's dual role?

`TavernProject` currently both:
1. Represents a project (domain concept)
2. Creates `ClaudeCode` instances (infrastructure concern)

**Recommendation:** Split responsibilities:
- `TavernProject` remains a domain entity
- New `ProjectInfrastructure` factory creates adapters
- `TavernProject` receives pre-configured adapters


## Conclusion

Hexagonal Architecture is a strong fit for Tavern because:

1. **The domain is rich** - Agent orchestration, commitment verification, and state management form meaningful business logic worth protecting

2. **External dependencies are volatile** - ClaudeCodeSDK is a local fork under active development; isolating it prevents churn from bleeding into domain code

3. **Testability is paramount** - The PRD's testing requirements align perfectly with hexagonal's mock-friendly design

4. **Growth is expected** - The architecture accommodates future LLM backends, sandbox strategies, and persistence options without domain changes

The migration path is incremental and low-risk. The existing codebase already demonstrates the key pattern (protocol + mock + injection) for `ClaudeCode` and `AssertionRunner`. Extending this systematically creates a clean, testable, maintainable architecture.

The main trade-off is increased indirection and protocol ceremony. For a project of Tavern's ambition (multi-agent orchestration with sandboxing, verification, and work queues), this trade-off is worthwhile.
