# Onion Architecture: Complete Analysis

This document captures all research, thinking, and recommendations for applying Onion Architecture to the Tavern multi-agent orchestrator.


## 1. Research Findings


### 1.1 Current Architecture State

The current codebase has a two-tier structure: `TavernCore` (framework) and `Tavern` (app). Within TavernCore, organization is by feature area rather than layer:

**Directory Structure:**
```
TavernCore/
├── Agents/           # Jake, MortalAgent, AgentRegistry, AgentSpawner
├── Chat/             # ChatViewModel, ChatMessage
├── Commitments/      # Commitment, CommitmentList, CommitmentVerifier
├── Coordination/     # TavernCoordinator
├── DocStore/         # Document, DocStore, AgentNode, AgentPersistence
├── Errors/           # TavernError, TavernErrorMessages
├── Logging/          # TavernLogger
├── Naming/           # NamingTheme, NameGenerator
├── Persistence/      # SessionStore
├── Project/          # TavernProject, ProjectManager
├── Registry/         # AgentRegistry
├── Testing/          # MockClaudeCode, TestFixtures
└── UI/               # AgentListViewModel, AgentListItem
```

**Current Dependency Flow Analysis:**

Examining imports across files reveals a flat dependency graph:

| File | External Dependencies |
|------|----------------------|
| `Jake.swift` | ClaudeCodeSDK, os.log |
| `MortalAgent.swift` | ClaudeCodeSDK, os.log |
| `TavernCoordinator.swift` | os.log (no direct SDK) |
| `SessionStore.swift` | ClaudeCodeSDK (for ClaudeNativeSessionStorage) |
| `ChatViewModel.swift` | ClaudeCodeSDK (for ClaudeStoredMessage) |
| `TavernProject.swift` | ClaudeCodeSDK, os.log |
| `CommitmentVerifier.swift` | Foundation (Process) |
| `DocStore.swift` | Foundation (FileManager) |

**Key observation:** ClaudeCodeSDK is imported in 6+ files, including domain-level types like `Jake` and `MortalAgent`. Onion Architecture would require pushing all SDK references to the infrastructure layer.


### 1.2 Existing Patterns That Align with Onion

The codebase already demonstrates proto-Onion patterns:

**1. Protocol-based dependency injection:**
- `ClaudeCode` is a protocol, not a concrete class
- `MockClaudeCode` implements it for testing
- `Jake` and `MortalAgent` receive `ClaudeCode` via constructor injection

**2. Domain-ish value types:**
- `AgentState` enum is pure (no imports beyond Foundation)
- `Commitment` struct defines domain concept
- `ChatMessage` is a simple data carrier

**3. Infrastructure abstraction hints:**
- `AssertionRunner` protocol abstracts shell execution
- `ShellAssertionRunner` and `MockAssertionRunner` implement it

**Gaps from Onion ideal:**
- Domain types (Jake, MortalAgent) directly import ClaudeCodeSDK
- No explicit Domain Services layer (business logic mixed into entities)
- Application layer (TavernCoordinator) directly constructs infrastructure
- No DI container; wiring is ad-hoc in TavernProject


### 1.3 Lines of Code by Area

Current state:
- TavernCore: 28 Swift files, ~2000 lines
- Tavern (app): 6 Swift files, ~400 lines

Onion Architecture projection (applying four layers):

| Layer | Files | Lines |
|-------|-------|-------|
| Domain Model | 8-10 | 300-400 |
| Domain Services | 8-12 | 500-700 |
| Application Services | 6-10 | 400-600 |
| Infrastructure | 12-16 | 600-800 |
| DI/Composition | 2-4 | 100-200 |

Total: ~40-50 files, ~2000-2700 lines

This is roughly a 50% file count increase with moderate line growth (protocols, DI wiring).


## 2. Onion Layers for Tavern


### 2.1 Domain Model (Innermost Core)

The Domain Model contains pure entities and value objects with absolutely no dependencies on external frameworks. These types represent the core business concepts of the Tavern.

**What belongs here:**

