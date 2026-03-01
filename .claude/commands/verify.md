---
description: Unified verification suite — complete project gap analysis
---

# Unified Verification Suite

Run all project verification checks and produce a combined gap analysis report per ADR-009.

**Output:** `docs/4-docs/verification-report_{YYYY-MM-DD}.md`

**Specification:** `docs/3-adr/ADR-009-verification-suite.md` (authoritative reference for all checks)


## Execution Plan

Maximize parallelism. Launch all independent work streams simultaneously, then collect results.

**IMPORTANT:** Use `run_in_background` for long-running bash commands. Execute grep-based checks inline while background tasks run. Use Agent tool for the attestation swarm.


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

4. **Stream G — Attestation Swarm** (background Agent):
   Launch a general-purpose agent with prompt: `Run the /attest-report slash command. When complete, read the generated attestation-report file and return the executive summary table and top 10 gaps.`
   This is the heaviest operation — runs in background.

**While background streams run, execute these inline (they're fast — seconds each):**

5. **Stream C — Structural Rules** (Sections 8, 9):
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

6. **Stream D — Provenance Coverage** (Section 6):
   - Read spec module index `docs/2-spec/000-index.md` to get requirement IDs per module
   - Grep `Tavern/Sources/**/*.swift` for `// MARK: - Provenance:.*REQ-`
   - Grep `Tavern/Tests/**/*.swift` for `.tags(.*\.req` and `// MARK: - Provenance:.*REQ-`
   - Compute per-module implementation% and test%

7. **Stream F — Informational Reports** (Section 10):

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

5. **Run Pipeline Traceability** (Section 5) — depends on provenance data from Stream D:
   - Read `docs/1-prd/prd_2026-01-19.md` and extract section headers
   - Read `docs/2-spec/000-index.md` coverage matrix
   - For each spec module: count actual requirement headers, compare against claimed count
   - Check for orphaned provenance markers
   - Compute PRD coverage %


### Phase 3: Wait for Attestation + Compile Report

1. Wait for Stream G (attestation swarm agent) to complete
2. Extract attestation summary from agent result

3. **Compile the full report** at `docs/4-docs/verification-report_{YYYY-MM-DD}.md` using this template:

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

---

## Action Items

{Ranked list:}
1. **CRITICAL** — test failures, build failures
2. **HIGH** — non-conformant must-have requirements, P0 open beads
3. **MEDIUM** — structural rule violations, provenance gaps
4. **LOW** — informational items
```

4. **Display the Executive Summary table** in the conversation after writing the file.
