---
description: Heavy cleanup — full audit, reader, spec, status, spec-status, audit-spec, attestation, verification
---

# Update Verifications — Heavy Cleanup Orchestrator

Run 8 cleanup steps in sequence with error gating. Each step must succeed before the next begins.

**Steps:** audit-transcripts → reader → spec-reader → status → spec-status → audit-spec → attest-report → verify

**Error gating:** After each step, check result. "Nothing new found" is SUCCESS. Broken data, file write failures, exceptions = FAILURE → halt immediately.


---


## Step 1: Audit Transcripts

Audit all session history for missing design transcripts and repair gaps.

### 1a. Discovery (Worktree-Aware)

When using ccmanager, worktrees are created as subdirectories with copied sessions. The audit must find all related project directories and deduplicate sessions by ID.

**Why deduplication matters:**
- ccmanager copies `~/.claude/projects/<path>` sessions when creating worktrees
- Same session ID may exist in main AND worktree directories
- Without deduplication, agents would analyze the same session multiple times
- We prefer the newest copy (by mtime) in case of active sessions

**Discovery Commands:**

```bash
# Show all related project directories
./scripts/audit/list-project-dirs.sh

# List all sessions (deduplicated, sorted by timestamp)
./scripts/audit/list-sessions.sh

# Quick mode (uses mtime instead of parsing files)
./scripts/audit/list-sessions.sh --quick

# Major sessions only (>1MB)
./scripts/audit/list-sessions.sh --min-size 1000000

# Just session paths (for piping to other tools)
./scripts/audit/list-sessions.sh --paths-only --min-size 100000

# JSON output
./scripts/audit/list-sessions.sh --json --min-size 100000

# List existing transcripts
ls -la docs/0-transcripts/transcript_*.md 2>/dev/null || echo "No transcripts found"
```

### 1b. Parallel Verification

Launch 5-7 Agent subagents in parallel, each covering a date range or batch of sessions.

**Agent prompt template:**
```
You are a transcript verification agent for the-tavern-at-the-spillway project.

## Your Mission
Verify if existing transcripts cover the design discussions in these sessions. If you find crucial missing content, produce ONE transcript and terminate immediately.

## Sessions to Review
[List deduplicated session files with paths and sizes - use discovery script output]

## Existing Transcripts
[List relevant transcripts by date]

## Instructions
1. Read session files using jq to extract ALL user messages (type="human"). Never sample — verify every message.
2. Read existing transcripts to understand what's covered
3. Look for design discussions NOT in transcripts:
   - Design principles
   - Architecture decisions
   - Feature discussions
   - Process/methodology discussions
   - [U] content that looks like interview material
4. **User completeness check**: Verify that EVERYTHING the user said in the session is accounted for in transcripts. User statements are primary sources — nothing they said should be lost or summarized away.
5. If you find missing content:
   - Produce a transcript following [U], [C], [T], [S] notation
   - Return filename and full content
   - STOP after ONE transcript
6. If nothing missing, report what you verified

## Return Format
STATUS: [MISSING_FOUND | ALL_COVERED]
VERIFIED_SESSIONS: [list]
VERIFIED_TOPICS: [what's already covered]

[If MISSING_FOUND:]
TRANSCRIPT_FILENAME: transcript_YYYY-MM-DD-HHMM.md
TRANSCRIPT_CONTENT:
[full transcript]
```

**Batching strategy:**
- Group sessions by date range
- Each agent gets 2-4 sessions max
- **Large sessions (>20MB) must be chunked** — spawn multiple agents with message offsets so every user message is verified. Example: agent 1 gets messages 0-500, agent 2 gets 501-1000, etc. Never sample large files.
- Calculate message counts first: `jq -s '[.[] | select(.type=="human")] | length' < session.jsonl`

### 1c. Repair

For each agent that returns `MISSING_FOUND`:
1. Extract the transcript filename and content
2. Write to `docs/0-transcripts/[filename]`
3. Serialize writes (one at a time to prevent contamination)

### 1d. Final Audit

Launch one Agent subagent to verify completeness:

```
You are the final auditor for transcript coverage.

## Mission
Comprehensive audit to verify ALL design discussions are captured.

## Check
- All major sessions (list them)
- All transcripts (count: should be N after repairs)

## Return
AUDIT STATUS: COMPLETE - ALL COVERED
or
AUDIT STATUS: INCOMPLETE - MISSING CONTENT FOUND
[with transcript if missing]
```

### Step 1 Gate

- **SUCCESS** — Final audit returns ALL_COVERED, or MISSING_FOUND with repairs completed
- **FAILURE** — Agent errors, discovery script fails, or file write failures

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 2.


---


## Step 2: Reader

Generate a standalone "System Design Reader" document that synthesizes all transcripts in `docs/0-transcripts/`.

Someone with zero prior context can read this instead of tailing transcripts. This is the authoritative summary of the system design as understood through the conceiving process.

**Output:** `docs/0-transcripts/reader_{DATETIME}.md` (use current datetime, e.g., `reader_2026-01-25-1430.md`)

### Structure

1. **Executive Summary** — What is this system? Core value proposition in 2-3 paragraphs.

2. **Problem Statement** — Pain points that drove the design. Include source references (transcript file + timestamp).

3. **Core Concepts** — Key abstractions with definitions:
   - Jake (daemon agent)
   - Mortal agents
   - Perseverance mode vs Chat mode
   - Bubbling
   - Agent naming
   - Any new concepts since last reader

4. **User Flow** — How someone uses the system, step by step. Starting a project, working with agents, zooming in/out, completing work.

