# 015 — Observability Specification

**Status:** complete
**Last Updated:** 2026-02-10

## Upstream References
- PRD: §9 (Metrics), §9.1 (Starter Templates — referenced here for meta process), §9.2 (Meta Process), §9.3 (Discovery Sharing), §16 (Violation Monitoring), §19.1 (Logging Standards)
- Reader: §10 (Instrumentation Principle), §7 (TavernLogger categories)
- Transcripts: transcript_2026-01-21-1620.md (TavernLogger, stress testing), transcript_2026-01-21-2113-performance.md (perception boundaries)

## Downstream References
- ADR: --
- Code: Tavern/Sources/TavernCore/Logging/ (TavernLogger), Tavern/Sources/TavernCore/Errors/ (TavernError, TavernErrorMessages)
- Tests: Tavern/Tests/TavernCoreTests/

---

## 1. Overview
Metrics collection, violation monitoring, logging standards, and the meta process for workflow improvement. Defines how the system instruments itself for diagnosability, how invariant violations are detected and reported, and how workflows improve through measurement.

## 2. Requirements

### REQ-OBS-001: Time Category Metrics
**Source:** PRD §9
**Priority:** must-have
**Status:** specified

**Properties:**
- Four time categories are tracked per agent: token time (LLM API waits), tool time (tool execution), wall clock time (total elapsed), throttle time (rate limiting/API limits)
- These four categories are the foundation for all derived metrics
- Throttle time is excluded from utilization calculations

**Testable assertion:** Each API call records its token time. Each tool execution records its tool time. Wall clock time is captured per-agent and per-task. Throttle time is identified and excluded from utilization calculations.

### REQ-OBS-002: Agent Utilization Metrics
**Source:** PRD §9
**Priority:** must-have
**Status:** specified

