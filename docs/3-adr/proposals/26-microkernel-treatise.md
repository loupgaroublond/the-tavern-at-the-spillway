# Microkernel Architecture Treatise

A complete analysis of the Microkernel Architecture proposal for The Tavern at the Spillway.


## Research Findings


### Operating System Microkernel Principles

The microkernel concept comes from operating system design, particularly Mach, L4, and QNX. The key insight is that traditional monolithic kernels (Linux, BSD) put too much functionality in the privileged kernel space. A microkernel moves most services - file systems, device drivers, network stacks - into user-space processes, leaving only essential mechanisms in the kernel.

**Typical microkernel responsibilities:**
1. Process/thread management (spawn, terminate, schedule)
2. Inter-process communication (IPC)
3. Memory management (address space isolation)
4. Basic I/O and interrupt handling

Everything else becomes a "server" that communicates with other servers and applications via IPC.

**Benefits realized in OS design:**
- Fault isolation (a crashing file system server doesn't crash the kernel)
- Hot-swapping (replace drivers without reboot)
- Security (smaller trusted computing base)
- Portability (kernel is small and well-defined)

**Costs realized in OS design:**
- IPC overhead (system calls become message passes)
- Increased context switches
- Complexity of message protocols
- Debugging across process boundaries


### Applying Microkernel to Multi-Agent Orchestration

Translating OS microkernel principles to Tavern:

| OS Concept | Tavern Equivalent |
|------------|-------------------|
| Process | Agent instance |
| IPC | Message routing between agents/modules |
| Scheduler | Fairness/priority for agent execution |
| Driver | Tool module (git, shell, linter) |
| File system server | DocStore module |
| System call | Kernel API for spawn/terminate/route |

The kernel becomes a minimal coordinator that knows only:
- How to spawn an agent process (via a module-provided factory)
- How to route messages between agents and modules
- How to detect agent failure (timeout, crash, budget exceeded)
- How to notify interested parties of lifecycle events

The kernel explicitly does NOT know:
- What an "agent" is or how it behaves
- What verification means or how to do it
- What Jake's personality is
- What makes an agent "done"
- How to name agents
- What workflows are


### Current Codebase Analysis

Examining the current implementation for microkernel alignment:

**Current TavernCoordinator responsibilities:**
1. Owns Jake and AgentSpawner
2. Manages chat view model cache
3. Handles agent selection and UI state
4. Coordinates spawn and dismiss operations

This is already somewhat monolithic - the coordinator knows about agents, spawning, selection, and UI.

**Current Agent responsibilities:**
1. Protocol defines: id, name, state, send(), resetConversation()
2. Jake has hardcoded system prompt (persona)
3. MortalAgent has hardcoded system prompt template
4. MortalAgent detects "DONE" signal in responses
5. MortalAgent triggers verification via CommitmentVerifier

In a microkernel design:
- The Agent protocol would be defined by a module, not the kernel
- Jake's persona would be in a module
- DONE detection logic would be in a module
- Verification triggering would be in a module

**Current AgentSpawner responsibilities:**
1. Creates MortalAgent instances
2. Manages AgentRegistry
3. Uses NameGenerator for themed names
4. Creates ClaudeCode instances via factory

In a microkernel design:
- AgentSpawner would BE a module that registers with the kernel
- The kernel would expose a spawn API that delegates to whatever agent module is loaded
- Naming would be a separate module

**Key Observation:** The current codebase is a reasonable "monolithic" design with some separation (registry, spawner, verifier). Converting to microkernel would require:
1. Defining kernel-module interfaces
2. Moving all behavior into modules
3. Implementing message routing between modules
4. Making the kernel truly minimal


## What's in the Kernel vs. Modules?


### The Kernel (Minimal Core)

```swift
// The ENTIRE kernel surface area

protocol TavernKernel {
    // Lifecycle
    func spawn(moduleId: String, config: ModuleConfig) -> ProcessId
    func terminate(id: ProcessId)
    func monitor(id: ProcessId, handler: (FaultEvent) -> Void)

    // Messaging
    func send(to: ProcessId, message: Message)
    func broadcast(topic: String, message: Message)
    func subscribe(topic: String, handler: (Message) -> Void)

    // Module management
    func loadModule(bundle: ModuleBundle) throws -> ModuleId
    func unloadModule(id: ModuleId) throws
    func moduleHandle(id: ModuleId) -> ModuleHandle?
}

// That's it. The kernel knows nothing about:
// - What agents are or how they work
// - What verification means
// - What Jake is
// - What workflows are
// - What the UI should show
```


### Core Modules (Required for Basic Functionality)

**AgentModule** - Defines what "agent" means
```swift
protocol AgentModule: Module {
    func createAgent(config: AgentConfig) -> AgentHandle
    func sendToAgent(handle: AgentHandle, message: String) async throws -> String
    func agentState(handle: AgentHandle) -> AgentState
}

// This module defines the Agent protocol equivalent
// It knows about Claude SDK, sessions, prompts
// Different AgentModules could implement different agent models
```

**SessionModule** - Claude SDK integration
```swift
protocol SessionModule: Module {
    func createSession(workingDirectory: String) -> SessionHandle
    func sendPrompt(session: SessionHandle, prompt: String, systemPrompt: String) async throws -> Response
    func resumeSession(id: String, prompt: String) async throws -> Response
}

// Wraps ClaudeCodeSDK
// Could be swapped for different LLM backends
```

**PersistenceModule** - DocStore operations
```swift
protocol PersistenceModule: Module {
    func save(document: Document) throws
    func load(id: String) throws -> Document
    func delete(id: String) throws
    func list(filter: DocumentFilter) throws -> [String]
}

// The filesystem-as-database abstraction
// Could be swapped for a real database
```


### Policy Modules (Swappable)

**JakeModule** - Jake's identity and behavior
```swift
protocol JakeModule: Module {
    var systemPrompt: String { get }
    var cogitationVerbs: [String] { get }
    func shouldSpawnAgent(for message: String) -> SpawnDecision?
    func coordinationLogic(event: CoordinationEvent) -> CoordinationAction
}

// All of Jake's personality and coordination logic
// Swap this module for a different top-level coordinator
```

**VerificationModule** - Commitment checking
```swift
protocol VerificationModule: Module {
    func verify(commitment: Commitment) async throws -> VerificationResult
    func shouldAgentBeDone(response: String, commitments: [Commitment]) -> Bool
    func handleFailedVerification(agent: AgentHandle, failure: VerificationResult) -> RecoveryAction
}

// All verification logic
// Could be swapped for semantic verification, AI-based verification, etc.
```

**NamingModule** - Themed name generation
```swift
protocol NamingModule: Module {
    var availableThemes: [NamingTheme] { get }
    func generateName(theme: NamingTheme) -> String
    func releaseName(name: String)
}

// Name generation is a module concern, not kernel concern
```

**WorkflowModule** - Multi-step orchestration
```swift
protocol WorkflowModule: Module {
    var availableWorkflows: [WorkflowDefinition] { get }
    func startWorkflow(id: String, input: WorkflowInput) -> WorkflowHandle
    func stepWorkflow(handle: WorkflowHandle, event: WorkflowEvent) -> WorkflowAction
}

// Workflows are completely external to the kernel
```


### Extension Modules

**Expert Modules** - Gang of Experts
```swift
// ReviewerModule, TesterModule, ArchitectModule
// Each provides: system prompt fragment, specialized tools, verification criteria
protocol ExpertModule: Module {
    var expertType: String { get }
    var systemPromptFragment: String { get }
    var requiredTools: [ToolModule] { get }
    var verificationCriteria: [VerificationCriterion] { get }
}
```

**Tool Modules** - External integrations
```swift
// GitToolModule, ShellToolModule, LinterToolModule
protocol ToolModule: Module {
    var toolId: String { get }
    var claudeToolDefinition: ClaudeTool { get }
    func execute(arguments: ToolArguments) async throws -> ToolResult
}
```

**UIBridgeModule** - SwiftUI integration
```swift
protocol UIBridgeModule: Module {
    func agentListState() -> AgentListState
    func chatState(for agentId: UUID) -> ChatState
    func handle(uiEvent: UIEvent)
}

// The UI itself becomes a module that subscribes to kernel events
// This enables testing without UI, or alternative UIs
```


## How This Differs from Plugin Architecture (#11)


### Philosophical Difference

**Plugin Architecture:** The framework is a capable thing that plugins extend.
- The framework knows what agents are
- The framework knows how verification works
- The framework knows Jake exists
- Plugins add variations (new expert types, new themes, new workflows)

**Microkernel Architecture:** The kernel is a minimal thing that modules complete.
- The kernel doesn't know what agents are - a module defines them
- The kernel doesn't know about verification - a module implements it
- The kernel doesn't know Jake exists - a module creates him
- Modules provide ALL functionality, not just variations


### Structural Difference

**Plugin Architecture:**
```
Framework Core (capable)
    └── Extension Points
            ├── AgentType plugins (extend agents)
            ├── Tool plugins (extend tools)
            ├── Workflow plugins (extend workflows)
            └── Theme plugins (extend naming)
```

**Microkernel Architecture:**
```
Kernel (minimal: spawn, route, monitor)
    └── Modules (all capability)
            ├── AgentModule (defines what agents ARE)
            ├── SessionModule (defines how LLM works)
            ├── JakeModule (defines Jake entirely)
            ├── VerificationModule (defines what done means)
            └── ... all other functionality
```


### Interface Difference

**Plugin Architecture:** Plugins implement well-defined extension points on a rich framework.
```swift
// Framework provides rich context
protocol AgentTypePlugin {
    var id: String { get }
    var displayName: String { get }
    var systemPrompt: String { get }  // Framework composes this
    var defaultTools: [String] { get }  // Framework resolves these
    var verificationRequirements: [String] { get }  // Framework checks these
}
```

**Microkernel Architecture:** Modules communicate only through kernel-provided IPC.
```swift
// Modules receive/send messages, not method calls
struct AgentModule: Module {
    func handle(message: Message) -> Message? {
        switch message.type {
        case .createAgent:
            // Module does EVERYTHING - no framework help
            let session = kernel.send(to: sessionModuleId, message: .createSession(...))
            let name = kernel.send(to: namingModuleId, message: .generateName(...))
            // ...
        }
    }
}
```


### Flexibility Difference

**Plugin Architecture:** You can add new agent types, but you can't change what "agent" means.

**Microkernel Architecture:** You can load a completely different AgentModule that implements an entirely different agent model.

Example: Want agents that don't use Claude at all (rule-based bots)?
- Plugin: Probably not possible without framework changes
- Microkernel: Load a different AgentModule that doesn't use SessionModule


### Overhead Difference

**Plugin Architecture:** Low overhead. Plugins are compiled Swift code with direct method calls.

**Microkernel Architecture:** Higher overhead. All cross-module communication is message passing.


### When Each is Better

**Plugin Architecture is better when:**
- The core abstractions (agent, verification, workflow) are stable
- Extensibility is about adding instances of known concepts
- Performance of plugin operations matters
- Swift's type system should enforce contracts

**Microkernel Architecture is better when:**
- The core abstractions themselves may need to change
- Modules might come from untrusted sources (sandboxing needed)
- Runtime loading/unloading is required
- Distribution across processes/machines is planned


## Mapping to PRD Requirements


### PRD Invariant 3: Commitments Verified Independently

**Microkernel mapping:** VerificationModule is completely independent of AgentModule. The kernel routes "agent says done" messages to VerificationModule, which runs checks and routes results back. Neither module knows the other's implementation.

```
AgentModule --(done)-> Kernel --(verify request)-> VerificationModule
                         Kernel <--(verification result)--
```


### PRD Invariant 5: DocStore is Source of Truth

**Microkernel mapping:** PersistenceModule is the sole interface to the filesystem. All other modules go through the kernel to reach it. No module directly touches files.


### PRD Section 4.1: Agent Types (Jake, Mortal, Drone, Monitor)

**Microkernel mapping:** JakeModule defines Jake's behavior. AgentModule's factory can create different agent variants based on module configuration. DronesModule could be a separate module with different lifecycle semantics.


### PRD Section 4.6: Sandbox Primitives

**Microkernel mapping:** The kernel's process isolation naturally supports sandboxing. If modules run in separate processes (true microkernel), they can have different sandbox policies. A ChangesetModule could implement overlay filesystem via IPC.


### PRD Section 10: Workflows

**Microkernel mapping:** WorkflowModule is entirely external to the kernel. Workflows are just message sequences that the WorkflowModule orchestrates, spawning agents via kernel API, receiving completion notifications, and triggering verification.


### PRD Section 11: Gang of Experts

**Microkernel mapping:** Each expert is an ExpertModule that contributes to prompt composition. When spawning "a reviewer", JakeModule sends a spawn request with expert=reviewer, AgentModule queries ReviewerModule for its prompt fragment and tools.


### PRD Section 12: Fish or Cut Bait

**Microkernel mapping:** FaultDetector is part of the kernel. It monitors for: token budget exceeded (via SessionModule reports), timeouts (kernel timers), and stuck agents (no progress messages). When triggered, it sends terminate + notify messages.


## Trade-offs Considered


### IPC Overhead vs. Isolation

**The trade-off:** Every cross-module call is a message send. In a true microkernel, this could mean process boundaries, serialization, context switches. Even in a single-process "microkernel-style" design, it means dynamic dispatch and protocol witnesses.

**Quantifying the cost:**
- Direct method call: ~1-10 nanoseconds
- Swift protocol witness: ~10-50 nanoseconds
- async message via channel: ~100-1000 nanoseconds
- Cross-process IPC: ~10-100 microseconds

For agent spawning (rare): overhead is negligible.
For message routing during conversation: could add noticeable latency.
For tool invocation in hot loops: potentially problematic.

**Mitigation strategies:**
1. Single-process modules with async channels (avoid real IPC until needed)
2. Batch messages where possible
3. Allow "trusted" modules to bypass kernel for performance-critical paths
4. Profile and optimize hotspots


### Module Boundaries vs. Development Velocity

**The trade-off:** Strict module boundaries mean every feature touches multiple modules. Adding "agent can pause" requires: AgentModule (state machine), JakeModule (coordination), UIBridgeModule (display), possibly VerificationModule (pause during verify).

**Impact on velocity:**
- Early development: Slower. More files, more interfaces, more message types.
- Mid development: Neutral. Once modules are established, changes are localized.
- Late development: Faster. Modules can be worked on independently.

**Recommendation:** This is a poor trade-off for v1. The velocity cost is highest when requirements are still being discovered.


### Flexibility vs. Simplicity

**The trade-off:** Microkernel is maximally flexible - you can swap anything. But flexibility that isn't used is complexity that IS paid.

**Current requirements don't need:**
- Hot-swapping modules at runtime
- Running modules in separate processes
- Loading untrusted user modules
- Multiple agent model implementations

**Future requirements might need:**
- User-defined experts (lighter than full modules)
- Cloud/distributed execution (natural process boundaries)
- Sandboxing for security

**Recommendation:** The flexibility cost isn't justified by current requirements.


### Type Safety vs. Dynamic Dispatch

**The trade-off:** Microkernel messaging is inherently dynamic. Messages are often untyped or weakly typed. Swift's type system provides less help.

```swift
// Type-safe (current)
let response = try await agent.send(message)  // Compiler knows types

// Microkernel style
let response = try await kernel.send(to: agentHandle, message: .text(message))
// Response is Message, not String
// Must pattern match, unwrap, validate
```

**Mitigation strategies:**
1. Strongly-typed message enums per module pair
2. Codable messages with runtime validation
3. Code generation for message types

**Recommendation:** The type safety loss is significant for Swift development.


## Implementation Complexity


### Phase 1: Kernel Infrastructure (High Complexity)

**New types:**
- `TavernKernel` protocol and implementation
- `ProcessId`, `ModuleId`, `ModuleHandle` types
- `Message` type (with discriminated union of all message types)
- `MessageRouter` with async channels
- `FaultDetector` with heartbeat/timeout logic
- `ModuleLoader` for discovery and initialization

**Estimated effort:** 4-6 weeks

This is substantial because we're building infrastructure that Swift doesn't provide natively.


### Phase 2: Core Modules (Moderate Complexity)

**Extract from current code:**
- `AgentModule` from Agent, Jake, MortalAgent
- `SessionModule` from ClaudeCode integration
- `PersistenceModule` from DocStore, SessionStore

**Estimated effort:** 3-4 weeks

The logic exists; the work is restructuring it into modules with message-based interfaces.


### Phase 3: Policy Modules (Moderate Complexity)

**New modules:**
- `JakeModule` - Extract Jake's personality and coordination
- `VerificationModule` - Extract commitment verification
- `NamingModule` - Extract name generation
- `WorkflowModule` - New, but simpler than in plugin architecture

**Estimated effort:** 3-4 weeks


### Phase 4: Extension Modules (Low-Moderate)

**Expert modules, tool modules, UI bridge**

**Estimated effort:** 2-3 weeks


### Total Implementation: 12-17 weeks

This is significantly more than Plugin Architecture (8-12 weeks) because we're building more foundational infrastructure.


## Migration Path from Current State


### Step 1: Introduce Message Types (Non-breaking)

Define message types that mirror current method signatures:
```swift
enum AgentMessage {
    case send(String)
    case resetConversation
}

enum AgentResponse {
    case sendResult(String)
    case resetComplete
}
```

This is preparatory work that doesn't change behavior.


### Step 2: Introduce Kernel Façade

Create a `TavernKernel` that initially just delegates to current components:

```swift
class TavernKernel {
    private let coordinator: TavernCoordinator

    func send(to processId: ProcessId, message: Message) async -> Message {
        // Translate to current API calls
        // This is a façade, not true microkernel
    }
}
```


### Step 3: Extract First Module (Persistence)

PersistenceModule is the cleanest extraction:
- DocStore and SessionStore become a module
- Other code calls through kernel.send() instead of direct calls
- Tests verify behavior is preserved


### Step 4: Extract Session Module

SessionModule wraps ClaudeCode:
- All Claude SDK calls go through SessionModule
- AgentModule (still not extracted) calls via kernel


### Step 5: Extract Agent Module

This is the big one:
- Jake and MortalAgent logic moves to modules
- TavernCoordinator becomes the kernel + AgentModule temporarily


### Step 6: Split Coordinator into Kernel + JakeModule

Finally separate:
- Kernel: spawn, route, monitor
- JakeModule: coordination logic


### Timeline Risk

This migration path is risky because:
1. Each step requires maintaining two systems in parallel
2. The façade approach delays true isolation benefits
3. Step 5-6 are large and disruptive

**Alternative:** Big-bang rewrite of core to microkernel, keeping current code as "legacy" temporarily.


## Open Questions


### 1. True Microkernel or Single-Process?

**Options:**
- True microkernel: Modules in separate processes, IPC via XPC/Mach ports
- Single-process: Modules as Swift objects, "IPC" via async channels

**True microkernel advantages:**
- Real fault isolation (module crash doesn't crash app)
- Real sandboxing via process boundaries
- Natural path to distribution

**True microkernel disadvantages:**
- Significant performance overhead
- Complex debugging
- Swift doesn't have great multi-process tooling

**Recommendation:** Single-process initially. The architecture allows graduating to true IPC later.


### 2. How Much Goes in the Kernel?

**Minimalist view:** Only spawn/terminate/route. Even fault detection is a module.

**Practical view:** Spawn/terminate/route/monitor in kernel. Fault detection uses kernel facilities.

**Recommendation:** Practical view. Fault detection needs tight coupling to lifecycle.


### 3. Module Dependencies

**Question:** Can modules depend on other modules?

**Options:**
- No direct dependencies. All communication via kernel.
- Declared dependencies. Kernel ensures load order.
- Implicit dependencies. Modules discover each other via kernel registry.

**Recommendation:** All communication via kernel (maximizes isolation), but kernel provides module discovery API.


### 4. Shared State

**Question:** Can modules share state?

In true microkernel: No. Each module has private memory space.

In single-process pseudo-microkernel: Technically yes, but architecturally no. Use kernel messaging.

**Recommendation:** No shared state. PersistenceModule is the single source of truth.


### 5. Module Versioning and Compatibility

**Question:** How do modules declare compatibility?

**Options:**
- Semantic versioning on message schemas
- Kernel protocol versions
- Runtime capability negotiation

**Recommendation:** Start with kernel protocol versions. Defer semantic versioning.


### 6. UI Integration

**Question:** Is UI a module or special?

**Options:**
- UI is a module like any other (UIBridgeModule)
- UI has privileged access to kernel
- UI is outside the microkernel entirely (kernel exposes API, UI consumes)

**Recommendation:** UI as a module, but with guaranteed synchronous access for responsiveness.


## Conclusion

The Microkernel Architecture is intellectually elegant and provides maximum theoretical flexibility. It cleanly separates mechanism (kernel) from policy (modules) and enables extreme customization without touching core code.

However, for Tavern v1, it's over-engineered:

1. **The flexibility isn't needed.** We're not hot-swapping modules, sandboxing untrusted code, or distributing across machines.

2. **The cost is high.** 12-17 weeks implementation, ongoing IPC overhead, Swift type system fights.

3. **Plugin Architecture provides 80% of the benefit at 50% of the cost.** If extensibility is the goal, plugins are the pragmatic choice.

4. **The current architecture is fine.** The existing Coordinator + Spawner + Registry + Agents design is reasonable for v1 scope.


### When Microkernel Would Make Sense

- **Security-critical deployment:** Untrusted user modules must be sandboxed
- **Distributed execution:** Modules will run on different machines
- **Radical experimentation:** We want to try fundamentally different agent models
- **Long-term platform:** Tavern becomes a platform that others build on


### Recommendation

Do not pursue Microkernel Architecture for v1 or v2.

If Plugin Architecture (#11) is chosen, the migration path to Microkernel exists: plugins can become modules, the plugin registry can become the kernel. But there's no need to pay the microkernel tax upfront.

Consider Microkernel only if:
1. User-defined modules with untrusted code become a requirement
2. Distribution across machines becomes a requirement
3. Swapping the entire agent model (not just extending it) becomes a requirement

None of these are in the current PRD.
