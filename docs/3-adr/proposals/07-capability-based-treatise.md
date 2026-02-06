# Capability-Based Architecture: Complete Analysis

This document contains my complete research, analysis, and thinking on applying a capability-based architecture to the Tavern multi-agent orchestrator.


## Research Findings


### Current Codebase State

The existing implementation has several relevant patterns:

**Agent Lifecycle (`AgentSpawner.swift`, `MortalAgent.swift`):**
- Agents are created via `AgentSpawner` with a `claudeFactory` injection
- Each agent receives a `ClaudeCode` instance at spawn time
- No capability restrictions - agents have full access to whatever the `ClaudeCode` instance can do
- The `assignment` is purely informational; it doesn't constrain behavior

**Commitment Verification (`CommitmentVerifier.swift`):**
- Uses `ShellAssertionRunner` which runs arbitrary bash commands
- No sandboxing - commands execute with full user permissions
- Supports mock injection (`MockAssertionRunner`) for testing
- This is a perfect example of where capabilities would help: shell access should be a granted capability

**Thread Safety Pattern:**
- All mutable state protected by serial `DispatchQueue`
- Pattern: `@unchecked Sendable` + private queue + sync accessors
- This pattern would extend to capability checks

**Error Handling (`TavernError.swift`):**
- Currently minimal - only `sessionCorrupt`
- Would need significant expansion for capability violations


### PRD Requirements Analysis

The PRD establishes several requirements that capability-based architecture addresses:

**Invariant 6: "Agents cannot modify their own invariants"**

This is the core requirement. In capability terms:
- Invariants = policy rules that govern capability grants
- "Cannot modify" = agents cannot grant themselves new capabilities
- Policy rules live outside agent control, in the `PolicyEngine`

**Section 4.6: Sandbox Primitives**

The PRD defines five orthogonal primitives:
1. **Changeset** - Overlay filesystem on project root
2. **Platform** - Where agent runs (Mac, container, cloud)
3. **Isolation** - VMs, containers, OS sandboxes
4. **Outputs** - Network access control
5. **Software** - OS choice

Each of these maps to a capability type:
```swift
enum CapabilityType {
    case filesystem(ChangesetCapability)  // Read, write, which paths
    case platform(PlatformCapability)     // Local, container, cloud
    case isolation(IsolationCapability)   // Sandbox level
    case network(NetworkCapability)       // Allowed hosts/ports
    case software(SoftwareCapability)     // Available tools/commands
}
```

**Section 16: Violation Monitoring**

The PRD lists configurable violations:
- Modifying files outside designated directories
- Exceeding token budgets
- Spawning more than N children
- Accessing network when disallowed
- Running commands on blocklist

In capability terms, these become **capability constraints**:
- File capability with path restrictions
- Token budget as a consumable capability
- Spawn capability with child limit
- Network capability (granted or not)
- Shell capability with command allowlist

**Key insight:** The PRD's "violation monitoring" (detect-and-respond) transforms into "capability enforcement" (prevent-by-construction). Violations become structurally impossible rather than post-hoc detected.


### How Capabilities Map to Sandbox Requirements

**Changeset Capability:**
```swift
struct ChangesetCapability: Capability {
    let id: UUID
    let projectRoot: URL
    let overlayRoot: URL
    let allowedOperations: Set<FileOperation>  // read, write, delete
    let pathGlobs: [String]  // Allowed path patterns

    func validate(_ operation: FileOperation, at path: URL) -> Bool {
        // Check operation is allowed
        // Check path matches allowed globs
        // Check path is within project/overlay
    }
}
```

**Network Capability:**
```swift
struct NetworkCapability: Capability {
    let id: UUID
    let allowedHosts: Set<String>
    let allowedPorts: Set<Int>
    let protocols: Set<NetworkProtocol>  // http, https, ssh, etc.

    func validate(_ request: NetworkRequest) -> Bool {
        // Check host, port, protocol against allowlist
    }
}
```

**Shell Capability:**
```swift
struct ShellCapability: Capability {
    let id: UUID
    let allowedCommands: Set<String>
    let blockedCommands: Set<String>
    let workingDirectory: URL?
    let environment: [String: String]?

    func validate(_ command: String) -> Bool {
        // Parse command, check against allow/block lists
        // Could also validate arguments
    }
}
```

**Token Budget Capability:**
```swift
struct TokenBudgetCapability: Capability {
    let id: UUID
    let totalBudget: Int
    private(set) var consumed: Int

    var remaining: Int { totalBudget - consumed }

    mutating func consume(_ tokens: Int) -> Bool {
        guard consumed + tokens <= totalBudget else { return false }
        consumed += tokens
        return true
    }
}
```