**Properties:**
- Utilization = Token time / Wall clock time (how much of the agent's time is spent on LLM calls)
- Saturation = (Token time + Tool time) / Wall clock time (how busy the agent is overall)
- Agent wait time = time since agent last stopped (monotonically increasing while stopped)
- All values are computable at any point; utilization and saturation are in [0.0, 1.0]

**Testable assertion:** Utilization and saturation are computable for any agent at any point. Values are between 0.0 and 1.0. Wait time increases monotonically while an agent is stopped.

### REQ-OBS-003: Human Metrics
**Source:** PRD §9
**Priority:** should-have
**Status:** specified

**Properties:**
- Human wait time = idle time between things needing attention (ideally zero)
- Context switching load = count of agents in waiting-for-input state simultaneously
- These are informational dashboard metrics, not warnings or alerts

**Testable assertion:** Human wait time is calculable from agent question timestamps and user response timestamps. Context switching load is a count of agents in waiting-for-input state.

### REQ-OBS-004: Amplification Factor
**Source:** PRD §9
**Priority:** must-have
**Status:** specified

**Properties:**
- Amplification factor = count of saturated agents running concurrently at a given moment
- High amplification means many agents are productively working while the human focuses elsewhere
- Saturation threshold for "saturated" is configurable (e.g., > 0.5)
- The metric is computable in real time

**Testable assertion:** Amplification factor equals the number of agents with saturation above a threshold at a given moment. The metric is computable in real time.

### REQ-OBS-005: Violation Monitoring
**Source:** PRD §16
**Priority:** must-have
**Status:** specified

**Properties:**
- Beyond static invariants (REQ-INV), the app maintains dynamic violation rules configurable per-project and per-agent
- Every violation is logged and reported to the parent agent and/or user — no violation is silently ignored
- Each rule has a configured response: pause agent, reap agent, or allow with warning
- Example violations: modifying files outside designated directories, exceeding token budgets, spawning more than N children, accessing network when disallowed, running commands on blocklist

**See also:** §2.2.6 (invariant immutability)

**Testable assertion:** Violation rules can be configured per-project and per-agent. A rule violation triggers logging and notification. The configured response (pause/reap/warn) is executed.

### REQ-OBS-006: Violation Rule Immutability
**Source:** PRD §16, Invariant REQ-INV-006
**Priority:** must-have
**Status:** specified

**Properties:**
- Agents cannot modify their own violation rules
- Only the user or system administrator can modify violation rules
- Attempting to modify one's own rules is itself a violation

**Testable assertion:** No agent tool or API allows modification of that agent's own violation rules. Attempts to modify rules are themselves violations.

### REQ-OBS-007: Logging Categories
**Source:** PRD §19.1, Reader §10
**Priority:** must-have
**Status:** specified

**Properties:**
- Structured logging via `os.log` with subsystem `com.tavern.spillway`
- Five categories: `agents` (lifecycle, state transitions), `chat` (message flow), `coordination` (spawn, dismiss, selection), `claude` (SDK calls), `window` (window management)
- Categories are filterable independently in Console.app

**Testable assertion:** Each category produces logs filterable by `category:<name>` in Console.app. All agent state transitions are logged at `.info` level. All errors are logged at `.error` level with full context.

### REQ-OBS-008: Log Levels
**Source:** PRD §19.1
**Priority:** must-have
**Status:** specified

**Properties:**
- Three log levels: `.debug` (verbose, stripped from release), `.info` (key events for understanding flow), `.error` (failures needing attention)
- Error logs always include: what operation failed, what parameters were used, what went wrong

**Testable assertion:** Debug logs are present in debug builds and absent in release builds. Info logs capture key events. Error logs include operation, parameters, and failure description.

### REQ-OBS-009: Diagnosability Principle
**Source:** PRD §19.1
**Priority:** must-have
**Status:** specified

**Properties:**
- Debug builds produce enough logs to diagnose issues without screenshots, videos, or human reproduction steps
- Logged: entry/exit for async operations, state transitions, errors with full context, key events (session creation, agent spawn/dismiss, message send/receive)

**Testable assertion:** Given a bug report describing a symptom, the logs from a debug build contain enough information to identify the root cause without additional reproduction.

### REQ-OBS-010: Meta Process
**Source:** PRD §9.2
**Priority:** deferred
**Status:** specified

**Properties:**
- A decision layer observes which workflows produce better results
- Recommendations for workflow changes are based on historical metric data

**Testable assertion:** Deferred. When implemented: the meta process recommends workflow changes based on historical metric data.

### REQ-OBS-011: Discovery Sharing
**Source:** PRD §9.3
**Priority:** should-have
**Status:** specified

**Properties:**
- Agent system prompts include discovery-sharing instructions (prompt-engineering-based, not deterministically enforceable)
- Agents can deliver discovery messages to parent agents or Jake
- Discovery sharing does not interrupt the agent's main task

**Testable assertion:** Agent system prompts include discovery-sharing instructions. Agents can deliver discovery messages to parent agents.

## 3. Properties Summary

### Metric Derivation Properties

| Metric | Formula | Range | Computable When |
|--------|---------|-------|----------------|
| Utilization | Token time / Wall clock time | [0.0, 1.0] | Any time after agent starts |
| Saturation | (Token time + Tool time) / Wall clock time | [0.0, 1.0] | Any time after agent starts |
| Amplification | count(agents where saturation > threshold) | [0, N] | Real-time |
| Human wait time | gap between attention-needed and user-response | [0, ∞) | Per-question |
| Context switch load | count(agents in waiting-for-input) | [0, N] | Real-time |

### Violation Properties

| Property | Holds When | Violated When |
|----------|-----------|---------------|
| No silent violations | Every violation logged + reported | Violation occurs without logging or notification |
| Rule immutability | Agent cannot modify own rules | Agent tool/API modifies own violation rules |
| Configurable response | Each rule has pause/reap/warn response | Violation detected but no response executed |
| Per-scope rules | Rules configurable per-project and per-agent | Only global rules, no per-agent customization |

## 4. Open Questions

- **Metric storage:** Where are metrics persisted? In the doc store? In memory only? How long are historical metrics retained?

- **Amplification thresholds:** What saturation level qualifies an agent as "saturated" for the amplification metric? Is it configurable?

- **Violation rule format:** What format do violation rules take? A DSL? JSON config? How are custom rules authored?

## 5. Coverage Gaps

- **Metric visualization:** The PRD mentions a "metrics dashboard" but it is deferred for v1. No specification for how metrics are displayed to the user.

- **Alerting:** No specification for automated alerts when metrics cross thresholds (e.g., human wait time too high, amplification dropping).

- **Audit trail:** No specification for an immutable audit trail of violation events for post-incident analysis.
