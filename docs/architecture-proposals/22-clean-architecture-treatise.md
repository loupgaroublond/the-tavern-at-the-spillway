# Clean Architecture: Complete Analysis

This document contains the full research, rationale, and trade-off analysis for applying Uncle Bob's Clean Architecture to The Tavern at the Spillway.


## 1. Research Findings: Current Architecture


### 1.1 Current Layer Structure

The current codebase has an implicit layering but does not enforce dependency direction:

**Application Layer** (`Sources/Tavern/`)
- `TavernApp.swift` - Entry point, window management
- `Views/` - SwiftUI views (ChatView, AgentListView, WelcomeView)

**Core Framework** (`Sources/TavernCore/`)
- `Agents/` - Jake, MortalAgent, AgentRegistry, AgentSpawner
- `Chat/` - ChatViewModel, ChatMessage
- `Coordination/` - TavernCoordinator
- `Commitments/` - Commitment, CommitmentList, CommitmentVerifier
- `DocStore/` - Document, DocStore, AgentNode, AgentPersistence
- `Errors/` - TavernError, TavernErrorMessages
- `Logging/` - TavernLogger
- `Naming/` - NamingTheme, NameGenerator
- `Persistence/` - SessionStore
- `Project/` - TavernProject, ProjectManager
- `Registry/` - AgentRegistry
- `Testing/` - MockClaudeCode, TestFixtures
- `UI/` - AgentListViewModel, AgentListItem


### 1.2 Current Dependency Violations

Examining imports reveals bidirectional and cross-cutting dependencies that Clean Architecture would prohibit:

**Entities import frameworks:**
```swift
// Jake.swift
import ClaudeCodeSDK  // Framework dependency in domain entity
import os.log         // Framework dependency
```

**Use-case-level code imports SDK types:**
```swift
// MortalAgent.swift
import ClaudeCodeSDK
// Uses ClaudeCode directly, not through abstraction
```

**View models import SDK:**
```swift
// ChatViewModel.swift
import ClaudeCodeSDK  // Knows about ClaudeStoredMessage
```

**Persistence couples to domain:**
```swift
// SessionStore.swift
import ClaudeCodeSDK  // Uses ClaudeNativeSessionStorage directly
```


### 1.3 Type Inventory

Current types that would need classification in Clean Architecture:

| Type | Current Location | Clean Architecture Layer |
|------|------------------|--------------------------|
| `Agent` protocol | Agents/ | Entity |
| `AgentState` enum | Agents/ | Entity |
| `Jake` class | Agents/ | Entity (needs SDK extraction) |
| `MortalAgent` class | Agents/ | Entity (needs SDK extraction) |
| `Commitment` struct | Commitments/ | Entity |
| `CommitmentList` class | Commitments/ | Entity |
| `ChatMessage` struct | Chat/ | Entity |
| `Document` struct | DocStore/ | Entity |
| `AnyAgent` class | Agents/ | Use Case (type erasure) |
| `AgentRegistry` class | Agents/ | Use Case |
| `AgentSpawner` class | Agents/ | Use Case |
| `CommitmentVerifier` class | Commitments/ | Use Case |
| `TavernCoordinator` class | Coordination/ | Interface Adapter |
| `ChatViewModel` class | Chat/ | Interface Adapter (Presenter) |
| `AgentListViewModel` class | UI/ | Interface Adapter (Presenter) |
| `DocStore` class | DocStore/ | Interface Adapter (Repository) |
| `SessionStore` enum | Persistence/ | Interface Adapter (Gateway) |
| `ClaudeCode` | ClaudeCodeSDK | Framework |
| `SwiftUI` views | Tavern/Views/ | Framework |
| `UserDefaults` | Apple SDK | Framework |


### 1.4 File Counts and Lines

Current state:
- TavernCore: 28 Swift files, ~2000 lines total
- Tavern (app): 6 Swift files, ~400 lines total

