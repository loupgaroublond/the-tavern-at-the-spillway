# Saga Pattern Architecture: Complete Analysis

This document contains the full research, analysis, and trade-off considerations for adopting a saga pattern architecture in Tavern.


## Research Findings


### Current Operation Patterns

The codebase currently handles agent operations as monolithic async calls:


**Agent Send Operation (MortalAgent.swift)**

```swift
public func send(_ message: String) async throws -> String {
    queue.sync { _state = .working }
    defer { updateStateAfterResponse() }

    // Monolithic operation - no intermediate checkpoints
    let result = try await claude.runSinglePrompt(...)

    // Post-processing
    await checkForCompletionSignal(in: response)
    return response
}
```

If any part fails, the entire operation fails with no partial state recovery. The `defer` ensures state returns to idle, but any side effects (partial writes, external calls) remain.


**Commitment Verification Flow (CommitmentVerifier.swift)**

```swift
public func verifyAll(in list: CommitmentList) async throws -> Bool {
    var allPassed = true

    for commitment in list.pendingCommitments {
        var mutableCommitment = commitment
        let passed = try await verify(&mutableCommitment, in: list)
        if !passed {
            allPassed = false
        }
    }

    return allPassed
}
```

This is a loop over commitments with no rollback on partial failure. If commitment 3 of 5 fails, commitments 1 and 2 remain marked as passed, but the agent doesn't complete. This is acceptable for verification (read-only), but the pattern doesn't extend to write operations.


**Agent Spawning Flow (AgentSpawner.swift)**

```swift
public func spawn(name: String, assignment: String) throws -> MortalAgent {
    // Step 1: Reserve name
    guard nameGenerator.reserveName(name) else {
        throw AgentRegistryError.nameAlreadyExists(name)
    }

    // Step 2: Create Claude instance
    let claude = claudeFactory()

    // Step 3: Create agent
    let agent = MortalAgent(name: name, assignment: assignment, claude: claude)

    // Step 4: Register
    do {
        try registry.register(agent)
    } catch {
        // Manual compensation for step 1
        nameGenerator.releaseName(name)
        throw error
    }

    return agent
}
```

This is a proto-saga. Manual compensation exists for the name reservation, but it's ad-hoc and wouldn't scale to more complex operations.


**Coordinator Operations (TavernCoordinator.swift)**

```swift
public func spawnAgent(assignment: String, selectAfterSpawn: Bool = true) throws -> MortalAgent {
    let agent = try spawner.spawn(assignment: assignment)

    // Side effects after spawn
    agentListViewModel.cacheAssignment(agentId: agent.id, assignment: assignment)
    agentListViewModel.agentsDidChange()

    if selectAfterSpawn {
        selectAgent(id: agent.id)
    }

    return agent
}
```

If `spawn` succeeds but UI update fails, the agent exists but isn't visible. No rollback mechanism.


### Key Observations

1. **Operations are sequences** - Spawning, verification, message handling are multi-step

2. **Compensation is ad-hoc** - Where it exists, it's manual and incomplete

3. **Failures leave partial state** - No mechanism to return to consistent state

4. **No operation history** - Can't resume or retry from intermediate point

5. **Side effects aren't tracked** - External calls, file writes have no undo path


## How Sagas Map to Agent Work and Changesets


### The Core Mapping

The PRD describes agent work in terms that naturally map to sagas:

**PRD Section 4.3 (Task Modes):**
> Agents can bounce between these modes: Execute, Delegate, Plan, Break up, Unify

Each mode is a saga step. An agent planning then delegating is:
1. Step: Enter Plan mode
2. Step: Generate subtasks
3. Step: Spawn child agents (Delegate mode)
4. Step: Wait for children
5. Step: Unify results