```swift
// Domain/Model/AgentIdentity.swift
import Foundation

public struct AgentIdentity: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// Domain/Model/AgentState.swift
public enum AgentState: String, Equatable, Sendable {
    case idle
    case working
    case waiting
    case verifying
    case done

    public var canTransitionTo: Set<AgentState> {
        switch self {
        case .idle: return [.working]
        case .working: return [.idle, .waiting, .verifying]
        case .waiting: return [.working, .idle]
        case .verifying: return [.done, .idle]
        case .done: return []
        }
    }
}

// Domain/Model/Commitment.swift
public struct Commitment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let description: String
    public let assertion: String
    public var status: CommitmentStatus

    public init(
        id: UUID = UUID(),
        description: String,
        assertion: String,
        status: CommitmentStatus = .pending
    ) {
        self.id = id
        self.description = description
        self.assertion = assertion
        self.status = status
    }
}

public enum CommitmentStatus: String, Equatable, Sendable {
    case pending, verifying, passed, failed
}

// Domain/Model/Message.swift
public struct Message: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
}

public enum MessageRole: String, Sendable {
    case user
    case agent
}

// Domain/Model/Document.swift
public struct Document: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var metadata: [String: String]
    public var content: String
    public let createdAt: Date
    public var updatedAt: Date
}
```

**Key constraints:**
- Zero imports beyond Foundation
- No references to ClaudeCodeSDK, SwiftUI, or any framework
- Pure value types or classes with value semantics
- Contains business invariants as computed properties or validation methods


### 2.2 Domain Services Layer

Domain Services contain business logic that operates on the domain model but doesn't fit naturally in a single entity. They orchestrate domain operations and enforce business rules.

**What belongs here:**

```swift
// Domain/Services/AgentLifecycleService.swift
import Foundation

/// Ports that domain services depend on (defined here, implemented in infrastructure)
public protocol LLMCommunicationPort: Sendable {
    func send(prompt: String, systemPrompt: String?, sessionId: String?) async throws -> LLMResponse
    func resume(sessionId: String, prompt: String, systemPrompt: String?) async throws -> LLMResponse
}

public struct LLMResponse: Sendable {
    public let content: String
    public let sessionId: String
}

/// Domain service for agent lifecycle management
public final class AgentLifecycleService: Sendable {
    private let llm: LLMCommunicationPort

    public init(llm: LLMCommunicationPort) {
        self.llm = llm
    }

    public func createAgent(name: String, assignment: String) -> AgentIdentity {
        return AgentIdentity(id: UUID(), name: name)
    }

    public func sendMessage(
        to agent: AgentIdentity,
        message: String,
        systemPrompt: String,
        sessionId: String?
    ) async throws -> (Message, String) {
        let response = try await llm.send(
            prompt: message,
            systemPrompt: systemPrompt,
            sessionId: sessionId
        )

        let replyMessage = Message(
            id: UUID(),
            role: .agent,
            content: response.content,
            timestamp: Date()
        )

        return (replyMessage, response.sessionId)
    }
}

// Domain/Services/CommitmentEvaluationService.swift
public protocol AssertionExecutionPort: Sendable {
    func execute(command: String) async throws -> AssertionResult
}

public struct AssertionResult: Sendable {
    public let passed: Bool
    public let output: String
    public let errorOutput: String
}

public final class CommitmentEvaluationService: Sendable {
    private let executor: AssertionExecutionPort

    public init(executor: AssertionExecutionPort) {
        self.executor = executor
    }

    public func verify(_ commitment: Commitment) async throws -> Commitment {
        var result = commitment
        result.status = .verifying

        let assertionResult = try await executor.execute(command: commitment.assertion)
        result.status = assertionResult.passed ? .passed : .failed

        return result
    }

    public func verifyAll(_ commitments: [Commitment]) async throws -> [Commitment] {
        var results: [Commitment] = []
        for commitment in commitments {
            results.append(try await verify(commitment))
        }
        return results
    }
}

// Domain/Services/NamingService.swift
public final class NamingService: @unchecked Sendable {
    private var usedNames: Set<String> = []
    private let themes: [NamingTheme]
    private var currentTheme: NamingTheme

    public init(themes: [NamingTheme]) {
        self.themes = themes
        self.currentTheme = themes.first ?? NamingTheme.fallback
    }

    public func nextName() -> String {
        // Pure domain logic for name generation
        for name in currentTheme.allNames where !usedNames.contains(name) {
            usedNames.insert(name)
            return name
        }
        let fallback = "Agent-\(usedNames.count + 1)"
        usedNames.insert(fallback)
        return fallback
    }

    public func release(_ name: String) {
        usedNames.remove(name)
    }
}

// Domain/Services/ConversationService.swift
public final class ConversationService: Sendable {
    public init() {}

    public func appendUserMessage(content: String, to conversation: [Message]) -> [Message] {
        var updated = conversation
        updated.append(Message(
            id: UUID(),
            role: .user,
            content: content,
            timestamp: Date()
        ))
        return updated
    }

    public func appendAgentMessage(content: String, to conversation: [Message]) -> [Message] {
        var updated = conversation
        updated.append(Message(
            id: UUID(),
            role: .agent,
            content: content,
            timestamp: Date()
        ))
        return updated
    }
}
```

