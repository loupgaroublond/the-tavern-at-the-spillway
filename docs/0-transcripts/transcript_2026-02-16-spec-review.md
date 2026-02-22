# Transcript: Spec Notes Review

**Date:** 2026-02-16
**Session:** `c858dcfd`
**Topic:** Batched Q&A on all 16 spec modules — clarifications, drops, new modules
**Archives:** `archive/0000-spec-review-q1.md` (Q1–Q16), `archive/0001-spec-review-q2.md` (Q17–Q23)

---

## Session Structure

[C] Organized `docs/2-spec/spec-notes.md` into three buckets: (1) can execute without questions, (2) new content to create, (3) needs user input. Batched questions across two rounds.

---

## Terminology Decisions

[U] "Agent" → "servitor" throughout. "Spawn" → "summon." "Outputs" → "connectors" (doc 011). View "modes" → "representations" — UI says "view as ..." and the R-word only appears in code.

---

## Architecture Drops

[U] Dropped entirely:
- Closed plugin set (from spec AND ADR-001 shapes)
- Three storage layers (doc 010 req 004)
- Jake's tool handler protocol — Jake works like every other servitor
- Continuation loop (doc 008 req 007) — just describes how Claude works
- Expert prompts / Gang of Experts (doc 012 req 005) as standalone req — just part of how workflows assign work
- Workflow metrics as premature

[U] Combine references minimized — only mention where strictly necessary.

___

[S] *The drop pattern: anything that describes Claude's internal behavior rather than Tavern's behavior gets dropped. The spec should describe what the Tavern orchestrates, not how Claude thinks.*

---

## Claude Teams / Two-Level Orchestration

[U] Rewrite to be agnostic of Claude's internal implementation. Tavern has its trees of servitors; each servitor may be running a Claude session with multiple agents/subagents internally. This is why the agent/servitor rename matters — differentiate Tavern's orchestration from Claude's.

---

## Failure Boundaries

[U] New concept belonging in a "Servitor Trees" spec doc. Property over parts of the tree determining failure rules. Erlang-style supervision: sometimes invalidate a whole gang on one failure, sometimes just restart the failed worker. Parent can declare child failed (kill it) or declare itself failed; system reverts as much as possible.

---

## Capability Delegation

[U] Gets its own new spec document. Summon is async (returns promise ID), then separate `delegate` command using handle. Spawned servitor's main actor receives capability handle, waits for session notification. Spec first, then backfill PRD.

---

## Naming Tiers

[U] Name set = themed collection assigned to a top-level servitor. All children take names from that set. Top servitor asks Jake for another name set if exhausted. Multiple trees may share a name set — concurrency management needed. Tier 1 = collection of initial name sets; Jake rotates through; higher tiers unlock on depletion or user action.

---

## Unified State/Mode Doc (new §019)

[U] Three orthogonal booleans: backgrounding (no chat window), perseverance (no idle), user presence (joined/left). These combine freely in any permutation. All lifecycle graphs from docs 004, 006, 007 consolidated into one canonical state machine. Separate doc from Servitor Trees (trees = structure/supervision, state/mode = individual behavior).

---

## Chat Discussion vs Session (new §022)

[U] Chat discussion persists for servitor's lifetime (user-visible, contiguous). Claude sessions underneath may be continued or replaced. When no resumable session exists, app creates new one to pick up. Gets its own new spec document.

---

## Done vs Complete

[U] Done = servitor says "done" (request to check commitment). Complete = verified commitment is met. Verification may include non-deterministic agent eval if surfaced properly. Not Complete until verified separately.

---

## Deterministic Shell

[U] Everything managed by the app vs a servitor. Deterministic state machines dictating servitor behavior and session display. Deterministic rules setting up new servitors. Invariants in prompts enforced even when parent composes child's prompt. All blocks shown to user are passthrough, not reinterpreted — user must trust what they see is accurate, not hallucinated.

---

## Distribution

[U] Source code only. Full stop. No builds, no binaries distributed.

---

## Testing Clarifications

[U] 100% code coverage + no warnings required. Grade 2.9 = local LLM (probably llama-ish + Apple Intelligence) for cheaper/faster grade-3-like testing during development. Grade 3 before merging, not in dev iteration cycle. Mutation testing = deliberately inject bugs to verify test coverage. Regression = requirement that all tests must continue to pass (policy/property).

---

## Sandbox / "Escaped"

[U] If "escaped" means reaching outside boundaries, sandbox should make it impossible — no escape. If it means exploiting a vulnerability, detection is pinned for if it ever becomes important.

---

## New Spec Modules

Seven new modules decided:

| Module | Topic |
|--------|-------|
| §019 | States & Modes (unified) |
| §020 | Servitor Trees (structure, supervision, failure boundaries) |
| §021 | Capability Delegation |
| §022 | Chat Discussions & Sessions |
| §023 | Keyboard Shortcuts |
| §024 | Accessibility |
| §025 | Search |

---

## Conventions

[U] Dropped sections get `<!-- DROPPED -->` markers in spec files — content stays for history. A `/spec-reader` slash command compiles only active sections into `docs/2-spec/compiled/`.

[U] Pinned items tracked as beads with label `spec-pin`, referenced from spec index.
