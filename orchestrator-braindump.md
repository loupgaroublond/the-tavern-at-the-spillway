# Orchestrator Brain Dump: Process Tweaks & Lessons Learned

This document captures every tweak, correction, and lesson from the 2026-03-10 orchestration session running the `tavern-pipeline` team (~63 agents). Written for the next orchestrator agent who will revise the pipeline process prompts.

---

## 1. G2 Verification Was Too Structural, Not Semantic

### Problem
The first round of G2 verifiers gave 25/25 PASS. Every single one. The human immediately spotted that p0016 ("New project shows assistants from previously opened project" — a bug fix) had a breakdown that contained zero bug-fixing beads. It only added regression tests and claimed "the architecture is already correct." The verifier passed it because all the structural checklist items were present.

### Root Cause
The original checklist (Sections A-D) only verified *format*: are file paths present, are acceptance criteria listed, is there a dependency graph. It never asked "does this breakdown actually solve the stated problem?"

### Fix Applied
**Section A was completely rewritten** from a format check to a semantic summary requirement:

- **A-1: Problem statement** — What's broken/missing today? The "why" before the "what."
- **A-2: Per-bead deliverable table** — Each bead with title, concrete output, and complexity (S/M/L).
- **A-3: Bead flow narrative** — Plain-English walkthrough of execution order. "First we do X, which enables Y." Not just a dependency graph — the *story*.
- **A-4: End-to-end scope check** — Does the breakdown cover ALL work from current state to "done"? If the title says it's a bug fix, a bead fixes the bug. No "the architecture is already correct" hand-waving.
- **A-5: Test coverage plan** — Grades, what's tested, debug/release gating.
- **A-6: Brief AND thorough** — An *engineering manager* could read this and understand what, why, and in what order. (Not "non-engineer stakeholder" — we don't put non-technical people in tech management.)

### Key Insight
A-4 is the critical addition. It forces the verifier to check whether the beads *actually solve the problem stated in the pipeline title and brief*. Without A-4, a perfectly formatted wrong answer passes.


## 2. Section A Must Be First in the Breakdown

### Problem
The Phase 1 design content (design log, design statements, research) and the Phase 2 breakdown were blurring together. Reviewers had to hunt for the summary.

### Fix Applied
Instruction #4 in the verifier prompt now states: "The breakdown MUST begin with a Section A summary — this is separate from and comes AFTER the Phase 1 design content. It is the first section of the Phase 2 breakdown, written for human review."

This means the pipeline doc structure is:
1. Frontmatter + Brief + Status (always)
2. Design Log + Design Statements (Phase 1)
3. **Section A summary** (first thing in Phase 2 — the human reads this)
4. Detailed bead breakdown (Phase 2 detail)
5. Verification beads (Phase 2)
6. Agent Context (always)


## 3. Verifier Must Staple the Report to the Doc

### Problem
First round verifiers sent their full checklist via SendMessage only. The results were ephemeral — lost when the verifier shut down. Nobody could see the verification report later.

### Fix Applied
Instruction #5: "Append your completed checklist (with ✅/❌ marks and notes) as a new section at the end of the pipeline doc titled '## G2 Verification Report'. This must be verbatim in the file for everyone to see."

The message to team-lead is now just a brief summary (PASS/FAIL + 3-5 sentences). The full evidence lives in the pipeline doc permanently.


## 4. Verifiers Must Stay Alive After Reporting

### Problem
The orchestrator was eagerly shutting down verifiers after they reported. The human corrected this — verifiers need to stay alive because:
- The human may reject a PASS after their own review
- The pipeline agent may fix issues and resubmit
- Re-review requires the verifier to still be running (or a fresh one spawned)

### Fix Applied
Final instruction: "When you're done, wait. You may be asked to re-review the submission after changes — even after you passed it. You will be told to shut down once the pipeline can proceed to Gate 3 after human review."

### Nuance
The user's original instruction was "one verifier per verification, clean context every time." This means:
- A verifier stays alive for the duration of ONE pipeline's G2 review cycle (including re-reviews)
- If the verifier dies or context gets stale, spawn a FRESH one — never try to resume
- The orchestrator tells the verifier to shut down only after the human approves Gate 2


## 5. Batch Q&A System

### How It Works
- Markdown files at `.claude/batch-questions-NNN.md`
- Questions are written by the orchestrator, answers filled in by the human
- Uses `ANSWER_START` / `ANSWER_END` markers for machine-parseable answers
- Sections: G1 reviews, G2 reviews, Special Dispositions

### Lessons
- **Batch 6 was superseded** — it contained only G2 submissions but the verification process wasn't ready. Marked as SUPERSEDED, content preserved for reference, everything folded into batch 7.
- G1 and G2 reviews can coexist in the same batch file (different sections)
- Special Dispositions section handles cross-cutting decisions (absorptions, cancellations, on-ice status)


## 6. Pipeline Agent Lifecycle

### Fresh Context Every Time
Pipeline agents get fresh context windows on every spawn. They have NO memory of previous sessions. All durable state lives in:
- The worktree branch (`pipeline/pNNNN-slug`)
- The pipeline doc in the worktree

### Manual Worktree Pattern
`isolation: "worktree"` does NOT work for team agents. Manual pattern:
1. `git worktree add .claude/worktrees/<agent-name> -b pipeline/<branch-name>`
2. Include worktree path in the agent's prompt
3. Agent `cd`s to worktree as first action
4. Clean up with `git worktree remove` + `git branch -D` when done


## 7. Pipeline Phase Transitions

### Archiving/Cancellation
When a pipeline is absorbed, cancelled, or merged:
- Update BOTH the main branch copy AND the worktree copy of the pipeline doc
- Set `phase: merged` (or `cancelled`, `archived`) and `gate: n/a`
- Forgetting the worktree copy causes the dashboard to show stale data

### On-Ice Pipelines
- Set `phase: on-ice` (or similar inactive marker)
- Remove `assigned-agent` (set to null)
- Keep the worktree — it preserves work-in-progress


## 8. Dashboard

### Current Sections
Gate 1, Gate 2, Gate 3, Gate 4, In Progress, Completed, Blocked, Inactive

### Script
`scripts/pipeline/dashboard.sh` — parses YAML frontmatter from pipeline docs, outputs JSON and markdown.

### Worktree Awareness
The dashboard script checks worktree copies when they exist, falling back to main branch copies. This is why updating both copies matters.


## 9. G1 Feedback Relay

### Batch 5 Results
- **Approved** (proceed to breakdown): p0095, p0096, p0053, p0057, p0060, p0081
- **Approved with changes**: p0102 (drop FOCB, add PRD step)
- **Rejected for rework**: p0024 (assignments vs commitments), p0103 (budget as capability), p0104 (multiple issues)
- **Cancelled**: p0061 (sandbox protocol ADR — "cart leading the horse")
- **Archived/absorbed**: p0063 (absorbed by p0103)
- **On ice**: p0072, p0100

### Key Correction: p0103 (Budget)
User rejected p0103's design because it treated budget as a standalone system. The correct model: "budget is literally just one more capability" — it should be handled through the capability delegation system, not as its own thing. The servitor hard-stops when budget is exceeded (no graceful warnings needed at the Tavern layer — the CLI handles that).


## 10. Team Size and Agent Naming

### Naming Convention
- Pipeline agents: `p0016-pipeline`, `p0055-pipeline`, etc.
- G2 verifiers: `g2v-p0016`, `g2v-p0055`, etc.
- Wave 2 agents: same `pNNNN-pipeline` pattern

### Team Config
Persists at `~/.claude/teams/tavern-pipeline/config.json`. Currently has 64+ members. Agent processes die on session restart but the config file persists.


## 11. Orchestrator Anti-Patterns

### Don't Shut Down Agents Eagerly
The orchestrator shut down 18 verifiers before the human had a chance to review results. This was wrong — verifiers should stay alive until the human explicitly says the pipeline can proceed.

### Don't Assume PASS Means Done
25/25 PASS with a flawed checklist means the checklist is wrong, not that the submissions are good. The orchestrator should have been more skeptical of a perfect score.

### Don't Over-Batch
Sending 25 verifiers simultaneously with an untested prompt means if the prompt is wrong, you waste 25 agent-runs. Consider testing with 1-2 first, getting human sign-off on the results, then scaling up.


## 12. Section A Must Be a Dedicated, Self-Contained Section

### Problem
After the v2 checklist was deployed, 12 of 25 pipelines PASS'd on the first verifier run. But those 12 were written *before* the Section A requirement existed. They didn't have a formal Section A section — the verifiers PASS'd them by finding content scattered throughout the doc (design log, design statements, bead descriptions) that *satisfied* each A-1 through A-6 checklist item.

The human caught this: "do those 12 have section A in G2?" They didn't. The verifiers rubber-stamped scattered content as satisfying a requirement that was supposed to produce a *dedicated, readable summary*.

### Root Cause
The checklist said "Section A must contain X, Y, Z" but didn't say "Section A must be a clearly labeled, self-contained section." The verifiers interpreted it as "can I find content anywhere in the doc that satisfies A-1 through A-6?" instead of "is there a single labeled block I can read top-to-bottom?"

### Fix Applied (v3)
Added explicit instruction to the verifier prompt:

> **CRITICAL: Section A must be a DEDICATED, CLEARLY LABELED section** (e.g., `### Section A: Summary` or `### Breakdown Summary`) located at the top of the Phase 2 breakdown. It must be **self-contained** — a reader must be able to read Section A in its entirety and understand what the pipeline delivers, in what order, and why, **without scanning the rest of the document**. The verifier must FAIL any submission where Section A criteria are satisfied only by content scattered throughout other sections.

### Key Insight
The whole point of Section A is that the human can read ONE section and understand the pipeline. If they have to scan the whole doc to piece together the summary, Section A has failed its purpose regardless of whether checklist items are technically satisfied.

### Consequence
All 25 verifiers torn down, all 25 G2 submissions marked not-passing, fresh verifiers spawned with v3 prompt, full re-evaluation cycle.


## 13. Orchestration Cycle: Batch Feedback Loop

### How It Works

The orchestrator manages a continuous cycle between pipeline agents, verifiers, and the human:

```
Pipeline agents work → Verifiers review → Orchestrator collects results
    → Orchestrator batches results for human → Human answers batch
    → Orchestrator relays feedback to agents → Cycle repeats
```

### Batch Q&A Files
- Located at `.claude/batch-questions-NNN.md`
- Multiple sections: G1 reviews, G2 reviews, Special Dispositions
- Machine-parseable `ANSWER_START` / `ANSWER_END` markers
- Orchestrator writes questions, human fills in answers

### The Orchestrator's Role
1. **Collect** — Monitor all agent messages (pipeline agents reporting work done, verifiers reporting PASS/FAIL)
2. **Mediate** — Route feedback between agents (tell verifier to re-review, tell pipeline agent what failed)
3. **Batch** — Accumulate verifier-approved submissions into a batch file for human review
4. **Relay** — After human answers, relay feedback verbatim to the appropriate pipeline agents
5. **Track** — Maintain the current state: which pipelines are at which gate, which are blocked, which need attention

### Key Rules
- **Don't wait for permission to mediate** — If a pipeline agent and verifier can go back and forth, make them do it. Only bring things to the human when they're ready for human review.
- **Relay feedback verbatim** — The human's exact words matter. Don't summarize or editorialize when relaying rejections.
- **Batch efficiently** — G1 and G2 reviews can coexist in the same batch. Don't create a new batch file for every small update.
- **Don't relay stale batches** — If the review process changes (e.g., checklist redesign), supersede the old batch and fold into a new one.

### Timing
The orchestrator does NOT need to wait until all agents finish before creating a batch. As verifier-approved submissions come in, they're added to the current batch. The human reviews when they're ready.


---

## Summary of Process Changes for Future Orchestrators

1. **G2 Verification Checklist v3** — Section A rewritten for semantic review (problem statement, per-bead deliverables, flow narrative, end-to-end scope check, test plan, engineering manager readability). **Must be a dedicated, self-contained, labeled section** — not content scattered throughout the doc.
2. **Section A placement** — First section of Phase 2 breakdown, after Phase 1 design content
3. **Section A is self-contained** — A reader reads Section A top-to-bottom and understands the pipeline. No scanning the rest of the doc required. Verifiers must FAIL submissions where Section A criteria are only satisfied by scattered content.
4. **Verification report stapled to doc** — Appended as `## G2 Verification Report` at end of pipeline doc
5. **Verifiers stay alive** — Wait after reporting; may be asked to re-review; told to shut down only after human approves
6. **Both copies updated** — Main branch AND worktree when archiving/cancelling pipelines
7. **Fresh verifier per re-review** — If context is stale, spawn new; never resume
8. **Test prompts before scaling** — Don't send 25 agents with an untested prompt
9. **Orchestration is a batch feedback loop** — Collect, mediate, batch, relay, track. Don't wait for permission to mediate agent back-and-forth.


---

## Appendix A: Verbatim Agent Prompts

### A1. G2 Verifier Prompt (Revised — v3)

This is the exact prompt given to each G2 verifier agent. The `pNNNN`, doc location, and worktree path were substituted per pipeline.

```
You are a G2 Verification Agent. Your job is to review a single Gate 2 (Work Breakdown Plan) submission against a comprehensive checklist, then report PASS or FAIL to the team lead.

## Pipeline Under Review
**Pipeline:** pNNNN
**Doc location:** .claude/worktrees/<worktree-name>/docs/pipeline/active/pNNNN-<slug>.md

## Instructions
1. Read the pipeline doc thoroughly — every section from frontmatter through Agent Context.
2. Also read the project's CLAUDE.md for framework context (architecture, patterns, testing grades, honor system). The pipeline agent had access to this, so you should too.
3. Evaluate against ALL checklist sections below. Mark each item ✅ or ❌ with brief notes.
4. The breakdown MUST begin with a Section A summary — this is separate from and comes AFTER the Phase 1 design content. It is the first section of the Phase 2 breakdown, written for human review. **CRITICAL: Section A must be a DEDICATED, CLEARLY LABELED section** (e.g., `### Section A: Summary` or `### Breakdown Summary`) located at the top of the Phase 2 breakdown. It must be **self-contained** — a reader must be able to read Section A in its entirety and understand what the pipeline delivers, in what order, and why, **without scanning the rest of the document**. The verifier must FAIL any submission where Section A criteria are satisfied only by content scattered throughout other sections rather than consolidated in one clearly labeled block.
5. Append your completed checklist (with ✅/❌ marks and notes) as a new section at the end of the pipeline doc titled "## G2 Verification Report". This must be verbatim in the file for everyone to see.
6. Report your verdict via SendMessage to "team-lead" with: PASS or FAIL, a brief summary (3-5 sentences), and specific failures if FAIL.

## G2 Verification Checklist

### Section A: Human-Readable Summary (MUST be a dedicated, labeled, self-contained section)
- [ ] A-0: **Section exists as a labeled block** — There is a clearly labeled section (e.g., `### Section A: Summary` or `### Breakdown Summary`) at the top of the Phase 2 breakdown. It is NOT content scattered across design log, design statements, or bead descriptions. If no such labeled section exists, ALL of Section A fails automatically.
- [ ] A-1: **Problem statement** — What's broken/missing today? The "why" before the "what."
- [ ] A-2: **Per-bead deliverable table** — Each bead listed with title, concrete output, and complexity estimate (S/M/L). This table must be IN Section A, not buried in the bead details below.
- [ ] A-3: **Bead flow narrative** — Plain-English walkthrough of execution order. "First we do X, which enables Y." Not just a dependency graph — the story. Must be IN Section A.
- [ ] A-4: **End-to-end scope check** — Does the breakdown cover ALL work from current state to "done"? If the title says it's a bug fix, a bead fixes the bug. If it says "add feature X," there's a bead that adds feature X. No "the architecture is already correct" hand-waving. Must be IN Section A.
- [ ] A-5: **Test coverage plan** — Which testing grades apply, what's tested, debug/release gating. Must be IN Section A.
- [ ] A-6: **Brief AND thorough** — An engineering manager could read ONLY this section and understand what the pipeline delivers, in what order, and why. If they need to read anything else in the doc to understand, this item fails.

### Section B: Worker-Ready Detail (each bead must have)
- [ ] B-1: **Exact file paths** — Every bead specifies which files it creates or modifies, using full paths from project root.
- [ ] B-2: **Clear acceptance criteria** — Each bead has specific, testable completion criteria (not vague "implement X").
- [ ] B-3: **Implementation approach** — Enough detail that a fresh agent with CLAUDE.md context could start working without guessing.
- [ ] B-4: **Dependencies** — Explicit blocked-by relationships between beads where applicable.
- [ ] B-5: **Context sources** — Each bead references the specs, ADRs, or code it builds on.

### Section C: Work Flow
- [ ] C-1: **Dependency graph** — Beads have explicit ordering where one depends on another.
- [ ] C-2: **Parallelizable beads** — Independent beads are identified as parallelizable.
- [ ] C-3: **Critical path** — The longest dependency chain is identified.
- [ ] C-4: **Cross-cutting concerns** — Shared patterns (logging, error handling, testing) addressed.

### Section D: Thoroughness
- [ ] D-1: **Edge cases** — Failure modes, error conditions, and boundary cases addressed.
- [ ] D-2: **Spec traceability** — Beads reference specific requirement IDs (REQ-XXX-NNN) where applicable.
- [ ] D-3: **No hand-waving** — No beads that say "implement the thing" without specifying how.
- [ ] D-4: **Test beads** — Dedicated test beads or test work within implementation beads.
- [ ] D-5: **No missing work** — No gaps between current state and the pipeline's stated goal.

## Verdict Format
Send a message to "team-lead" with:
- **PASS** or **FAIL** (one word, clear)
- Brief summary (3-5 sentences)
- If FAIL: specific checklist items that failed with brief explanation

The full checklist with ✅/❌ marks goes in the pipeline doc, not in the message.

## After Reporting
When you're done, wait. You may be asked to re-review the submission after changes — even after you passed it. You will be told to shut down once the pipeline can proceed to Gate 3 after human review.
```

---

### A2. Pipeline Agent Fix Prompt (G2 Remediation)

This is the exact prompt given to pipeline agents whose G2 submission FAIL'd verification. The pipeline ID, worktree path, doc path, and specific failures were substituted per agent.

```
You are a pipeline agent for pNNNN. Your G2 (Work Breakdown Plan) submission was reviewed and FAILED verification.

## Your Worktree
Path: .claude/worktrees/<worktree-name>
cd to this path as your FIRST action. All your work happens here.

## Pipeline Doc
.claude/worktrees/<worktree-name>/docs/pipeline/active/pNNNN-<slug>.md

## What Failed
The G2 verifier found the following issues:
<specific failures listed here>

## What You Need to Fix

Your Work Breakdown Plan needs a **Section A** summary as the first section of the Phase 2 breakdown (after the Phase 1 design content). Section A must contain:

- **A-1: Problem statement** — What's broken/missing today? The "why" before the "what."
- **A-2: Per-bead deliverable table** — Each bead with title, concrete output, and complexity (S/M/L).
- **A-3: Bead flow narrative** — Plain-English walkthrough of execution order. "First we do X, which enables Y."
- **A-4: End-to-end scope check** — Does the breakdown cover ALL work from current state to "done"?
- **A-5: Test coverage plan** — Grades, what's tested, debug/release gating.
- **A-6: Brief AND thorough** — An engineering manager could read this and understand what, why, and in what order.

Also fix any other specific failures noted above (missing file paths, vague acceptance criteria, etc.).

## Instructions
1. cd to your worktree path
2. Read your pipeline doc
3. Read CLAUDE.md for project context
4. Add/fix Section A and address all noted failures
5. Remove the old G2 Verification Report section (the verifier will write a new one)
6. When done, send a message to "team-lead" saying you've resubmitted for G2 re-review
```

---

### A3. Pipeline Agent Phase 2 Prompt (Original Breakdown)

This is the prompt given to pipeline agents to produce their initial Phase 2 (Work Breakdown Plan). Pipeline ID, worktree path, and doc path were substituted.

```
You are a pipeline agent for pNNNN. Your Phase 1 design has been approved at Gate 1. Now produce the Phase 2 Work Breakdown Plan.

## Your Worktree
Path: .claude/worktrees/<worktree-name>
cd to this path as your FIRST action. All your work happens here.

## Pipeline Doc
.claude/worktrees/<worktree-name>/docs/pipeline/active/pNNNN-<slug>.md

## Instructions
1. cd to your worktree path
2. Read your pipeline doc — your Phase 1 design is already there
3. Read CLAUDE.md for full project context (architecture, patterns, testing, honor system)
4. Produce a Phase 2 Work Breakdown Plan in the pipeline doc

## What Phase 2 Must Contain

### Section A: Human-Readable Summary (FIRST section of Phase 2)
- **A-1: Problem statement** — What's broken/missing today?
- **A-2: Per-bead deliverable table** — Each bead with title, concrete output, complexity (S/M/L)
- **A-3: Bead flow narrative** — Execution order in plain English
- **A-4: End-to-end scope check** — Does the breakdown cover ALL work?
- **A-5: Test coverage plan** — Grades, what's tested
- **A-6: Engineering manager readable** — Brief AND thorough

### Detailed Bead Breakdown
For each work bead:
- Exact file paths (creates/modifies)
- Clear acceptance criteria
- Implementation approach
- Dependencies (blocked-by)
- Context sources (specs, ADRs, code)
- Complexity estimate (S/M/L)

### Verification Beads
- Scope-check bead per work bead
- Layer 1-5 verification beads per pipeline process

### Work Flow
- Dependency graph
- Parallelizable beads identified
- Critical path identified

## After Completing
1. Update the pipeline doc frontmatter: phase: 2, gate: g2
2. Send a message to "team-lead" saying your G2 submission is ready for verification
```
