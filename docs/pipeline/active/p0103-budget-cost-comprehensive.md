---
id: p0103
slug: budget-cost-comprehensive
title: "Comprehensive budget & cost tracking: SDK integration, persistence, and reporting"
phase: design
gate: pending
priority: 1
source-bead: null
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-08
updated: 2026-03-08
assigned-agent: null
merges: [p0094, p0032, p0063]
---

# Comprehensive Budget & Cost Tracking

## Brief
> Budget is a capability that flows through the servitor tree. A servitor receives a USD budget from its parent, tracks cumulative cost against it, and can dole out portions to sub-servitors. Budget exhaustion is reported upward, not enforced as a hard stop at the SDK layer. Absorbs p0032 (token budget and cost visibility), p0063 (token budget fine-tuning), and p0094 (budget capability & cost tracking).

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **PENDING** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Gate 1 human review of merged design.

## Merged Scope

This pipeline merges three predecessors:

- **p0094** (Budget capability & cost tracking) — Complete design with 10 design statements and 8-bead work breakdown. Foundation of this document.

- **p0032** (Token budget and cost visibility) — Stub. Raised per-agent budgets, spend tracking, fish-or-cut-bait trigger on budget exceeded, cost roll-up to parent. All covered by p0094's DS-1 through DS-8.

- **p0063** (Token budget fine-tuning) — Stub. Raised periodic budget updates to agents and fine-tuning of budget parameters. Covered by p0094's DS-7 (periodic budget reports via system prompt).

**Unique scope from p0032 not in p0094:** The "fish-or-cut-bait" concept (budget exceeded as a decision trigger for the parent) maps to DS-6 (exhaustion reporting upward) — the parent decides whether to dismiss, allocate more, or ignore. No additional design needed.

**Unique scope from p0063 not in p0094:** None. Periodic updates are DS-7. Fine-tuning details were unspecified in the stub.

## Stub
~~Per-servitor budget cap flowing into options.maxBudgetUsd. User-level default budget via TavernDefaults (same two-layer pattern as 2a). Cost accumulation per-session in ChatTile. Budget warning at 90% threshold. Budget enforcement — query refuses to start if exceeded.~~

**Revised scope (post-human-discussion):** Budget is a tree-level capability, not a per-query SDK limit. Cumulative cost tracking per-servitor. Budget portions delegated from parent to child at spawn time. Exhaustion reported upward to budget originator. No hard stop at SDK layer. Dashboard view of all budgets and spend.

## Design Log

### 2026-03-08: Human Discussion — Scope Expansion

Human clarified the budget model:

1. **Budget is a capability**, passed through the servitor tree. A servitor receives a budget from its parent and can dole out portions to sub-servitors.

2. **No per-query SDK limit.** The SDK's `maxBudgetUsd` option is NOT wired in. Budget is cumulative reckoning, periodically reported to the agent.

3. **Servitors without budget operate freely.** Budget is opt-in. A servitor with no budget has no limits.

4. **Exhaustion reports upward.** When a servitor hits 100%, the event is reported up the tree to the servitor that created the budget. That originating servitor has no budget imposed on itself.

5. **p0032 and p0063 absorbed into this pipeline.** This pipeline owns both the infrastructure and the tree-level features.

### 2026-03-08: Merge into p0103

Three pipelines (p0094, p0032, p0063) merged into this comprehensive document. p0094's approved design preserved as foundation. p0032 and p0063 were stubs whose scope is fully covered by the design statements below.

## Design Statements

### DS-1: Budget as Capability

Budget is a capability in the §021 capability delegation system. It flows downward only, from parent to child. A parent cannot delegate more budget than it has remaining. Jake (or the user via Jake) creates the initial budget. The budget creator has no budget constraint on itself — it is the source.