**Key constraints:**
- Imports Domain Model only (plus Foundation)
- Defines ports (protocols) for infrastructure it needs
- Contains business rules that span multiple entities
- Stateless where possible (receives data, returns data)


### 2.3 Application Services Layer

Application Services orchestrate use cases by combining domain services and managing transactions. They know about the outside world through injected infrastructure but contain no business logic themselves.

**What belongs here:**

```swift
// Application/Services/TavernApplicationService.swift
import Foundation

/// Ports for persistence (defined by application layer, implemented by infrastructure)
public protocol SessionPersistencePort: Sendable {
    func save(sessionId: String, for agentId: UUID, projectPath: String) async
    func load(for agentId: UUID, projectPath: String) async -> String?
    func clear(for agentId: UUID, projectPath: String) async
}

public protocol AgentRegistryPort: Sendable {
    func register(_ identity: AgentIdentity) async throws
    func remove(id: UUID) async throws
    func find(id: UUID) async -> AgentIdentity?
    func all() async -> [AgentIdentity]
}

@MainActor
public final class TavernApplicationService: ObservableObject {
    private let lifecycleService: AgentLifecycleService
    private let namingService: NamingService
    private let commitmentService: CommitmentEvaluationService
    private let sessionPersistence: SessionPersistencePort
    private let registry: AgentRegistryPort
    private let projectPath: String

    @Published public private(set) var activeAgents: [AgentIdentity] = []

    public init(
        lifecycleService: AgentLifecycleService,
        namingService: NamingService,
        commitmentService: CommitmentEvaluationService,
        sessionPersistence: SessionPersistencePort,
        registry: AgentRegistryPort,
        projectPath: String
    ) {
        self.lifecycleService = lifecycleService
        self.namingService = namingService
        self.commitmentService = commitmentService
        self.sessionPersistence = sessionPersistence
        self.registry = registry
        self.projectPath = projectPath
    }

    public func spawnAgent(assignment: String) async throws -> AgentIdentity {
        let name = namingService.nextName()
        let identity = lifecycleService.createAgent(name: name, assignment: assignment)
        try await registry.register(identity)
        activeAgents = await registry.all()
        return identity
    }

    public func dismissAgent(id: UUID) async throws {
        guard let identity = await registry.find(id: id) else { return }
        try await registry.remove(id: id)
        namingService.release(identity.name)
        await sessionPersistence.clear(for: id, projectPath: projectPath)
        activeAgents = await registry.all()
    }
}

// Application/Services/ChatApplicationService.swift
@MainActor
public final class ChatApplicationService: ObservableObject {
    private let lifecycleService: AgentLifecycleService
    private let conversationService: ConversationService
    private let sessionPersistence: SessionPersistencePort
    private let projectPath: String

    @Published public private(set) var messages: [Message] = []
    @Published public private(set) var isCogitating: Bool = false

    private var currentAgentId: UUID?
    private var currentSessionId: String?

    public init(
        lifecycleService: AgentLifecycleService,
        conversationService: ConversationService,
        sessionPersistence: SessionPersistencePort,
        projectPath: String
    ) {
        self.lifecycleService = lifecycleService
        self.conversationService = conversationService
        self.sessionPersistence = sessionPersistence
        self.projectPath = projectPath
    }

    public func setActiveAgent(_ agent: AgentIdentity, systemPrompt: String) async {
        currentAgentId = agent.id
        currentSessionId = await sessionPersistence.load(for: agent.id, projectPath: projectPath)
        // Load history if needed
    }

    public func send(message: String, systemPrompt: String) async throws {
        guard let agentId = currentAgentId else { return }

        messages = conversationService.appendUserMessage(content: message, to: messages)
        isCogitating = true

        defer { isCogitating = false }

        let agent = AgentIdentity(id: agentId, name: "")  // Simplified
        let (response, newSessionId) = try await lifecycleService.sendMessage(
            to: agent,
            message: message,
            systemPrompt: systemPrompt,
            sessionId: currentSessionId
        )

        currentSessionId = newSessionId
        await sessionPersistence.save(sessionId: newSessionId, for: agentId, projectPath: projectPath)

        messages = conversationService.appendAgentMessage(content: response.content, to: messages)
    }
}
```

**Key constraints:**
- Imports Domain Model and Domain Services
- Receives infrastructure through constructor injection
- Orchestrates use cases (spawn agent, send message, verify commitments)
- Manages @Published state for UI binding (but contains no UI code)
- No direct framework imports (ClaudeCodeSDK, etc.)


### 2.4 Infrastructure Layer (Outermost)

Infrastructure implements all the ports defined by inner layers. This is where framework dependencies live.