Clean Architecture projection:
- Entities: 8-10 files (~400 lines)
- Use Cases: 12-15 files (~600 lines)
- Interface Adapters: 15-20 files (~800 lines)
- Frameworks/Drivers: 10-12 files (~400 lines)
- Protocols (ports): 10-15 files (~200 lines)

Total: 55-72 files (~2400 lines, growth from protocols and indirection)


## 2. Clean Architecture Layers for Tavern


### 2.1 Entities Layer (Innermost)

Entities are pure domain objects with no dependencies. They represent core business concepts.

**What belongs here:**

```swift
// Pure Agent entity - no SDK imports
public struct AgentIdentity: Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
}

public enum AgentState: String, Equatable, Sendable {
    case idle, working, waiting, verifying, done
}

// Pure message - just data
public struct Message: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
}

public enum MessageRole: String, Sendable {
    case user, agent
}

// Pure commitment - no verification logic
public struct Commitment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let description: String
    public let assertion: String
    public var status: CommitmentStatus
}

public enum CommitmentStatus: String, Sendable {
    case pending, verifying, passed, failed
}
```

**Key constraint:** Zero imports except Foundation. No ClaudeCodeSDK, no os.log, no SwiftUI.


### 2.2 Use Cases Layer

Use cases contain application-specific business rules. They orchestrate entities and define ports (protocols) for external dependencies.

**What belongs here:**

```swift
// Port for AI communication
public protocol AIGateway: Sendable {
    func send(message: String, sessionId: String?) async throws -> AIResponse
    func resumeSession(id: String, message: String) async throws -> AIResponse
}

public struct AIResponse: Sendable {
    public let content: String
    public let sessionId: String
}

// Port for agent storage
public protocol AgentRepository: Sendable {
    func save(agent: AgentIdentity) throws
    func load(id: UUID) -> AgentIdentity?
    func loadAll() -> [AgentIdentity]
    func delete(id: UUID) throws
}

// Port for session persistence
public protocol SessionStorage: Sendable {
    func saveSession(id: String, forAgent: UUID)
    func loadSession(forAgent: UUID) -> String?
    func clearSession(forAgent: UUID)
}

// Use case: Send message to agent
public final class SendMessageUseCase: Sendable {
    private let gateway: AIGateway
    private let sessionStorage: SessionStorage

    public init(gateway: AIGateway, sessionStorage: SessionStorage) {
        self.gateway = gateway
        self.sessionStorage = sessionStorage
    }

    public func execute(agentId: UUID, message: String) async throws -> Message {
        let existingSession = sessionStorage.loadSession(forAgent: agentId)
        let response = try await gateway.send(message: message, sessionId: existingSession)
        sessionStorage.saveSession(id: response.sessionId, forAgent: agentId)
        return Message(id: UUID(), role: .agent, content: response.content, timestamp: Date())
    }
}

// Use case: Spawn agent
public final class SpawnAgentUseCase: Sendable {
    private let repository: AgentRepository
    private let nameGenerator: NameGeneratorPort

    public func execute(assignment: String) throws -> AgentIdentity {
        let name = nameGenerator.nextName()
        let agent = AgentIdentity(id: UUID(), name: name)
        try repository.save(agent: agent)
        return agent
    }
}

// Use case: Verify commitments
public final class VerifyCommitmentsUseCase: Sendable {
    private let assertionRunner: AssertionRunnerPort

    public func execute(commitments: [Commitment]) async throws -> [Commitment] {
        var results = commitments
        for i in results.indices {
            results[i].status = .verifying
            let passed = try await assertionRunner.run(results[i].assertion)
            results[i].status = passed ? .passed : .failed
        }
        return results
    }
}
```

**Key constraint:** Imports only Entity layer. Defines protocols for external dependencies (ports). No framework imports.


### 2.3 Interface Adapters Layer

Adapters translate between use cases and external systems. This includes presenters (for UI), gateways (for external services), and repositories (for storage).

**What belongs here:**

