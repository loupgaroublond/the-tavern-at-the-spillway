# Spec Review — Questions 0001

Follow-ups from your responses to 0000.


## Q17 — Workflow Metrics: My Answer (Doc 012)

You asked me to give you an answer or drop it.

**Recommendation: Drop for now.** Here's why:

Workflow metrics (completion rates, bottleneck identification, template effectiveness) require workflows to actually be running. The entire workflow system (doc 012) is deferred. Speccing metrics for a system that doesn't exist yet is premature — when workflows ship, metrics will naturally emerge as a concern and we'll have real data to inform what's worth measuring.

The observability spec (doc 015) already covers agent-level metrics (utilization, saturation, wait time). Those metrics will apply to agents executing workflow steps without needing a separate "workflow metrics" concept.

Sound right, or do you see a reason to keep even a stub?

> Response:
>
>

Make it so.

---


## Q18 — Sandbox Integrity (Doc 011, follow-up to Q10)

You made two good points:

1. If "escaped" means reaching outside boundaries — the sandbox should simply make that impossible. No escape.
2. If it means exploiting a vulnerability — how would we know?

For (1), I'll strengthen the sandbox spec to state this as an invariant: the sandbox MUST make boundary violations impossible, not just detectable.

For (2), this is really about sandbox integrity verification. Options range from lightweight (audit logs of boundary-adjacent operations, canary files outside the sandbox) to heavy (syscall interception, checksum verification). Given that we're building on macOS sandbox primitives and containers, do you want:

- **A)** A requirement that sandbox integrity is verified (without specifying mechanism — leave that to implementation)
- **B)** Just trust the OS/container sandbox and don't add our own detection layer
- **C)** Pin it for when we actually implement sandbox isolation

> Response:
>
>
Let's pin it for if it ever becomes important.

---


## Q19 — New Doc Boundaries

Your answers call for several new spec modules. I want to confirm the scope of each so they don't overlap:

**Servitor Trees** (from Q4) — Tree structure, parent-child relationships, how operating modes work at different tree positions, failure boundaries/supervision strategies (Erlang-style: restart-one, restart-all, etc.), gang invalidation.

**Unified State/Mode** (from Q7) — Canonical state machine for all servitor states, the three orthogonal booleans (backgrounding, perseverance, user presence), state transitions, deprecates state/mode sections from docs 004, 006, 007.

**Chat Discussion vs Session** (from Q9) — The user-visible "chat discussion" that persists for a servitor's lifetime, underlying Claude sessions that may be created/replaced, contiguous experience rules, session resumption/recreation.

**Capability Delegation** (from Q5) — Async summon → promise ID, delegate command with handle, capability grants, enforcement by deterministic shell, what capabilities exist, delegation chains.

My concern: "servitor trees" and "unified state/mode" could overlap since tree position affects available states/modes. Should these be one doc or two? My instinct is two — trees are about structure and supervision, state/mode is about individual servitor behavior — but you may see it differently.

> Response:
>
>

This is all entirely correct. 
---


## Q20 — Capability Delegation PRD

You said capability delegation needs PRDs to suit. The current PRD (prd_2026-01-19.md v1.2) mentions capabilities in passing but doesn't define the delegation system.

Options:
- **A)** Add a new section to the existing PRD document
- **B)** Create a separate PRD document for capability delegation
- **C)** Write the spec first, then backfill the PRD once the spec shapes up

> Response:
>
>
first C, then we take a look at A

---


## Q21 — Doc 003 Req 006 / ADR-001 Cleanup

You said to drop closed plugin set entirely. ADR-001 currently lists "Closed Plugin Set" as one of the 7 selected architecture shapes. Should I:

- **A)** Remove it from ADR-001's selected shapes (changing the ADR)
- **B)** Add a note to ADR-001 that this shape was subsequently dropped
- **C)** Leave ADR-001 as historical record, just remove it from the spec and CLAUDE.md

ADRs are typically immutable records of decisions. Option B or C preserves that principle.

> Response:
>
>
what's the difference between B and C? we should have a straightforward clear process to talk about "dropped" sections or pieces, where we mark it as dropped, and then publish a spec reader that combines just the active sections across all the files, into one. we can leave the dropped sections in the spec files, since they may only grow

---


## Q22 — Expert Prompts Clarification (Doc 012)

You said "Expert prompts isn't a question. they're part of workflows. drop it."

Just to confirm: drop REQ-WRK-005 (Gang of Experts) as a standalone requirement, because specialized prompt templates are just a natural part of how workflows assign work to servitors? The concept doesn't disappear — it just doesn't need its own requirement?

> Response:
>
>
exactly

---


## Q23 — Spec Index Update

With all the new modules, the index (000-index.md) will need updating. Proposed new module list:

| # | Topic | Status |
|---|-------|--------|
| 018 | Servitor States & Modes (unified) | New, consolidates from 004/006/007 |
| 019 | Servitor Trees | New (structure, supervision, failure boundaries) |
| 020 | Capability Delegation | New |
| 021 | Chat Discussions & Sessions | New |
| 022 | Keyboard Shortcuts | New (stub) |
| 023 | Accessibility | New (stub) |
| 024 | Search | New (stub) |

Does this ordering make sense, or would you rearrange? Also, 017 is currently "V1 Scope" and 018 is "Spec Fidelity" — so the new modules would actually start at §019. Want me to just use the next available numbers?

> Response:
>
>
the numbering is correct, because it just represents what order we added that module