**What belongs here:**

```swift
// Infrastructure/Adapters/ClaudeCodeAdapter.swift
import Foundation
import ClaudeCodeSDK

public final class ClaudeCodeAdapter: LLMCommunicationPort, @unchecked Sendable {
    private let client: ClaudeCode

    public init(configuration: ClaudeCodeConfiguration) throws {
        self.client = try ClaudeCodeClient(configuration: configuration)
    }

    public func send(
        prompt: String,
        systemPrompt: String?,
        sessionId: String?
    ) async throws -> LLMResponse {
        var options = ClaudeCodeOptions()
        options.systemPrompt = systemPrompt

        let result: ClaudeCodeResult
        if let session = sessionId {
            result = try await client.resumeConversation(
                sessionId: session,
                prompt: prompt,
                outputFormat: .json,
                options: options
            )
        } else {
            result = try await client.runSinglePrompt(
                prompt: prompt,
                outputFormat: .json,
                options: options
            )
        }

        switch result {
        case .json(let msg):
            return LLMResponse(content: msg.result ?? "", sessionId: msg.sessionId)
        case .text(let text):
            return LLMResponse(content: text, sessionId: UUID().uuidString)
        case .stream:
            return LLMResponse(content: "", sessionId: UUID().uuidString)
        }
    }

    public func resume(
        sessionId: String,
        prompt: String,
        systemPrompt: String?
    ) async throws -> LLMResponse {
        try await send(prompt: prompt, systemPrompt: systemPrompt, sessionId: sessionId)
    }
}

// Infrastructure/Adapters/UserDefaultsSessionAdapter.swift
import Foundation

public final class UserDefaultsSessionAdapter: SessionPersistencePort, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "com.tavern.session") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func save(sessionId: String, for agentId: UUID, projectPath: String) async {
        let key = makeKey(agentId: agentId, projectPath: projectPath)
        defaults.set(sessionId, forKey: key)
    }

    public func load(for agentId: UUID, projectPath: String) async -> String? {
        let key = makeKey(agentId: agentId, projectPath: projectPath)
        return defaults.string(forKey: key)
    }

    public func clear(for agentId: UUID, projectPath: String) async {
        let key = makeKey(agentId: agentId, projectPath: projectPath)
        defaults.removeObject(forKey: key)
    }

    private func makeKey(agentId: UUID, projectPath: String) -> String {
        let encodedPath = projectPath.replacingOccurrences(of: "/", with: "-")
        return "\(keyPrefix).\(encodedPath).\(agentId.uuidString)"
    }
}

// Infrastructure/Adapters/ShellProcessAdapter.swift
import Foundation

public final class ShellProcessAdapter: AssertionExecutionPort, @unchecked Sendable {
    private let workingDirectory: URL?

    public init(workingDirectory: URL? = nil) {
        self.workingDirectory = workingDirectory
    }

    public func execute(command: String) async throws -> AssertionResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                process.currentDirectoryURL = self.workingDirectory
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                    continuation.resume(returning: AssertionResult(
                        passed: process.terminationStatus == 0,
                        output: output,
                        errorOutput: error
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// Infrastructure/Adapters/InMemoryAgentRegistry.swift
public actor InMemoryAgentRegistry: AgentRegistryPort {
    private var agents: [UUID: AgentIdentity] = [:]

    public init() {}

    public func register(_ identity: AgentIdentity) throws {
        agents[identity.id] = identity
    }

    public func remove(id: UUID) throws {
        agents.removeValue(forKey: id)
    }

    public func find(id: UUID) -> AgentIdentity? {
        agents[id]
    }

    public func all() -> [AgentIdentity] {
        Array(agents.values)
    }
}
```

**Key constraints:**
- Implements ports defined by Domain Services and Application Services
- Can import any framework (ClaudeCodeSDK, SwiftUI, Foundation)
- Contains no business logic
- Handles framework-specific error mapping


### 2.5 Composition Root

The outermost point where all dependencies are wired together.