```swift
// Gateway: Implements AIGateway using ClaudeCodeSDK
import ClaudeCodeSDK

public final class ClaudeGateway: AIGateway {
    private let claude: ClaudeCode

    public init(claude: ClaudeCode) {
        self.claude = claude
    }

    public func send(message: String, sessionId: String?) async throws -> AIResponse {
        let options = ClaudeCodeOptions()
        options.systemPrompt = JakeSystemPrompt.value  // From entities

        let result: ClaudeCodeResult
        if let session = sessionId {
            result = try await claude.resumeConversation(sessionId: session, prompt: message, outputFormat: .json, options: options)
        } else {
            result = try await claude.runSinglePrompt(prompt: message, outputFormat: .json, options: options)
        }

        switch result {
        case .json(let msg):
            return AIResponse(content: msg.result ?? "", sessionId: msg.sessionId)
        case .text(let text):
            return AIResponse(content: text, sessionId: UUID().uuidString)
        case .stream:
            return AIResponse(content: "", sessionId: UUID().uuidString)
        }
    }
}

// Repository: Implements AgentRepository using in-memory storage
public final class InMemoryAgentRepository: AgentRepository {
    private let queue = DispatchQueue(label: "com.tavern.AgentRepository")
    private var agents: [UUID: AgentIdentity] = [:]

    public func save(agent: AgentIdentity) throws { /* ... */ }
    public func load(id: UUID) -> AgentIdentity? { /* ... */ }
    public func loadAll() -> [AgentIdentity] { /* ... */ }
    public func delete(id: UUID) throws { /* ... */ }
}

// Session adapter: Implements SessionStorage using UserDefaults
public final class UserDefaultsSessionStorage: SessionStorage {
    private let defaults = UserDefaults.standard

    public func saveSession(id: String, forAgent: UUID) {
        defaults.set(id, forKey: "session.\(forAgent.uuidString)")
    }

    public func loadSession(forAgent: UUID) -> String? {
        defaults.string(forKey: "session.\(forAgent.uuidString)")
    }

    public func clearSession(forAgent: UUID) {
        defaults.removeObject(forKey: "session.\(forAgent.uuidString)")
    }
}

// Presenter: Translates use case output to view model
@MainActor
public final class ChatPresenter: ObservableObject {
    private let sendMessageUseCase: SendMessageUseCase

    @Published public private(set) var messages: [MessageViewModel] = []
    @Published public private(set) var isLoading: Bool = false

    public func send(text: String, agentId: UUID) async {
        isLoading = true
        messages.append(MessageViewModel(role: .user, content: text))

        do {
            let response = try await sendMessageUseCase.execute(agentId: agentId, message: text)
            messages.append(MessageViewModel(role: .agent, content: response.content))
        } catch {
            messages.append(MessageViewModel(role: .agent, content: "Error: \(error.localizedDescription)"))
        }

        isLoading = false
    }
}
```

**Key constraint:** Imports use case layer and can import frameworks. Implements ports defined by use cases.


### 2.4 Frameworks & Drivers Layer (Outermost)

The outermost layer contains framework-specific code that wires everything together.

**What belongs here:**

```swift
// SwiftUI View - imports only adapters, not use cases or entities directly
import SwiftUI

struct ChatView: View {
    @ObservedObject var presenter: ChatPresenter
    @State private var inputText: String = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(presenter.messages) { message in
                    MessageBubble(message: message)
                }
            }

            HStack {
                TextField("Message", text: $inputText)
                Button("Send") {
                    Task {
                        await presenter.send(text: inputText, agentId: agentId)
                        inputText = ""
                    }
                }
            }
        }
    }
}

// App composition root - wires all dependencies
@main
struct TavernApp: App {
    // Composition happens here
    let claude = ClaudeCode(options: ClaudeCodeOptions())
    lazy var gateway = ClaudeGateway(claude: claude)
    lazy var sessionStorage = UserDefaultsSessionStorage()
    lazy var sendMessageUseCase = SendMessageUseCase(gateway: gateway, sessionStorage: sessionStorage)
    lazy var presenter = ChatPresenter(sendMessageUseCase: sendMessageUseCase)

    var body: some Scene {
        WindowGroup {
            ChatView(presenter: presenter)
        }
    }
}
```

