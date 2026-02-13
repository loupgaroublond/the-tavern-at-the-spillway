# 005 — Spawning Specification

**Status:** complete
**Last Updated:** 2026-02-10

## Upstream References
- PRD: §6.2 (Agent Spawn Configuration), §6.3 (Work Queues), §7 (Agent Naming)
- Reader: §3 (Two-Mode Agent Spawning, Agent Naming, Chat Description)
- Transcripts: transcript_2026-01-19-1144.md (naming themes), transcript_2026-01-27-testing-principles.md (two-mode spawn, chat description), transcript_2026-01-28-jake-spawn-tool.md (spawn tool)

## Downstream References
- ADR: --
- Code: Tavern/Sources/TavernCore/Agents/ServitorSpawner.swift, Tavern/Sources/TavernCore/Naming/, Tavern/Sources/TavernCore/Coordination/
- Tests: Tavern/Tests/TavernCoreTests/, Tavern/Tests/TavernTests/

---

## 1. Overview
Agent spawning, naming themes, work queue management, and spawn configuration. Covers the two spawn modes (user-spawn vs Jake-spawn), the theatrical naming system with themed name generators, how work is queued and distributed, and the full set of spawn-time parameters.

## 2. Requirements

### REQ-SPN-001: Spawn Configuration Parameters
**Source:** PRD §6.2
**Priority:** must-have
**Status:** specified

**Properties:**
- A spawn call accepts these optional parameters: assignment, sandbox config, model selection, token budget, work queue attachment, commitments to prefill, done behavior
- For Jake-spawn, assignment is required; for user-spawn, no parameters are required
- Omitted parameters receive sensible defaults
- Each parameter, when provided, is reflected in the resulting agent's configuration

**Testable assertion:** A spawn call with each parameter set correctly creates an agent with those parameters applied. A spawn call with default parameters creates an agent with sensible defaults.

### REQ-SPN-002: User-Spawn Mode
**Source:** Reader §3 (Two-Mode Agent Spawning)
**Priority:** must-have
**Status:** specified

**Properties:**
- A user-spawned agent has no assignment
- A user-spawned agent starts in chat mode
- A user-spawned agent does not begin working until the user sends a message
- Spawning is instant — no dialogs, no intermediate UI

**See also:** §4.2.7 (two-level orchestration model)

**Testable assertion:** Clicking `+` creates an agent immediately (no modal dialog). The new agent has no assignment. The agent does not begin working until the user sends a message.

### REQ-SPN-003: Jake-Spawn Mode
**Source:** Reader §3 (Two-Mode Agent Spawning)
**Priority:** must-have
**Status:** specified

**Properties:**
- A Jake-spawned agent has an assignment
- A Jake-spawned agent begins working immediately without waiting for user input
- A Jake-spawned agent starts in perseverance mode

**See also:** §4.2.7 (two-level orchestration model)

**Testable assertion:** A `summon_servitor` call with an assignment creates an agent that immediately begins working. The agent does not wait for user input before starting.

### REQ-SPN-004: Naming Theme Assignment
**Source:** PRD §7
**Priority:** should-have
**Status:** specified

**Properties:**
- Every mortal agent tree has exactly one naming theme, assigned at tree creation
- All agents in the same tree share their tree's naming theme
- Different trees may have different themes

**Testable assertion:** All agents in the same tree share a naming theme. Different trees may have different themes. The theme is set at tree creation time.

### REQ-SPN-005: Global Name Uniqueness
**Source:** PRD §7
**Priority:** must-have
**Status:** specified

**Properties:**
- Every mortal agent has a globally unique name across the entire system (all projects, all trees)
- An agent can be identified by name alone — no path addressing is required
- Name lookup by string returns exactly one agent or none

**Testable assertion:** No two agents share the same name. Name lookup by string returns exactly one agent or none.

### REQ-SPN-006: Tier Depletion
**Source:** PRD §7
**Priority:** should-have
**Status:** specified

