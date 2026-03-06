# Object Capability Model: Complete Analysis

This document contains comprehensive research, analysis, and thinking on applying the Object Capability Model (OCaM) to the Tavern multi-agent orchestrator.


## Research Findings


### The E Programming Language Heritage

The Object Capability Model originated with the E programming language (created by Mark S. Miller at Electric Communities in the late 1990s). E was designed from the ground up for secure distributed computing, and its core insight was revolutionary: **conflate designation with authorization**.

In traditional security models:
1. You name a resource (designation)
2. The system checks if you're allowed (authorization)
3. Access is granted or denied

In E/OCaM:
1. Having a reference IS the authorization
2. There is no step 2

This eliminates the confused deputy problem, TOCTOU races, and capability forgery attacks by construction. If you can name it, you can use it. If you can't name it, you can't even try.

Key E concepts relevant to Tavern:
- **Vats**: Isolated containers of objects (maps to agents)
- **Promises**: Asynchronous capability passing (maps to Swift async/await)
- **Facets**: Attenuated views of objects (maps to wrapper protocols)
- **Sealer/Unsealer pairs**: Unforgeable tokens (maps to Swift class identity)


### How This Differs from Capability-Based (#7)

The existing Capability-Based proposal (#7) uses a **token-based** approach:

```swift
// Capability-Based (#7) approach
guard let shellCap = try await capabilityRegistry.request(
    .shell(commands: ["bash"]),
    for: agent.id
) else {
    throw CapabilityError.denied(.shell)
}
let result = try await runner.run(command, capability: shellCap)
```

This has three steps:
1. Request token from registry
2. Registry checks policy, grants or denies
3. Resource validates token before action

The Object Capability Model eliminates all three:

```swift
// Object Capability Model approach
// Agent only HAS shellRunner if it was explicitly passed at spawn
let result = try await shellRunner.run(command)
```

**Key distinctions:**

| Aspect | Capability-Based (#7) | Object Capability Model |
|--------|----------------------|------------------------|
| **Access check** | Runtime, by registry | Compile-time, by reference existence |
| **Token nature** | Data structure, validated | Reference, unforgeable |
| **Authority source** | Policy engine | Explicit passing |
| **Revocation** | Registry can invalidate | Must use wrapper objects |
| **Performance** | Registry lookup cost | Zero overhead (reference is check) |
| **Audit** | Logged at grant time | Traceable through call graph |
| **Forgery** | Token must be cryptographically secure | References cannot be forged in Swift |


### Swift Reference Semantics Analysis

Swift's type system and reference semantics are well-suited for OCaM, with some caveats:

**Enabling Factors:**

1. **Class references are unforgeable**: You cannot manufacture a reference to an object without going through its initializer. There's no pointer arithmetic, no `unsafeBitCast` in safe Swift.

```swift
final class FileWriter {
    private let root: URL

    // The only way to get a FileWriter is through this init
    init(root: URL) {
        self.root = root
    }

    func write(_ data: Data, to path: String) throws {
        // Can only write within root - enforced by construction
    }
}
```

2. **No global mutable state by convention**: Swift discourages singletons. While you CAN create them, the community norm is explicit dependency injection.

3. **Sendable enforcement**: Swift 6's strict concurrency model means capabilities that cross actor boundaries must be `Sendable`, preventing accidental sharing of mutable state.

4. **Protocol-based attenuation**: Wrapping capabilities to restrict them is natural with protocols:

```swift
protocol FileReading {
    func read(from path: String) throws -> Data
}

protocol FileWriting {
    func write(_ data: Data, to path: String) throws
}

// Full capability implements both
final class FileSystem: FileReading, FileWriting { ... }

// Attenuated view for read-only access
func spawnAgent(reader: some FileReading) -> Agent {
    // Agent can only read, cannot write
    // This is compile-time enforced
}
```

**Hindering Factors:**

1. **Global functions and static members**: Swift allows global functions and static members that can bypass OCaM:

```swift
// This violates OCaM - ambient authority
FileManager.default.contentsOfDirectory(atPath: "/")
```

Mitigation: Wrap all system interfaces in capability objects, never use global APIs directly.

2. **Process-level resources**: Some resources (stdin, stdout, environment variables) are process-global.

Mitigation: Create capability wrappers at app startup, never access directly.

3. **Objective-C runtime**: The Objective-C runtime allows dynamic method dispatch and swizzling that could theoretically break OCaM guarantees.

Mitigation: Use `final class` everywhere (prevents subclassing), avoid Objective-C interop in capability-sensitive code.

4. **Debugging and testing**: Debuggers and test frameworks often need to reach into objects. This is acceptable as long as production code respects OCaM.


### Current Codebase State

Analyzing the existing implementation for OCaM readiness:

**`Jake.swift` and `MortalAgent.swift`:**

Current pattern:
```swift
public init(id: UUID = UUID(), claude: ClaudeCode, loadSavedSession: Bool = true) {
    self.id = id
    self.claude = claude  // Claude is already passed, not created internally!
    // ...
}
```

This is already partially OCaM! The `ClaudeCode` instance is injected, not globally accessed. The agent can only talk to Claude through the reference it was given.

**`AgentSpawner.swift`:**

```swift
private let claudeFactory: () -> ClaudeCode

public func spawn(assignment: String) throws -> MortalAgent {
    let claude = claudeFactory()  // Creates capability on demand
    let agent = MortalAgent(name: name, assignment: assignment, claude: claude)
    // ...
}
```

The factory pattern here is OCaM-adjacent. The spawner has the capability to create ClaudeCode instances, and passes them to agents. However, the factory is unlimited — full OCaM would pass pre-constrained instances.

**`CommitmentVerifier.swift`:**

```swift
public init(runner: AssertionRunner = ShellAssertionRunner()) {
    self.runner = runner
}
```

Excellent! The `AssertionRunner` is injected. This IS object capability — the verifier can only run assertions through the runner it was given. If you want to restrict what commands can run, pass a restricted `AssertionRunner`.

**`DocStore.swift`:**

```swift
public init(rootDirectory: URL, ...) throws {
    self.rootDirectory = rootDirectory
    // Can only access files under rootDirectory
}
```

This is OCaM by design! The store can only access its root directory. Pass a different root = different capability scope.

**Violations of OCaM in current code:**

1. `FileManager.default` used in several places — global access
2. `SessionStore` uses `UserDefaults.standard` — global access
3. `TavernLogger` uses static loggers — global access (acceptable for logging)


### PRD Sandbox Requirements Mapping

The PRD Section 4.6 defines five sandbox primitives. Here's how OCaM maps each:

**1. Changeset (Overlay filesystem on project root)**

OCaM approach:
```swift
protocol FileCapability: Sendable {
    func read(path: String) async throws -> Data
    func write(path: String, data: Data) async throws
    func exists(path: String) async -> Bool
}

final class ChangesetFileSystem: FileCapability {
    private let projectRoot: URL
    private let overlayRoot: URL

    // Writes go to overlay, reads merge overlay + project
    // Agent receives this as its only file capability
}
```

The agent receives a `ChangesetFileSystem` reference. It cannot access files outside the overlay/project because it has no other `FileCapability`. This is enforced by the type system — the agent's code literally cannot express "access a file outside my capability."

**2. Platform (Where agent runs)**

OCaM approach:
```swift
protocol ExecutionEnvironment: Sendable {
    func spawn(command: String, args: [String]) async throws -> ProcessResult
}

final class LocalExecutionEnvironment: ExecutionEnvironment { ... }
final class ContainerExecutionEnvironment: ExecutionEnvironment { ... }
final class CloudExecutionEnvironment: ExecutionEnvironment { ... }
```

The agent receives whichever `ExecutionEnvironment` is appropriate for its platform. It cannot "reach out" to a different platform — it only has a reference to one.

**3. Isolation (VMs, containers, OS sandboxes)**

This is inherently about the platform layer, but OCaM adds: even if an agent is in the same process, it cannot affect other agents because it has no references to their capabilities.

**4. Outputs (Network access control)**

OCaM approach:
```swift
protocol NetworkCapability: Sendable {
    func fetch(url: URL) async throws -> Data
}

final class RestrictedNetwork: NetworkCapability {
    private let allowedHosts: Set<String>

    func fetch(url: URL) async throws -> Data {
        guard allowedHosts.contains(url.host ?? "") else {
            throw NetworkError.hostNotAllowed
        }
        // Actual fetch
    }
}
```

Pass the agent a `RestrictedNetwork` with only allowed hosts. It cannot access other hosts because it has no reference to an unrestricted network capability.

**5. Software (OS choice)**

This maps to the `ExecutionEnvironment` capability — the environment determines what software is available.


### Implementation Approach

**Phase 1: Define Capability Protocols**

Create the fundamental capability interfaces:

```swift
// Sources/TavernCore/Capabilities/Capabilities.swift

/// Marker protocol for all capability objects
public protocol Capability: Sendable {}

/// File system access
public protocol FileCapability: Capability {
    func read(path: String) async throws -> Data
    func write(path: String, data: Data) async throws
    func delete(path: String) async throws
    func list(directory: String) async throws -> [String]
    func exists(path: String) async -> Bool
}

/// Shell command execution
public protocol ShellCapability: Capability {
    func run(_ command: String) async throws -> ShellResult
}

/// Claude SDK access
public protocol ClaudeCapability: Capability {
    func prompt(_ message: String) async throws -> String
    var tokenBudget: Int { get }
    var tokensUsed: Int { get }
}

/// Agent spawning
public protocol SpawnCapability: Capability {
    func spawn(
        assignment: String,
        capabilities: AgentCapabilities
    ) async throws -> AgentHandle
}

/// Network access
public protocol NetworkCapability: Capability {
    func fetch(url: URL) async throws -> Data
}
```

**Phase 2: Create Capability Bundles**

Agents receive a bundle of capabilities at spawn time:

```swift
// Sources/TavernCore/Capabilities/AgentCapabilities.swift

/// The complete set of capabilities an agent possesses
public struct AgentCapabilities: Sendable {
    public let files: (any FileCapability)?
    public let shell: (any ShellCapability)?
    public let claude: (any ClaudeCapability)?
    public let spawn: (any SpawnCapability)?
    public let network: (any NetworkCapability)?

    public init(
        files: (any FileCapability)? = nil,
        shell: (any ShellCapability)? = nil,
        claude: (any ClaudeCapability)? = nil,
        spawn: (any SpawnCapability)? = nil,
        network: (any NetworkCapability)? = nil
    ) {
        self.files = files
        self.shell = shell
        self.claude = claude
        self.spawn = spawn
        self.network = network
    }
}
```

**Phase 3: Implement Concrete Capabilities**

Full-power implementations for Jake:

```swift
// Sources/TavernCore/Capabilities/Concrete/FullFileSystem.swift

public final class FullFileSystem: FileCapability {
    private let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func read(path: String) async throws -> Data {
        let url = root.appendingPathComponent(path)
        return try Data(contentsOf: url)
    }

    // ... other methods
}
```

Attenuated implementations for mortals:

```swift
// Sources/TavernCore/Capabilities/Attenuated/ReadOnlyFileSystem.swift

public final class ReadOnlyFileSystem: FileCapability {
    private let wrapped: any FileCapability

    public init(wrapping: any FileCapability) {
        self.wrapped = wrapping
    }

    public func read(path: String) async throws -> Data {
        try await wrapped.read(path: path)
    }

    public func write(path: String, data: Data) async throws {
        throw FileError.readOnly
    }

    public func delete(path: String) async throws {
        throw FileError.readOnly
    }

    // ... list and exists pass through
}
```

**Phase 4: Refactor Agents**

Modify `MortalAgent` to use capabilities:

```swift
public final class MortalAgent: Agent, @unchecked Sendable {
    // Before
    // private let claude: ClaudeCode

    // After
    private let capabilities: AgentCapabilities

    public init(
        name: String,
        assignment: String,
        capabilities: AgentCapabilities
    ) {
        self.capabilities = capabilities
        // ...
    }

    public func send(_ message: String) async throws -> String {
        guard let claude = capabilities.claude else {
            throw CapabilityError.missing(.claude)
        }
        return try await claude.prompt(message)
    }
}
```

**Phase 5: Refactor Spawning**

The spawner becomes a capability itself:

```swift
public final class TavernSpawner: SpawnCapability {
    private let agentCapabilities: AgentCapabilities  // What children can receive
    private let registry: AgentRegistry
    private let nameGenerator: NameGenerator

    public func spawn(
        assignment: String,
        capabilities: AgentCapabilities
    ) async throws -> AgentHandle {
        // Validate requested capabilities are subset of what we can grant
        let granted = capabilities.attenuatedTo(agentCapabilities)

        let agent = MortalAgent(
            name: nameGenerator.next(),
            assignment: assignment,
            capabilities: granted
        )

        try registry.register(agent)
        return AgentHandle(agent)
    }
}
```


### Trade-offs Considered


**1. Structural Guarantee vs. Development Velocity**

OCaM provides the strongest possible security guarantee: unauthorized access is a *type error*, not a runtime failure. However, this requires threading capabilities through every call site.

Current code:
```swift
func someOperation() {
    let files = FileManager.default  // Grab global
    // ...
}
```

OCaM code:
```swift
func someOperation(files: some FileCapability) {
    // ...
}
```

Every function signature grows. Every call site must provide capabilities. This is the price of the guarantee.

**Verdict:** For Tavern, this trade-off is worth it. The PRD explicitly demands that "agents cannot modify their own invariants." OCaM makes this impossible by construction.


**2. Revocation Complexity**

Pure OCaM has no revocation — once you share a reference, it's shared. The recipient can use it forever.

Mitigation pattern (Membrane/Caretaker):

```swift
final class RevocableFileSystem: FileCapability {
    private let wrapped: any FileCapability
    private var revoked = false

    func revoke() {
        revoked = true
    }

    func read(path: String) async throws -> Data {
        guard !revoked else { throw CapabilityError.revoked }
        return try await wrapped.read(path: path)
    }
}
```

The parent keeps the `RevocableFileSystem` instance and can call `revoke()` at any time. The child only has access through this wrapper.

**Verdict:** Revocation is implementable within OCaM using the Membrane pattern. Not a blocker.


**3. Dynamic Capability Decisions**

Sometimes capability grants depend on runtime state. Token-based systems handle this naturally — the policy engine evaluates at request time.

OCaM requires a different pattern:

```swift
// Factory that creates capabilities based on runtime state
final class CapabilityFactory {
    func makeClaudeCapability(forAgent agent: AgentHandle) -> any ClaudeCapability {
        let budget = calculateBudget(agent)
        return BudgetedClaude(budget: budget)
    }
}
```

The factory becomes a capability itself — having the factory reference means you can request capability objects, but the factory decides what you get.

**Verdict:** Slightly more ceremony than token-based, but preserves OCaM's guarantee that the returned capability object itself embodies the constraint.


**4. Bootstrap Problem**

OCaM says "no ambient authority." But something has to create the initial capabilities. Who creates the `FullFileSystem` that Jake receives?

Solution: The application entry point (outside the agent system) creates root capabilities:

```swift
// TavernApp.swift (outside agent boundary)
@main
struct TavernApp {
    static func main() {
        // Bootstrap: create root capabilities
        let rootFiles = FullFileSystem(root: projectURL)
        let rootShell = FullShellRunner()
        let rootClaude = ClaudeCodeWrapper()

        // Create Jake with full capabilities
        let jakeCapabilities = AgentCapabilities(
            files: rootFiles,
            shell: rootShell,
            claude: rootClaude,
            spawn: /* spawner with subset */,
            network: nil  // Jake doesn't need network
        )

        let jake = Jake(capabilities: jakeCapabilities)
        // ...
    }
}
```

The app shell is the "trusted computing base" — it bootstraps the capability graph, then hands off to Jake.

**Verdict:** Clean separation. The bootstrap code is small, auditable, and separate from agent code.


### Implementation Complexity Estimate

**New Files:**

| File | Purpose | Estimated LOC |
|------|---------|--------------|
| `Capabilities/Capability.swift` | Base protocol | 30 |
| `Capabilities/FileCapability.swift` | File access protocol | 50 |
| `Capabilities/ShellCapability.swift` | Shell execution protocol | 30 |
| `Capabilities/ClaudeCapability.swift` | SDK access protocol | 50 |
| `Capabilities/SpawnCapability.swift` | Agent spawning protocol | 40 |
| `Capabilities/NetworkCapability.swift` | Network access protocol | 30 |
| `Capabilities/AgentCapabilities.swift` | Capability bundle | 80 |
| `Capabilities/Concrete/FullFileSystem.swift` | Full file access | 100 |
| `Capabilities/Concrete/FullShellRunner.swift` | Full shell access | 80 |
| `Capabilities/Concrete/ClaudeCodeWrapper.swift` | SDK wrapper | 100 |
| `Capabilities/Attenuated/ReadOnlyFileSystem.swift` | Read-only wrapper | 60 |
| `Capabilities/Attenuated/BudgetedClaude.swift` | Budget-limited wrapper | 80 |
| `Capabilities/Attenuated/AllowlistShell.swift` | Command-restricted shell | 70 |
| `Capabilities/Attenuated/RevocableWrapper.swift` | Revocation membrane | 60 |

**Total new code:** ~860 LOC

**Modified Files:**

| File | Changes |
|------|---------|
| `Jake.swift` | Accept capabilities instead of `ClaudeCode` |
| `MortalAgent.swift` | Accept `AgentCapabilities` bundle |
| `AgentSpawner.swift` | Become `SpawnCapability`, pass capabilities |
| `TavernCoordinator.swift` | Initialize capability graph |
| `CommitmentVerifier.swift` | Require `ShellCapability` |
| `DocStore.swift` | Require `FileCapability` |
| `TavernApp.swift` | Bootstrap capability graph |

**Modified LOC:** ~200-300 lines of changes across existing files

**Testing Requirements:**

- ~30 tests for capability protocols and implementations
- ~20 tests for attenuation wrappers
- ~15 tests for revocation/membrane patterns
- ~20 tests for integration with agents
- Modify ~50 existing tests to pass capabilities

**Total estimate:** ~85+ new tests, modifications to ~50 existing tests


### Migration Path from Current State


**Phase 1: Capability Infrastructure (Week 1)**

1. Create `Capabilities/` directory structure
2. Define core protocols (`FileCapability`, `ShellCapability`, `ClaudeCapability`)
3. Create concrete implementations wrapping current code
4. Create `AgentCapabilities` bundle type
5. **All existing tests still pass** — no behavior change yet

Verification: Run full test suite, all 173 tests pass.


**Phase 2: Wrap CommitmentVerifier (Week 2)**

The verifier is isolated and well-tested — perfect first target.

1. Modify `CommitmentVerifier` to require `ShellCapability` parameter
2. Update all verifier tests to pass shell capability
3. Update `MortalAgent` to pass its shell capability to verifier
4. **Behavior unchanged, but capability is now explicit**

Verification: All commitment tests pass with capability injection.


**Phase 3: Wrap ClaudeCode (Week 2)**

1. Create `ClaudeCapability` protocol
2. Create `ClaudeCodeWrapper` implementing the protocol
3. Create `BudgetedClaude` for token-limited access
4. Modify `Jake` to accept `ClaudeCapability`
5. Modify `MortalAgent` to accept `ClaudeCapability`

Verification: All agent communication tests pass.


**Phase 4: Wrap DocStore (Week 3)**

1. Modify `DocStore` to require `FileCapability` for operations
2. Create `ChangesetFileSystem` for overlay pattern
3. Update all DocStore tests

Verification: All persistence tests pass with capability injection.


**Phase 5: Full Agent Refactor (Week 3-4)**

1. Create `AgentCapabilities` bundle
2. Modify `MortalAgent` to receive bundle at init
3. Modify `AgentSpawner` to construct capability bundles
4. Implement `SpawnCapability` protocol
5. Jake receives spawn capability that creates child bundles

Verification: End-to-end spawning tests pass with capability flow.


**Phase 6: Bootstrap and Integration (Week 4)**

1. Modify `TavernApp` to create root capability graph
2. Pass root capabilities to `TavernCoordinator`
3. Coordinator passes to Jake
4. Remove all remaining global access patterns

Verification: Full integration test — app launches, creates agents, respects capability boundaries.


### Open Questions


**Q1: How do we handle optional capabilities?**

Current: `AgentCapabilities` uses optional properties. Agent must check before use.

Alternative: Multiple `AgentCapabilities` types (e.g., `FileAgentCapabilities`, `ComputeAgentCapabilities`) enforced at compile time.

Recommendation: Start with optionals, evaluate if compile-time enforcement adds value without too much type complexity.


**Q2: How do we debug capability flow?**

When something doesn't work because an agent lacks a capability, how do we diagnose?

Options:
1. Descriptive error messages ("Agent X attempted file write but has no FileCapability")
2. Capability tracing logs ("Capability FileSystem(root=/project) passed to Agent X at spawn")
3. Capability visualization in UI

Recommendation: Implement option 2 at minimum. Consider option 3 for production debugging.


**Q3: How do capabilities interact with session persistence?**

Current: `SessionStore` persists session IDs using `UserDefaults.standard` (global access).

Challenge: SessionStore needs some capability, but sessions must survive app restart.

Resolution: SessionStore is part of the trusted bootstrap code, not agent code. It receives `FileCapability` for its storage location from the app shell.


**Q4: What about logging?**

`TavernLogger` uses static loggers. Is this a violation of OCaM?

Answer: Logging is an exception to the "no ambient authority" rule in most OCaM systems. Logs are append-only, don't affect computation, and debugging requires global access. This is acceptable pragmatism.


**Q5: How does this interact with Swift actors?**

If we combine OCaM with the Actor Model (#2), actor isolation adds another layer:
- Actor isolation: prevents data races across actors
- Object capability: prevents unauthorized resource access

These are orthogonal and composable. An `actor Agent` could still receive capability objects at initialization.


**Q6: Performance of protocol existentials?**

Using `any FileCapability` has performance overhead compared to concrete types due to existential boxing and dynamic dispatch.

Mitigation options:
1. Use generics where possible (`<F: FileCapability>`)
2. Accept the overhead (usually negligible for I/O-bound operations)
3. Use `@inlinable` and `@usableFromInline` for hot paths

Recommendation: Start with existentials for simplicity, profile if performance issues arise.


**Q7: Can agents share capabilities?**

If Agent A has `FileCapability` for `/project/src/`, can it pass this to Agent B?

OCaM answer: Yes, if A has a reference, it can pass it. This is capability delegation.

Question: Should we allow this in Tavern?

Recommendation: Yes, but document that passing a capability shares access. Parents should pass attenuated capabilities to children.


### Comparison with Capability-Based (#7)


| Dimension | Capability-Based (#7) | Object Capability Model |
|-----------|----------------------|------------------------|
| **Security model** | Policy-checked tokens | Reference-is-capability |
| **Checking** | Runtime, by registry | None (possession is proof) |
| **Performance** | Registry lookup overhead | Zero overhead |
| **Forgery resistance** | Depends on token implementation | Guaranteed by language |
| **Implementation** | 800-1000 LOC, registry central | 860 LOC, distributed |
| **Mental model** | Request-grant workflow | Dependency injection |
| **Swift fit** | Requires registry infrastructure | Natural with protocols |
| **Revocation** | Registry invalidates token | Requires membrane wrappers |
| **Audit trail** | Logged at grant time | Implicit in call graph |
| **Compile-time safety** | Limited | Full (type errors for missing caps) |


### Conclusion

The Object Capability Model provides the strongest security guarantees of any architecture considered. Its core insight — that having a reference IS the capability — eliminates entire classes of security vulnerabilities by construction.

For Tavern specifically:

1. **PRD Invariant 6** ("Agents cannot modify their own invariants") becomes mathematically guaranteed. An agent cannot grant itself capabilities because references cannot be forged.

2. **Sandbox primitives** map cleanly to capability protocols. Each primitive becomes a capability type; each configuration becomes an attenuated implementation.

3. **Current codebase** is already partially OCaM (dependency injection of `ClaudeCode`, `AssertionRunner`). Migration is incremental, not revolutionary.

4. **Swift's type system** enforces OCaM naturally. No additional runtime infrastructure needed.

5. **Testing** improves because capabilities can be mocked at protocol boundaries.

**Recommendation:** Object Capability Model is the strongest choice for Tavern's security requirements. The implementation complexity is comparable to Capability-Based (#7), but the guarantees are stronger. Prioritize OCaM if security is the primary concern; consider Capability-Based (#7) if you want more runtime flexibility for dynamic policy changes.

The migration can be incremental — start with capability protocols alongside existing code, gradually enforce until all global access is eliminated. The current codebase's existing dependency injection patterns make this tractable.
