# Transcript: Performance Requirements & Perception-Bounded Design

**Date:** 2026-01-21 21:13
**Session:** Performance principles, stress testing, perception-bounded responsiveness


## Context

Continuing from previous design work on multi-agent coordination. Current architecture has basic commitments and verification. Now focusing on defining performance expectations — what does "fast enough" mean for an app with potentially thousands of messages and hundreds of agents?


## The Challenge

**[U]** (via content extraction) Performance requirement presented as a tension: how to keep everything responsive when the app is coordinating many agents, loading large histories, and running heavy operations like search and compaction?


## First Draft: Key Questions

**[C]** Reflected back the tension: The **Instrumentation Principle** requires heavy logging in debug builds. But logging impacts performance. Do we carve out an exception ("debug builds are slower"), or design instrumentation that doesn't tax performance (async logging, sampling)?

Then laid out follow-up questions:

1. **RAM budget** — Is there a target (e.g., "stay under 500MB"), or is it behavioral ("don't cause system slowdown")?

2. **Finding limits** — Synthetic stress tests (e.g., 100,000 messages, 500 agents), or empirical ("use until it feels bad"), or both?

3. **Cancellation** — If a search is abandoned or an agent hangs, should it cancel immediately or finish in background?

Then identified technical implications:

- UI virtualization — render only visible content
- Background threading — heavy work off main thread
- Progressive/lazy loading — show shell immediately, fill in as available
- Operation isolation — separate task queues so one runaway can't starve others
- Backpressure — buffer and batch output, don't flood the UI

Also flagged an inconsistency: the architecture doc says several components are `@MainActor` (ChatViewModel, TavernCoordinator). This is correct for UI safety, but we need to be explicit that `@MainActor` is for UI updates ONLY, not computation.


## Core Principle Emerges: Perception-Bounded Performance

**[C]** Synthesized the discussion into a core principle:

> The goal isn't "everything is instant" — it's "nothing feels slow where it shouldn't feel slow, and nothing blocks something else."

**Key concepts:**

1. **Isolation** — Heavy operations (search, loading history) can't impact unrelated parts. User should be able to open another pane while a search runs.

2. **Responsiveness over speed** — A search can take time, but the window pops up fast, spinner spins smoothly. Network calls take however long; UI never freezes.

3. **Perception boundaries** — Zones where latency is natural and expected:
   - Debug mode (expected slower due to instrumentation)
   - Search results (can spin)
   - Cold start (can show skeleton/progressive load)
   - Network operations (waiting state is natural)

4. **No degradation of unrelated work** — Zillions of messages don't slow down viewing the current few on screen. A runaway agent doesn't freeze the coordinator.


## Refining the Definition

**[C]** Explored what "perception boundaries" really means:

A perception boundary is a place where the user's mental model already includes waiting — they'd be surprised if it were INSTANT. Examples:

- Thorough search across massive history
- Scrolling back through long discussion
- Initial load of very old session

Conversely: anywhere the user doesn't expect delay, there must be none. Typing, clicking buttons, switching tabs, viewing current content — must feel instant regardless of background state.


## Drafting the Requirement

**[C]** Created formal requirement language:

```
### Principle: Perception-Bounded Performance

The app must remain responsive under all conditions. "Fast" is defined by 
user perception, not raw metrics. Heavy operations may take time, but they 
must never degrade unrelated work.

### Core Rules

1. Isolation — No operation may impact unrelated parts of the app.
2. Responsiveness over speed — UI responds to user input, shows feedback.
3. Perception boundaries — Zones where latency is acceptable (debug mode, 
   search, cold start, network, agent work). Discovered during development.
4. Scale independence — Performance of viewing current content doesn't 
   degrade as history grows. Thousands of messages, hundreds of agents — 
   visible slice stays fast.

### Cancellation
Context-dependent. Design each case explicitly.

### RAM Budget
No fixed target. If the app causes system slowdown or memory warnings, 
that's a bug. Design data structures to avoid unbounded memory holding.
```

Also drafted a **Testing Requirement (Stress Testing)** section:

```
Stress testing is mandatory. Tests must:
- Generate synthetic load (large histories, many agents, deep compaction)
- Measure responsiveness under load
- Verify isolation (heavy work doesn't impact UI metrics)
- Establish baselines and catch regressions

Specific thresholds TBD after initial testing identifies natural limits.
```


## Integration with PRD

**[C]** Proposed:
1. Add performance as a new section in the PRD
2. Add stress testing to the testability section

**[U]** Approved.

**[C]** Added to PRD and committed: `5eeb13f`


---

## [S] Synthesis: Perception-Bounded Performance


### Core Principle

"Fast" is not measured in milliseconds but in user perception. The app must remain responsive under all conditions. Heavy operations may take time, but they must never degrade unrelated work.


### Key Rules

**Isolation** — No operation impacts unrelated parts. Search doesn't cause scroll jank. Runaway agent doesn't freeze coordinator. Loading one session doesn't block viewing another.

**Responsiveness over speed** — UI always responds. If an operation takes time, show appropriate feedback (spinner, progress, skeleton). Window appears immediately; content fills as available.

**Perception boundaries** — Zones where latency is natural and expected. User's mental model includes waiting:
- Debug mode (instrumentation overhead expected)
- Thorough search (might take a moment)
- Scrolling deep history (will take time)
- Cold start (might load progressively)
- Network operations (depends on API)
- Agent work (depends on Claude)

Conversely: anywhere the user doesn't expect delay, there must be none. Typing, clicking, switching tabs, viewing current content must feel instant.

**Scale independence** — Performance doesn't degrade as data grows. Thousands of messages, hundreds of agents, multiple compactions — the visible slice stays fast.


### Technical Implications

1. **UI virtualization** — Only render visible content
2. **Background threading** — Heavy work off main thread, always
3. **Progressive/lazy loading** — Show shell immediately, fill in as available
4. **Operation isolation** — Separate task queues prevent starvation
5. **Backpressure** — Buffer and batch output, don't flood UI
6. **@MainActor discipline** — Used for UI updates only, not computation


### Stress Testing (Mandatory)

Performance testing is part of the mandatory suite:
- Synthetic load: large histories, many agents, compaction chains
- Measure responsiveness under load
- Verify isolation
- Establish baselines, catch regressions
- Thresholds TBD after initial testing


### Open Questions

1. How to instrument debug builds thoroughly without impacting performance?
2. What cancellation semantics for different operations?
3. What counts as "system slowdown" for the RAM budget?

---

*This principle guides all performance-related architecture decisions going forward. It's not about being the fastest; it's about never feeling slow where it shouldn't.*

