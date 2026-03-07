# 005 — Spawning Specification

**Status:** complete
**Last Updated:** 2026-02-16

## Upstream References
- PRD: §6.2 (Agent Spawn Configuration), §6.3 (Work Queues), §7 (Agent Naming)
- Reader: §3 (Two-Mode Agent Spawning, Agent Naming, Chat Description)
- Transcripts: transcript_2026-01-19-1144.md (naming themes), transcript_2026-01-27-testing-principles.md (two-mode spawn, chat description), transcript_2026-01-28-jake-spawn-tool.md (spawn tool)

## Downstream References
- ADR: --
- Code: Tavern/Sources/TavernCore/Servitors/MortalSpawner.swift, Tavern/Sources/TavernCore/Naming/, Tavern/Sources/TavernCore/Coordination/
- Tests: Tavern/Tests/TavernCoreTests/, Tavern/Tests/TavernTests/

---

## 1. Overview
Servitor summoning, naming themes, work queue management, and summon configuration. Covers the two summon modes (user-summon vs Jake-summon), the theatrical naming system with themed name generators, how work is queued and distributed, and the full set of summon-time parameters.

## 2. Requirements

### REQ-SPN-001: Summon Configuration Parameters
**Source:** PRD §6.2
**Priority:** must-have
**Status:** specified

**Properties:**
- A summon call accepts these optional parameters: assignment, sandbox config, model selection, token budget, work queue attachment, commitments to prefill, done behavior
- For Jake-summon, assignment is required; for user-summon, no parameters are required
- Omitted parameters receive sensible defaults
- Each parameter, when provided, is reflected in the resulting servitor's configuration
- Capability delegation is separate from summon — see §021

**Testable assertion:** A summon call with each parameter set correctly creates a servitor with those parameters applied. A summon call with default parameters creates a servitor with sensible defaults.

### REQ-SPN-002: User-Summon Mode
**Source:** Reader §3 (Two-Mode Agent Spawning)
**Priority:** must-have
**Status:** specified

**Properties:**
- A user-summoned servitor has no assignment
- A user-summoned servitor starts in chat mode
- A user-summoned servitor does not begin working until the user sends a message
- Summoning is instant — no dialogs, no intermediate UI

**See also:** §4.2.7 (servitor trees)

**Testable assertion:** Clicking `+` creates a servitor immediately (no modal dialog). The new servitor has no assignment. The servitor does not begin working until the user sends a message.

### REQ-SPN-003: Jake-Summon Mode
**Source:** Reader §3 (Two-Mode Agent Spawning)
**Priority:** must-have
**Status:** specified

**Properties:**
- A Jake-summoned servitor has an assignment
- A Jake-summoned servitor begins working immediately without waiting for user input
- A Jake-summoned servitor starts in perseverance mode
- Jake-summoned servitors may receive an assignment to: work on a task, ask the user a question, say something, or wait for user input
- Capability grants are conditional on the summon call — the parent must tick that box in the summon call with assignment

**See also:** §4.2.7 (servitor trees), §021 (capability delegation)

**Testable assertion:** A `summon_servitor` call with an assignment creates a servitor that immediately begins working. The servitor does not wait for user input before starting.

### REQ-SPN-004: Naming Theme Assignment
**Source:** PRD §7
**Priority:** should-have
**Status:** specified

**Properties:**
- Each tree gets a name set assigned to the top-level servitor
- All children in that tree draw names from the same set
- If the set is depleted, the top servitor requests another name set from Jake
- Multiple trees may share a name set, requiring concurrency management
- Different trees may have different themes

**Testable assertion:** All servitors in the same tree share a name set. If the set is depleted, a new set is requested. Different trees may have different themes.

### REQ-SPN-005: Global Name Uniqueness
**Source:** PRD §7
**Priority:** must-have
**Status:** specified

**Properties:**
- Every mortal servitor has a globally unique name across the entire system (all projects, all trees)
- A servitor can be identified by name alone — no path addressing is required
- Name lookup by string returns exactly one servitor or none
- Root servitors of trees must coordinate on name usage within shared name sets
- The deterministic shell can enforce name locking before servitor creation to maintain uniqueness

**Testable assertion:** No two servitors share the same name. Name lookup by string returns exactly one servitor or none.

