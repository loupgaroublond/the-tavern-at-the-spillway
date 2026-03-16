# Pipeline Agent Model Refinements

**Date:** 2026-03-07
**Session:** 15062a9f (continuation, post-commit)
**Scope:** Refinements to the pipeline system agent model after the initial commit. Worktree enforcement, Jukebox reframing, manual worktree pattern for team agents, Gate 2 completeness requirements, orchestrator role boundaries, and pre-Gate-2 agent verification.
**Follows:** `transcript_2026-03-06-development-pipeline-system.md`

---

## Worktree Enforcement for Pipeline Agents

*[T] After the commit that captured the main pipeline design, the user ran the orchestrator and discovered agents were not being placed in worktrees.*

[U] the instructions really need to emphasize that every pipeline agent *must* have its own worktree. i just fired up an orchestrator and it totally disregarded that

*[T] This led to stronger language in both orchestrate.md and process.md — every pipeline agent MUST have its own worktree, and a pipeline agent without a worktree is a bug.*

---

## Jukebox as Standing Example Only

[U] can we also emphasize that the jukebox is now not an explicit feature, but just the thing we use as an example when talking about something?

*[T] p0000 (The Jukebox) was reframed from a real feature pipeline to the canonical example used in documentation whenever a concrete pipeline ID is needed for illustration. It exists only as the standing example in process.md, not as actual work to be implemented.*

[C] Updated p0000 with confabulated content to serve as the example pipeline.

[U] make it more nonsensical, like jake wrote it

*[T] The example content was rewritten in Jake's voice — used car salesman energy, CAPITALS for EMPHASIS, sketchy-but-warm overselling — to make it clearly an example rather than real work.*

---

## Manual Worktree Pattern for Team Agents

*[T] A platform limitation was discovered: `isolation: "worktree"` on the Agent tool does not work for team agents spawned via `team_name`. Team agents always run in the main repo directory regardless of the isolation parameter.*

[U] turns out worktrees don't get created with team agents. we need to modify instructions to create worktrees manually and then point team agents at that worktree

[C] Established the manual worktree pattern:
1. `git worktree add .claude/worktrees/<agent-name> -b pipeline/<branch-name>`
2. Include the worktree path in the agent's prompt
3. Agent must `cd` to the worktree path as its first action
4. Clean up with `git worktree remove` + `git branch -D` when done

*[T] This is a fundamental operational constraint — the orchestrator must create worktrees before spawning pipeline agents, not after. Worktree FIRST, agent SECOND.*

---

## Gate 2 Plan Completeness

[U] can you clarify pipeline agents need to commit their work going through gate 2? until then, everything they're doing is in a draft form

[U] update all the docs around gate 2, and emphasize that the plan must be complete, except for the common sections that will get put into beads via `cat`. the human might only review the summary of the structure, but the plan must be beads ready to pass through gate 2

*[T] Key distinction established: Gate 2 is not an outline review. The breakdown plan must be fully complete — every work item with full scope, acceptance criteria, context-source specifications, and verification bead definitions. The human reviews only the summary (titles, scopes, ordering, complexity estimates) and spot-checks the rest. The plan is the finished blueprint that beads will be created from mechanically.*

**All work through Gate 2 is draft.** The pipeline agent's breakdown plan is uncommitted work-in-progress until the human approves. On approval, the pipeline agent commits the updated pipeline doc, THEN creates all beads mechanically from the plan.

---

## Orchestrator Role Boundaries

[U] emphasize to the orchestrator that it is to only manage other agents. if there's anything that doesn't fit an existing agent, don't just 'giterdone', but fire up a team member to handle that

[U] also include run builds and tests

*[T] The orchestrator's "does NOT" list was expanded: it must not do any direct work, run builds, or run tests. If something needs doing that no existing agent covers, the orchestrator spawns a new agent for it rather than handling it directly. This prevents the orchestrator from accumulating stale context or becoming a bottleneck.*

---

## Pre-Gate-2 Agent Verification

[U] we need to clarify that in order to do the gate 2 check, first, the orchestrator must use a subagent to check if the beads breakdown is complete, and provides sufficient information that any agent with no other context provided could do the work from just what's in the bead. the descriptions may call out that they will use `cat` to pipe in common instructions, instead of providing that text. the pipeline as provided must pass this agent driven part of the gate before presenting it to the human, who will look at the overview of the breakdown section and possibly spot check the rest

*[T] This established a two-phase Gate 2: first an automated completeness check (orchestrator's subagent verifies each bead is self-contained and actionable), then human review (summary-level review with spot-checking). The automated check prevents half-baked plans from wasting the human's time.*

---

## Artifacts Modified

| File | Action |
|------|--------|
| `.claude/commands/orchestrate.md` | Updated: worktree enforcement, orchestrator role boundaries, builds/tests exclusion |
| `docs/pipeline/process.md` | Updated: Gate 2 completeness requirements, pre-Gate-2 verification, draft-until-approval |
| `docs/pipeline/active/p0000-*.md` | Rewritten: confabulated Jake-voice example content |
| `MEMORY.md` (auto-memory) | Updated: Jukebox as example-only, manual worktree pattern, team agent limitation |

---

___

[S] These refinements complete the pipeline agent model. The core design (from the previous transcript) established the two-tier model and 4-phase lifecycle. This session hardened it with operational constraints discovered through actual usage: worktree enforcement, the team agent worktree limitation, Gate 2 completeness as a non-negotiable, and the orchestrator as pure coordinator. The pattern is consistent with the project's broader philosophy: discover constraints through practice, then codify them immediately so the next agent session benefits.