## Trade-offs Considered


### Structural Safety vs. Implementation Complexity

**Pro - Structural Safety:**
The fundamental advantage of capability-based security is that unauthorized operations become *impossible*, not merely *detectable*. If an agent doesn't have a `NetworkCapability`, it literally cannot make a network request. The code path doesn't exist without the capability token.

Compare to the current approach where `ShellAssertionRunner` can execute any bash command. A misbehaving agent could run `curl` to exfiltrate data. With capabilities, the agent would need both `ShellCapability` (with `curl` allowed) AND `NetworkCapability` to do this.

**Con - Implementation Complexity:**
Every resource access now requires:
1. Capability request from agent
2. Policy evaluation
3. Capability grant/denial
4. Capability token passed through the call chain
5. Resource validates capability before action

This touches every file. Current code:
```swift
// Current: Simple, direct
let result = try await runner.run(command)
```

Becomes:
```swift
// Capability-based: More plumbing
guard let shellCap = try await capabilityRegistry.request(
    .shell(commands: ["bash"]),
    for: agent.id
) else {
    throw CapabilityError.denied(.shell)
}
let result = try await runner.run(command, capability: shellCap)
```


### Granularity Trade-off

**Fine-grained capabilities:**
- Pro: Precise control, minimal privilege
- Con: Explosion of capability types, complex policy rules

Example: Do we have one `FileCapability` or separate `ReadCapability`, `WriteCapability`, `DeleteCapability`? Do we distinguish between reading source code vs. reading config files?

**Coarse-grained capabilities:**
- Pro: Simpler to understand and manage
- Con: Over-permissive, defeats the purpose

Recommendation: Start coarse (5 capability types matching PRD sandbox primitives), refine as needed.


### Performance Considerations

Every capability check adds overhead:
1. Lock acquisition on capability registry
2. Policy rule evaluation
3. Capability validation
4. Audit logging

For high-frequency operations (file reads during code analysis), this could be significant.

Mitigation strategies:
- Cache validated capabilities per-operation-type
- Batch capability requests ("give me read access to these 50 files")
- Lazy validation (validate on first use, not on grant)
- Skip checks in release builds for known-safe paths (risky)


### Testability

Capabilities actually *improve* testability:

```swift
// Current mock approach
let mockClaude = MockClaudeCode()
mockClaude.queueJSONResponse(result: "Hello", sessionId: "test")
let agent = MortalAgent(..., claude: mockClaude)

// Capability approach adds controllable boundaries
let mockCapabilities = MockCapabilityRegistry()
mockCapabilities.allow(.shell(commands: ["swift test"]))
mockCapabilities.deny(.network)
let agent = MortalAgent(..., capabilities: mockCapabilities)

// Test: Agent correctly handles capability denial
mockCapabilities.deny(.shell)
await XCTAssertThrowsError(try await agent.runTests())
```

The mock capability registry lets tests precisely control what agents can do without touching real resources.


## Implementation Complexity


### Core Components Needed

1. **`Capability` Protocol** (~50 LOC)
   ```swift
   protocol Capability: Sendable, Identifiable {
       var id: UUID { get }
       var grantedTo: UUID { get }  // Agent ID
       var grantedAt: Date { get }
       var expiresAt: Date? { get }
       var revoked: Bool { get }

       func validate(_ action: some Action) -> Bool
   }
   ```

2. **`CapabilityRegistry`** (~200 LOC)
   - Stores granted capabilities
   - Thread-safe (same pattern as `AgentRegistry`)
   - Request/grant/deny/revoke operations
   - Audit logging

3. **`PolicyEngine`** (~300 LOC)
   - Evaluates policy rules
   - Determines if capability should be granted
   - Configurable per-project, per-agent
   - Default-deny semantics

4. **`PolicyRule`** (~100 LOC)
   ```swift
   struct PolicyRule: Codable {
       let condition: Condition  // Agent type, name pattern, etc.
       let action: Action        // Grant, deny, grant-with-limits
       let capabilities: [CapabilityType]
   }
   ```

5. **Capability-wrapped resources** (~50 LOC each):
   - `CapabilityShellRunner` wrapping `ShellAssertionRunner`
   - `CapabilityFileSystem` wrapping file operations
   - `CapabilityClaudeCode` wrapping SDK calls
   - `CapabilityNetwork` for network operations

