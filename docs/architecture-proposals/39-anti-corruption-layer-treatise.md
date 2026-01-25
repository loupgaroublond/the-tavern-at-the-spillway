# Anti-Corruption Layer Architecture: Complete Analysis

This treatise documents the research, findings, and detailed thinking behind the ACL proposal for the Tavern at the Spillway.


## Research Findings: Current SDK Integration


### SDK Types Exposed in Domain Code

The codebase currently exposes ClaudeCodeSDK types throughout the domain layer:

**1. Module-Level Export (TavernCore.swift:8)**
```swift
@_exported import ClaudeCodeSDK
```

This re-exports the entire SDK's public API as part of TavernCore. Any consumer of TavernCore gets all SDK types for free — whether they want them or not. This is the most significant coupling point.


**2. Agent Protocol Dependency**

Both `Jake` and `MortalAgent` take `ClaudeCode` (an SDK protocol) as a constructor parameter:

```swift
// Jake.swift:80
public init(id: UUID = UUID(), claude: ClaudeCode, loadSavedSession: Bool = true)

// MortalAgent.swift:79
public init(
    id: UUID = UUID(),
    name: String,
    assignment: String,
    claude: ClaudeCode,  // SDK type
    ...
)
```


**3. SDK Result Types in Business Logic**

Agents directly pattern-match on SDK result types:

```swift
// Jake.swift:150-175, MortalAgent.swift:144-166
switch result {
case .json(let resultMessage):  // ResultMessage is SDK type
    queue.sync { _sessionId = resultMessage.sessionId }
    let response = resultMessage.result ?? ""
    ...
case .text(let text):  // SDK type
    ...
case .stream:  // SDK type
    ...
}
```


**4. SDK Configuration in Domain (TavernProject.swift:93-100)**

```swift
private static func createClaudeCode(for rootURL: URL) throws -> ClaudeCode {
    var config = ClaudeCodeConfiguration.default  // SDK type
    config.workingDirectory = rootURL.path
    config.enableDebugLogging = true
    return try ClaudeCodeClient(configuration: config)  // SDK type
}
```


**5. Session Storage Types (SessionStore.swift:40-51)**

```swift
public static func loadJakeSessionHistory(projectPath: String) async -> [ClaudeStoredMessage] {
    // Returns SDK type
    let storage = ClaudeNativeSessionStorage()  // SDK type
    return try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
}
```


**6. Content Block Translation (ChatViewModel.swift:133-169)**

The view model manually translates SDK types to domain types:

```swift
for (j, block) in stored.contentBlocks.enumerated() {
    switch block {
    case .text(let text):
        chatMessage = ChatMessage(role: role, content: text, messageType: .text)
    case .toolUse(_, let name, let input):
        chatMessage = ChatMessage(
            role: .agent,
            content: input,
            messageType: .toolUse,
            toolName: name
        )
    case .toolResult(_, let content, let isError):
        chatMessage = ChatMessage(
            role: role,
            content: content,
            messageType: isError ? .toolError : .toolResult,
            isError: isError
        )
    }
}
```

This is effectively a translator embedded in view model code — a candidate for extraction into an ACL.


**7. Error Handling (TavernErrorMessages.swift:18-19, 44-159)**

The error mapper explicitly handles `ClaudeCodeError`:

```swift
if let claudeError = error as? ClaudeCodeError {
    return message(for: claudeError)
}
```

This is already partial ACL behavior — translating external errors to domain messages. But it's reactive (after the fact) rather than proactive (at the boundary).


**8. Mock Implementation (MockClaudeCode.swift)**

The mock must implement the SDK protocol and factory SDK result types:

```swift
public final class MockClaudeCode: ClaudeCode, @unchecked Sendable {
    // ...
    public func queueJSONResponse(
        result: String?,
        sessionId: String = UUID().uuidString,
        isError: Bool = false
    ) {
        guard let message = ResultMessageFactory.make(...)  // SDK type factory
        // ...
    }
}
```

Testing requires understanding SDK internals to construct valid mock responses.