```swift
// Infrastructure/Composition/TavernComposition.swift
import Foundation
import ClaudeCodeSDK

public final class TavernComposition {
    private let projectURL: URL

    public init(projectURL: URL) {
        self.projectURL = projectURL
    }

    public func createTavernApplicationService() throws -> TavernApplicationService {
        // Create infrastructure adapters
        var config = ClaudeCodeConfiguration.default
        config.workingDirectory = projectURL.path
        let llmAdapter = try ClaudeCodeAdapter(configuration: config)

        let sessionAdapter = UserDefaultsSessionAdapter()
        let assertionAdapter = ShellProcessAdapter(workingDirectory: projectURL)
        let registry = InMemoryAgentRegistry()

        // Create domain services with injected ports
        let lifecycleService = AgentLifecycleService(llm: llmAdapter)
        let namingService = NamingService(themes: [.lotr, .dune, .norse])
        let commitmentService = CommitmentEvaluationService(executor: assertionAdapter)

        // Create application service with all dependencies
        return TavernApplicationService(
            lifecycleService: lifecycleService,
            namingService: namingService,
            commitmentService: commitmentService,
            sessionPersistence: sessionAdapter,
            registry: registry,
            projectPath: projectURL.path
        )
    }

    public func createChatApplicationService(llmAdapter: LLMCommunicationPort) -> ChatApplicationService {
        let sessionAdapter = UserDefaultsSessionAdapter()
        let conversationService = ConversationService()

        return ChatApplicationService(
            lifecycleService: AgentLifecycleService(llm: llmAdapter),
            conversationService: conversationService,
            sessionPersistence: sessionAdapter,
            projectPath: projectURL.path
        )
    }
}
```


## 3. How Onion Differs from Clean and Hexagonal


### 3.1 Comparison with Clean Architecture (#22)

| Aspect | Clean Architecture | Onion Architecture |
|--------|-------------------|-------------------|
| **Layer names** | Entities, Use Cases, Interface Adapters, Frameworks | Domain Model, Domain Services, Application Services, Infrastructure |
| **Core focus** | Use Cases (orchestration) | Domain Model (entities) |
| **Business rules** | Split between Entities and Use Cases | Split between Domain Model and Domain Services |
| **Port location** | Use Case layer defines ports | Domain Services layer defines ports |
| **Presenter pattern** | Interface Adapter converts data for views | Application Service is observable, drives UI |
| **Dependency direction** | Inward | Inward |
| **When identical** | Often equivalent in practice | Often equivalent in practice |

**Key difference:** Clean Architecture elevates use cases as the organizing principle. Onion Architecture elevates the domain model. In Clean, you ask "what can the user do?" In Onion, you ask "what does the business domain look like?"

**For Tavern:** Both would work. Clean might be better if use cases (spawn agent, send message, verify) are the primary concept. Onion might be better if the domain model (agents, commitments, messages) is richer than the use case layer.


### 3.2 Comparison with Hexagonal Architecture (#21)

| Aspect | Hexagonal | Onion |
|--------|-----------|-------|
| **Metaphor** | Hexagon with ports on perimeter | Concentric circles with core at center |
| **Port classification** | Driving (inbound) vs Driven (outbound) | Not explicit (all ports defined by inner layers) |
| **Adapter classification** | Primary (left) vs Secondary (right) | Infrastructure layer (outer shell) |
| **Layer count** | 2 (core + adapters) | 4 (model + services + application + infrastructure) |
| **Domain services** | Part of core (not distinguished) | Explicit layer between model and application |
| **When to use** | Clear port symmetry needed | Rich domain model worth protecting |

**Key difference:** Hexagonal focuses on the port/adapter pattern without prescribing internal structure. Onion prescribes explicit layering within the "core."

**For Tavern:** Hexagonal might be simpler for current scale. Onion adds structure that becomes valuable as domain complexity grows.


### 3.3 Comparison with DDD (#14)

| Aspect | DDD | Onion |
|--------|-----|-------|
| **Bounded contexts** | Multiple domains, each with own model | Single domain with layered structure |
| **Aggregates** | Entities that control access to children | Domain Model contains entities |
| **Domain events** | Cross-context communication | Not prescribed (can be added) |
| **Repository pattern** | Core pattern | Implemented as ports in Domain Services |
| **Ubiquitous language** | Central concept | Implicit in Domain Model naming |

**Relationship:** Onion Architecture is often used to implement a single bounded context in DDD. They are complementary, not competing.


## 4. PRD Requirements Mapping


### 4.1 Invariants Mapping

| PRD Invariant | Onion Architecture Enforcement |
|---------------|-------------------------------|
| "Test suite must pass before any feature ships" | Domain Model and Domain Services testable with zero mocks. Application Services testable with mock ports. |
| "Every feature must be testable" | Each layer testable in isolation. Domain = pure assertions. Services = mock ports. Application = mock everything. |
| "Commitments must be verified independently" | CommitmentEvaluationService is pure domain logic. AssertionExecutionPort is mockable. |
| "User attention is sacred" | UI concerns in Infrastructure layer only. Domain knows nothing of notifications. |
| "Doc store is source of truth" | DocumentPersistencePort in Domain Services. Filesystem implementation in Infrastructure. |
| "Agents cannot modify their own invariants" | Invariants in Domain Model as immutable data or validation methods. Domain Services enforce rules. |
| "Failures must be visible" | Error types in Domain. Application Services handle and surface. Infrastructure logs. |
| "Original project files protected" | SandboxPort (future) in Domain Services. OverlayFSAdapter in Infrastructure. |