6. **Error types** (~50 LOC)
   ```swift
   enum CapabilityError: Error {
       case denied(CapabilityType, reason: String)
       case expired(Capability)
       case revoked(Capability)
       case insufficientBudget(remaining: Int, requested: Int)
   }
   ```

**Total estimate:** ~800-1000 LOC of new infrastructure, plus modifications to existing code.


### Modifications to Existing Code

**`AgentSpawner.swift`:**
- Add capability grant at spawn time
- Configure initial capabilities from spawn config

**`MortalAgent.swift`:**
- Add capability registry reference
- Request capabilities before operations
- Handle capability denials gracefully

**`CommitmentVerifier.swift`:**
- Require `ShellCapability` for assertions
- Validate commands against capability constraints

**`Jake.swift`:**
- Jake gets elevated capabilities (spawn, delegate, etc.)
- Jake grants capabilities to children

**`TavernCoordinator.swift`:**
- Initialize capability registry
- Configure policy rules from project settings


### Testing Requirements

Based on current test counts (173 tests), adding capabilities would require:

- ~20 tests for `Capability` and `CapabilityRegistry`
- ~15 tests for `PolicyEngine`
- ~10 tests for each capability-wrapped resource (5 resources = 50 tests)
- ~20 tests for integration with existing agent tests

**Estimate:** ~100+ new tests, bringing total to ~275+.


## Migration Path from Current State


### Phase 1: Infrastructure (No Behavior Change)

1. Add `Capability` protocol and base types
2. Add `CapabilityRegistry` (empty, unused)
3. Add `PolicyEngine` with default "allow all" policy
4. Write tests for new infrastructure
5. No changes to agent behavior

**Verification:** All 173 existing tests still pass.


### Phase 2: Wrap ShellAssertionRunner

The `CommitmentVerifier` is the perfect first target - it's isolated, well-tested, and clearly should be sandboxed.

1. Create `ShellCapability` type
2. Create `CapabilityShellRunner` wrapping `ShellAssertionRunner`
3. Modify `CommitmentVerifier` to require `ShellCapability`
4. Update `MortalAgent` to request `ShellCapability` for commitments
5. Configure policy: agents get shell capability with `swift test` allowed

**Verification:** Commitment tests still pass, with capability logging showing grants.


### Phase 3: Wrap ClaudeCode

1. Create `TokenBudgetCapability`
2. Create `CapabilityClaudeCode` wrapping `ClaudeCode`
3. Track token consumption per agent
4. Enforce budget limits
5. Log capability usage

**Verification:** Agent tests still pass, token tracking visible in logs.


### Phase 4: FileSystem Capabilities

This aligns with PRD's "Changeset" sandbox primitive.

1. Create `FileCapability` type
2. Create `CapabilityFileSystem` wrapping file operations
3. Modify `DocStore` to require file capabilities
4. Configure path restrictions per agent

**Verification:** DocStore tests still pass with capability-restricted access.


### Phase 5: Network Capabilities

1. Create `NetworkCapability` type
2. Wrap any network operations (minimal in current code)
3. Default policy: no network access unless explicitly granted

**Verification:** No network access possible without explicit capability.


### Phase 6: Full Integration