**Key constraint:** Only imports adapters layer. Contains no business logic.


## 3. PRD Requirements Mapping


### 3.1 Invariants Mapping

| PRD Invariant | Clean Architecture Enforcement |
|---------------|-------------------------------|
| Test suite must pass | Entities and use cases testable with no framework setup |
| Every feature must be testable | Each layer testable in isolation via protocol mocks |
| Commitments verified independently | VerifyCommitmentsUseCase is pure logic, AssertionRunnerPort is mockable |
| User attention is sacred | UI logic in presenters, easily tested for intrusion behavior |
| Doc store is source of truth | Repository ports ensure single source, implementations pluggable |
| Agents cannot modify invariants | Rules layer becomes use case validation, entities are immutable data |
| Failures must be visible | Error handling in use cases, presentation in adapters |
| Original project files protected | Changeset port defined in use cases, implemented by adapter |


### 3.2 V1 Scope Mapping

| V1 Requirement | Clean Architecture Component |
|----------------|------------------------------|
| User can chat with Jake | SendMessageUseCase, ChatPresenter, ChatView |
| Jake can spawn mortal agents | SpawnAgentUseCase, AgentRepository |
| User can see agent list | ListAgentsUseCase, AgentListPresenter |
| Basic spawn configuration | SpawnAgentUseCase with configuration entities |
| Agents can complete tasks | AgentState entity, UpdateAgentStateUseCase |
| Commitments verified by assertion | VerifyCommitmentsUseCase, AssertionRunnerPort |


### 3.3 Future Requirements

| Future Requirement | Clean Architecture Benefit |
|--------------------|---------------------------|
| Sandboxing with overlays | ChangesetPort defined in use cases, FileSystemAdapter implements |
| Containerization / cloud agents | AIGateway implemented for remote agents |
| Different AI backends | Swap ClaudeGateway for OpenAIGateway, GPTGateway |
| Workflow templates | WorkflowEntity, ExecuteWorkflowUseCase |
| Metrics dashboard | MetricsPort, MetricsPresenter |
| Rewind and branch | SessionHistoryPort, BranchUseCase |


## 4. Trade-offs Considered


### 4.1 Purity vs. Pragmatism

**Pure Clean Architecture argument:** Every cross-layer dependency must go through a protocol. Jake entity should not know about ClaudeCode at all.

**Pragmatic counter-argument:** The current Jake class is ~190 lines. Splitting into JakeEntity (~30 lines) + JakeAgentUseCase (~80 lines) + JakeClaudeAdapter (~80 lines) triples file count for conceptual benefit only.

**Trade-off decision:** For v1, accept that Jake's system prompt is domain knowledge (belongs in entity) but communication is use-case orchestration. The current mixing is pragmatic for the scale.


### 4.2 Protocol Proliferation

**Clean Architecture requirement:** Use cases depend on abstractions, not concretions. Every external dependency needs a port protocol.

**Current Tavern reality:**
- ClaudeCode is the only AI backend
- UserDefaults is the only session storage
- FileManager is the only file system

**Trade-off:** Creating AIGateway, SessionStorage, FileSystemPort, AssertionRunnerPort, AgentRepositoryPort, NameGeneratorPort is 6+ protocols for single implementations.

**Recommendation:** If only one implementation exists and no test doubles are needed, skip the protocol. Add protocols when a second implementation or mock emerges.


### 4.3 Testing Strategy Shift

**Current testing:** MockClaudeCode is injected into Jake/MortalAgent constructors. Tests exercise agents with mock SDK.