### 4.2 V1 Scope Mapping

| V1 Requirement | Onion Layer Placement |
|----------------|----------------------|
| User can chat with Jake | ChatApplicationService orchestrates. AgentLifecycleService handles LLM. Message in Domain Model. |
| Jake can spawn mortal agents | TavernApplicationService.spawnAgent(). AgentLifecycleService.createAgent(). AgentIdentity in Domain Model. |
| User can see agent list | TavernApplicationService.activeAgents. AgentRegistryPort in Application. InMemoryAgentRegistry in Infrastructure. |
| Basic spawn configuration | Configuration types in Domain Model. Application Service accepts and passes to Domain Services. |
| Agents can complete tasks | AgentState in Domain Model. State transitions in Domain Services. |
| Commitments verified by assertion | CommitmentEvaluationService in Domain Services. Commitment in Domain Model. ShellProcessAdapter in Infrastructure. |


### 4.3 Future Requirements

| Future Requirement | Onion Benefit |
|--------------------|--------------|
| Sandboxing with overlays | SandboxPort in Domain Services. OverlayFSAdapter in Infrastructure. Domain unaware of implementation. |
| Different AI backends | LLMCommunicationPort in Domain Services. ClaudeCodeAdapter, OpenAIAdapter, LocalModelAdapter in Infrastructure. |
| Workflow templates | WorkflowTemplate in Domain Model. WorkflowExecutionService in Domain Services. |
| Metrics dashboard | MetricsPort in Domain Services. PrometheusAdapter or InMemoryMetrics in Infrastructure. |
| Rewind and branch | SessionHistoryPort in Domain Services. Replay logic in Application. |


## 5. Trade-offs Considered


### 5.1 Layer Placement Ambiguity

**The problem:** Where does Jake's system prompt live? It's not infrastructure. It's not purely domain model (it's configuration). It's not a service (it's data).

**Options:**
1. Domain Model: `JakeCharacter` struct with prompt constant
2. Domain Services: `JakePromptService` that constructs prompts
3. Application Services: Configuration injected at composition time
4. Infrastructure: Environment-specific prompts

**Recommendation:** Domain Model. Jake's personality is core domain knowledge. Create:

```swift
// Domain/Model/JakeCharacter.swift
public enum JakeCharacter {
    public static let systemPrompt = """
        You are Jake, The Proprietor of The Tavern at the Spillway.
        ...
        """

    public static let cogitatingVerbs = ["Pondering", "Scheming", "Ruminating"]
}
```


### 5.2 Domain Services vs Application Services

**The problem:** When is logic "domain" vs "application"?

**Rule of thumb:**
- **Domain Service:** Would this logic exist if there was no UI? Would a domain expert recognize it?
  - "Verify a commitment" = domain
  - "Generate a themed name" = domain
  - "Send message to LLM" = domain (orchestrates a business operation)

- **Application Service:** Does this orchestrate a user interaction? Does it manage @Published state?
  - "Spawn agent and update list" = application
  - "Send message and update UI" = application
  - "Handle project open/close" = application

**For Tavern:** The distinction is fairly clear. Agent lifecycle, commitment verification, naming are domain. User workflows (spawn-and-select, chat-and-display) are application.


### 5.3 Sendable Boundaries

**The problem:** Swift's Sendable requirements make passing objects across layer boundaries complex.

**Onion solution:**
- Domain Model = value types, all Sendable
- Domain Services = either `Sendable` classes or actors
- Ports = protocols marked `: Sendable`
- Application Services = `@MainActor` with @Published properties
- Infrastructure = `@unchecked Sendable` where necessary (thread-safe internally)

**Example port design:**
```swift
public protocol LLMCommunicationPort: Sendable {
    func send(...) async throws -> LLMResponse  // Value type return
}
```


### 5.4 DI Complexity

**The problem:** Onion requires dependency injection throughout. Without a DI container, constructor parameters explode.

**Current Jake constructor:** `init(id: UUID, claude: ClaudeCode, loadSavedSession: Bool)`

**Onion equivalent:**
```swift
// Domain Service
init(llm: LLMCommunicationPort)

// Application Service
init(
    lifecycleService: AgentLifecycleService,
    namingService: NamingService,
    commitmentService: CommitmentEvaluationService,
    sessionPersistence: SessionPersistencePort,
    registry: AgentRegistryPort,
    projectPath: String
)
```