**Key distinction from other capabilities:** Budget is a _consumable_ capability. Filesystem access is binary (have it or don't). Budget decreases as the servitor works. This makes it the first capability type with mutable state.

### DS-2: Budget Data Model

A budget has three values:

- **`allocatedUsd: Double`** — The total budget granted by the parent at spawn time.
- **`spentUsd: Double`** — Cumulative cost of this servitor's own API calls (from `SDKResultSuccess.totalCostUsd` / `SessionUsage.costUsd`).
- **`delegatedUsd: Double`** — Sum of budget portions delegated to children.

**Remaining = allocated - spent - delegated.** A servitor cannot delegate more than its remaining budget.

### DS-3: No SDK Budget Enforcement

The SDK's `QueryOptions.maxBudgetUsd` is NOT used. Budget enforcement is Tavern-side, cumulative, and soft:

- At **90% spent**, the servitor receives a budget warning in its next system prompt update or periodic report.
- At **100% spent**, the exhaustion event is reported upward. The servitor does NOT hard-stop — the parent (or budget originator) decides what to do.

This means queries continue even after budget exhaustion. The system reports, it doesn't block.

### DS-4: Cost Accumulation

Each servitor tracks its own cumulative cost from SDK responses:

- **Streaming mode:** `CompletionInfo.totalCostUsd` from each `.completed` event gives the session-level cumulative cost. The servitor stores `lastReportedCostUsd` and computes the delta.
- **Batch mode:** `SDKResultSuccess.totalCostUsd` same pattern.

Cost tracking lives in the servitor layer (on `ClodSession` or a new `BudgetTracker` type), not in UI tiles. ChatTile reads it for display but doesn't own it.

### DS-5: Budget Delegation at Spawn

When a servitor with a budget spawns a child, it can optionally allocate a portion:

```
summon_servitor(assignment: "...", budgetUsd: 2.00)
```

This:
1. Checks that the parent has >= $2.00 remaining (allocated - spent - delegated).
2. Increases the parent's `delegatedUsd` by $2.00.
3. Creates the child with `allocatedUsd = 2.00`.

If `budgetUsd` is omitted and the parent has a budget, the child inherits NO budget (operates freely). Budget is explicit opt-in per child.

### DS-6: Exhaustion Reporting

When a servitor's `spentUsd >= allocatedUsd`:

1. The servitor's `BudgetTracker` marks it as exhausted.
2. An event is emitted upward through the tree: `budgetExhausted(servitorId, servitorName, allocated, spent)`.
3. The event bubbles up to the budget originator — the first ancestor that created the budget (has no budget of its own, or has a different budget scope).
4. The originator decides: dismiss the servitor, allocate more budget, or ignore.

This is the "fish-or-cut-bait" trigger from p0032 — budget exhaustion forces a decision from the parent rather than silently continuing or hard-stopping.

### DS-7: Periodic Budget Reports

Servitors with budgets receive periodic updates about their remaining budget. This happens via system prompt augmentation:

- After each response, if the servitor has a budget, append a budget status line to the next system prompt or inject it as a system message.
- Format: `[Budget: $X.XX remaining of $Y.YY allocated ($Z.ZZ spent, $W.WW delegated)]`
- At 90%+ spent: `[WARNING: Budget nearly exhausted — $X.XX remaining of $Y.YY]`

### DS-8: Budget Dashboard

A budget dashboard shows all active budgets across the project:

| Servitor | Allocated | Spent | Delegated | Remaining | Status |
|----------|-----------|-------|-----------|-----------|--------|
| Marcos Antonio | $5.00 | $2.30 | $1.50 | $1.20 | Active |
| → María Elena | $1.50 | $1.50 | $0.00 | $0.00 | Exhausted |

This could be a slash command (`/budget`) or a panel in the UI. Implementation details deferred to breakdown.

### DS-9: Servitors Without Budget

A servitor with no budget (`allocatedUsd == nil`) operates freely — no tracking, no warnings, no limits. This is the default. Budget is an opt-in constraint.

Jake never has a budget imposed on him (he's the source). User-spawned servitors (via + button) default to no budget. Jake-spawned servitors get a budget only if Jake explicitly passes one via `summon_servitor`.

### DS-10: Budget Persistence

Budget state is persisted in the servitor record (`.tavern/servitors/<name>/servitor.md`):

```yaml
budgetAllocatedUsd: 5.00
budgetSpentUsd: 2.30
budgetDelegatedUsd: 1.50
```

On app restart, budget state is restored from the record. The `spentUsd` value is authoritative — it's updated from SDK responses during the session and persisted after each response (same pattern as `sessionId` persistence in `ClodSessionManager.wrapStreamWithPersistence`).

## Work Breakdown Plan

### Dependency Graph

```
WB-1 (BudgetTracker domain type)
  ├── WB-2 (ServitorRecord budget fields) ── depends on WB-1
  │     └── WB-5 (Budget persistence in ClodSessionManager) ── depends on WB-2, WB-3
  ├── WB-3 (Cost accumulation in ClodSession) ── depends on WB-1
  │     └── WB-5
  ├── WB-4 (Budget delegation in MortalSpawner + MCP tool) ── depends on WB-1, WB-2
  ├── WB-6 (Periodic budget reports via system prompt) ── depends on WB-3, WB-5
  ├── WB-7 (Exhaustion reporting upward) ── depends on WB-3, WB-5
  └── WB-8 (Budget dashboard slash command) ── depends on WB-1, WB-5
```

### WB-1: BudgetTracker Domain Type

**Implements:** DS-2 (data model), DS-9 (servitors without budget)

**Acceptance criteria:**
- New `BudgetTracker` type in `TavernCore/Budget/` with `allocatedUsd`, `spentUsd`, `delegatedUsd` properties
- Computed `remainingUsd` and `isExhausted` properties
- `canDelegate(amount:)` check: remaining >= amount
- `recordSpend(delta:)` method to increment `spentUsd`
- `recordDelegation(amount:)` method to increment `delegatedUsd`
- Thread-safe: either genuinely `Sendable` (immutable snapshot pattern) or an actor
- `MockBudgetTracker` for testing
- `nil` budget means no tracking (DS-9)

**Tests:**
- Grade 1: arithmetic correctness (remaining = allocated - spent - delegated)
- Grade 1: canDelegate returns false when amount > remaining
- Grade 1: isExhausted when spent >= allocated
- Grade 1: nil budget means no constraints

**Dependencies:** None (foundation layer)

### WB-2: ServitorRecord Budget Fields

**Implements:** DS-10 (budget persistence)

**Acceptance criteria:**
- Add `budgetAllocatedUsd: Double?`, `budgetSpentUsd: Double?`, `budgetDelegatedUsd: Double?` to `ServitorRecord`
- YAML frontmatter serialization/deserialization handles these fields
- Backwards-compatible: existing records without budget fields parse correctly (nil values)
- `ProjectDirectory` read/write paths unchanged (ServitorRecord is just data)

**Tests:**
- Grade 1: round-trip encode/decode with budget fields
- Grade 1: decode existing record without budget fields (all nil)
- Grade 1: decode record with partial budget fields

**Dependencies:** WB-1 (needs to know the data model)

### WB-3: Cost Accumulation in ClodSession

**Implements:** DS-4 (cost accumulation)

**Acceptance criteria:**
- `ClodSession` tracks cumulative cost from SDK responses
- Streaming: extract cost delta from `CompletionInfo.totalCostUsd` after each `.completed` event
- Store `lastReportedTotalCostUsd` to compute deltas (SDK reports session-cumulative, not per-response)
- New method or property: `sessionCostUsd: Double` (current cumulative cost)
- If a `BudgetTracker` is attached to the session, feed cost deltas into it via `recordSpend(delta:)`
- `ClodSession.Config` gains optional `budgetTracker: BudgetTracker?`

**Tests:**
- Grade 2: mock messenger returns known cost values, verify accumulation
- Grade 2: streaming mode accumulates across multiple completions
- Grade 2: cost delta correctly computed from session-cumulative values
- Grade 2: no budget tracker = cost still tracked (for display), just no enforcement

**Dependencies:** WB-1 (BudgetTracker type)

### WB-4: Budget Delegation in MortalSpawner + MCP Tool

**Implements:** DS-5 (budget delegation at spawn)

**Acceptance criteria:**
- `MortalSpawner.summon(assignment:budgetUsd:)` accepts optional budget allocation
- When parent has a budget and `budgetUsd` is specified:
  - Validates parent has sufficient remaining budget
  - Calls parent's `budgetTracker.recordDelegation(amount:)`
  - Creates child `Mortal` with `BudgetTracker(allocated: budgetUsd)`
- When `budgetUsd` is nil, child has no budget (DS-9)
- `summon_servitor` MCP tool gains optional `budgetUsd` parameter in its input schema
- Error case: insufficient budget returns informative error via MCP
- `TavernError` gains `.insufficientBudget(requested:available:)` case

**Tests:**
- Grade 2: spawn with budget creates child with correct allocation
- Grade 2: spawn with budget reduces parent's remaining
- Grade 2: spawn with insufficient budget fails with informative error
- Grade 2: spawn without budget = no budget on child
- Grade 2: MCP tool passes budgetUsd through correctly

**Dependencies:** WB-1 (BudgetTracker), WB-2 (ServitorRecord for persistence)

### WB-5: Budget Persistence in ClodSessionManager

**Implements:** DS-10 (budget persistence, runtime updates)

**Acceptance criteria:**
- `ClodSessionManager.wrapStreamWithPersistence` also persists budget state after each `.completed` event
- Budget fields in `ServitorRecord` updated with current `spentUsd` and `delegatedUsd`
- On app restart, `Mortal` instances restored with `BudgetTracker` initialized from `ServitorRecord` budget fields
- Restoration handles records with and without budget fields

**Tests:**
- Grade 2: budget state persisted after streaming completion
- Grade 2: budget state restored on mortal reconstruction
- Grade 2: mortal without budget fields restores with nil budget

**Dependencies:** WB-2 (ServitorRecord fields), WB-3 (cost accumulation populates the data)

### WB-6: Periodic Budget Reports via System Prompt

**Implements:** DS-7 (periodic budget reports), DS-3 (warning at 90%)

**Acceptance criteria:**
- After each response, if servitor has a budget, `ClodSession.buildOptions()` appends budget status to `appendSystemPrompt`
- Format: `[Budget: $X.XX remaining of $Y.YY allocated ($Z.ZZ spent, $W.WW delegated)]`
- At 90%+ spent: `[WARNING: Budget nearly exhausted — $X.XX remaining of $Y.YY]`
- No budget = no augmentation

**Tests:**
- Grade 2: system prompt contains budget line when budget exists
- Grade 2: warning format at 90% threshold
- Grade 2: no budget line when budget is nil
- Grade 2: format strings are accurate with real numbers

**Dependencies:** WB-3 (cost accumulation), WB-5 (budget state available at query time)

### WB-7: Exhaustion Reporting Upward

**Implements:** DS-6 (exhaustion reporting)

**Acceptance criteria:**
- When `BudgetTracker.isExhausted` becomes true after a cost update, emit an event
- Event type: `StreamEvent.budgetExhausted(servitorId:servitorName:allocated:spent:)` (new case)
- Event propagates through `ClodSessionManager.wrapStreamWithPersistence` up to the UI layer
- ChatTile or ChatViewModel surfaces the exhaustion to the user
- Log the exhaustion event at `.warning` level

**Tests:**
- Grade 2: exhaustion event emitted when spent crosses allocated threshold
- Grade 2: event not emitted when budget has remaining
- Grade 2: event contains correct servitor identification and amounts

**Dependencies:** WB-3 (cost accumulation triggers the check), WB-5 (budget state must be persisted for cross-session tracking)

### WB-8: Budget Dashboard Slash Command

**Implements:** DS-8 (budget dashboard)

**Acceptance criteria:**
- New `/budget` slash command in `CommandRegistry`
- Queries all active servitors for budget state
- Outputs formatted table: servitor name, allocated, spent, delegated, remaining, status
- Tree indentation showing parent-child relationships (if tree info available)
- Shows "No active budgets" when none exist
- Logging per slash command standards

**Tests:**
- Grade 2: command produces correct output with mock servitors
- Grade 2: handles mix of budgeted and unbudgeted servitors
- Grade 2: handles no servitors with budgets

**Dependencies:** WB-1 (BudgetTracker), WB-5 (budget state accessible)

## Verification Results

_Pending execution._

## Agent Context

### Relevant Specs
- §005 Spawning — REQ-SPN-001 (summon parameters include token budget)
- §020 Servitor Trees — REQ-TRE-005 (token budget inheritance: parent→child, periodic updates, exhaustion triggers)
- §021 Capability Delegation — REQ-CAP-003 (capability types), REQ-CAP-004 (delegation chains: child <= parent <= Jake)
- §015 Observability — boundary attempts include exceeding token budgets

### Relevant ADRs
- ADR-011 (thread safety model — BudgetTracker must be Sendable or actor-isolated)
- ADR-003 (dependency injection — BudgetTracker needs mock for testing)

### Key Code
- `Tavern/Sources/TavernCore/Sessions/ClodSession.swift` — mechanism layer, builds QueryOptions, receives SDK responses with cost data
- `Tavern/Sources/TavernCore/Providers/ClodSessionManager.swift` — policy layer, persists session state after responses
- `Tavern/Sources/TavernCore/Servitors/MortalSpawner.swift` — spawn factory, accepts defaults, creates Mortal instances
- `Tavern/Sources/TavernCore/Servitors/Mortal.swift` — wraps ClodSession, manages state machine
- `Tavern/Sources/TavernCore/MCP/TavernMCPServer.swift` — `summon_servitor` tool (needs `budgetUsd` parameter)
- `Tavern/Sources/TavernCore/Persistence/ServitorRecord.swift` — persistent servitor state (needs budget fields)
- `Tavern/Sources/TavernCore/Persistence/TavernDefaults.swift` — two-layer defaults pattern (Layer 1 for budget NOT needed — budget is capability, not default)
- `Tavern/Sources/Tiles/ChatTile/ChatTile.swift` — already tracks `totalCostUsd` for display
- `Tavern/Sources/TavernCore/Commands/CostCommand.swift` — `/cost` command, could be extended for budget display
- `Tavern/Sources/TavernKit/StreamTypes.swift` — `CompletionInfo.totalCostUsd`, `SessionUsage.costUsd`
- `ClodKit/Sources/ClodKit/Transport/SDKResultSuccess.swift` — `totalCostUsd` from SDK responses
- `ClodKit/Sources/ClodKit/Transport/ModelUsage.swift` — `costUSD` per-response

### Distilled Instructions
- Budget is NOT a TavernDefaults setting — it's a capability, not a user preference
- `@unchecked Sendable` banned — BudgetTracker must be genuinely Sendable, an actor, or @MainActor
- SDK's `QueryOptions.maxBudgetUsd` is NOT wired in — all budget logic is Tavern-side cumulative tracking
- Cost data source: `CompletionInfo.totalCostUsd` (streaming) and `SDKResultSuccess.totalCostUsd` (batch) give session-cumulative USD cost
- Budget persistence follows the same pattern as sessionId: updated in `ClodSessionManager.wrapStreamWithPersistence` after each completed response

## Child Beads

## Generated Stubs