**Clean Architecture testing:**
- Entity tests: Pure value comparisons, no mocks needed
- Use case tests: Mock ports (AIGateway, Repository), test orchestration
- Adapter tests: Real frameworks (ClaudeCodeSDK, UserDefaults), mock use cases
- Integration tests: Full stack with real dependencies

**Trade-off:** More test files, more granular coverage, but also more setup complexity. Current MockClaudeCode becomes MockAIGateway.


### 4.4 Navigation Complexity

**Current:** Follow code from ChatView -> ChatViewModel -> Jake -> ClaudeCode. 4 jumps.

**Clean Architecture:** ChatView -> ChatPresenter -> SendMessageUseCase -> AIGateway -> ClaudeGateway -> ClaudeCode. 6 jumps.

**Trade-off:** More indirection for better isolation. Debugging requires understanding layer boundaries. IDE "jump to definition" becomes less direct.


## 5. Implementation Complexity


### 5.1 Estimated Effort

**Phase 1: Extract Entities (3-5 hours)**
- Create `Entities/` directory
- Move AgentState, Commitment, CommitmentStatus, ChatMessage to pure structs
- Remove all imports except Foundation
- Update existing types to use new entities

**Phase 2: Define Ports (2-3 hours)**
- Create `UseCases/Ports/` directory
- Define AIGateway, AgentRepository, SessionStorage protocols
- Define AssertionRunnerPort, NameGeneratorPort

**Phase 3: Implement Use Cases (5-8 hours)**
- Create `UseCases/` directory
- Implement SendMessageUseCase, SpawnAgentUseCase, DismissAgentUseCase
- Implement VerifyCommitmentsUseCase, ListAgentsUseCase
- Wire use cases to use entities through ports

**Phase 4: Implement Adapters (4-6 hours)**
- Create `Adapters/` directory
- Implement ClaudeGateway (wraps ClaudeCode)
- Implement InMemoryAgentRepository
- Implement UserDefaultsSessionStorage
- Create presenters (ChatPresenter, AgentListPresenter)

**Phase 5: Wire Composition Root (2-3 hours)**
- Update TavernApp to compose all dependencies
- Update views to use presenters instead of view models
- Verify all existing tests still pass (update as needed)

**Phase 6: Update Tests (4-6 hours)**
- Create mock ports for use case testing
- Migrate existing tests to new structure
- Add entity unit tests
- Add use case unit tests
- Add adapter integration tests

**Total: 20-31 hours (3-4 development days)**


### 5.2 Risk Assessment

**High risk: Regression during migration**
- Many files change
- Import structure completely reshuffled
- Tests may pass individually but integration breaks

*Mitigation:* Incremental migration. Each phase must have passing tests before proceeding.

**Medium risk: Performance impact from indirection**
- Each layer adds function call overhead
- Protocol dispatch vs. direct method calls

*Mitigation:* Profile after migration. Swift optimizer handles most cases. If hotspots emerge, selectively inline.

**Medium risk: Team confusion during transition**
- Two architectures coexist during migration
- Which pattern to follow for new code?

*Mitigation:* Freeze new features during migration. Complete migration in focused sprint.

**Low risk: Over-engineering**
- Protocols for single implementations
- Excessive ceremony

*Mitigation:* Apply "three strikes" rule. Add protocol only when third use case for abstraction emerges.


## 6. Migration Path


### 6.1 Phase 1: Entity Extraction

**Before:**
```swift
// Agents/Agent.swift
import Foundation

public enum AgentState: String, Equatable, Sendable {
    case idle, working, waiting, verifying, done
}

public protocol Agent: AnyObject, Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var state: AgentState { get }
    func send(_ message: String) async throws -> String
    func resetConversation()
}
```

**After:**
```swift
// Entities/AgentState.swift
import Foundation

public enum AgentState: String, Equatable, Sendable {
    case idle, working, waiting, verifying, done
}

// Entities/AgentIdentity.swift
import Foundation

public struct AgentIdentity: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let assignment: String?

    public init(id: UUID = UUID(), name: String, assignment: String? = nil) {
        self.id = id
        self.name = name
        self.assignment = assignment
    }
}

// UseCases/Ports/AgentOperations.swift
public protocol AgentOperations: Sendable {
    func send(message: String, to agent: AgentIdentity) async throws -> Message
    func reset(agent: AgentIdentity)
}
```


