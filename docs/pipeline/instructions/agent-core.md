# Agent Core Instructions

_Sources: 004-agents, 005-spawning, 006-lifecycle, 007-operating-modes, 008-deterministic-shell, ADR-003, ADR-011_

Load alongside `core.md` for work on servitor types, spawning, lifecycle, state machines, deterministic shell, or MCP tools.

---

## Servitor Types

### Jake (The Proprietor)
- Daemon — exactly one per project, lifecycle tied to project open/close
- Coordinates, does not execute. Highest authority to manage other servitors.
- Session persists across app restarts (per-project).
- Delegates capabilities to servitors with stipulations (see capability delegation below).
- Cannot delegate capabilities beyond what he himself has.

### Mortal (The Regulars)
- Task-scoped — lifecycle bound to task completion.
- Can summon children, forming tree structures of arbitrary depth.
- Parent-child relationships tracked.
- Immortal servitors (daemons) resuscitated when session context becomes invalid.

### Drones (Deferred)
- Complete exactly one task, auto-terminate. Cheap to fail, no recovery.

### Monitor Daemons (Deferred)
- Background reporters to Jake. No user tasks. Track health, progress, spending.

---

## State Machine (REQ-AGT-005, REQ-STM)

Every servitor has exactly one state:
- **Summoned** -> Working (begin execution)
- **Working** -> WaitingForInput | WaitingForWakeup | DismissedReaped | FailedReaped
- **WaitingForInput** -> Working (user responds) | FailedReaped (timeout/reap)
- **WaitingForWakeup** -> Working (perseverance prod) | FailedReaped (timeout/reap)
- **DismissedReaped** -> GC
- **FailedReaped** -> GC

Only valid transitions permitted. Invalid transitions produce an error. State transitions logged in debug.

**Done requires verified commitments (REQ-DET-004).** Self-assessment has no bearing.

---

## Spawning

### Two Spawn Modes

| Property | User-Summon | Jake-Summon |
|----------|------------|-------------|
| Has assignment | No | Yes (required) |
| Initial mode | Chat | Perseverance |
| Begins working | After user's first message | Immediately |
| UI | Instant, no dialogs | Invisible (tool call) |

### Summon Configuration (REQ-SPN-001)
Parameters: assignment, sandbox config, model selection, token budget, work queue attachment, commitments to prefill, done behavior. Omitted params get sensible defaults.

### Naming (REQ-SPN-004 through REQ-SPN-007)
- Each tree gets a name set; all children draw from same set.
- Every mortal has a **globally unique name** across all projects and trees.
- Tier 1 exhausted before tier 2. Deterministic ordering.
- Auto-generated names via `summon_servitor` without `name` param.

### Chat Description (REQ-SPN-009)
- Every servitor has a mutable chat description visible in sidebar.
- Both user and servitor can alter it. Persists across restarts.

---

## Lifecycle (REQ-LCM)

### Fish-or-Cut-Bait Triggers (REQ-LCM-001)
Five triggers: token budget exceeded, changeset fundamentally wrong, agent spinning, entire gang on wrong path, agent self-termination. Each detectable programmatically. Fires -> FailedReaped. Parent notified with trigger reason.

### Token Budget (REQ-LCM-002)
Every agent has a budget set at spawn. Exceeding fires FOCB. Overshoot is bounded.

### Spin Detection (REQ-LCM-003)
N identical/near-identical tool calls without new artifacts = spinning. Threshold configurable.

### Dead Agent Artifacts (REQ-LCM-004)
Dead agents leave persistent artifacts. Tile persists in sidebar. User can view final state, history, outputs. Not immediately cleaned up.

### Agent Expiration (REQ-LCM-007)
Mortal agents transition to done/expired or hibernation. Jake notified. Dashboard reflects accurate status.

---

## Deterministic Shell (REQ-DET)

### Prompt Composition (REQ-DET-001)
- Prompts constructed by deterministic code, not by previous agent responses.
- Each message includes all necessary context regardless of history length.
- Never rely on agent "remembering" prior instructions.
- Invariants in prompts enforced by the system, even for child servitor prompts.

### Passthrough Display (REQ-DET-002)
- All content blocks the user sees are passthrough — not reinterpreted by any agent.
- Content from doc store is byte-identical to file on disk.
- No LLM summarization between storage and display.

### Structured Outputs (REQ-DET-003)
- Precision operations go through typed tool calls, not free-text parsing.
- Tool calls have validated params; results have typed returns.

### Commitment Verification (REQ-DET-004)
- Done = agent requests commitment check. Complete only after all commitments pass.
- Verification by `CommitmentVerifier`, external to agent's session.
- Agent self-assessment of "done" has no bearing on actual completeness.
- Failure leaves agent in non-complete state. Parent notified of both pass and fail.

### MCP Tools (REQ-DET-008)
- `summon_servitor` — optional `assignment` and `name`. Auto-generates name if not provided.
- `dismiss_servitor` — removes from UI, not from registry.
- New Jake tools: define `MCPTool` with handler, use callbacks for side effects.

---

## Dependency Injection (ADR-003)

Two mocking layers:
1. **MockServitor** — conforms to `Servitor` protocol, returns canned responses.
2. **ServitorMessenger** — abstracts SDK boundary. `LiveMessenger` (prod), `MockMessenger` (test).

Jake and Mortal accept `ServitorMessenger` via constructor injection, defaulting to `LiveMessenger()`.

**Rule:** Any new servitor type that calls the SDK must accept `ServitorMessenger`.

---

## Thread Safety (ADR-011)

Preference hierarchy:
1. Genuinely `Sendable` (no mutable state)
2. Actor isolation
3. `@MainActor`

`@unchecked Sendable` banned for new code. Legacy types with serial `DispatchQueue` are tracked for removal.

---

## Operating Modes (REQ-OPM)

Modes that affect the attention model and notification routing:
- **Hands-on:** User actively working with agents. All notifications visible.
- **Supervisory:** User monitoring but not directing. Escalations only.
- **Away:** User absent. Queue everything, batch on return.

Mode transitions are observable and affect the communication system.

---

## Two-Level Orchestration (REQ-AGT-007)

**Level 1 — Tavern Servitors:** Full Claude sessions, sidebar visible, persist across sessions. For substantial, independent work.

**Level 2 — Subagents (Task tool):** Internal parallel workers within a session. Lightweight, ephemeral. For quick parallel tasks.

Tavern does not wrap or abstract Claude's internal agent mechanism — session internals are opaque.