If step 3 fails (can't spawn), compensation rolls back: delete subtask documents, return to previous mode.


**PRD Section 4.6 (Sandbox Primitives):**
> **Changeset** — Overlay filesystem on project root. Writes go to overlay. Changeset = diff. Protects original.

Changesets are the compensation mechanism for file operations:
- Forward: Write to overlay
- Compensation: Discard overlay (or specific changes within it)

This is why sagas are particularly powerful for Tavern: the changeset primitive provides compensation "for free" for all file operations.


### Saga Structure for Agent Operations

**Simple Message Saga:**

```swift
struct MessageSaga: Saga {
    let agentId: UUID
    let message: String

    var steps: [SagaStep] {
        [
            SagaStep(
                name: "prepare",
                execute: { ctx in
                    ctx.agent.markWorking()
                    return .continue
                },
                compensate: { ctx in
                    ctx.agent.markIdle()
                }
            ),
            SagaStep(
                name: "send_to_claude",
                execute: { ctx in
                    let response = try await ctx.claude.send(message)
                    ctx.store("response", response)
                    return .continue
                },
                compensate: { ctx in
                    // Claude call can't be undone, but we can:
                    // - Not persist the session ID
                    // - Clear partial response from memory
                    ctx.clear("response")
                }
            ),
            SagaStep(
                name: "persist_session",
                execute: { ctx in
                    let sessionId = ctx.response.sessionId
                    SessionStore.saveAgentSession(agentId: agentId, sessionId: sessionId)
                    return .continue
                },
                compensate: { ctx in
                    SessionStore.clearAgentSession(agentId: agentId)
                }
            ),
            SagaStep(
                name: "check_completion",
                execute: { ctx in
                    await ctx.agent.checkForCompletionSignal(in: ctx.response)
                    return .success(ctx.response)
                },
                compensate: { ctx in
                    ctx.agent.markIdle()
                }
            )
        ]
    }
}
```


**File Modification Saga (with Changesets):**

```swift
struct RefactorFileSaga: Saga {
    let filePath: String
    let transformation: (String) -> String

    var steps: [SagaStep] {
        [
            SagaStep(
                name: "read_original",
                execute: { ctx in
                    let content = try ctx.changeset.read(filePath)
                    ctx.store("original", content)
                    return .continue
                },
                compensate: { _ in
                    // Read has no side effects
                }
            ),
            SagaStep(
                name: "transform",
                execute: { ctx in
                    let transformed = transformation(ctx.get("original"))
                    ctx.store("transformed", transformed)
                    return .continue
                },
                compensate: { _ in
                    // Pure computation, no side effects
                }
            ),
            SagaStep(
                name: "write_to_overlay",
                execute: { ctx in
                    try ctx.changeset.write(filePath, content: ctx.get("transformed"))
                    return .continue
                },
                compensate: { ctx in
                    // Changeset provides compensation
                    ctx.changeset.revert(filePath)
                }
            ),
            SagaStep(
                name: "verify",
                execute: { ctx in
                    let result = try await ctx.runTests()
                    if result.passed {
                        return .success
                    } else {
                        return .failure(TestsFailedError(result))
                    }
                },
                compensate: { _ in
                    // Verification has no side effects
                }
            )
        ]
    }
}
```


### Changeset as Natural Compensation Boundary

The PRD's changeset concept aligns perfectly with saga compensation:

| Changeset Operation | Saga Equivalent |
|---------------------|-----------------|
| Create overlay | Begin saga |
| Write to overlay | Execute step |
| Discard overlay | Compensate all steps |
| Apply overlay to project | Commit saga |
| Partial revert | Compensate specific steps |

This means implementing changesets effectively gives us saga compensation for all file operations without writing individual compensation logic.


## Mapping to PRD Requirements


| PRD Requirement | Saga Pattern Support |
|-----------------|---------------------|
| **Section 2: Invariant 7 - Failures must be visible** | Saga log captures every step and failure with context |
| **Section 2: Invariant 8 - Original files protected** | Saga compensation ensures overlay changes can be reverted |
| **Section 4.2: Agent States** | State transitions are saga steps with compensation |
| **Section 4.6: Changeset primitive** | Changesets provide natural compensation for file operations |
| **Section 4.7: Commitment flow** | Verification is a saga that can be retried or compensated |
| **Section 6.4: Preflight Checks** | Preflight is a saga that compensates by not spawning |
| **Section 6.5: Merge Queue** | Merge is a saga: prepare → merge → verify → commit |
| **Section 12: Fish or Cut Bait** | Compensation provides graceful alternative to kill-and-restart |


### Specific PRD Alignments


**Section 12: Fish or Cut Bait**

> Triggers to kill and restart rather than continue: Token budget exceeded, Changeset is totally wrong, Agent spinning, Whole gang going down wrong path

Sagas enhance this by providing alternatives to "kill":

- **Token budget exceeded** → Compensate current saga, save progress, spawn new agent with saved context
- **Changeset is wrong** → Compensate to checkpoint, try different approach
- **Agent spinning** → Compensate last N steps, inject guidance, resume
- **Gang wrong path** → Compensate all child sagas, restart from common checkpoint

Instead of binary "continue or kill," sagas enable "rollback and redirect."


**Section 4.7: Deterministic Shell**

> Commitment flow: Parent assigns task → Child supplements with commitments → Child works → Independent assertion verifies → Only then is agent "done"

This is a saga:
1. Receive assignment (step)
2. Generate commitments (step, compensation: delete commitments)
3. Execute work (step, compensation: revert changeset)
4. Verify commitments (step)
5. Mark done (final step)

If verification fails, the saga can:
- Compensate step 3 (revert changes)
- Loop back to step 3 with adjusted approach
- Or escalate to parent agent


**Section 6.4: Preflight Checks**

> At spawn, before autonomous work: Sandbox configured correctly, Has access to required resources, No permissions prompts expected

Preflight is a validation saga:
1. Check sandbox (compensation: not needed, read-only)
2. Verify resources (compensation: not needed)
3. Check permissions (compensation: not needed)
4. Spawn agent (compensation: dismiss agent)
5. Initialize agent (compensation: reset agent state)

If any check fails, the saga never reaches step 4, so no agent is spawned.


## Trade-offs Considered


### Compensation Complexity

**The Challenge:**

Not all operations have clean compensation:

- **Claude API calls** - Can't unsend a message, can't unfetch a response
- **External API calls** - May have real-world effects (created resources, sent notifications)
- **Time-sensitive operations** - State may have changed externally between execute and compensate

**Mitigations:**

1. **Semantic compensation** - Even if we can't undo, we can:
   - Not persist the result
   - Mark the operation as rolled back in logs
   - Send a follow-up correcting message

2. **Compensation flags** - Mark steps as:
   - `fullyCompensatable` - Clean undo possible
   - `partiallyCompensatable` - Some aspects can be undone
   - `nonCompensatable` - Execute at your own risk, compensation is best-effort

3. **Idempotent steps** - Design steps to be safely retryable


### Coordination Overhead

**The Cost:**

Every operation now goes through saga infrastructure:
- Create saga definition
- Execute through coordinator
- Log each step
- Handle compensation path

**Analysis:**

For simple operations (send message, read file), this overhead is noticeable. For complex operations (multi-file refactor, spawn tree of agents), the overhead is negligible compared to operation time.

**Mitigation:**

Two-tier system:
1. **Simple operations** - Direct execution (current pattern)
2. **Complex operations** - Saga-based execution

Threshold: If operation involves multiple side effects or needs rollback capability, use saga.


### Testing Multiplication

**The Challenge:**

For a 5-step saga, testing requires:
- Happy path (5 steps succeed)
- Failure at step 1, 2, 3, 4, 5 (5 paths)
- Compensation failure (5 more paths)
- Partial compensation (combinatorial)

**Mitigation:**

1. **Property-based testing** - Generate random failure points
2. **Compensation contracts** - Each step's compensation is tested in isolation
3. **Saga invariant testing** - Verify: for any failure point, final state is either "all done" or "all undone"


### Eventual Consistency During Execution

**The Challenge:**

During saga execution, the system is in an inconsistent state:
- File partially modified
- Agent state transitioning
- Commitments partially verified

**Mitigation:**

1. **Saga isolation** - Each saga operates on its own changeset
2. **Visibility rules** - Partial state not visible to other components until saga completes
3. **Atomic projection** - UI shows either pre-saga or post-saga state, not intermediate


## Implementation Complexity


### Phase 1: Saga Infrastructure (2-3 weeks)

```swift
// Core protocols
protocol Saga {
    associatedtype Result
    var id: UUID { get }
    var steps: [SagaStep<Result>] { get }
}

struct SagaStep<Result> {
    let name: String
    let execute: (SagaContext) async throws -> StepResult<Result>
    let compensate: (SagaContext) async -> Void
}

enum StepResult<Result> {
    case `continue`
    case success(Result)
    case failure(Error)
}

// Coordinator
actor SagaCoordinator {
    private var activeSagas: [UUID: SagaExecution] = [:]
    private let log: SagaLog

    func execute<S: Saga>(_ saga: S) async throws -> S.Result {
        let execution = SagaExecution(saga: saga, log: log)
        activeSagas[saga.id] = execution
        defer { activeSagas.removeValue(forKey: saga.id) }

        return try await execution.run()
    }
}

// Execution engine
actor SagaExecution<S: Saga> {
    private let saga: S
    private let log: SagaLog
    private var completedSteps: [Int] = []
    private var context: SagaContext

    func run() async throws -> S.Result {
        for (index, step) in saga.steps.enumerated() {
            log.record(.stepStarted(sagaId: saga.id, step: step.name))

            do {
                let result = try await step.execute(context)
                completedSteps.append(index)
                log.record(.stepCompleted(sagaId: saga.id, step: step.name))

                switch result {
                case .continue:
                    continue
                case .success(let value):
                    log.record(.sagaCompleted(sagaId: saga.id))
                    return value
                case .failure(let error):
                    throw error
                }
            } catch {
                log.record(.stepFailed(sagaId: saga.id, step: step.name, error: error))
                await compensate()
                throw error
            }
        }

        fatalError("Saga completed without returning result")
    }

    private func compensate() async {
        for index in completedSteps.reversed() {
            let step = saga.steps[index]
            log.record(.compensationStarted(sagaId: saga.id, step: step.name))
            await step.compensate(context)
            log.record(.compensationCompleted(sagaId: saga.id, step: step.name))
        }
    }
}
```


### Phase 2: Changeset Integration (2-3 weeks)

```swift
// Changeset as compensation provider
class Changeset {
    private var originalContents: [String: Data] = [:]
    private var modifications: [String: Data] = [:]

    func read(_ path: String) throws -> Data {
        if let modified = modifications[path] {
            return modified
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        originalContents[path] = data
        return data
    }

    func write(_ path: String, content: Data) {
        modifications[path] = content
    }

    func revert(_ path: String) {
        modifications.removeValue(forKey: path)
    }

    func revertAll() {
        modifications.removeAll()
    }

    func apply() throws {
        for (path, content) in modifications {
            try content.write(to: URL(fileURLWithPath: path))
        }
    }

    // Generate compensation for all modifications
    func compensationSteps() -> [SagaStep<Void>] {
        modifications.keys.map { path in
            SagaStep(
                name: "revert_\(path)",
                execute: { _ in .success(()) },
                compensate: { [weak self] _ in
                    self?.revert(path)
                }
            )
        }
    }
}
```


### Phase 3: Agent Saga Integration (2-3 weeks)

```swift
// Extend MortalAgent to use sagas for complex operations
extension MortalAgent {
    func executeTask(_ task: AgentTask) async throws {
        let saga = TaskExecutionSaga(
            agent: self,
            task: task,
            changeset: Changeset()
        )

        try await sagaCoordinator.execute(saga)
    }
}

struct TaskExecutionSaga: Saga {
    let agent: MortalAgent
    let task: AgentTask
    let changeset: Changeset

    var steps: [SagaStep<TaskResult>] {
        [
            analyzeStep,
            planStep,
            executeStep,
            verifyStep,
            commitStep
        ]
    }

    var analyzeStep: SagaStep<TaskResult> {
        SagaStep(
            name: "analyze",
            execute: { ctx in
                let analysis = try await agent.analyze(task)
                ctx.store("analysis", analysis)
                return .continue
            },
            compensate: { _ in
                // Analysis has no side effects
            }
        )
    }

    // ... other steps
}
```


### Phase 4: Saga Persistence and Recovery (2 weeks)

```swift
// Saga log for durability
struct SagaLog {
    let store: DocStore

    func record(_ event: SagaEvent) {
        // Append to saga log file
        let entry = SagaLogEntry(
            timestamp: Date(),
            event: event
        )
        // Persist to JSONL file
    }

    func recover(sagaId: UUID) -> SagaExecution? {
        // Load saga state from log
        // Determine last completed step
        // Return execution ready to resume or compensate
    }
}

// On app restart
func recoverSagas() async {
    let incompleteSagas = sagaLog.findIncomplete()

    for sagaState in incompleteSagas {
        switch sagaState.status {
        case .inProgress:
            // Option 1: Resume from last step
            // Option 2: Compensate and restart
            await sagaCoordinator.resume(sagaState)
        case .compensating:
            // Continue compensation
            await sagaCoordinator.completeCompensation(sagaState)
        }
    }
}
```


### Phase 5: Multi-Agent Saga Coordination (3-4 weeks)

```swift
// Orchestration saga that spawns and coordinates child sagas
struct DelegationSaga: Saga {
    let parentAgent: MortalAgent
    let subtasks: [AgentTask]

    var steps: [SagaStep<[TaskResult]>] {
        [
            spawnAgentsStep,
            assignTasksStep,
            awaitResultsStep,
            unifyResultsStep,
            dismissAgentsStep
        ]
    }

    var spawnAgentsStep: SagaStep<[TaskResult]> {
        SagaStep(
            name: "spawn_agents",
            execute: { ctx in
                var agents: [MortalAgent] = []
                for subtask in subtasks {
                    let agent = try await spawner.spawn(assignment: subtask.description)
                    agents.append(agent)
                }
                ctx.store("agents", agents)
                return .continue
            },
            compensate: { ctx in
                let agents: [MortalAgent] = ctx.get("agents") ?? []
                for agent in agents {
                    try? await spawner.dismiss(agent)
                }
            }
        )
    }

    // ... other steps handle nested sagas for each agent
}
```


### Total Estimate: 11-15 weeks

The investment is comparable to event sourcing but provides different capabilities. Sagas are more focused on operational correctness than temporal queries.


## Migration Path from Current State


### Step 1: Add Saga Infrastructure (Non-Breaking)

Introduce saga protocols and coordinator without changing existing code:

```swift
// New files, no modifications to existing
- Sources/TavernCore/Sagas/Saga.swift
- Sources/TavernCore/Sagas/SagaStep.swift
- Sources/TavernCore/Sagas/SagaCoordinator.swift
- Sources/TavernCore/Sagas/SagaLog.swift
```


### Step 2: Wrap Existing Operations

Create sagas that wrap existing operations without changing them:

```swift
// Wraps existing spawner.spawn()
struct SpawnAgentSaga: Saga {
    let spawner: AgentSpawner
    let assignment: String

    var steps: [SagaStep<MortalAgent>] {
        [
            SagaStep(
                name: "spawn",
                execute: { ctx in
                    let agent = try spawner.spawn(assignment: assignment)
                    return .success(agent)
                },
                compensate: { ctx in
                    // Existing spawn has its own compensation
                    // This is additive, not replacement
                }
            )
        ]
    }
}
```


### Step 3: Introduce Changeset Prototype

Build changeset infrastructure, initially used only by sagas:

```swift
// Optional changeset injection
func send(_ message: String, changeset: Changeset? = nil) async throws -> String {
    // If changeset provided, use it for file operations
    // Otherwise, use current direct approach
}
```


### Step 4: Saga-ify Complex Operations

Identify operations that would benefit from saga pattern:
- Agent spawning with complex setup
- Multi-file modifications
- Verification workflows

Rewrite these as sagas while keeping simple operations direct.


### Step 5: Add Recovery Infrastructure

Once sagas are in use, add persistence and recovery:
- Saga log persistence
- Crash recovery
- Resume capabilities


### Risks and Mitigations

**Risk:** Saga overhead for simple operations

**Mitigation:** Two-tier execution - simple operations bypass saga infrastructure


**Risk:** Compensation logic bugs

**Mitigation:** Extensive testing of compensation paths, property-based tests


**Risk:** Nested saga complexity

**Mitigation:** Start with single-level sagas, add nesting only when needed


## Open Questions


### Saga Granularity

How big should a saga be?

- **Coarse:** One saga per agent task (many steps)
- **Fine:** One saga per file modification (few steps)
- **Hybrid:** Nested sagas (coarse contains fine)

Recommendation: Start with task-level sagas, decompose when compensation becomes complex.


### Compensation Timeout

How long to wait before abandoning compensation?

- Some compensations may hang (external service down)
- Need timeout and fallback strategy
- Consider: log failure, alert, manual intervention

Recommendation: 30-second default timeout, configurable per step.


### Saga Visibility

Should users see saga progress?

- Pro: Transparency about what's happening
- Con: UI complexity, information overload

Recommendation: Show saga status in debug mode, hide in production. Expose to power users via setting.


### Concurrent Saga Limits

How many sagas can run simultaneously?

- Resource constraints (memory, CPU)
- Coordination complexity
- Changeset isolation requirements

Recommendation: Limit based on changeset availability (one changeset per project = one file-modifying saga at a time).


### Integration with Event Sourcing

Sagas and event sourcing are complementary:
- Events record what happened
- Sagas orchestrate what to do

Could combine: saga steps emit events, compensation reverses event effects.

Recommendation: Decide event sourcing separately. If adopted, sagas emit events. If not, saga log serves similar purpose.


## Conclusion

The saga pattern provides a structured approach to handling the reality that agent work is multi-step and can fail at any point. Key benefits:

1. **Changeset integration** - The PRD's changeset primitive provides natural compensation
2. **Graceful failure handling** - Alternatives to "kill and restart"
3. **Crash recovery** - Resume from last successful step
4. **Explicit failure reasoning** - Forces upfront design of compensation

The main costs are implementation complexity and the need to design compensation for every step. However, for an orchestration system where partial failures are expected and graceful handling is valuable, sagas provide a proven pattern.

Recommendation: Adopt saga pattern if:
- Changesets are implemented (provides compensation for free)
- Graceful failure handling is important
- Multi-agent coordination needs isolation

Consider event sourcing instead if:
- Rewind/branch is more important than graceful failure
- Temporal queries are valuable
- Full audit trail is needed

Consider combining both if:
- All of the above are important
- Implementation budget allows 20+ weeks