### 6.2 Phase 2: Port Definition

```swift
// UseCases/Ports/AIGateway.swift
public protocol AIGateway: Sendable {
    func send(
        message: String,
        systemPrompt: String,
        sessionId: String?
    ) async throws -> AIResponse
}

public struct AIResponse: Sendable {
    public let content: String
    public let sessionId: String
    public let contentBlocks: [ContentBlock]
}

// UseCases/Ports/AgentRepository.swift
public protocol AgentRepository: Sendable {
    func save(_ agent: AgentIdentity) async throws
    func load(id: UUID) async -> AgentIdentity?
    func loadAll() async -> [AgentIdentity]
    func delete(id: UUID) async throws
}

// UseCases/Ports/SessionStorage.swift
public protocol SessionStorage: Sendable {
    func save(sessionId: String, for agentId: UUID, projectPath: String)
    func load(for agentId: UUID, projectPath: String) -> String?
    func clear(for agentId: UUID, projectPath: String)
}
```


### 6.3 Phase 3: Use Case Implementation

```swift
// UseCases/SendMessageUseCase.swift
public actor SendMessageUseCase {
    private let gateway: AIGateway
    private let sessionStorage: SessionStorage
    private let projectPath: String

    public init(
        gateway: AIGateway,
        sessionStorage: SessionStorage,
        projectPath: String
    ) {
        self.gateway = gateway
        self.sessionStorage = sessionStorage
        self.projectPath = projectPath
    }

    public func execute(
        message: String,
        agent: AgentIdentity,
        systemPrompt: String
    ) async throws -> Message {
        let existingSession = sessionStorage.load(
            for: agent.id,
            projectPath: projectPath
        )

        let response = try await gateway.send(
            message: message,
            systemPrompt: systemPrompt,
            sessionId: existingSession
        )

        sessionStorage.save(
            sessionId: response.sessionId,
            for: agent.id,
            projectPath: projectPath
        )

        return Message(
            id: UUID(),
            role: .agent,
            content: response.content,
            timestamp: Date()
        )
    }
}
```


### 6.4 Phase 4: Adapter Implementation

```swift
// Adapters/ClaudeGateway.swift
import ClaudeCodeSDK

public final class ClaudeGateway: AIGateway, @unchecked Sendable {
    private let claude: ClaudeCode

    public init(claude: ClaudeCode) {
        self.claude = claude
    }

    public func send(
        message: String,
        systemPrompt: String,
        sessionId: String?
    ) async throws -> AIResponse {
        var options = ClaudeCodeOptions()
        options.systemPrompt = systemPrompt

        let result: ClaudeCodeResult
        if let session = sessionId {
            result = try await claude.resumeConversation(
                sessionId: session,
                prompt: message,
                outputFormat: .json,
                options: options
            )
        } else {
            result = try await claude.runSinglePrompt(
                prompt: message,
                outputFormat: .json,
                options: options
            )
        }

        switch result {
        case .json(let msg):
            return AIResponse(
                content: msg.result ?? "",
                sessionId: msg.sessionId,
                contentBlocks: [] // Map from SDK types if needed
            )
        case .text(let text):
            return AIResponse(
                content: text,
                sessionId: UUID().uuidString,
                contentBlocks: []
            )
        case .stream:
            return AIResponse(
                content: "",
                sessionId: UUID().uuidString,
                contentBlocks: []
            )
        }
    }
}
```


## 7. Open Questions


### 7.1 Where Does Jake's System Prompt Live?

**Options:**
1. Entity layer as static constant
2. Use case as injected configuration
3. Adapter as framework knowledge

**Recommendation:** Entity layer. Jake's personality is core domain knowledge, not an adapter concern. Create `JakeCharacter` entity with prompt and voice constants.


