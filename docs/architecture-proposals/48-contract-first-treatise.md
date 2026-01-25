# Contract-First Architecture: Complete Analysis

This document contains the full research, rationale, and trade-off analysis for the Contract-First architecture proposal.


## 1. Research Findings: Current Contract Landscape


### 1.1 Existing Protocols in the Codebase

The current codebase already uses protocols in several places:

**`Agent` protocol** (`Agents/Agent.swift`)
```swift
public protocol Agent: AnyObject, Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var state: AgentState { get }
    func send(_ message: String) async throws -> String
    func resetConversation()
}
```

This is the most complete contract in the codebase. Both `Jake` and `MortalAgent` conform to it. The `AnyAgent` type eraser enables heterogeneous collections. This protocol demonstrates the value of Contract-First: code can work with any agent implementation without knowing the concrete type.


**`AssertionRunner` protocol** (`Commitments/CommitmentVerifier.swift`)
```swift
public protocol AssertionRunner: Sendable {
    func run(_ command: String) async throws -> AssertionResult
}
```

A well-designed contract with two implementations: `ShellAssertionRunner` (production) and `MockAssertionRunner` (testing). This enables commitment verification tests without running actual shell commands.


**`ClaudeCode` protocol** (from ClaudeCodeSDK)
```swift
public protocol ClaudeCode: Sendable {
    var configuration: ClaudeCodeConfiguration { get }
    func runSinglePrompt(...) async throws -> ClaudeCodeResult
    func resumeConversation(...) async throws -> ClaudeCodeResult
    func listSessions() async throws -> [SessionInfo]
    func cancel()
    func validateCommand(_ command: String) async throws -> Bool
}
```

The SDK provides this protocol, and `MockClaudeCode` already conforms to it. This is the pattern we would extend to internal components.


### 1.2 Missing Contracts (Implicit Interfaces)

Several major components lack formal protocols:

**TavernCoordinator** (no protocol)
- Methods: `selectAgent(id:)`, `spawnAgent(assignment:)`, `dismissAgent(id:)`, `refresh()`
- Properties: `jake`, `spawner`, `agentListViewModel`, `activeChatViewModel`
- Depends on: `Jake`, `AgentSpawner`
- Used by: `ContentView`, `AgentListView`, `ChatView`

**AgentSpawner** (no protocol)
- Methods: `spawn(assignment:)`, `spawn(name:assignment:)`, `dismiss(_:)`, `dismiss(id:)`
- Properties: `activeAgents`, `agentCount`
- Depends on: `AgentRegistry`, `NameGenerator`, `ClaudeCode` factory
- Used by: `TavernCoordinator`

**AgentRegistry** (no protocol)
- Methods: `register(_:)`, `remove(id:)`, `agent(id:)`, `agent(named:)`, `allAgents()`, `isNameTaken(_:)`, `removeAll()`
- Properties: `count`
- Used by: `AgentSpawner`

**DocStore** (no protocol)
- Methods: `create(_:)`, `read(id:)`, `update(_:)`, `delete(id:)`, `exists(id:)`, `listAll()`, `readAll()`, `save(_:)`
- Properties: `rootDirectory`, `fileExtension`
- Used by: (not yet heavily used, architecture reserve)

**SessionStore** (no protocol, static methods)
- Static methods: `loadJakeSession(projectPath:)`, `saveJakeSession(_:projectPath:)`, `clearJakeSession(projectPath:)`, etc.
- Used by: `Jake`, `MortalAgent`, `ChatViewModel`

**NameGenerator** (no protocol)
- Methods: `nextName()`, `nextNameOrFallback()`, `reserveName(_:)`, `releaseName(_:)`
- Properties: `theme`, `remainingNames`
- Used by: `AgentSpawner`


### 1.3 Dependency Graph Without Contracts

