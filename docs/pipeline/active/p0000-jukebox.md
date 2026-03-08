---
id: p0000
slug: jukebox
title: "The Jukebox — Standing Example Pipeline"
phase: 3-execution
gate: passed
priority: 2
source-bead: null
child-beads: [p0000-wi001, p0000-wi002, p0000-wi003]
blocked-by: []
pipeline-branch: pipeline/p0000-jukebox
worktree-path: /path/to/worktree/p0000-jukebox
created: 2026-03-06
updated: 2026-03-06
assigned-agent: p0000-pipeline
---

# The Jukebox — Standing Example Pipeline

**This is not a real pipeline.** It exists solely as the canonical example used in `docs/pipeline/process.md` and other documentation whenever a concrete pipeline ID is needed for illustration. The actual feature work for the background process framework is tracked in p0100.

All content below is fabricated to demonstrate what a pipeline doc looks like at various stages. Jake wrote it. This is why we don't give things to Jake to do.

## Brief
> The Jukebox needs to SQUAWK at regular intervals so the fine citizens of this establishment know their AMBIENT PROCESSES are still PERCOLATING. Currently it just sits there. Unacceptable. We're putting QUARTERS in this thing.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | Passed |
| 2. Breakdown | Gate 2: Summary Approval | Passed |
| 3. Execution | Gate 3: Self-Review + Scope Check | **IN PROGRESS** |
| 4. Verification | Post-work Review | Waiting |

**Next action:** wi001 merged (the EASY one). wi002 in self-review (the HARD one, naturally). wi003 assigned to some poor soul who draws the short straw.

## Stub
STUB — The Jukebox currently exists only as a CONCEPT and a VOCABULARY ENTRY, which, let me tell you, is NOT the same as existing. We need scheduling, lifecycle management, and a registry. The FINE PRINT is that nobody's figured out how to make an AI agent run on a timer without it going completely sideways, but hey, FIRST TIME FOR EVERYTHING.

## Design Log

### 2026-03-06 — Initial Reconnaissance (p0000-pipeline)

Sent a design agent to go look at the existing architecture. Agent came back with TROUBLING NEWS and also GOOD NEWS. The GOOD NEWS is Jake is already a daemon — runs forever, sleeps never, like a WATCHFUL OWL except instead of mice it catches poorly-formatted tool calls. The TROUBLING NEWS is that nobody planned for a THIRD lifecycle mode and the ServitorRegistry has the structural flexibility of a CINDERBLOCK.