1. Add spawn configuration for capabilities
2. Jake grants capabilities to children at spawn
3. Implement capability delegation (child gets subset of parent's)
4. Add UI for capability configuration
5. Add audit log viewer

**Verification:** End-to-end tests showing capability flow from spawn to completion.


## Open Questions


### Q1: Where Do Policy Rules Live?

Options:
1. **In the project's doc store** - Co-located with project, version controlled
2. **In app preferences** - Global defaults, per-project overrides
3. **In agent node files** - Each agent's rules with its persisted state
4. **Hybrid** - Default rules in app, project overrides in doc store

Recommendation: Hybrid. Default-deny rules in app, project can grant additional capabilities.


### Q2: How Does Jake Get Elevated Capabilities?

Jake is "eternal" and coordinates all agents. He needs capabilities that children don't have:
- Spawn agents
- Grant capabilities to children
- Read all agent states
- Access full project filesystem

Options:
1. Jake has "superuser" capability that bypasses all checks
2. Jake has explicit list of elevated capabilities
3. Jake's capabilities are the union of all possible child capabilities

Recommendation: Explicit elevated capabilities. "Superuser" defeats the purpose; union is complex.


### Q3: Can Capabilities Be Delegated?

The PRD says agents can spawn children. Can a parent grant its child a subset of its own capabilities?

Example: Agent A has `FileCapability` for `/src/*`. Can A spawn Agent B with `FileCapability` for `/src/tests/*`?

Options:
1. No delegation - all capabilities come from policy engine
2. Full delegation - parent can grant any subset of its capabilities
3. Restricted delegation - policy rules specify what can be delegated

Recommendation: Restricted delegation. Policy specifies which capabilities are "delegatable" by which agent types.


### Q4: What Happens When Capability Is Revoked Mid-Operation?

If an operation is in-progress (e.g., long-running shell command) and the capability is revoked:

Options:
1. Operation continues (revocation affects future operations)
2. Operation is cancelled immediately
3. Operation is cancelled at next checkpoint

Recommendation: Option 1 for simplicity. Revocation prevents *new* operations; existing ones complete.


### Q5: How Granular Should Token Budgets Be?

Options:
1. Per-agent total budget
2. Per-agent budget per operation type (prompt, response, tool use)
3. Per-session budget (resets on conversation reset)

Recommendation: Per-agent total budget for v1. Finer granularity adds complexity without clear benefit.


### Q6: Should Capability Violations Be Logged Only, or Also Surfaced to User?

Options:
1. Log only (developer visibility)
2. Log + notify parent agent
3. Log + notify parent + notify user
4. Configurable per-capability-type

Recommendation: Option 4. Network violations might warrant user notification; file path violations might be log-only.


### Q7: How Do Capabilities Interact with Session Persistence?

Current `SessionStore` saves session IDs. With capabilities:
- Do we persist granted capabilities?
- On session restore, do we re-validate against current policy?
- What if policy changed and agent no longer qualifies?

Recommendation: Re-validate on restore. Capabilities are not persisted; they're computed from policy at runtime.


## Comparison to Alternatives


### Alternative: Role-Based Access Control (RBAC)

RBAC assigns roles to agents; roles have permissions.

```
Agent -> Role -> Permissions
```

**vs. Capabilities:**
- RBAC: "Agent X has role Y which grants permission Z"
- Capabilities: "Agent X possesses capability token for Z"

Key difference: In RBAC, permissions are checked by identity. In capabilities, the token itself authorizes. Capabilities are unforgeable; RBAC roles can potentially be spoofed if identity is compromised.

For Tavern: Capabilities are better because agents are untrusted (they're LLMs that might try to do unexpected things).


### Alternative: Mandatory Access Control (MAC)

MAC assigns security labels to subjects (agents) and objects (resources). Operations allowed based on label comparison.

**vs. Capabilities:**
- MAC: "Agent has clearance L; file has classification L; access allowed"
- Capabilities: "Agent has token for this specific file"

Key difference: MAC is hierarchical (clearance levels). Capabilities are granular (specific operations on specific resources).

For Tavern: The PRD's sandbox primitives aren't hierarchical. Different agents need different combinations of capabilities, not different "clearance levels."


### Alternative: Sandboxing via OS Primitives

macOS provides sandboxing:
- App Sandbox (entitlements)
- Hardened Runtime
- Quarantine attributes

**vs. Application-Level Capabilities:**
- OS sandbox: Coarse-grained, applies to entire process
- Capabilities: Fine-grained, per-agent, per-operation

For Tavern: OS sandboxing applies to the entire app. We need *intra-app* sandboxing between agents. Capabilities provide this.


### Alternative: Violation Monitoring (Current PRD Approach)

Detect violations after the fact, then respond (log, pause, reap).

**vs. Capabilities:**
- Monitoring: "Detect bad behavior, respond"
- Capabilities: "Make bad behavior impossible"

For Tavern: Monitoring is reactive; capabilities are proactive. Capabilities are strictly stronger security, but at the cost of implementation complexity.


## Conclusion

A capability-based architecture is a strong fit for Tavern's stated requirements:

1. **Directly addresses PRD invariant 6** - Agents cannot modify their own invariants because they cannot grant themselves capabilities.

2. **Transforms violation monitoring into violation prevention** - Security becomes structural rather than observational.

3. **Maps cleanly to sandbox primitives** - Each PRD sandbox primitive becomes a capability type.

4. **Improves testability** - Mock capabilities provide precise control over what agents can do in tests.

5. **Prepares for future complexity** - As agents become more capable (containers, cloud, real network access), capability infrastructure scales.

**However**, the implementation complexity is significant. For v1 (which defers sandboxing), this may be over-engineering. The recommendation is:

- **v1**: Implement capability infrastructure but use "allow all" policy
- **v1.1**: Add shell capability for commitment verification
- **v2**: Full capability enforcement as sandboxing is implemented

This gives the architectural benefits without blocking v1 delivery.