### 7.2 How to Handle AgentState Transitions?

**Options:**
1. Entity owns state machine logic
2. Use case orchestrates transitions
3. Both (entity validates, use case decides)

**Recommendation:** Entity defines valid transitions (working -> idle, but not done -> working). Use case decides when to trigger. This keeps invariants in entities.


### 7.3 Should ChatViewModel Become a Presenter?

**Current:** ChatViewModel is both presentation logic and state management.

**Clean Architecture:** ChatPresenter handles presentation. State lives in use case or is derived.

**Recommendation:** Rename ChatViewModel to ChatPresenter. Keep @Published properties. Inject use cases instead of agents directly. This is mostly naming and composition, not restructuring.


### 7.4 What About TavernLogger?

**Current:** Static logger used throughout.

**Clean Architecture:** Logging is cross-cutting concern. Options:
1. Allow logging in all layers (pragmatic)
2. Define LoggerPort, inject everywhere (pure but tedious)
3. Logging only in adapters, silent entities (loses debug info)

**Recommendation:** Option 1. Logging is infrastructure, not business logic. Allow TavernLogger imports anywhere. This is a common Clean Architecture exception.


### 7.5 How to Handle DocStore?

**Current:** DocStore is both repository pattern (CRUD on documents) and file system wrapper.

**Clean Architecture:**
- DocumentRepository port in use cases
- FileDocStore adapter in adapters layer
- Document entity in entities

**Challenge:** The PRD says "doc store IS the filesystem." This means our repository IS the adapter.

**Recommendation:** Define DocumentRepository port for use cases. Implement FileDocStore adapter. Accept that for Tavern, the repository and adapter are conceptually merged because filesystem IS the storage.


## 8. Alternatives Not Chosen


### 8.1 Keep Current Architecture

**Why considered:** Working code, tests passing, cognitive overhead of migration.

**Why rejected:** Current architecture has framework dependencies in domain types. As codebase grows, this becomes technical debt. Migration now is cheaper than migration later.

**Verdict:** Valid for v1, but not for long-term.


### 8.2 Partial Clean Architecture (Use Cases Only)

**Why considered:** Add use case layer without full entity extraction.

**Why rejected:** Half-measures create confusion. If we're going Clean Architecture, commit fully.

**Verdict:** All or nothing.


### 8.3 VIPER Architecture

**Why considered:** Similar to Clean Architecture, popular in iOS.

**Why rejected:** VIPER is view-centric (View, Interactor, Presenter, Entity, Router). Clean Architecture is domain-centric. Tavern's domain (agents, commitments, coordination) is complex enough to warrant domain-first thinking.

**Verdict:** Clean Architecture is better fit for multi-agent orchestrator.


### 8.4 Hexagonal Architecture (Ports and Adapters)

**Why considered:** Very similar to Clean Architecture, focuses on ports.

**Why rejected:** Hexagonal doesn't prescribe inner layer structure. Clean Architecture's entity/use-case split provides clearer guidance for Tavern's domain model.

**Verdict:** Clean Architecture subsumes hexagonal benefits.


## 9. Conclusion

Clean Architecture provides strong long-term benefits for Tavern:
- Framework independence enables future AI backend swaps
- Pure domain logic enables comprehensive testing
- Explicit boundaries scale with team size

However, the costs are significant:
- 20-31 hours of migration work
- 2x file count increase
- Ongoing ceremony for new features
- Overkill for current ~2000 line codebase

**Recommendation:** Do not adopt Clean Architecture for v1. The current architecture is sufficient for proof of concept. Revisit when:
- Codebase exceeds 5000 lines
- Second AI backend is needed (OpenAI, local models)
- Team grows beyond 3 developers
- Test coverage requirements mandate framework isolation

If Clean Architecture is chosen despite these concerns, proceed with the phased migration (6 phases, 20-31 hours) and accept the file count growth as the cost of long-term maintainability.
