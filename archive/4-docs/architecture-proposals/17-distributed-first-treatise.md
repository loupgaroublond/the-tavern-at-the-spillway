# Distributed-First Architecture: Complete Analysis

This document contains detailed research, trade-off analysis, and implementation considerations for adopting a Distributed-First architecture in Tavern.


## Research Findings


### Current Codebase Analysis

The existing architecture is fundamentally **single-process, in-memory**:

**Agent Execution Model:**
- `Jake` and `MortalAgent` are Swift classes running in the app process
- Communication is direct method calls: `agent.send(message)` returns a `String`
- State is held in instance variables protected by `DispatchQueue`
- The `ClaudeCode` SDK spawns Node.js subprocesses for API calls, but results are returned synchronously to the Swift process

**Coordination Model:**
- `TavernCoordinator` is `@MainActor`-bound and manages all agent state
- `AgentSpawner` creates agents in-process via constructor calls
- `AgentRegistry` is an in-memory dictionary with thread-safe access
- No network boundaries exist anywhere in the current design

**Persistence Model:**
- `SessionStore` uses `UserDefaults` for session IDs (machine-local)
- `DocStore` writes to the local filesystem
- `ClaudeNativeSessionStorage` reads from `~/.claude/` (machine-local)

**Multi-Project Support:**
- `ProjectManager` tracks open projects
- `TavernProject` creates per-project coordinators and Claude instances
- Project isolation is in-memory (separate `TavernCoordinator` instances)


### PRD Requirements Related to Distribution

The PRD (Section 4.6 - Sandbox Primitives) explicitly identifies five orthogonal primitives:

1. **Changeset** - Overlay filesystem (deferred)
2. **Platform** - "Where agent runs (Mac, container, cloud, hybrid)"
3. **Isolation** - "VMs, containers, OS sandboxes"
4. **Outputs** - Network access control
5. **Software** - OS choice (macOS, Linux, FreeBSD)

The Platform and Software primitives directly imply multi-machine execution:

> "Agent can trash everything, reap and restart" (Section 4.6)

This suggests agents should be disposable units that can be killed and restarted without affecting the coordinator. That's much easier with process/container isolation than in-process threading.


### V1 Scope vs Future Scope

**V1 Deferred (PRD Section 18):**
- Sandboxing with overlays
- Containerization / cloud agents
- Changesets

**Future Indicators (PRD Section 20):**
- "High amplification factor (many saturated agents, one human)"
- Multiple concurrent agents is a core goal

The tension: V1 is explicitly local-only, but the architecture should "leave space" for future capabilities. The question is whether that space is a clean interface boundary or full network abstraction.


## Mapping to Platform/Cloud Requirements

A Distributed-First architecture maps directly to the PRD's sandbox primitives:


### Platform Primitive Implementation

```
Platform Selection:
├── mac-local     → Swift process in app sandbox
├── mac-daemon    → LaunchAgent with IPC
├── container     → Docker/Podman with gRPC
├── cloud-vm      → EC2/GCE instance with secure tunnel
└── cloud-lambda  → Serverless function with async messaging
```

Each platform becomes a deployment target with a common agent interface. The coordinator doesn't know or care where agents run.


### Isolation Primitive Implementation

```
Isolation Levels:
├── none          → In-process (current state, testing only)
├── process       → Separate process, same machine
├── container     → Docker/cgroup isolation
├── vm            → Full VM isolation (Firecracker, QEMU)
└── cloud         → Separate cloud account/VPC
```

Distributed-First treats network as the universal isolation boundary. Even "process" isolation uses localhost networking rather than shared memory.


### Software Primitive Implementation

```
OS Requirements:
├── macOS-only tools  → Route to Mac agents
├── Linux tools       → Route to container/cloud agents
├── Windows tools     → Route to Windows VM agents (hypothetical)
└── Any               → Scheduler chooses optimal platform
```

The coordinator maintains a capability registry and routes agent spawns to platforms that support required tools.


## Trade-offs Considered


### Complexity vs Future-Proofing

**In favor of distribution complexity now:**
- Retrofitting network boundaries is harder than designing them in
- PRD clearly envisions multi-platform agents
- Clean separation forces better abstractions

**Against distribution complexity now:**
- V1 explicitly defers cloud agents
- Shipping faster matters for proving the concept
- Complexity can be added incrementally at interface boundaries


### Latency Characteristics

**Local in-process (current):**
- Agent method call: ~0 ms overhead
- ClaudeCode SDK subprocess: ~50-100ms spawn + API latency

**Local network (Distributed-First, same machine):**
- Agent spawn: ~10-50ms (process start + connection)
- Agent method call: ~1-5ms (IPC/localhost)
- Total: +10-55ms overhead per agent lifecycle

**Remote network (container/cloud):**
- Agent spawn: ~500ms-5s (container start) or ~30s-2m (VM start)
- Agent method call: ~10-100ms (network latency)
- Total: Significant overhead, mitigated by long-running agents


### Operational Overhead