### REQ-SPN-006: Tier Depletion
**Source:** PRD §7
**Priority:** should-have
**Status:** specified

**Properties:**
- Tier 1 is a set of name sets. Jake rotates through assigning name sets from tier 1 to new trees until depleted or the user unlocks higher tiers.
- Lower tiers are exhausted before higher tiers are used
- Names within each tier are not repeated
- Tier depletion ordering is deterministic (same summon sequence produces same names)

**Testable assertion:** The first servitors summoned in a theme receive tier-1 names. After tier-1 is exhausted, tier-2 names are used. Names within each tier are not repeated.

### REQ-SPN-007: Easter Egg Names
**Source:** PRD §7
**Priority:** should-have
**Status:** specified

**Properties:**
- Some naming themes contain names that only appear after enough servitors have been summoned to exhaust earlier tiers
- High concurrency is rewarded with humor

**Testable assertion:** Specific themes have names that only appear after a threshold number of servitors. (Theme-specific, verified per naming theme.)

### REQ-SPN-008: Work Queues
**Source:** PRD §6.3
**Priority:** deferred
**Status:** specified

**Properties:**
- Work queues live in the document store
- Parents create queues; servitors attach to them at summon or mid-task
- When a queue item appears, the attached servitor fires immediately
- Empty-queue behavior is deterministic (idle, hibernate, terminate, etc.) and specified at attachment time

**Testable assertion:** Deferred for v1. When implemented: creating a queue item triggers the attached servitor. A servitor with empty-queue instructions follows them when the queue drains.

### REQ-SPN-009: Chat Description
**Source:** Reader §3 (Chat Description)
**Priority:** must-have
**Status:** specified

**Properties:**
- Every servitor has a mutable chat description visible in the sidebar
- Both the user and the servitor (via tools) can alter the description at any time
- The description includes the original ask plus current status
- The description persists across app restarts

**Testable assertion:** The chat description is visible in the sidebar. The user can edit it. The servitor can update it via a tool call. The description persists across app restarts.

### REQ-SPN-010: Auto-Generated Names
**Source:** CLAUDE.md (MCP Tools)
**Priority:** must-have
**Status:** specified

**Properties:**
- When `summon_servitor` is called without a `name`, a name is auto-generated from the current naming theme
- Auto-generated names follow the theme's tier depletion rules (REQ-SPN-006)
- Auto-generated names are globally unique (REQ-SPN-005)

**Testable assertion:** `summon_servitor` without a name produces a servitor with a non-nil, theme-appropriate name. The name is unique.

## 3. Properties Summary

### Summon Mode Properties

| Property | User-Summon | Jake-Summon |
|----------|-----------|------------|
| Has assignment | No | Yes (required) |
| Initial mode | Chat | Perseverance |
| Begins working | After user's first message | Immediately |
| Summoning UI | Instant, no dialogs | Invisible (tool call) |

### Naming Properties

| Property | Holds When | Violated When |
|----------|-----------|---------------|
| Global uniqueness | No two servitors share a name, system-wide | Name collision across any project or tree |
| Tier depletion | Tier N+1 names only appear after tier N is exhausted | Higher-tier name used while lower-tier names remain |
| Theme consistency | All servitors in a tree use the same theme | A servitor's name doesn't match its tree's theme |
| Deterministic ordering | Same summon sequence → same names | Non-deterministic name selection |

## 4. Open Questions

- **Model selection:** Resolved: Orthogonal to the servitor. Can be set by user, Jake, or servitor.

- **Token budget:** Resolved: Fine-tuning needed, but servitors get periodic updates. Pinned for detailed design.

- **Done behavior:** Resolved: Three flags — check work queue and wait idle if empty, dismiss, or just wait idle. A daemon may periodically check queues and wake idle servitors.

- **Summon failure:** Resolved: Parent gets notified of the event (same as completion or reaping notifications).

- **Maximum count:** Resolved: No maximum. Deal with it.

- **Migration:** Resolved: No servitor migration. Cross-tree communication via capability grants.

## 5. Coverage Gaps

- **Summon failure handling:** Resolved: Parent receives notification on summon failure.

- **Maximum servitor count:** Resolved: No maximum.

- **Servitor migration:** Resolved: No migration. Cross-tree communication via §021.