```
TavernProject
  --> TavernCoordinator (concrete)
       --> Jake (conforms to Agent)
       --> AgentSpawner (concrete)
            --> AgentRegistry (concrete)
            --> NameGenerator (concrete)
            --> ClaudeCode factory (protocol, good!)

ChatViewModel
  --> Agent (protocol, good!)
  --> SessionStore (static, untestable)

MortalAgent
  --> ClaudeCode (protocol, good!)
  --> CommitmentList (concrete)
  --> CommitmentVerifier (concrete)
       --> AssertionRunner (protocol, good!)
  --> SessionStore (static, untestable)
```

Observations:
1. External dependencies (`ClaudeCode`, `AssertionRunner`) have protocols
2. Internal components (Coordinator, Spawner, Registry) do not
3. `SessionStore` uses static methods, making it impossible to mock
4. Testing `TavernCoordinator` requires real `AgentSpawner` which requires real `AgentRegistry`


## 2. PRD Requirements Mapping


### 2.1 Requirements That Contracts Enable

| PRD Requirement | Contract Benefit |
|-----------------|------------------|
| **Commitment verification** (PRD 2.3, 4.7) | `CommitmentVerifying` protocol enables testing without shell |
| **Multiple agent types** (PRD 4.1) | `Agent` protocol already enables Jake + MortalAgent + future Drones |
| **Parallel development** (PRD 3) | Teams can implement different protocols concurrently |
| **Test suite required** (PRD 17) | Protocols make every component mockable |
| **Sandboxing** (PRD 4.6) | `SandboxProviding` protocol abstracts changeset/isolation |
| **Doc store as source of truth** (PRD 4.5) | `DocumentStoring` protocol enables in-memory test store |


### 2.2 Requirements That Contracts Complicate

| PRD Requirement | Contract Challenge |
|-----------------|-------------------|
| **Rapid iteration** (PRD 18) | Protocol changes are more expensive than implementation changes |
| **Small v1 scope** (PRD 18) | Upfront protocol design may over-engineer simple features |
| **Deterministic shell** (PRD 4.7) | Some verification logic is inherently implementation-specific |


### 2.3 Invariants Enforcement via Contracts

PRD Section 2 defines invariants. Contracts can enforce these at the type level:

```swift
/// Contract: Commitments must be verified independently
protocol CommitmentVerifying {
    /// Verify all commitments. Agent state changes only after this returns.
    func verifyAll(in list: CommitmentList) async throws -> Bool
}

/// Contract: Doc store is source of truth
protocol DocumentStoring {
    /// All state must be persistable. No in-memory-only state that matters.
    func save(_ document: Document) throws
    func read(id: String) throws -> Document
}

/// Contract: Failures must be visible
protocol AgentCoordinating {
    /// Errors must be surfaced, never swallowed. Logging is required.
    func spawnAgent(assignment: String) throws -> MortalAgent
}
```


## 3. Proposed Contract Hierarchy


### 3.1 Core Agent Contracts

**`Agent`** (existing, kept as-is)
```swift
public protocol Agent: AnyObject, Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var state: AgentState { get }
    func send(_ message: String) async throws -> String
    func resetConversation()
}
```

**`AgentCoordinating`** (new)
```swift
public protocol AgentCoordinating: AnyObject {
    var jake: any Agent { get }
    var activeAgents: [AnyAgent] { get }
    var selectedAgentId: UUID? { get }

    func selectAgent(id: UUID)
    func spawnAgent(assignment: String) throws -> MortalAgent
    func dismissAgent(id: UUID) throws
    func refresh()
}
```

**`AgentSpawning`** (new)
```swift
public protocol AgentSpawning: Sendable {
    var activeAgents: [AnyAgent] { get }
    var agentCount: Int { get }

    func spawn(assignment: String) throws -> MortalAgent
    func spawn(name: String, assignment: String) throws -> MortalAgent
    func dismiss(_ agent: MortalAgent) throws
    func dismiss(id: UUID) throws
}
```

**`AgentStoring`** (new)
```swift
public protocol AgentStoring: Sendable {
    var count: Int { get }

    func register<A: Agent>(_ agent: A) throws
    func remove(id: UUID) throws
    func agent(id: UUID) -> AnyAgent?
    func agent(named: String) -> AnyAgent?
    func allAgents() -> [AnyAgent]
    func isNameTaken(_ name: String) -> Bool
    func removeAll()
}
```