**Properties:**
- Naming themes have escalating tiers of silliness
- Lower tiers are exhausted before higher tiers are used
- Names within each tier are not repeated
- Tier depletion ordering is deterministic (same spawn sequence produces same names)

**Testable assertion:** The first agents spawned in a theme receive tier-1 names. After tier-1 is exhausted, tier-2 names are used. Names within each tier are not repeated.

### REQ-SPN-007: Easter Egg Names
**Source:** PRD §7
**Priority:** should-have
**Status:** specified

**Properties:**
- Some naming themes contain names that only appear after enough agents have been spawned to exhaust earlier tiers
- High concurrency is rewarded with humor

**Testable assertion:** Specific themes have names that only appear after a threshold number of agents. (Theme-specific, verified per naming theme.)

### REQ-SPN-008: Work Queues
**Source:** PRD §6.3
**Priority:** deferred
**Status:** specified

**Properties:**
- Work queues live in the document store
- Parents create queues; agents attach to them at spawn or mid-task
- When a queue item appears, the attached agent fires immediately
- Empty-queue behavior is deterministic (idle, hibernate, terminate, etc.) and specified at attachment time

**Testable assertion:** Deferred for v1. When implemented: creating a queue item triggers the attached agent. An agent with empty-queue instructions follows them when the queue drains.

### REQ-SPN-009: Chat Description
**Source:** Reader §3 (Chat Description)
**Priority:** must-have
**Status:** specified

**Properties:**
- Every agent has a mutable chat description visible in the sidebar
- Both the user and the agent (via tools) can alter the description at any time
- The description includes the original ask plus current status
- The description persists across app restarts

**Testable assertion:** The chat description is visible in the sidebar. The user can edit it. The agent can update it via a tool call. The description persists across app restarts.

### REQ-SPN-010: Auto-Generated Names
**Source:** CLAUDE.md (MCP Tools)
**Priority:** must-have
**Status:** specified

**Properties:**
- When `summon_servitor` is called without a `name`, a name is auto-generated from the current naming theme
- Auto-generated names follow the theme's tier depletion rules (REQ-SPN-006)
- Auto-generated names are globally unique (REQ-SPN-005)

**Testable assertion:** `summon_servitor` without a name produces an agent with a non-nil, theme-appropriate name. The name is unique.

## 3. Properties Summary

### Spawn Mode Properties

| Property | User-Spawn | Jake-Spawn |
|----------|-----------|------------|
| Has assignment | No | Yes (required) |
| Initial mode | Chat | Perseverance |
| Begins working | After user's first message | Immediately |
| Spawning UI | Instant, no dialogs | Invisible (tool call) |

### Naming Properties

| Property | Holds When | Violated When |
|----------|-----------|---------------|
| Global uniqueness | No two agents share a name, system-wide | Name collision across any project or tree |
| Tier depletion | Tier N+1 names only appear after tier N is exhausted | Higher-tier name used while lower-tier names remain |
| Theme consistency | All agents in a tree use the same theme | An agent's name doesn't match its tree's theme |
| Deterministic ordering | Same spawn sequence → same names | Non-deterministic name selection |

## 4. Open Questions

- **Model selection availability:** PRD §6.2 says "Haiku for drones, Sonnet for coordinators, Opus for architects." Is this the exact mapping or is it configurable per-spawn? What happens if a preferred model is unavailable?

- **Token budget enforcement:** How is the token budget enforced? Does the system cut off the agent mid-response? Pre-calculate remaining budget before each API call?

- **Done behavior transitions:** When an agent finishes its task and the done behavior is "check queue," what queue does it check? Must the queue be specified at spawn time?

## 5. Coverage Gaps

- **Spawn failure handling:** What happens when a spawn fails (out of resources, name generation exhausted, SDK error)? The PRD specifies preflight checks (§11) but not spawn-level failure handling.

- **Maximum agent count:** No specification for how many agents can be alive simultaneously per project or system-wide.

- **Agent migration:** No specification for moving an agent from one tree to another, or re-parenting an agent.