5. **Architecture Notes** — Tech stack, agent hierarchy, communication patterns, session management.

6. **Core Systems** — Document store, workflow engine, sandbox primitives, etc. (from initial_notes.md walkthrough if covered).

7. **UI Concepts** — Dashboard, context cards, merge queue, question triage, session inbox, etc.

8. **Agent Communication** — Message protocol, lateral collaboration, surfacing questions.

9. **Open Questions** — Unresolved [?N] items with context for why they matter. Mark resolved ones as RESOLVED with resolution summary.

10. **Vocabulary Decisions** — Cogitation verbs, naming themes, terminology notes.

11. **Conversation Chronicle** — Chronological index of when topics were discussed. Format as tables with Time, Topic, Notes columns. Include session number and file references.

12. **Source Files** — Table listing all input documents and their purpose.

### Rules

- Write for a reader with zero memory of past sessions
- Include timestamps and source references for traceability
- Use plain technical names, not character voice (Jake's colorful vocabulary is presentation layer)
- Flag resolved vs unresolved questions clearly
- When updating from a previous reader, carry forward all content and ADD new material — don't lose information
- Reference the previous reader if one exists, noting what's new

### Before Writing

1. Read the current reader (if any) to understand baseline
2. Read all transcript files to find new content since last reader
3. Read process doc for open questions status
4. Identify what's new vs what's unchanged

### Step 2 Gate

- **SUCCESS** — Reader file written to `docs/0-transcripts/reader_{DATETIME}.md`
- **FAILURE** — File write fails or no transcripts found

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 3.


---


## Step 3: Spec Reader

Compile all active spec modules into a single markdown file, stripping dropped sections.

Run the compilation script:

```bash
python3 scripts/compile-spec.py
```

This script:
1. Reads all spec modules from `docs/2-spec/` matching `NNN-*.md` (three-digit prefix)
2. Strips dropped sections in both formats: `<!-- DROPPED ... -->` HTML comments (legacy) and `~~strikethrough~~` headings (current format per 000-index.md §5)
3. Compiles active content into `docs/2-spec/compiled/spec-reader_YYYY-MM-DD.md`

Report the script's output:
- Total modules compiled
- Number of dropped sections skipped
- Output file path and size

### Step 3 Gate

- **SUCCESS** — Script exits 0 and output file created
- **FAILURE** — Script errors or output file missing

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 4.


---


## Step 4: Status

Update `docs/4-docs/project-status.md` to reflect all transcripts, including any newly created from audits.

### 4a. Discover All Transcripts

```bash
ls -1 docs/0-transcripts/transcript_*.md | sort
```

### 4b. Read Current Status

Read `docs/4-docs/project-status.md` and identify:
- Which transcripts are mentioned/covered in the Timeline section
- Which features have been documented

### 4c. Find Uncovered Transcripts

Compare the transcript list against what's mentioned in `docs/4-docs/project-status.md`. A transcript is "uncovered" if:
- Its date/topic isn't referenced in the Timeline
- Its content isn't reflected in the Features sections

**Important:** Don't assume chronological ordering. Audits may create transcripts for older sessions that weren't captured at the time.

### 4d. Read Uncovered Transcripts

For each uncovered transcript, read it and extract:
- **Timeline entry:** Date, key topics/decisions
- **Feature updates:** What was implemented, what was discussed as remaining

### 4e. Update project-status.md

Merge the new information:

**Timeline section:**
- Add entries for uncovered transcripts
- Keep chronological order
- Use the established format: `- **YYYY-MM-DD HH:MM** — Brief description`

**Features sections:**
- Update "Implemented" lists with newly completed items
- Update "Remaining" lists (remove completed items, add new ones)
- Add new feature sections if needed

### 4f. Update the Generated Date

Change the `**Generated:**` line to today's date.

### Quality Checks

Before writing the updated file:
- [ ] All transcript dates appear in Timeline
- [ ] No duplicate entries
- [ ] Timeline is chronologically sorted
- [ ] Feature sections reflect current state (not just additions)
- [ ] Implemented/Remaining lists are accurate based on transcripts

### Step 4 Gate

- **SUCCESS** — `docs/4-docs/project-status.md` updated and passes quality checks
- **FAILURE** — File write fails or quality checks fail

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 5.


---


## Step 5: Spec Status Dashboard

Scan all spec modules and provenance markers to produce a live coverage dashboard.

### 5a. Parse All Spec Modules

Read every spec file matching `docs/2-spec/002-*.md` through `docs/2-spec/018-*.md`. For each file, extract every requirement block:

- **Requirement ID and title** from lines matching `^### (REQ-[A-Z]+-[0-9]{3}): (.+)$`
- **Priority** from `**Priority:** (must-have|should-have|deferred)` within the requirement block
- **Module number and name** from the filename

Build a master list of all requirements with: module, req ID, title, priority.

### 5b. Scan Code for Provenance Markers

Search `Tavern/Sources/**/*.swift` for lines matching:
```
// MARK: - Provenance:.*REQ-[A-Z]+-[0-9]{3}
```

Extract each `REQ-PREFIX-NNN` from matching lines. A single MARK line may contain multiple comma-separated requirement IDs. Map each requirement ID to the file(s) it appears in.

### 5c. Scan Tests for Provenance Tags

Search `Tavern/Tests/**/*.swift` for two patterns:

**Pattern 1 — Swift Testing tags:**
```
\.tags\(.*\.req([A-Z]+)(\d{3})
```
Convert tag format to requirement ID: `.reqAGT001` → `REQ-AGT-001`

**Pattern 2 — MARK comments in test files:**
```
// MARK: - Provenance:.*REQ-[A-Z]+-[0-9]{3}
```

Map each requirement ID to the test file(s) it appears in.

### 5d. Derive Status

For each requirement:
- `specified` — exists in spec only (no code markers, no test markers)
- `implemented` — has at least one code provenance marker
- `tested` — has at least one test provenance tag (implies implemented)

### 5e. Output Per-Module Tables

For each spec module, output a table:

```
## Module 004 — Agents (REQ-AGT)

| Req ID | Title | Priority | Status | Code Files | Test Files |
|--------|-------|----------|--------|------------|------------|
| REQ-AGT-001 | Jake Daemon Agent | must-have | specified | — | — |
| REQ-AGT-002 | Mortal Agents (Servitors) | must-have | specified | — | — |
...
```

- Code/Test Files columns show relative paths (e.g., `Agents/Jake.swift`) or `—` if none
- If multiple files, comma-separate them
- **Sort rows by implementation status:** `specified` first, then `implemented`, then `tested`. Within each status group, sort by req ID.

### 5f. Output Summary Table

```
## Summary

| Module | Prefix | Total | Specified | Implemented | Tested | Coverage% |
|--------|--------|-------|-----------|-------------|--------|-----------|
| 002-invariants | REQ-INV | 8 | 8 | 0 | 0 | 0% |
...
| **TOTAL** | | **162** | **162** | **0** | **0** | **0%** |
```

Coverage% = (Tested + Implemented) / Total × 100, rounded to nearest integer.

**Sort rows by Coverage% ascending** (least covered modules first). The TOTAL row stays at the bottom.

### 5g. Flag Anomalies

After the summary table, list any anomalies found:

- **Orphaned provenance:** Code or test files referencing requirement IDs that don't exist in any spec module
- **Must-have gaps:** Must-have requirements still at `specified` status (expected on first run — note this)
- **Deferred-but-implemented:** Requirements marked `deferred` priority that have implementation markers (not necessarily wrong, but worth flagging)

### 5h. Write Report

Display the full dashboard in the conversation.

Write the complete dashboard to `docs/4-docs/spec-status-report_{YYYY-MM-DD}.md` (today's date, overwrite same-day). This file is consumed by Steps 6 and 8.

**Key Files:**
- `docs/2-spec/000-index.md` — module list and requirement counts (use to verify scan completeness)
- `docs/2-spec/002-*.md` through `docs/2-spec/018-*.md` — spec modules
- `Tavern/Sources/**/*.swift` — code provenance markers
- `Tavern/Tests/**/*.swift` — test provenance tags

### Step 5 Gate

- **SUCCESS** — Dashboard displayed and report file written to `docs/4-docs/spec-status-report_{YYYY-MM-DD}.md`
- **FAILURE** — Spec parsing fails or file write fails

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 6.


---


## Step 6: Spec Audit (PRD-to-Spec Coverage)

Walk the entire pipeline checking for gaps between PRD, spec modules, code, and tests.

### 6a. Extract PRD Section Headers

Read `docs/1-prd/prd_2026-01-19.md` and extract all `## N. Title` and `## N.N Title` section headers. Build a list of all PRD sections with their numbers and titles.

### 6b. Load Coverage Matrix

Read `docs/2-spec/000-index.md` and extract:

**PRD Coverage Matrix:** Map each PRD section to its spec module(s) and status. Note which sections are "context-only" (no spec needed).

**Module Status Overview:** Extract the claimed requirement counts per module (the "Requirements Count" column).

### 6c. Verify Each Spec Module

For each spec module listed in the index (`002-invariants.md` through `018-spec-fidelity.md`):

1. Read the spec file
2. Count actual requirement headers matching `^### (REQ-[A-Z]+-[0-9]{3}):`
3. Compare against the claimed count in the index
4. Extract the Upstream References section — verify PRD sections are listed
5. Extract the Downstream References section — note claimed code and test directories

### 6d. Verify Downstream References

For each spec module's Downstream References:
- Check if claimed code directories exist (e.g., `Tavern/Sources/TavernCore/Agents/`)
- Check if claimed test directories exist (e.g., `Tavern/Tests/TavernCoreTests/`)
- Flag missing directories

### 6e. Load Provenance Coverage

Read `docs/4-docs/spec-status-report_{YYYY-MM-DD}.md` (written by Step 5) and extract the per-module coverage data (implementation% and test%).

### 6f. Output Section 1 — PRD Coverage

```
## PRD Coverage

| PRD Section | Title | Spec Module | Index Status | Verified |
|-------------|-------|-------------|--------------|----------|
| §1 | Executive Summary | (context) | — | — |
| §2 | Invariants | 002-invariants.md | complete | ✓ |
...
```

"Verified" column: ✓ if the spec module exists and its Upstream References mention this PRD section. ✗ if not.

### 6g. Output Section 2 — Spec Module Health

```
## Spec Module Health

| Module | Prefix | Claimed | Actual | Match? | Implemented | Tested | Coverage% |
|--------|--------|---------|--------|--------|-------------|--------|-----------|
| 002-invariants | REQ-INV | 8 | 8 | ✓ | 0 | 0 | 0% |
...
```

- Claimed = count from index
- Actual = count from scanning the spec file
- Match? = ✓ if equal, ✗ with note if not
- Coverage% = (Implemented + Tested) / Actual × 100

### 6h. Output Section 3 — Gap Analysis

Report three categories of issues:

**Critical Gaps** — Must-have requirements with no implementation path:
```
### Critical Gaps
- REQ-AGT-001 (must-have): Jake Daemon Agent — no code provenance
...
```

On first run with zero provenance markers, note: "All must-have requirements lack provenance — this is expected. Provenance markers are added incrementally as code is touched."

**Index Discrepancies** — Mismatches between index claims and reality:
```
### Index Discrepancies
- Module 004: index claims 10 requirements, file has 9 (missing REQ-AGT-XXX?)
```

**Downstream Reference Issues** — Missing directories or files:
```
### Downstream Reference Issues
- Module 008 claims code in Tavern/Sources/TavernCore/Shell/ — directory not found
```

**Unmapped PRD Sections** — PRD sections not covered by any spec module (beyond the known context-only sections):
```
### Unmapped PRD Sections
(none expected — all should be mapped)
```

**Orphaned Provenance** — Code/test markers referencing nonexistent requirement IDs:
```
### Orphaned Provenance
(none found)
```

### 6i. Output Section 4 — PRD Pipeline Flow (Top-to-Bottom)

Trace each PRD section through the full pipeline to show what percentage of the PRD appears downstream in implementation and testing.

**Per-PRD-Section Table:** Group PRD sections by their spec module. For each group, show the PRD section(s), spec module, total requirements, implemented count, tested count, Code%, and Test%.

```
## PRD Pipeline Flow (Top-to-Bottom)

### Per-PRD-Section Downstream Coverage

| PRD Section(s) | Spec Module | Reqs | Impl'd | Tested | Code% | Test% |
|----------------|-------------|------|--------|--------|-------|-------|
| §2 Invariants | 002-invariants | 8 | 4 | 3 | 50% | 38% |
...
```

**Aggregate Pipeline Flow:** Show the full pipeline as a flow diagram with counts and percentages at each layer transition:

```
### Aggregate Pipeline Flow

PRD  ━━━  N sections
       │ X% coverage
       ▼
Spec ━━━  N requirements across N modules
       │ X% have code provenance
       ▼
Code ━━━  N requirements traced to source
       │ X% of implemented reqs have test tags
       ▼
Tests ━━━  N requirements traced to tests
```

Plus a transition rate table:

| Layer Transition | Rate |
|-----------------|------|
| PRD → Spec | X% |
| Spec → Code | X% (N/N) |
| Spec → Tests | X% (N/N) |
| Code → Tests | X% (N/N) |

**Unimplemented Breakdown:** Categorize the unimplemented requirements into:
- **Explicitly deferred** — items marked deferred in v1 scope or spec
- **Meta/process** — requirements that describe standards/processes with no code artifact
- **Genuinely unimplemented** — features that need building
- **Arguably provenance-able** — existing code that could be tagged but isn't

**Test Coverage Gaps:** Identify modules with the widest gap between implementation and test coverage (highest leverage for adding tests). Show module, Code%, Test%, and gap in percentage points.

### 6j. Summary Statistics

```
## Summary

- **PRD sections:** N total, N covered, N context-only
- **Spec modules:** N total, all present
- **Total requirements:** N
- **Implementation coverage:** N/N (X%)
- **Test coverage:** N/N (X%)
- **Index accuracy:** X/N modules match claimed counts
- **Downstream references:** X/Y directories verified
- **Deferred (no code expected):** ~N requirements
- **Meta/process (no code artifact):** ~N requirements
- **Adjusted code provenance:** N/N active reqs (X%)
- **Orphaned provenance:** N
- **Unmapped PRD sections:** N
```

### 6k. Write Report

Display the full audit in the conversation.

Write the complete audit to `docs/4-docs/audit-spec-report_{YYYY-MM-DD}.md` (today's date, overwrite same-day). This file is consumed by Step 8.

**Key Files:**
- `docs/1-prd/prd_2026-01-19.md` — PRD
- `docs/2-spec/000-index.md` — coverage matrix and module index
- `docs/2-spec/002-*.md` through `docs/2-spec/018-*.md` — spec modules
- `docs/4-docs/spec-status-report_{YYYY-MM-DD}.md` — provenance data from Step 5

### Step 6 Gate

- **SUCCESS** — Audit displayed and report file written to `docs/4-docs/audit-spec-report_{YYYY-MM-DD}.md`
- **FAILURE** — PRD or spec index cannot be read, or file write fails

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 7.


---


## Step 7: Attestation Report

Run semantic conformance attestation across all spec modules in parallel using a team, then compile results into a single attestation report.

### 7a. Discover Active Modules

Read `docs/2-spec/000-index.md` and extract all modules with status `complete` and requirements count > 0. Skip stubs. Build a list of module numbers and names.

### 7b. Spin Up Team

Create a team (`attest-YYYYMMDD`). For each active module, create a task and spawn a worker Agent (use `sonnet` model). Each worker writes to a separate file — no contention.

**Worker prompt (one per module):**

```
You are an attestation worker analyzing spec module {NNN}-{name}.

## Phase 1 — Mechanical Gathering

### 1. Parse Target

Your target is module number: {NNN}

Look up the filename in `docs/2-spec/000-index.md` Module Status Overview table by matching the Doc # column. Read that spec file and extract all requirement IDs matching `^### (REQ-[A-Z]+-[0-9]{3}):`.

### 2. Read Spec Blocks

For each requirement ID, read its spec block from the appropriate `docs/2-spec/*.md` file. Extract:

- Title
- Source (PRD section reference)
- Priority
- Status
- Properties list (all bullet points under Properties)
- Testable assertion (the quoted block or assertion text)

### 3. Find Code Files

Search `Tavern/Sources/**/*.swift` for provenance markers:

```
// MARK: - Provenance:.*REQ-XXX-NNN
```

Read the matched files. For small files (<300 lines), read the full file. For larger files, read targeted sections around each provenance marker (50 lines of context).

### 4. Find Test Files

Search `Tavern/Tests/**/*.swift` for both patterns:

**Tags** (convert `REQ-AGT-003` → `.reqAGT003`):
```
\.tags\(.*\.reqPREFIXNNN
```

**MARK comments:**
```
// MARK: - Provenance:.*REQ-XXX-NNN
```

Read the matched test files using the same sizing strategy as code files.

## Phase 2 — Semantic Analysis

For each requirement, perform two analyses:

### Property Analysis

For each **property** listed in the requirement's spec block:

1. Read the property statement
2. Examine the gathered code for evidence of satisfaction
3. Assign a verdict:
   - **satisfied** — Code clearly implements the property; cite specific evidence
   - **partial** — Some aspects implemented but incomplete; explain what's missing
   - **unsatisfied** — No evidence the property is implemented
   - **unexamined** — Cannot assess (e.g., requires runtime behavior observation)

### Assertion Analysis

For each clause of the **testable assertion**:

1. Read the assertion clause
2. Examine the gathered test code for coverage
3. Assign a verdict:
   - **verified** — A test explicitly exercises this assertion clause; cite the test
   - **partial** — Tests touch the area but don't fully verify the clause
   - **unverified** — No test covers this assertion clause

## Phase 3 — Verdict Synthesis

Roll up per-requirement using **weakest-link** logic:

- All properties satisfied + all assertions verified → **CONFORMANT**
- Mix of satisfied/partial/unsatisfied → **PARTIAL**
- No properties satisfied → **NON-CONFORMANT**
- Priority is `deferred` or no code exists → **NOT ASSESSED** (state the reason)

## Output

Write your report to `docs/4-docs/attestations/attest-{NNN}-{name}.md` where {NNN} is the module number and {name} is the module slug. Create the `attestations/` directory if it doesn't exist.

### Per-Requirement Report Card

For each requirement:

```markdown
## Attestation: REQ-XXX-NNN — Title

**Verdict: VERDICT**
**Priority:** priority | **Source:** PRD §X.X | **Spec:** filename.md

### Properties

| # | Property | Verdict | Evidence |
|---|----------|---------|----------|
| 1 | Property text | satisfied | Specific code evidence |
| 2 | Property text | partial | What exists + what's missing |

### Testable Assertions

| Clause | Verdict | Test(s) |
|--------|---------|---------|
| "assertion clause text" | verified | TestFile.testName |
| "assertion clause text" | unverified | (none) |

### Gaps
- Bullet list of specific gaps discovered
```

### Multi-Requirement Summary Table

Prepend a summary table before the individual report cards:

```markdown
## Attestation Summary — Module NNN (Name)

| Req ID | Title | Verdict | Properties | Assertions | Gaps |
|--------|-------|---------|------------|------------|------|
| REQ-XXX-001 | Title | PARTIAL | 4/5 | 1/3 | 3 |
...

**Module verdict: N conformant, N partial, N non-conformant, N not assessed**
```

When complete, return the module verdict line:
"Module {NNN}: N conformant, N partial, N non-conformant, N not assessed"
```

### 7c. Monitor and Collect

As workers complete, collect their module verdict summaries. Track progress: N/total modules complete.

### 7d. Compile Combined Report

Once all workers have finished, read all individual attestation files from `docs/4-docs/attestations/attest-*.md` and compile them into:

```
docs/4-docs/attestation-report_{YYYY-MM-DD}.md
```

The combined report has this structure:

```markdown
# Attestation Report — {date}

**Scope:** Full specification ({N} modules, {N} active requirements)
**Generated by:** Swarm attestation ({N} parallel workers)

## Executive Summary

| Verdict | Count | % |
|---------|-------|---|
| CONFORMANT | N | X% |
| PARTIAL | N | X% |
| NON-CONFORMANT | N | X% |
| NOT ASSESSED | N | X% |

## Module Verdicts

| Module | Active Reqs | Conformant | Partial | Non-Conformant | Not Assessed |
|--------|-------------|------------|---------|----------------|--------------|
| 002-invariants | 9 | ... | ... | ... | ... |
...

## Top Gaps (Highest Impact)

Aggregate all gaps from individual attestations. Sort by priority (must-have first), then by module. List the top 20 most impactful gaps — those where must-have requirements have unsatisfied properties or unverified assertions.

## Per-Module Detail

(Include each individual module attestation below, in module number order)

---

### Module 002 — Invariants

(paste content from attest-002-invariants.md)

---

### Module 003 — System Architecture

(paste content from attest-003-system-architecture.md)

...
```

### 7e. Tear Down Team

After the combined report is written, tear down the team.

Ensure `docs/4-docs/attestations/` is in `.gitignore` — the individual per-module files are build artifacts. Only the combined dated report is meant to be committed.

### Step 7 Gate

- **SUCCESS** — Combined report written to `docs/4-docs/attestation-report_{YYYY-MM-DD}.md` and all modules attested
- **FAILURE** — Any worker errors out, module file missing, or combined report write fails

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 8.


---


## Step 8: Verification Suite

Run all project verification checks and produce a combined gap analysis report per ADR-009.

**Output:** `docs/4-docs/verification-report_{YYYY-MM-DD}.md`

**Specification:** `docs/3-adr/ADR-009-verification-suite.md` (authoritative reference for all checks)

### Execution Plan

Maximize parallelism. Launch all independent work streams simultaneously, then collect results.

**IMPORTANT:** Use `run_in_background` for long-running bash commands. Execute grep-based checks inline while background tasks run. Read pre-generated reports from disk for Sections 4, 5, 6.


### Phase 1: Launch Background Streams + Inline Checks

**In a single message, launch these in parallel:**

1. **Stream A — Build** (background bash):
   ```bash
   cd /Users/yankee/Documents/Projects/the-tavern-at-the-spillway && redo Tavern/build 2>&1
   ```
   Save output for Section 1 (warning analysis).

2. **Stream B — Tests + Coverage** (background bash):
   ```bash
   cd /Users/yankee/Documents/Projects/the-tavern-at-the-spillway/Tavern && swift test \
     --skip TavernIntegrationTests \
     --skip TavernStressTests \
     --enable-code-coverage 2>&1
   ```
   Save output for Sections 2 (test results) and 3 (coverage).

3. **Stream E — Beads Audit** (background bash):
   ```bash
   ~/.claude/scripts/beads_audit.sh 2>&1; echo "---BEADS-JSON---"; bd list -n 0 --json 2>/dev/null || echo "[]"
   ```
   **MANDATORY:** Always use `-n 0` with `bd list` to retrieve ALL beads. Without it, bd returns a truncated default page.
   Save output for Section 7.

4. **Stream G — Attestation** (read from disk):
   Read `docs/4-docs/attestation-report_{YYYY-MM-DD}.md` (written by Step 7).
   Extract the executive summary table and top gaps for Section 4.

5. **Stream I — SDK Feature Parity** (read from disk, fallback to background Agent):
   Read today's SDK parity report from `docs/4-docs/sdk-parity-report_{YYYY-MM-DD}.md`.
   If the file exists, extract the summary table and per-section details for Section 11.
   If the file does not exist, launch a general-purpose Agent subagent (sonnet model) with this prompt:

   ```
   Verify every row in the SDK feature matrix at `docs/3-adr/ADR-010-sdk-feature-parity.md` (Part 2).

   Parse all tables in Part 2. Each row has: SDK Capability | Status | Notes.

   For each row, apply the check matching its Status:

   **Implemented rows:**
   - Search `Tavern/Sources/**/*.swift` for code implementing the capability
   - Search `Tavern/Tests/**/*.swift` for tests exercising it
   - Verdict: VERIFIED (code + tests, wired end-to-end), PARTIAL (code exists but incomplete wiring or no tests), or FALSE (no code found)

   **Gap rows:**
   - Confirm no implementation code exists
   - Run: bd list -n 0 --json — search output for a bead tracking this capability
   - Verdict: CONFIRMED (gap is real, bead exists), UNTRACKED (gap but no bead), or RESOLVED (code now exists — matrix status is stale)

   **Deferred rows:** Same checks as Gap.

   **Broken rows:**
   - Confirm code exists but verify it's still broken
   - Check for tracking bead via bd list
   - Verdict: CONFIRMED (still broken, bead exists), UNTRACKED (broken but no bead), or FIXED (code works now — matrix status stale)

   **N/A rows:** Confirm justification still holds. Verdict: CONFIRMED or RECONSIDER.

   Output format — write to `docs/4-docs/sdk-parity-report_{YYYY-MM-DD}.md` (today's date):

   # SDK Feature Parity Report — {date}

   ## Summary
   | Matrix Status | Count | Verified | Partial | False/Stale | Confirmed | Untracked |
   |---------------|-------|----------|---------|-------------|-----------|-----------|
   | Implemented   | N     | N        | N       | N           | —         | —         |
   | Gap           | N     | —        | —       | —           | N         | N         |
   | Deferred      | N     | —        | —       | —           | N         | N         |
   | Broken        | N     | —        | —       | —           | N         | N         |
   | N/A           | N     | —        | —       | —           | N         | —         |

   **Pass criteria:** Zero FALSE implementations. Zero UNTRACKED violations.

   ## Per-Section Details
   (One table per ADR-010 section: 2.1 through 2.12)

   | SDK Capability | Matrix Status | Verdict | Evidence |
   |----------------|---------------|---------|----------|
   | capability name | Implemented | VERIFIED | code: File.swift, test: FileTests.swift |
   ...

   Also return the summary statistics line to the caller.
   ```

   Save output for Section 11.

**While background streams run, execute these inline (they're fast — seconds each):**

6. **Stream C — Structural Rules** (Sections 8, 9):
   Run each check from Section 8 of ADR-009 using Grep and Glob tools:

   **8a. Test timeouts:**
   - Grep for `@Suite(` in `Tavern/Tests/` — get all matches with content
   - For each match, check if `.timeLimit` appears on the same line
   - Report any `@Suite` without `.timeLimit`

   **8b. Preview blocks:**
   - Grep for `struct.*:.*View` in `Tavern/Sources/Tavern/Views/` and `Tavern/Sources/Tiles/`
   - For each file with a View struct, grep same file for `#Preview`
   - Report files with Views but no preview

   **8c. Logging:**
   - Grep for `Logger(` in `Tavern/Sources/TavernCore/` excluding `Testing/`
   - List all `.swift` files in same scope
   - Report files without any Logger

   **8d. Provenance markers:**
   - Grep for `// MARK: - Provenance:` in `Tavern/Sources/` excluding `Testing/` and `TavernKit/`
   - List all `.swift` files in same scope
   - Report files without provenance

   **8e. @MainActor ViewModels:**
   - Glob for `*ViewModel.swift` in `Tavern/Sources/`
   - Grep each for `@MainActor`
   - Report any without

   **8f. ServitorMessenger DI:**
   - Read `Jake.swift` and `Mortal.swift` init signatures
   - Check for `ServitorMessenger` or `messenger:` parameter
   - Report any servitor missing DI

   **8g. No blocking calls:**
   - Grep `Tavern/Sources/` (excluding Testing/) for `Thread\.sleep` and `DispatchSemaphore.*\.wait`
   - Report any matches

   **8h. Layer violations:**
   - Grep `import TavernCore` in `Tavern/Sources/Tiles/` — should be zero
   - Grep `import TavernCore` or `import ClodKit` in `Tavern/Sources/TavernKit/` — should be zero
   - Grep `import Tavern` (but not `import TavernCore` or `import TavernKit`) in `Tavern/Sources/TavernCore/` — should be zero
   - Report any violations

   **Section 9 — Architecture:**
   - Read `Tavern/Package.swift` and extract `.target(name:, dependencies:)` entries
   - Validate against the intended layer model from ADR-009
   - Report any violations

7. **Stream D — Provenance Coverage** (Section 6, read from disk):
   Read `docs/4-docs/spec-status-report_{YYYY-MM-DD}.md` (written by Step 5) and extract per-module coverage data for Section 6.

8. **Stream F — Informational Reports** (Section 10):

   **10a. TODO/FIXME/HACK:**
   - Grep `Tavern/Sources/` and `Tavern/Tests/` for `TODO|FIXME|HACK` (case-insensitive)
   - List each with file:line and comment text

   **10b. Unwired code analysis (exhaustive — do NOT skip or sample):**

   **Why this step matters — read this before executing:** This is one of the most important checks in the entire suite. In agent-driven development, a common failure mode is that an agent implements a feature — writes the type, the methods, the tests — but doesn't complete the wiring. The session ends, the code passes review because it compiles and tests pass, but the feature silently sits disconnected. By running this analysis exhaustively, you are catching what your fellow agents missed. You are the backstop. Do this thoroughly — every declaration checked, every unwired finding diagnosed. This is how you are doing your part to support your crew.

   - Find ALL type declarations (`class`, `struct`, `enum`, `protocol`) and function declarations (`func`) in `Tavern/Sources/`
   - For EACH declaration, search the entire `Tavern/` tree (Sources + Tests) for references outside the declaring file
   - "Unwired" means the declaration exists but has no callers/references outside its own file
   - For each unwired declaration, diagnose **why** it's unwired and classify as:
     - **Development gap** — code written for a purpose that hasn't been connected yet (wiring incomplete, not the code)
     - **Obsolete** — code superseded by a different approach, can be removed
     - **Premature API** — public surface declared speculatively with no consumer yet
   - Label all results as heuristic — false positives expected (entry points, protocol witnesses, @objc, generics)
   - **This analysis must be exhaustive.** Every declaration is checked. No sampling, no shortcuts.

   **10c. Dependency freshness:**
   ```bash
   cd /Users/yankee/Documents/Projects/the-tavern-at-the-spillway/Tavern && swift package show-dependencies 2>&1
   ```
   Then check latest releases via `gh api`.

   **10d. File complexity:**
   ```bash
   find /Users/yankee/Documents/Projects/the-tavern-at-the-spillway/Tavern/Sources -name "*.swift" -exec wc -l {} + | sort -rn | head -30
   ```
   Also count functions per file:
   ```bash
   for f in $(find /Users/yankee/Documents/Projects/the-tavern-at-the-spillway/Tavern/Sources -name "*.swift"); do echo "$(grep -c 'func ' "$f") $f"; done | sort -rn | head -20
   ```


### Phase 2: Collect Background Results + Pipeline Traceability

After Streams A, B, E complete (check with TaskOutput):

1. **Parse build output** (Section 1):
   - Grep captured output for `warning:` lines
   - Count and categorize

2. **Parse test output** (Section 2):
   - Extract total/passed/failed/skipped from test summary
   - Extract any failure details

3. **Parse coverage** (Section 3) — **must produce a hierarchical filesystem tree**:
   ```bash
   cd /Users/yankee/Documents/Projects/the-tavern-at-the-spillway/Tavern && \
     COV_PATH=$(swift test --show-codecov-path 2>/dev/null) && \
     jq '[.data[0].files[]
       | select(.filename | contains("/Tavern/Sources/"))
       | select(.filename | contains("/checkouts/") | not)
       | {file: (.filename | split("/Sources/")[1]),
          covered: .summary.lines.covered,
          total: .summary.lines.count,
          percent: (.summary.lines.percent | . * 100 | round / 100)}
     ] | sort_by(.file)' < "$COV_PATH"
   ```
   Build a **hierarchical coverage table** mirroring the filesystem:
   - List every file with lines covered, total lines, and coverage %
   - Roll up directory-level coverage by summing covered/total lines across all files in that directory
   - Roll up target-level coverage (TavernCore/, TavernKit/, Tiles/, Tavern/) the same way
   - Show overall project coverage at the top
   - Use tree-drawing characters (`├──`, `└──`, `│`) for the hierarchy

4. **Parse beads output** (Section 7):
   - Extract bead count, status breakdown, priority distribution from JSON
   - Flag any P0 open beads

5. **Run Pipeline Traceability** (Section 5, read from disk):
   Read `docs/4-docs/audit-spec-report_{YYYY-MM-DD}.md` (written by Step 6) and extract PRD coverage %, module health, and orphaned provenance data for Section 5.

6. **Parse SDK parity output** (Section 11):
   - Read the SDK parity report from `docs/4-docs/sdk-parity-report_{YYYY-MM-DD}.md` (from Stream I)
   - Extract summary statistics table
   - Flag any FALSE implementations or UNTRACKED violations for Action Items


### Phase 3: Compile Report

If Stream I launched a background Agent (SDK parity file was missing), wait for it to complete.

**Compile the full report** at `docs/4-docs/verification-report_{YYYY-MM-DD}.md` using this template:

```markdown
# Verification Report — {YYYY-MM-DD}

**Generated:** {timestamp}
**Duration:** {elapsed time from start to finish}

---

## Executive Summary

| Section | Status | Detail |
|---------|--------|--------|
| Build Health | {PASS/FAIL} | {0 warnings / N warnings} |
| Test Health | {PASS/FAIL} | {N/N passed, N failed, N skipped} |
| Code Coverage | INFO | {XX%} overall |
| Spec Conformance | INFO | {N conformant, N partial, N non-conformant, N not assessed} |
| Pipeline Traceability | {PASS/WARN} | {N% PRD covered, N discrepancies} |
| Provenance Coverage | INFO | {N% code, N% test} |
| Beads | INFO | {N total, N open, N critical} |
| Structural Rules | {PASS/WARN} | {N/8 pass, N violations} |
| Architecture | {PASS/WARN} | {N violations} |
| Informational | — | {N TODOs, N large files, deps current/stale} |
| SDK Feature Parity | {PASS/WARN/FAIL} | {N verified, N partial, N false, N untracked} |

---

## Section 1: Build Health
{warning count, categorized list}

## Section 2: Test Health
{total, passed, failed, skipped, failure details}

## Section 3: Code Coverage
{hierarchical filesystem tree: per-file covered/total/%, rolled up per-directory and per-target}

## Section 4: Spec Conformance
{verdict distribution table, top 10 gaps}

## Section 5: Pipeline Traceability
{PRD coverage %, module health table, orphaned provenance list}

## Section 6: Provenance Coverage
{per-module implementation% and test% table}

## Section 7: Beads Audit
{count, status breakdown, priority distribution, P0 list}

## Section 8: Structural Rules

| Check | Status | Detail |
|-------|--------|--------|
| 8a. Test timeouts | {PASS/WARN} | {detail} |
| 8b. Preview blocks | {PASS/WARN} | {detail} |
| 8c. Logging | {PASS/WARN} | {detail} |
| 8d. Provenance markers | {PASS/WARN} | {detail} |
| 8e. @MainActor ViewModels | {PASS/WARN} | {detail} |
| 8f. ServitorMessenger DI | {PASS/WARN} | {detail} |
| 8g. No blocking calls | {PASS/WARN} | {detail} |
| 8h. Layer violations | {PASS/WARN} | {detail} |

{violation details for any WARN checks}

## Section 9: Architecture
{dependency graph summary, any violations}

## Section 10: Informational

### 10a. TODO/FIXME/HACK
{count per category, full list}

### 10b. Unwired Code (heuristic)
{list of unwired declarations, classified as development gap / obsolete / premature API}

### 10c. Dependency Freshness
| Dependency | Current | Latest | Status |
|------------|---------|--------|--------|
| {name} | {version} | {version} | {current/outdated} |

### 10d. File Complexity
**Large files (>500 lines):**
| File | Lines |
|------|-------|
| {path} | {count} |

**Highest function counts:**
| File | Functions |
|------|-----------|
| {path} | {count} |

## Section 11: SDK Feature Parity

**Source:** ADR-010 feature matrix ({N} total capabilities)

| Matrix Status | Count | Verified | Partial | False/Stale | Confirmed | Untracked |
|---------------|-------|----------|---------|-------------|-----------|-----------|
| Implemented | {N} | {N} | {N} | {N} | — | — |
| Gap | {N} | — | — | — | {N} | {N} |
| Deferred | {N} | — | — | — | {N} | {N} |
| Broken | {N} | — | — | — | {N} | {N} |
| N/A | {N} | — | — | — | {N} | — |

**Violation tracking:** {N} gaps/deferred/broken with beads, {N} untracked

{Per-section detail tables from Stream I agent output}

---

## Action Items

{Ranked list:}
1. **CRITICAL** — test failures, build failures
2. **HIGH** — non-conformant must-have requirements, P0 open beads, false SDK implementations, untracked SDK violations
3. **MEDIUM** — structural rule violations, provenance gaps
4. **LOW** — informational items
```

Display the Executive Summary table in the conversation after writing the file.

### Step 8 Gate

- **SUCCESS** — Report written to `docs/4-docs/verification-report_{YYYY-MM-DD}.md`
- **FAILURE** — Build or tests fail catastrophically, or report write fails (individual WARN results are not failures)

If FAILURE, report what went wrong.


---


## Completion

Report all 8 step results:

| Step | Command | Result | Detail |
|------|---------|--------|--------|
| 1 | audit-transcripts | SUCCESS/FAILURE | {summary} |
| 2 | reader | SUCCESS/FAILURE | {summary} |
| 3 | spec-reader | SUCCESS/FAILURE | {summary} |
| 4 | status | SUCCESS/FAILURE | {summary} |
| 5 | spec-status | SUCCESS/FAILURE | {summary} |
| 6 | audit-spec | SUCCESS/FAILURE | {summary} |
| 7 | attest-report | SUCCESS/FAILURE | {summary} |
| 8 | verify | SUCCESS/FAILURE | {summary} |

**Files written:** List all files created or modified across all steps.

If all SUCCESS: "Heavy cleanup complete. Reports at docs/4-docs/."
If any FAILURE: "Stopped at Step N: {reason}"