### 3.2 Commitment Contracts

**`CommitmentVerifying`** (new, extracts from CommitmentVerifier)
```swift
public protocol CommitmentVerifying: Sendable {
    func verify(_ commitment: inout Commitment, in list: CommitmentList?) async throws -> Bool
    func verifyAll(in list: CommitmentList) async throws -> Bool
    func retryFailed(in list: CommitmentList) async throws -> Bool
}
```

**`AssertionRunner`** (existing, kept as-is)
```swift
public protocol AssertionRunner: Sendable {
    func run(_ command: String) async throws -> AssertionResult
}
```


### 3.3 Persistence Contracts

**`DocumentStoring`** (new)
```swift
public protocol DocumentStoring: Sendable {
    var rootDirectory: URL { get }

    func create(_ document: Document) throws
    func read(id: String) throws -> Document
    func update(_ document: Document) throws
    func delete(id: String) throws
    func exists(id: String) -> Bool
    func listAll() throws -> [String]
    func readAll() throws -> [Document]
    func save(_ document: Document) throws
}
```

**`SessionPersisting`** (new, replaces static SessionStore)
```swift
public protocol SessionPersisting: Sendable {
    // Jake sessions (per-project)
    func loadJakeSession(projectPath: String) -> String?
    func saveJakeSession(_ sessionId: String, projectPath: String)
    func clearJakeSession(projectPath: String)
    func loadJakeSessionHistory(projectPath: String) async -> [ClaudeStoredMessage]

    // Agent sessions (per-agent)
    func loadAgentSession(agentId: UUID) -> String?
    func saveAgentSession(agentId: UUID, sessionId: String)
    func clearAgentSession(agentId: UUID)
}
```


### 3.4 Naming Contract

**`NameGenerating`** (new)
```swift
public protocol NameGenerating: Sendable {
    var theme: NamingTheme { get }
    var remainingNames: Int { get }

    func nextName() -> String?
    func nextNameOrFallback() -> String
    func reserveName(_ name: String) -> Bool
    func releaseName(_ name: String)
}
```


### 3.5 External Integration Contract