**Current model (in-process):**
- Zero infrastructure beyond the Mac app
- Debugging: Xcode, Console.app, local logs
- Deployment: Single `.app` bundle

**Distributed-First:**
- Message queue (Redis, RabbitMQ, or custom gRPC)
- Service discovery (DNS, Consul, or embedded)
- Shared state store (Redis, SQLite via network, or custom)
- Container runtime (Docker, Podman) for container agents
- Cloud credentials and networking for cloud agents
- Distributed tracing (OpenTelemetry) for debugging


## Implementation Complexity


### Phase 1: Protocol Abstraction

Before any network code, extract an `AgentProtocol` that is network-agnostic:

```swift
/// Network-transparent agent interface
public protocol DistributedAgent: Identifiable, Sendable {
    var id: AgentID { get }
    var location: AgentLocation { get }
    var state: AgentState { get async }

    func send(_ message: AgentMessage) async throws -> AgentResponse
    func terminate() async
}

public enum AgentLocation {
    case local(pid: Int32)
    case container(id: String, host: String)
    case cloud(region: String, instanceId: String)
}
```


### Phase 2: Local Process Agents

Move agents out-of-process on the same machine:

```swift
/// Spawns agents as separate processes with IPC
class LocalAgentSpawner {
    func spawn(assignment: String) async throws -> RemoteAgentHandle {
        let process = Process()
        process.executableURL = agentBinaryURL
        process.arguments = ["--assignment", assignment]

        // Set up bidirectional communication
        let (input, output) = try await setupIPC(process)

        process.launch()

        return RemoteAgentHandle(
            process: process,
            input: input,
            output: output
        )
    }
}
```


### Phase 3: Container Agents

Add Docker/Podman support:

```swift
/// Spawns agents in containers
class ContainerAgentSpawner {
    func spawn(assignment: String, image: String) async throws -> ContainerAgentHandle {
        let containerId = try await docker.create(
            image: image,
            command: ["agent", "--assignment", assignment],
            environment: [
                "COORDINATOR_URL": coordinatorURL.absoluteString,
                "AGENT_ID": UUID().uuidString
            ]
        )

        try await docker.start(containerId)

        // Agent connects back to coordinator via COORDINATOR_URL
        return ContainerAgentHandle(containerId: containerId)
    }
}
```


### Phase 4: Cloud Agents

Add cloud VM or serverless support:

```swift
/// Spawns agents on cloud infrastructure
class CloudAgentSpawner {
    func spawn(assignment: String, region: Region) async throws -> CloudAgentHandle {
        // Option A: Launch EC2/GCE instance
        let instanceId = try await cloud.launchInstance(
            image: agentAMI,
            instanceType: .t3Micro,
            userData: cloudInitScript(assignment: assignment)
        )

        // Option B: Invoke Lambda/Cloud Function
        let invocationId = try await lambda.invokeAsync(
            function: "tavern-agent",
            payload: AgentInvocation(assignment: assignment)
        )

        return CloudAgentHandle(instanceId: instanceId)
    }
}
```


### Network Protocol Options

**Option A: gRPC**
- Pros: Efficient binary protocol, streaming, codegen
- Cons: Learning curve, debugging requires tooling
- Best for: High-frequency agent communication

**Option B: JSON over WebSocket**
- Pros: Simple, debuggable, browser-compatible
- Cons: Less efficient, manual schema management
- Best for: Lower frequency, easier debugging

**Option C: Message Queue (Redis Streams, RabbitMQ)**
- Pros: Decoupled, persistent, fan-out
- Cons: Additional infrastructure, eventual consistency
- Best for: Reliable delivery, agent recovery


## Migration Path from Current State


### Step 0: Interface Extraction (No Breaking Changes)

Extract `AgentHandle` protocol from existing code without changing behavior:

```swift
// Current: Direct class usage
let agent = MortalAgent(name: "Frodo", assignment: "...", claude: claude)
let response = try await agent.send(message)

// After: Protocol-based
let handle: AgentHandle = spawner.spawn(assignment: "...")
let response = try await handle.send(message)
```

This is purely a refactor - `LocalInProcessAgentHandle` wraps the existing `MortalAgent`.


### Step 1: Process Isolation (Mac-only)

Replace in-process agents with subprocess agents on the same machine:

1. Create standalone `TavernAgent` binary (new target)
2. Modify `AgentSpawner` to launch subprocess and establish IPC
3. `AgentHandle` now wraps a subprocess connection
4. Jake remains in-process (coordinator doesn't move)

**Test:** All existing tests pass with subprocess agents.


### Step 2: Configuration-Driven Platform Selection

Add platform selection to spawn configuration:

```swift
let agent = try spawner.spawn(
    assignment: "Review code",
    platform: .local  // or .container, .cloud
)
```

Initially, only `.local` is implemented. Container and cloud return errors.


### Step 3: Container Support

1. Build Docker image containing agent binary
2. Implement `ContainerAgentSpawner`
3. Agent connects back to coordinator via configured URL
4. Mac app exposes coordinator endpoint (localhost or tunnel)


### Step 4: Cloud Support

1. Build AMI or Lambda deployment package
2. Implement `CloudAgentSpawner`
3. Add secure tunnel (WireGuard, Tailscale, or AWS VPC peering)
4. Agent connects back through tunnel


### Rollback Safety

Each step is independently reversible:

- Step 1: Remove subprocess spawner, revert to in-process
- Step 2: Fix platform to `.local`
- Step 3: Remove container spawner, fall back to subprocess
- Step 4: Remove cloud spawner, fall back to container or subprocess


## Open Questions


### 1. Where Does Jake Live?

Options:
- **A: Always on Mac** - Jake is the user's local coordinator, never distributed
- **B: Per-project variable** - Some projects might have cloud-hosted Jake
- **C: Replicated** - Jake runs locally with cloud backup for failover

Recommendation: **A (Always on Mac)** for v1/v2. Jake is the human's representative; it makes sense for Jake to live where the human's UI is.


### 2. State Synchronization Model

When agents run on multiple machines, where is the source of truth?

Options:
- **A: Coordinator holds all state** - Agents are stateless; all state queries go to coordinator
- **B: Agents own their state** - Coordinator asks agents for state
- **C: Shared data store** - Both coordinator and agents read/write shared store

Recommendation: **C (Shared data store)** - Most resilient to coordinator restarts and agent crashes. Redis, PostgreSQL, or CockroachDB depending on scale needs.


### 3. Security Model

How do remote agents authenticate to the coordinator?

Options:
- **A: Pre-shared keys** - Tokens generated at spawn, validated on connect
- **B: Mutual TLS** - Certificates issued per agent
- **C: Cloud IAM** - AWS/GCP roles for cloud agents, tokens for others

Recommendation: **A + C** - Simple tokens for local/container agents, IAM roles for cloud agents. mTLS adds significant operational complexity.


### 4. Agent Binary Distribution

How do agent binaries get to remote platforms?

Options:
- **A: Pre-built images** - Container images / AMIs built in CI
- **B: Dynamic download** - Agents download binary from CDN at start
- **C: Embedded in coordinator** - Coordinator pushes binary during spawn

Recommendation: **A (Pre-built images)** - Most reliable, avoids runtime download failures, enables caching.


### 5. Partial Distribution

Can some agents be local while others are remote in the same project?

Answer: **Yes, this is a core benefit.** The platform primitive is per-agent. A project might have:
- Jake: Local (Mac)
- Reviewers: Local (Mac, for speed)
- Build agents: Container (Linux, for CI tools)
- Heavy compute agents: Cloud VM (for parallelization)


### 6. Offline Operation

What happens when cloud/container infrastructure is unavailable?

Options:
- **A: Fail spawn** - Return error if requested platform unavailable
- **B: Fallback to local** - Degrade gracefully to local execution
- **C: Queue for later** - Hold spawn request until platform available

Recommendation: **A + B configurable** - Let user/project config specify fallback behavior. Some assignments might require specific platforms (Linux tools), others are flexible.


## Comparison with Other Proposals


### vs Actor Model (02)

Actor Model focuses on **concurrency within a single process** using Swift's actor isolation. Distributed-First is orthogonal - you could use actors for local coordination while still using network protocols for remote agents.

**Combination possible:** Use Swift actors for coordinator internals, network protocols for agent boundaries.


### vs Event-Sourced (05)

Event sourcing addresses **state persistence and replay**. Distributed-First addresses **execution location**. These are complementary - event logs could be stored in the shared data store, enabling agent recovery after crashes regardless of where the agent ran.

**Combination possible:** Event-sourced state in shared store, consumed by distributed agents.


### vs Supervisor Trees (04)

Supervisor trees define **failure handling hierarchies**. In a Distributed-First model, the supervisor tree spans network boundaries. A container agent crashing triggers supervisor restart logic, possibly on a different container.

**Combination possible:** Supervisor tree topology with network-transparent restart.


### vs Blackboard (06)

Blackboard architecture uses **shared memory for coordination**. In Distributed-First, the "blackboard" becomes the shared data store, accessible over the network. Agents read/write to central state rather than passing messages.

**Combination possible:** Network-accessible blackboard (Redis, shared database) in Distributed-First model.


## Recommendation

**For V1: Do not adopt full Distributed-First architecture.**

The PRD explicitly defers containerization and cloud agents. The complexity cost of network protocols, service discovery, and shared state stores is not justified when the primary use case is a single Mac running a single user's agents.

**However:** Extract clean interface boundaries now so distribution can be added later without rewriting core logic.

**Suggested approach:**

1. Define `AgentHandle` protocol (sync-compatible initially)
2. Keep implementation in-process for V1
3. Document the interface as the future network boundary
4. Add subprocess isolation when reliability becomes important
5. Add container/cloud support when PRD features require it

This gives the benefits of architectural clarity without the operational overhead of premature distribution.