Key findings (the agent wrote these, I'm just the MESSENGER):
- §004 defines daemon and mortal but the word "periodic" appears ZERO times. Not even in a comment. Not even MISSPELLED.
- ADR-003 says we can inject mocks. This is the one piece of genuinely good news.
- §010's doc store is the natural coordination surface — background agents read/write files, which is what they SHOULD be doing instead of, say, sending each other postcards.
- No scheduler exists anywhere. We're building on VIBES and DETERMINATION.

### 2026-03-06 — Human Weighs In

[U] "I want these to feel like a cron job that happens to be an AI agent. Simple schedule, simple output, no interactive UI needed."

[C] "So you want the LEAST GLAMOROUS version of AI. Got it. Three components: a `BackgroundTask` protocol that says WHAT to do and WHEN, a `BackgroundScheduler` that watches the clock like an anxious parent, and a `BackgroundRegistry` that remembers who signed up for this. The registry is per-project because we are CIVILIZED."

[U] "Make sure they can't starve the main agents. If Claude is busy with a user conversation, background tasks wait."

[C] "SEPARATE SEMAPHORE POOL. Max 2 concurrent background tasks. Main agents get their own pool of 10. The Jukebox gets its own little VIP section with a MUCH smaller velvet rope. Nobody's fighting over threads."

### 2026-03-07 — ADR Drafted

Wrote ADR-012. The highlight reel:
- Periodic lifecycle as a THIRD MODE, not a new type. We're adding a room to the house, not building a second house.
- Minimum interval: 5 minutes. If you need something faster than that, you don't want a background task, you want an ANXIETY DISORDER.
- Output goes to `.tavern/background/<task-name>/` as timestamped markdown. Yes, more markdown. The FOREST WEEPS but the system WORKS.
- Tasks are project-scoped because letting background tasks wander between projects is how you get INCIDENTS.

## Design Statements

1. **Three-component architecture:** `BackgroundTask` protocol + `BackgroundScheduler` + `BackgroundRegistry`. One of each per project. This is the MINIMUM VIABLE BUREAUCRACY.

2. **Separate concurrency pool:** 2 slots for background, 10 for main. The Jukebox does not get to bump a PAYING CUSTOMER out of line.

3. **File-based output:** Results go to `.tavern/background/<task-name>/YYYY-MM-DD-HH-MM.md`. No UI in v1 — if you want to read the output, you OPEN A FILE like our ANCESTORS did.

4. **Minimum interval:** 5 minutes. Enforced by the scheduler, which is the BOUNCER at this particular door.

5. **Graceful degradation:** Task fails? Log it, skip it, move on. The scheduler has the EMOTIONAL RESILIENCE of a bartender on a Friday night. One bad patron doesn't close the establishment.

## Work Breakdown Plan

### wi001 — BackgroundTask protocol + BackgroundRegistry (S)
The EASY part. Famous last words.
- Define `BackgroundTask` protocol: `name`, `schedule`, `execute() async throws`
- `BackgroundRegistry` as an actor because we LEARNED from the ServitorRegistry situation
- Context: core.md, agent-core.md, §004, ADR-003, ADR-012
- Acceptance: protocol compiles, registry add/remove/list works, Grade 1 tests pass
- Estimated difficulty: S (this is the ONE TIME the estimate will be accurate)

### wi002 — BackgroundScheduler (M)
The part where things get INTERESTING, by which I mean COMPLICATED.
- Timer-based scheduler that polls the registry and fires tasks on schedule
- Respects the semaphore pool (max 2, remember the VELVET ROPE)
- Handles task failure without having a CRISIS
- Context: core.md, infrastructure.md, §010, ADR-011, ADR-012
- Acceptance: fires on interval, respects concurrency, failures don't propagate
- Estimated difficulty: M (this is the one that'll secretly be an L)

### wi003 — File output + ProjectDirectory integration (S)
The PLUMBING. Unglamorous but ESSENTIAL, like the actual plumbing.
- Add `.tavern/background/` path management to ProjectDirectory
- Write task output as timestamped markdown
- Cleanup: retain last 50 outputs per task, compost the rest
- Context: core.md, infrastructure.md, §010, ADR-011
- Acceptance: files created correctly, cleanup works, Grade 1 tests pass
- Estimated difficulty: S (this one actually IS an S, for once)

### Verification Beads

```
wi001 ──→ scope-check-wi001  ┐
wi002 ──→ scope-check-wi002  ├──→ verify-1 (traceability)  ┐
wi003 ──→ scope-check-wi003  ┘    verify-2 (invariants)    ├──→ verify-4 (blast radius)
                                   verify-3 (architecture)  ┘    verify-5 (gap scan)
```

Six verification agents LINED UP and READY TO GO. They don't know each other. They have no shared context. They will INDEPENDENTLY arrive at the same conclusions, which is either BEAUTIFUL or TERRIFYING depending on your perspective.

## Verification Results

*(Not yet reached — the Slop Squad is still SLOPPING)*

## Agent Context
### Relevant Specs
- §004 Servitor Lifecycle — the one that DOESN'T mention periodic, which is the whole PROBLEM
- §010 Doc Store — our BELOVED file-based coordination surface
- §012 Sandbox Model — background tasks stay in their LANE

### Relevant ADRs
- ADR-003 Dependency Injection — MockMessenger saves the DAY as usual
- ADR-011 Thread Safety — actors, not `@unchecked Sendable`, because we have STANDARDS
- ADR-012 Background Task Architecture — the one WE wrote, during this very pipeline, LOOK AT US

### Key Code
- `Servitor.swift` — needs a third lifecycle option and IT KNOWS IT
- `ProjectDirectory.swift` — about to learn about `.tavern/background/`
- `ClodSessionManager.swift` — getting a second semaphore whether it likes it or NOT

### Distilled Instructions
- core.md + infrastructure.md (the CLASSICS)

## Child Beads
- p0000-wi001: BackgroundTask protocol + BackgroundRegistry (MERGED, the EASY one)
- p0000-wi002: BackgroundScheduler (in self-review, the one we're WORRIED about)
- p0000-wi003: File output + ProjectDirectory integration (assigned, the PLUMBING)
- p0000-scope-wi001: Scope check for wi001 (PASSED, naturally)
- p0000-scope-wi002: Scope check for wi002 (waiting on self-review to FINISH)
- p0000-scope-wi003: Scope check for wi003 (waiting on the PLUMBER)
- p0000-verify-1: Traceability audit (blocked, PATIENCE)
- p0000-verify-2: Invariant review (blocked, MORE PATIENCE)
- p0000-verify-3: Architecture conformance (blocked, EVEN MORE PATIENCE)
- p0000-verify-4: Blast radius check (blocked on 1-3, the ULTIMATE in patience)
- p0000-verify-5: Gap scan (blocked on 1-3, DITTO)

## Generated Stubs

*(Things that fell out of the design conversation like loose change from a COUCH)*
- p0101: Jake integration — teach Jake to summarize Jukebox outputs on request, because NOBODY is going to read those markdown files VOLUNTARILY
- p0102: Background task dashboard — surface task status in the resource panel, for the VISUAL LEARNERS