**`ClaudeCodeProviding`** (wrapper around SDK's ClaudeCode)
```swift
public protocol ClaudeCodeProviding: ClaudeCode {
    // Inherits all ClaudeCode requirements
    // Could add Tavern-specific extensions if needed
}

extension ClaudeCodeClient: ClaudeCodeProviding {}
```


## 4. Swift Protocol Capabilities and Limitations


### 4.1 What Swift Protocols Enable

**Protocol extensions** provide default implementations:
```swift
extension AgentStoring {
    func agent(id: UUID) -> AnyAgent? {
        allAgents().first { $0.id == id }
    }
}
```

**Protocol composition** enables precise dependencies:
```swift
func setup(coordinator: some AgentCoordinating & Observable) { ... }
```

**Existential types** enable heterogeneous storage:
```swift
var spawner: any AgentSpawning
```

**Opaque types** preserve type information:
```swift
func makeSpawner() -> some AgentSpawning { ... }
```


### 4.2 Swift Protocol Limitations

**No stored properties**: Protocols cannot require stored properties, only computed ones.
```swift
// Cannot do this:
protocol Foo { var cache: [String: Int] { get set } }

// Must do this:
protocol Foo {
    var cache: [String: Int] { get }
    func setCache(_ key: String, value: Int)
}
```

**Associated types complicate existentials**:
```swift
protocol Store {
    associatedtype Item
    func get() -> Item
}

// Cannot write: var stores: [any Store]
// Must constrain: var stores: [any Store<String>] (Swift 5.7+)
```

**Performance overhead**: Existential types (`any Protocol`) have runtime dispatch overhead. For hot paths, use `some Protocol` or generics.

**Retroactive conformance limits**: Cannot add conformance to types you don't own if the protocol uses `Self` requirements.


### 4.3 Mitigations for Limitations

**Property storage**: Use backing storage in conforming types.
```swift
protocol AgentStoring {
    func register(_ agent: AnyAgent) throws
}

class AgentRegistry: AgentStoring {
    private var _agents: [UUID: AnyAgent] = [:] // Implementation detail

    func register(_ agent: AnyAgent) throws {
        _agents[agent.id] = agent
    }
}
```

**Associated type alternatives**: Prefer concrete types or type erasure for simpler protocols.
```swift
// Instead of:
protocol Store { associatedtype Item; func get() -> Item }

// Use:
protocol DocumentStore { func get() -> Document }
```


## 5. Trade-offs Considered


### 5.1 Upfront Design vs. Emergent Design

**Contract-First approach**: Define protocols, then implement.
- Pro: Clear boundaries from start
- Pro: Parallel development enabled immediately
- Con: May over-design for unknown requirements
- Con: Protocol changes are expensive

**Emergent approach** (current): Implement, extract protocols when needed.
- Pro: Only abstract what's proven to need abstraction
- Pro: Faster initial development
- Con: Refactoring required to add protocols later
- Con: Tests often written against concrete types, harder to mock

**Recommendation**: Hybrid approach. Extract protocols for:
1. External dependencies (already done: ClaudeCode, AssertionRunner)
2. Components with multiple implementations (Agent protocol)
3. Components that need mocking for critical tests (SessionStore)

Do NOT extract protocols for:
1. Simple value types (ChatMessage, Document)
2. Components with genuinely single implementation


### 5.2 Protocol per Component vs. Minimal Protocols

**Maximal approach**: Every class has a protocol.
- 18 protocols for current 18 significant types
- Maximum flexibility, maximum ceremony

**Minimal approach**: Protocols only where polymorphism is needed.
- ~8 protocols (Agent, Coordinating, Spawning, Storing, Verifying, DocumentStoring, SessionPersisting, NameGenerating)
- Less ceremony, less flexibility

**Recommendation**: Minimal approach. Start with protocols where:
1. Multiple implementations exist or are planned
2. Testing requires mocking
3. Future replacement is likely (external dependencies)


### 5.3 Static SessionStore vs. Protocol Instance

**Current**: `SessionStore` uses static methods.
```swift
SessionStore.loadJakeSession(projectPath: path)
```

**Problem**: Cannot mock. Tests hit real UserDefaults.

**Contract-First solution**:
```swift
class Jake {
    private let sessionStore: any SessionPersisting

    init(claude: ClaudeCode, sessionStore: any SessionPersisting = UserDefaultsSessionStore()) {
        self.sessionStore = sessionStore
    }
}
```

**Impact**: Requires updating Jake, MortalAgent, ChatViewModel constructors. Moderate refactoring cost, significant testing benefit.


### 5.4 Protocol Extensions vs. Implementation Details

**Question**: Should protocol extensions provide shared logic?

**Example**:
```swift
extension AgentStoring {
    func agentExists(id: UUID) -> Bool {
        agent(id: id) != nil
    }
}
```

**Pro**: Shared implementation, DRY.
**Con**: Hides performance characteristics. A dictionary lookup is O(1), but the extension implies O(n) scan.

**Recommendation**: Protocol extensions for truly generic logic. Keep performance-sensitive methods as requirements.


## 6. Implementation Complexity


### 6.1 Estimated Effort

**Phase 1: Core Agent Contracts** (3-4 hours)
- Extract `AgentCoordinating` from `TavernCoordinator`
- Extract `AgentSpawning` from `AgentSpawner`
- Extract `AgentStoring` from `AgentRegistry`
- Update all usage sites to depend on protocols

**Phase 2: Persistence Contracts** (2-3 hours)
- Convert `SessionStore` from static to instance
- Extract `SessionPersisting` protocol
- Update Jake, MortalAgent, ChatViewModel
- Create `MockSessionStore`

**Phase 3: Verification Contracts** (1-2 hours)
- Extract `CommitmentVerifying` from `CommitmentVerifier`
- Update MortalAgent
- Create `MockCommitmentVerifier`

**Phase 4: Document Store Contract** (1 hour)
- Extract `DocumentStoring` from `DocStore`
- Create `InMemoryDocStore` for testing

**Phase 5: Naming Contract** (1 hour)
- Extract `NameGenerating` from `NameGenerator`
- Update AgentSpawner
- Create `MockNameGenerator`

**Phase 6: Update All Tests** (3-4 hours)
- Replace concrete types with mocks
- Add protocol conformance tests
- Verify coverage maintained

**Total: 11-15 hours**


### 6.2 Risk Assessment

**Low risk**: Protocols extracted from existing implementations match existing behavior.

**Medium risk**: `SessionStore` refactoring touches multiple components. Test thoroughly.

**Low risk**: Protocol extraction is additive. Existing code continues to work during migration.

**Medium risk**: Swift existential type limitations may require workarounds for some protocols.


### 6.3 Incremental Adoption Strategy

Unlike some architectures that require big-bang migration, Contract-First can be adopted incrementally:

1. **Week 1**: Extract `SessionPersisting` (highest test impact)
2. **Week 2**: Extract `AgentCoordinating`, `AgentSpawning`, `AgentStoring`
3. **Week 3**: Extract `CommitmentVerifying`, `DocumentStoring`
4. **Week 4**: Extract `NameGenerating`, finalize test migration

Each phase produces a working system. No "flag day" cutover required.


## 7. Migration Path


### 7.1 Phase 1: Extract AgentStoring

```swift
// Before (AgentRegistry.swift)
public final class AgentRegistry: @unchecked Sendable {
    public func register<A: Agent>(_ agent: A) throws { ... }
    public func agent(id: UUID) -> AnyAgent? { ... }
    // ...
}

// After (AgentStoring.swift + AgentRegistry.swift)
public protocol AgentStoring: Sendable {
    func register<A: Agent>(_ agent: A) throws
    func agent(id: UUID) -> AnyAgent?
    // ...
}

public final class AgentRegistry: AgentStoring, @unchecked Sendable {
    // Same implementation
}

// Test support (MockAgentRegistry.swift)
public final class MockAgentRegistry: AgentStoring {
    public var registeredAgents: [AnyAgent] = []
    public func register<A: Agent>(_ agent: A) throws {
        registeredAgents.append(AnyAgent(agent))
    }
    // ...
}
```


### 7.2 Phase 2: Update AgentSpawner to Use Protocol

```swift
// Before
public final class AgentSpawner {
    private let registry: AgentRegistry
    public init(registry: AgentRegistry, ...) { ... }
}

// After
public final class AgentSpawner: AgentSpawning {
    private let registry: any AgentStoring
    public init(registry: any AgentStoring, ...) { ... }
}
```


### 7.3 Phase 3: Convert SessionStore

```swift
// Before (static methods)
public enum SessionStore {
    public static func loadJakeSession(projectPath: String) -> String? {
        UserDefaults.standard.string(forKey: ...)
    }
}

// After (instance methods)
public protocol SessionPersisting: Sendable {
    func loadJakeSession(projectPath: String) -> String?
    func saveJakeSession(_ sessionId: String, projectPath: String)
    // ...
}

public final class UserDefaultsSessionStore: SessionPersisting {
    public func loadJakeSession(projectPath: String) -> String? {
        UserDefaults.standard.string(forKey: ...)
    }
}

// Backward compatibility (deprecated, remove later)
public enum SessionStore {
    private static let instance = UserDefaultsSessionStore()

    @available(*, deprecated, message: "Use injected SessionPersisting instead")
    public static func loadJakeSession(projectPath: String) -> String? {
        instance.loadJakeSession(projectPath: projectPath)
    }
}
```


### 7.4 Phase 4: Update Jake Constructor

```swift
// Before
public init(id: UUID = UUID(), claude: ClaudeCode, loadSavedSession: Bool = true) {
    // ...
    if loadSavedSession, let savedSession = SessionStore.loadJakeSession(projectPath: currentProjectPath) {
        self._sessionId = savedSession
    }
}

// After
public init(
    id: UUID = UUID(),
    claude: ClaudeCode,
    sessionStore: any SessionPersisting = UserDefaultsSessionStore(),
    loadSavedSession: Bool = true
) {
    self.sessionStore = sessionStore
    // ...
    if loadSavedSession, let savedSession = sessionStore.loadJakeSession(projectPath: currentProjectPath) {
        self._sessionId = savedSession
    }
}
```


## 8. Contract Documentation Standards


### 8.1 Protocol Documentation Requirements

Every protocol should document:
1. **Purpose**: What capability does this contract represent?
2. **Thread safety**: Is conformance required to be thread-safe?
3. **Error handling**: What errors can methods throw?
4. **Semantic constraints**: What invariants must implementations maintain?

Example:
```swift
/// A storage mechanism for agent identity and lookup.
///
/// ## Thread Safety
/// All implementations must be thread-safe. Methods may be called
/// concurrently from multiple isolation contexts.
///
/// ## Semantic Constraints
/// - Agent names must be unique. `register(_:)` throws if name exists.
/// - `agent(id:)` returns nil only if the agent was never registered
///   or was removed via `remove(id:)`.
/// - `count` reflects the current number of registered agents.
///
/// ## Error Handling
/// Methods that can fail throw `AgentRegistryError` cases.
public protocol AgentStoring: Sendable {
    // ...
}
```


### 8.2 Precondition and Postcondition Documentation

```swift
public protocol AgentSpawning {
    /// Spawn a new mortal agent.
    ///
    /// - Precondition: `assignment` is non-empty.
    /// - Postcondition: Returned agent is registered and has unique name.
    /// - Throws: `AgentRegistryError.nameAlreadyExists` if name collision
    ///   (should never happen with generated names).
    func spawn(assignment: String) throws -> MortalAgent
}
```


## 9. Testing Strategy with Contracts


### 9.1 Protocol Conformance Tests

Each protocol gets a test suite that any conforming type should pass:

```swift
func testAgentStoringConformance<S: AgentStoring>(_ store: S) throws {
    // Test 1: Empty store has count 0
    XCTAssertEqual(store.count, 0)

    // Test 2: Registration increases count
    let agent = MockAgent(name: "Test")
    try store.register(agent)
    XCTAssertEqual(store.count, 1)

    // Test 3: Lookup by ID works
    XCTAssertNotNil(store.agent(id: agent.id))

    // Test 4: Duplicate name throws
    let duplicate = MockAgent(name: "Test")
    XCTAssertThrowsError(try store.register(duplicate))

    // ... more tests
}

// Run conformance tests for each implementation
func testAgentRegistryConformance() throws {
    testAgentStoringConformance(AgentRegistry())
}

func testMockAgentRegistryConformance() throws {
    testAgentStoringConformance(MockAgentRegistry())
}
```


### 9.2 Mock Generation Pattern

Each protocol gets a standard mock:

```swift
public final class MockAgentStoring: AgentStoring {
    // Capture inputs for verification
    public var registeredAgents: [AnyAgent] = []
    public var removedIds: [UUID] = []

    // Configure outputs
    public var agentsToReturn: [UUID: AnyAgent] = [:]
    public var shouldThrowOnRegister: Error?

    // Protocol implementation
    public func register<A: Agent>(_ agent: A) throws {
        if let error = shouldThrowOnRegister { throw error }
        registeredAgents.append(AnyAgent(agent))
        agentsToReturn[agent.id] = AnyAgent(agent)
    }

    public func agent(id: UUID) -> AnyAgent? {
        agentsToReturn[id]
    }

    // ...
}
```


### 9.3 Integration Test Isolation

Contracts enable testing coordinator logic without real Claude:

```swift
func testCoordinatorSpawnsAgent() async throws {
    // Given: Mock dependencies
    let mockClaude = MockClaudeCode()
    mockClaude.queueJSONResponse(result: "Hello", sessionId: "test")

    let mockRegistry = MockAgentStoring()
    let mockNameGen = MockNameGenerating()
    mockNameGen.nextNameToReturn = "Gandalf"

    let spawner = AgentSpawner(
        registry: mockRegistry,
        nameGenerator: mockNameGen,
        claudeFactory: { mockClaude }
    )

    // When: Spawn agent
    let agent = try spawner.spawn(assignment: "Test task")

    // Then: Agent registered with correct name
    XCTAssertEqual(agent.name, "Gandalf")
    XCTAssertEqual(mockRegistry.registeredAgents.count, 1)
}
```


## 10. Open Questions


### 10.1 Protocol File Organization

**Option A**: One file per protocol + implementation
```
AgentStoring.swift (protocol only)
AgentRegistry.swift (implementation only)
MockAgentStoring.swift (mock only)
```

**Option B**: Protocol and primary implementation together
```
AgentRegistry.swift (protocol + implementation)
MockAgentRegistry.swift (mock)
```

**Option C**: Protocols in dedicated directory
```
Protocols/AgentStoring.swift
Implementations/AgentRegistry.swift
Testing/MockAgentStoring.swift
```

**Recommendation**: Option A for clarity. Protocols are design artifacts; separating them emphasizes this.


### 10.2 Existential vs. Generic Dependencies

**Existential (`any`)**:
```swift
class AgentSpawner {
    let registry: any AgentStoring
}
```
- Pro: Simple, flexible
- Con: Runtime dispatch overhead, cannot use with associated types

**Generic (`some` or generic parameter)**:
```swift
class AgentSpawner<R: AgentStoring> {
    let registry: R
}
```
- Pro: Static dispatch, full type information
- Con: Generic propagation, type erasure needed for storage

**Recommendation**: Use existentials (`any`) for most dependencies. Reserve generics for performance-critical paths.


### 10.3 Protocol Inheritance vs. Composition

**Inheritance**:
```swift
protocol AgentCoordinating: AgentSpawning, AgentStoring { ... }
```

**Composition**:
```swift
protocol AgentCoordinating {
    var spawner: any AgentSpawning { get }
    var registry: any AgentStoring { get }
}
```

**Recommendation**: Composition. Inheritance creates god-protocols. Composition keeps responsibilities clear.


### 10.4 Versioning Protocol Changes

**Question**: How do we evolve protocols without breaking conformers?

**Options**:
1. Protocol extensions with default implementations
2. `@available` annotations for new requirements
3. Semantic versioning with breaking change documentation

**Recommendation**: Protocol extensions for additive changes. Document breaking changes in CHANGELOG. Keep protocol changes minimal.


## 11. Relationship to Other Proposals

**Flat Coordinator (#01)**: Contract-First is orthogonal. You can flatten coordination while still using protocols. The flattened `ProjectCoordinator` would conform to `AgentCoordinating`.

**Actor Model (#02)**: Protocols can define actor-isolated methods using `@MainActor` or `nonisolated` annotations. Contract-First complements actors.

**Domain-Driven Design (#14)**: DDD uses interfaces at aggregate boundaries. Contract-First provides the Swift mechanism (protocols) for those interfaces.

**Plugin Architecture (#11)**: Plugins require stable protocols to conform to. Contract-First is a prerequisite for plugins.


## 12. Conclusion

Contract-First architecture is less a complete architecture and more an architectural discipline. It mandates that interfaces be designed before implementations, that protocols be the source of truth for component interactions, and that every dependency be injectable.

For the Tavern, this means:
1. **Immediate benefit**: Testability. `SessionStore` becomes mockable. Integration tests become isolated.
2. **Medium-term benefit**: Parallel development. Multiple agents can implement different components against stable contracts.
3. **Long-term benefit**: Evolvability. Swapping ClaudeCodeSDK for a different SDK requires only new conformance, not architectural changes.

The primary cost is upfront design time. Protocols must be thought through before implementation. This is a feature, not a bug: it forces architectural decisions to be explicit and documented.

**Recommended action**: Adopt Contract-First incrementally, starting with `SessionPersisting` (highest test impact) and `AgentStoring` (most reused). Evaluate after two weeks whether the discipline is providing value before extracting remaining protocols.