**Options:**
1. Manual DI at composition root (verbose but explicit)
2. Builder pattern to construct services
3. DI container (Swinject, Resolver)

**Recommendation:** Manual DI for now. The dependency count is manageable (~5-6 per service). DI container adds learning curve and runtime complexity not justified at current scale.


### 5.5 Logging Placement

**The problem:** TavernLogger is a cross-cutting concern. Which layer owns it?

**Options:**
1. All layers can log (pragmatic)
2. Logging port in Domain Services, implementations in Infrastructure
3. Logging only in Application and Infrastructure

**Recommendation:** Option 1. Logging is infrastructure but universally needed. Allow TavernLogger in all layers. This is a common Onion exception. The alternative (passing logger ports everywhere) adds significant ceremony for little benefit.


## 6. Implementation Complexity


### 6.1 Estimated Effort

**Phase 1: Create Domain Model (4-6 hours)**
- Create `Domain/Model/` directory
- Move pure types: AgentState, Commitment, CommitmentStatus, ChatMessage → Message
- Extract AgentIdentity from Agent protocol
- Remove all imports except Foundation
- Tests: Pure value assertions

**Phase 2: Create Domain Services (6-10 hours)**
- Create `Domain/Services/` directory
- Define ports: LLMCommunicationPort, AssertionExecutionPort
- Create AgentLifecycleService, CommitmentEvaluationService, NamingService, ConversationService
- Wire domain services to use domain model
- Tests: Mock ports, verify service logic

**Phase 3: Create Infrastructure Adapters (6-8 hours)**
- Create `Infrastructure/Adapters/` directory
- Implement ClaudeCodeAdapter, UserDefaultsSessionAdapter, ShellProcessAdapter
- Move MockClaudeCode → MockLLMAdapter
- Tests: Real infrastructure where safe (UserDefaults), mocks otherwise

**Phase 4: Create Application Services (6-10 hours)**
- Create `Application/Services/` directory
- Define application ports: SessionPersistencePort, AgentRegistryPort
- Create TavernApplicationService, ChatApplicationService
- Wire to domain services and ports
- Tests: Mock all ports, verify orchestration

**Phase 5: Create Composition Root (2-4 hours)**
- Create TavernComposition
- Wire all dependencies
- Update TavernProject to use composition
- Update SwiftUI views to consume application services

**Phase 6: Update Tests (4-6 hours)**
- Migrate existing tests to new structure
- Add layer-specific test files
- Verify coverage maintained

**Total: 28-44 hours (4-6 development days)**


### 6.2 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Layer placement debates slow progress | High | Medium | Establish clear criteria upfront. When unclear, default to Domain Services. |
| Sendable violations at boundaries | Medium | Medium | Design all ports with value types from start. |
| Over-abstraction of simple operations | Medium | Low | Apply "three strikes" rule before abstracting. |
| DI constructor sprawl | Medium | Low | Accept 5-6 parameters. Consider builders if it grows. |
| Breaking tests during migration | Medium | High | Migrate one layer at a time. Green tests after each phase. |
| Performance overhead | Low | Low | Swift optimizes protocol dispatch well. Profile if needed. |


## 7. Migration Path from Current State


### 7.1 Step 0: Preparation

- Create directory structure:
  ```
  TavernCore/
  ├── Domain/
  │   ├── Model/
  │   └── Services/
  ├── Application/
  │   └── Services/
  └── Infrastructure/
      ├── Adapters/
      └── Composition/
  ```
- Baseline current test count and coverage
- Document existing imports per file


### 7.2 Step 1: Extract Domain Model

**Files to create:**
- `Domain/Model/AgentIdentity.swift`
- `Domain/Model/AgentState.swift`
- `Domain/Model/Commitment.swift`
- `Domain/Model/CommitmentStatus.swift`
- `Domain/Model/Message.swift`
- `Domain/Model/MessageRole.swift`
- `Domain/Model/Document.swift`
- `Domain/Model/NamingTheme.swift` (move existing, remove imports)
- `Domain/Model/JakeCharacter.swift` (extract prompt)

**Files to modify:**
- All files that import these types now import from Domain/Model

**Test verification:**
- All existing tests still pass
- Add pure unit tests for new value types


### 7.3 Step 2: Extract Domain Services

**Files to create:**
- `Domain/Services/Ports/LLMCommunicationPort.swift`
- `Domain/Services/Ports/AssertionExecutionPort.swift`
- `Domain/Services/AgentLifecycleService.swift`
- `Domain/Services/CommitmentEvaluationService.swift`
- `Domain/Services/NamingService.swift`
- `Domain/Services/ConversationService.swift`