### SDK Types Inventory

Types from ClaudeCodeSDK that appear in domain code:

| SDK Type | Where Used | Domain Concept |
|----------|------------|----------------|
| `ClaudeCode` (protocol) | Jake, MortalAgent, AgentSpawner | "LLM Backend" |
| `ClaudeCodeClient` | TavernProject | "Backend instance" |
| `ClaudeCodeConfiguration` | TavernProject | "Backend config" |
| `ClaudeCodeOptions` | Jake, MortalAgent | "Request options" |
| `ClaudeCodeResult` | Jake, MortalAgent | "Agent response" |
| `ClaudeCodeOutputFormat` | Jake, MortalAgent | "Response format" |
| `ResultMessage` | Jake, MortalAgent, MockClaudeCode | "Structured response" |
| `ClaudeCodeError` | TavernErrorMessages | "Backend errors" |
| `SessionInfo` | MockClaudeCode | "Session metadata" |
| `ClaudeStoredMessage` | SessionStore, ChatViewModel | "Stored message" |
| `ClaudeStoredSession` | (via storage) | "Session history" |
| `StoredContentBlock` | ChatViewModel | "Message block" |
| `ClaudeNativeSessionStorage` | SessionStore | "Session storage" |


## Where SDK Concepts Leak Into Domain


### Conceptual Leakage

**1. Output Format Semantics**

Domain code must understand that `.json` gives session IDs but `.text` doesn't:

```swift
// Using .json format (fixed in local SDK fork)
// This gives us session ID tracking and full content blocks
result = try await claude.resumeConversation(
    sessionId: sessionId,
    prompt: message,
    outputFormat: .json,  // SDK concept: why does domain care?
    options: options
)
```

The domain wants "a response with session continuity." The SDK says "use .json format."


**2. Session ID Management**

Session IDs are an SDK concept (how Claude CLI tracks conversations). The domain treats them as opaque strings, but must juggle them:

```swift
let currentSessionId: String? = queue.sync { _sessionId }
if let sessionId = currentSessionId {
    result = try await claude.resumeConversation(sessionId: sessionId, ...)
} else {
    result = try await claude.runSinglePrompt(prompt: message, ...)
}
```

An ACL could hide this: "continue conversation" vs "start new" — let the adapter track session state.


**3. Response Shape Assumptions**

Domain code assumes SDK response structure:

```swift
case .json(let resultMessage):
    let response = resultMessage.result ?? ""  // Knows result can be nil
    queue.sync { _sessionId = resultMessage.sessionId }  // Knows sessionId always exists
```

If SDK changes response structure, domain breaks.


**4. Content Block Taxonomy**

`StoredContentBlock` has cases: `.text`, `.toolUse`, `.toolResult`. Domain's `MessageType` mirrors this but adds `.toolError`, `.thinking`, `.webSearch`. The translation is explicit but scattered.


### Behavioral Leakage

**1. Error Semantics**

`ClaudeCodeError` has retry semantics (`isRetryable`, `suggestedRetryDelay`) that the domain doesn't use but could. The SDK error model leaks because `TavernErrorMessages` switches on all its cases.


**2. Streaming vs Batch**

The SDK supports streaming (`.stream` result type), but domain code treats it as "shouldn't happen":

```swift
case .stream:
    TavernLogger.agents.debug("Jake received unexpected stream result")
    return ""
```

The domain has no concept of streaming — it's a batch-only consumer. But SDK's model includes streaming.


**3. Backend Configuration**

SDK supports multiple backends (Agent SDK, headless CLI). Domain passes through configuration:

```swift
config.backend = .agentSDK  // SDK concept
config.enableDebugLogging = true  // SDK concept
```

Domain shouldn't know about backend types — it wants "an LLM that can chat."


## How ACL Would Translate Between Models


### Domain-Side Abstractions