**Migration strategy:**
1. Create port protocols matching current ClaudeCode and AssertionRunner
2. Create services that use ports
3. Update Jake to use AgentLifecycleService (temporary dual existence)
4. Verify tests pass
5. Remove direct ClaudeCodeSDK usage from Jake


### 7.4 Step 3: Extract Infrastructure

**Files to create:**
- `Infrastructure/Adapters/ClaudeCodeAdapter.swift`
- `Infrastructure/Adapters/UserDefaultsSessionAdapter.swift`
- `Infrastructure/Adapters/ShellProcessAdapter.swift`
- `Infrastructure/Adapters/InMemoryAgentRegistry.swift`
- `Infrastructure/Adapters/MockLLMAdapter.swift` (from MockClaudeCode)

**Migration strategy:**
1. Create adapters that implement domain ports
2. Verify each adapter works with existing domain services
3. Update existing tests to use new mock adapters


### 7.5 Step 4: Extract Application Services

**Files to create:**
- `Application/Services/Ports/SessionPersistencePort.swift`
- `Application/Services/Ports/AgentRegistryPort.swift`
- `Application/Services/TavernApplicationService.swift`
- `Application/Services/ChatApplicationService.swift`

**Migration strategy:**
1. TavernApplicationService wraps TavernCoordinator logic
2. ChatApplicationService wraps ChatViewModel logic
3. Wire application services to domain services
4. Views consume application services instead of coordinators


### 7.6 Step 5: Wire Composition

**Files to create:**
- `Infrastructure/Composition/TavernComposition.swift`

**Migration strategy:**
1. TavernProject uses TavernComposition to create services
2. Views receive application services from composition
3. Remove old direct construction code


## 8. Open Questions


### 8.1 Should We Use Swift Actors for Domain Services?

**Argument for:** Natural concurrency safety. No manual DispatchQueue management.

**Argument against:** Actor isolation can make composition awkward. Cross-actor calls require await.

**Recommendation:** Use actors for services that need mutable state (NamingService, AgentRegistry). Use plain classes/structs for stateless services (CommitmentEvaluationService).


### 8.2 Where Does TavernCoordinator End Up?

**Current role:** Central hub owning Jake, AgentSpawner, and view models.

**Onion placement:** TavernCoordinator responsibilities split:
- Agent lifecycle → TavernApplicationService
- Chat management → ChatApplicationService
- UI state → @Published in application services
- Spawner → part of TavernApplicationService

**Recommendation:** TavernCoordinator becomes TavernApplicationService. It's the primary application orchestrator.


### 8.3 How to Handle @MainActor Requirements?

**Problem:** SwiftUI requires @MainActor for ObservableObject. Domain services shouldn't be MainActor.

**Solution:**
- Application Services are @MainActor (they own @Published properties)
- Domain Services are not @MainActor
- Application Services call domain services within Task or nonisolated context
- Ports return Sendable types that can cross boundaries


### 8.4 What About SwiftUI View Models?

**Current:** ChatViewModel, AgentListViewModel are separate types.

**Onion option 1:** View models ARE application services (ChatApplicationService replaces ChatViewModel).

**Onion option 2:** Thin view models wrap application services.

**Recommendation:** Option 1 for simplicity. Application services serve as view models. They're @MainActor, have @Published properties, and are observed by views.


## 9. Conclusion

Onion Architecture provides a rigorous structure for separating domain logic from infrastructure in the Tavern codebase.

**Strengths for Tavern:**
- Pure domain model (Agent, Commitment, Message) testable without any mocks
- Clean separation of business rules (Domain Services) from UI orchestration (Application Services)
- All infrastructure (ClaudeCodeSDK, UserDefaults, FileManager) pushed to outer layer
- Natural evolution path as domain complexity grows

**Weaknesses for Tavern:**
- Four layers may be excessive for ~2000 lines of code
- Layer placement decisions require upfront thought
- Migration cost (28-44 hours) is significant for v1 scope
- More files, more indirection, more ceremony

**Recommendation:** Onion Architecture is viable but not recommended for v1. The current codebase is small enough that the benefits of formal layering don't justify the migration cost.

**Consider Onion when:**
- Domain model grows beyond 10+ core entity types
- Multiple teams work on different layers
- Testability without any framework is a hard requirement
- The distinction between domain services and application services becomes meaningful

**For v1:** Continue with current structure. Apply Onion incrementally if:
1. ClaudeCodeSDK churn becomes painful (extract LLMCommunicationPort)
2. Testing becomes blocked by infrastructure (extract more ports)
3. Domain logic becomes complex enough to warrant explicit Domain Services

The patterns in this document can guide incremental adoption without requiring a big-bang migration.