**LLMBackend Protocol (Tavern's own interface):**

```swift
/// What Tavern needs from any LLM backend
protocol LLMBackend: Sendable {
    /// Send a message and get a response
    func chat(
        message: String,
        sessionContext: SessionContext?,
        systemPrompt: String?
    ) async throws -> AgentResponse

    /// Load historical messages for session restoration
    func loadHistory(for sessionContext: SessionContext) async throws -> [ConversationTurn]
}

/// Tavern's session concept (opaque to domain)
struct SessionContext: Sendable {
    let projectPath: String
    internal let sessionId: String?  // Implementation detail
}

/// What the domain receives from a chat
struct AgentResponse: Sendable {
    let content: String
    let sessionContext: SessionContext  // For continuity
    let metadata: ResponseMetadata
}

struct ResponseMetadata: Sendable {
    let cost: Double?
    let duration: TimeInterval
    let tokenUsage: TokenUsage?
}

/// Reconstructed conversation for history loading
struct ConversationTurn: Sendable {
    let role: ConversationRole
    let blocks: [ContentBlock]
    let timestamp: Date
}

enum ConversationRole { case user, agent }

enum ContentBlock: Sendable {
    case text(String)
    case toolInvocation(name: String, input: String)
    case toolOutput(content: String, isError: Bool)
    case thinking(String)
}
```


### Adapter Implementation

```swift
/// Translates between Tavern's LLMBackend and ClaudeCodeSDK
final class ClaudeCodeAdapter: LLMBackend {
    private let client: ClaudeCode
    private let translator: SDKTranslator

    init(workingDirectory: String) throws {
        var config = ClaudeCodeConfiguration.default
        config.workingDirectory = workingDirectory
        self.client = try ClaudeCodeClient(configuration: config)
        self.translator = SDKTranslator()
    }

    func chat(
        message: String,
        sessionContext: SessionContext?,
        systemPrompt: String?
    ) async throws -> AgentResponse {
        var options = ClaudeCodeOptions()
        options.systemPrompt = systemPrompt

        let result: ClaudeCodeResult
        do {
            if let context = sessionContext, let sessionId = context.sessionId {
                result = try await client.resumeConversation(
                    sessionId: sessionId,
                    prompt: message,
                    outputFormat: .json,
                    options: options
                )
            } else {
                result = try await client.runSinglePrompt(
                    prompt: message,
                    outputFormat: .json,
                    options: options
                )
            }
        } catch let error as ClaudeCodeError {
            throw translator.translateError(error)
        }

        return try translator.translateResult(result, projectPath: sessionContext?.projectPath)
    }

    func loadHistory(for context: SessionContext) async throws -> [ConversationTurn] {
        guard let sessionId = context.sessionId else { return [] }
        let storage = ClaudeNativeSessionStorage()
        let messages = try await storage.getMessages(
            sessionId: sessionId,
            projectPath: context.projectPath
        )
        return messages.map { translator.translateStoredMessage($0) }
    }
}
```


### Translator Component

```swift
struct SDKTranslator {
    func translateResult(_ result: ClaudeCodeResult, projectPath: String?) throws -> AgentResponse {
        switch result {
        case .json(let msg):
            return AgentResponse(
                content: msg.result ?? "",
                sessionContext: SessionContext(
                    projectPath: projectPath ?? "",
                    sessionId: msg.sessionId
                ),
                metadata: ResponseMetadata(
                    cost: msg.totalCostUsd,
                    duration: TimeInterval(msg.durationMs) / 1000,
                    tokenUsage: msg.usage.map { translateUsage($0) }
                )
            )
        case .text(let text):
            // Text format loses session context — create fresh
            return AgentResponse(
                content: text,
                sessionContext: SessionContext(projectPath: projectPath ?? "", sessionId: nil),
                metadata: ResponseMetadata(cost: nil, duration: 0, tokenUsage: nil)
            )
        case .stream:
            throw TavernError.unsupportedOperation("Streaming not supported")
        }
    }

    func translateError(_ error: ClaudeCodeError) -> TavernError {
        switch error {
        case .rateLimitExceeded(let retryAfter):
            return .rateLimited(retryAfter: retryAfter)
        case .timeout(let duration):
            return .operationTimeout(duration: duration)
        case .notInstalled:
            return .backendNotAvailable(reason: "Claude Code not installed")
        case .networkError(let underlying):
            return .networkFailure(underlying: underlying)
        // ... etc
        }
    }

    func translateStoredMessage(_ msg: ClaudeStoredMessage) -> ConversationTurn {
        let role: ConversationRole = msg.role == .user ? .user : .agent
        let blocks = msg.contentBlocks.compactMap { translateContentBlock($0) }
        return ConversationTurn(role: role, blocks: blocks, timestamp: msg.timestamp)
    }

    func translateContentBlock(_ block: StoredContentBlock) -> ContentBlock? {
        switch block {
        case .text(let text):
            return text.isEmpty ? nil : .text(text)
        case .toolUse(_, let name, let input):
            return .toolInvocation(name: name, input: input)
        case .toolResult(_, let content, let isError):
            return content.isEmpty ? nil : .toolOutput(content: content, isError: isError)
        }
    }
}
```


### Domain Code After ACL

**Jake.swift (simplified):**

```swift
public final class Jake: Agent {
    private let backend: LLMBackend
    private var sessionContext: SessionContext?

    public init(backend: LLMBackend, projectPath: String) {
        self.backend = backend
        self.sessionContext = SessionContext(projectPath: projectPath, sessionId: nil)
        // Restore from persistence if available
    }

    public func send(_ message: String) async throws -> String {
        let response = try await backend.chat(
            message: message,
            sessionContext: sessionContext,
            systemPrompt: Self.systemPrompt
        )
        self.sessionContext = response.sessionContext
        SessionStore.save(sessionContext, forProject: response.sessionContext.projectPath)
        return response.content
    }
}
```

No SDK types. No pattern matching on result cases. No knowledge of output formats.


## Trade-offs Considered


### Abstraction Depth

**Shallow ACL:** Just wrap `ClaudeCode` protocol with a Tavern-named protocol that has same methods. Minimal benefit.

**Deep ACL:** Define completely new domain concepts (Agent responses, conversation turns) that don't map 1:1 to SDK. Higher investment, bigger payoff.

**Recommendation:** Medium depth. Wrap core operations (chat, history) with domain types. Don't try to abstract every SDK capability.


### What to Abstract vs Pass Through

| SDK Capability | Abstract? | Rationale |
|----------------|-----------|-----------|
| Chat/prompt | Yes | Core operation, domain needs own result type |
| Session management | Partially | Domain tracks context; adapter handles IDs |
| History retrieval | Yes | Domain has own message types |
| Streaming | No | Domain doesn't use it yet |
| MCP configuration | No | Infrastructure concern |
| Rate limiting/retry | Partially | Error translation, but retry policy in adapter |
| Backend selection | No | Infrastructure concern |


### Error Handling Strategy

**Option A: Wrap all SDK errors in TavernError**
- Pro: Domain never sees SDK errors
- Con: Loses granularity, harder to debug

**Option B: Translate known errors, rethrow unknown**
- Pro: Handles expected cases, doesn't hide unexpected
- Con: SDK errors can still leak

**Option C: Translate all with "unknown backend error" fallback**
- Pro: Clean boundary, but retains information
- Con: Some duplication of error types

**Recommendation:** Option C. Every error that crosses the boundary becomes a TavernError. Unknown cases become `.backendError(underlying: Error)` for debugging.


## Implementation Complexity


### Files to Create

1. `LLMBackend.swift` — Protocol and domain types (~100 LOC)
2. `ClaudeCodeAdapter.swift` — SDK adapter (~150 LOC)
3. `SDKTranslator.swift` — Translation logic (~200 LOC)
4. `MockLLMBackend.swift` — Domain-native mock (~80 LOC)

Total: ~530 new lines of code.


### Files to Modify

1. `TavernCore.swift` — Remove `@_exported import ClaudeCodeSDK`
2. `Jake.swift` — Use `LLMBackend` instead of `ClaudeCode`
3. `MortalAgent.swift` — Use `LLMBackend` instead of `ClaudeCode`
4. `AgentSpawner.swift` — Change factory from `ClaudeCode` to `LLMBackend`
5. `TavernProject.swift` — Create adapter instead of raw client
6. `SessionStore.swift` — Use domain session types
7. `ChatViewModel.swift` — Use domain content blocks
8. `TavernError.swift` — Add new error cases
9. `MockClaudeCode.swift` — Replace with `MockLLMBackend` (or delete)

Moderate refactoring across ~9 files.


### Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Abstraction doesn't fit future needs | Medium | Start minimal, expand as needed |
| Performance overhead | Low | Translation is cheap |
| Testing regression | Medium | Parallel test runs during transition |
| Feature gap (SDK has capability, ACL doesn't) | Medium | Expose escape hatch if needed |


## Migration Path from Current State


### Phase 1: Define Domain Types (Non-breaking)

Create `LLMBackend` protocol and domain types alongside existing SDK usage. No changes to existing code.


### Phase 2: Create Adapter (Non-breaking)

Implement `ClaudeCodeAdapter` that wraps `ClaudeCodeClient`. Tests prove equivalence.


### Phase 3: Migrate Jake (Breaking but contained)

Switch Jake to use `LLMBackend`. Update tests to use `MockLLMBackend`. One agent converted, verify stability.


### Phase 4: Migrate MortalAgent

Same process. Both agent types now use domain abstraction.


### Phase 5: Clean Up

- Remove `@_exported import ClaudeCodeSDK`
- Update SessionStore to domain types
- Update ChatViewModel translation
- Delete `MockClaudeCode`, use `MockLLMBackend`


### Rollback Points

Each phase is a stable state. If issues arise, stop at current phase.


## Open Questions


### 1. Should session context be fully opaque?

Currently proposed as having internal sessionId. Alternative: completely opaque handle that only the adapter can interpret.

**Impact:** Affects serialization for persistence. Opaque handle needs adapter involvement in save/load.


### 2. How to handle future streaming?

If domain eventually wants streaming, ACL needs to expose it. Options:
- Add streaming method to protocol when needed
- Design protocol with streaming from start (unused for now)
- Create separate StreamingLLMBackend protocol

**Recommendation:** Defer until needed. Adding later is straightforward.


### 3. Should adapter manage session persistence?

Currently, Jake/agents call SessionStore directly. Alternative: adapter owns persistence.

**Trade-off:**
- Adapter owns: Cleaner separation, but adapter needs project context
- Domain owns: More control, but persistence logic scattered

**Recommendation:** Keep persistence in domain (SessionStore) for now. It's about domain state, not SDK behavior.


### 4. What about MCP tools configuration?

SDK supports MCP server configuration. Currently unused in Tavern. Options:
- Ignore in ACL (pass through in configuration if ever needed)
- Abstract as "tool registration" in domain

**Recommendation:** Ignore for now. Cross that bridge when Tavern needs tools.


### 5. Should error translation be exhaustive?

`ClaudeCodeError` has many cases. Translate each, or bucket into categories?

**Recommendation:** Start with buckets (network, timeout, auth, backend, unknown). Expand if domain needs to differentiate.


### 6. How to handle the local SDK fork?

The project uses a forked ClaudeCodeSDK with JSON parsing fixes. ACL doesn't change this, but isolation makes it easier to eventually switch to upstream when fixed.


## Summary

The Anti-Corruption Layer architecture addresses a real coupling issue in the Tavern codebase. SDK types permeate domain code, creating fragility and testing complexity. An ACL would:

1. Define clean domain abstractions (`LLMBackend`, `AgentResponse`, `ConversationTurn`)
2. Isolate SDK specifics in adapter layer
3. Enable domain-native mocking
4. Translate errors at the boundary
5. Protect against SDK evolution

The implementation is moderate (~530 new LOC, ~9 files modified) with a clear migration path. The main trade-off is the upfront investment in abstraction design versus continued ad-hoc integration.

For a multi-agent orchestrator that will grow in complexity, this boundary clarity is likely worth the investment.
