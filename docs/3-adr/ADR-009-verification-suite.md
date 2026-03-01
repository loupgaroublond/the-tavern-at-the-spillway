# ADR-009: Unified Verification Suite

**Status:** Accepted
**Date:** 2026-03-01
**Context:** The project has strong but fragmented verification tools (`redo test`, `/attest-report`, `/audit-spec`, `/spec-status`, `/beads-audit`) plus honor-system rules in CLAUDE.md and ADRs. A full gap analysis requires invoking 6+ commands and mentally stitching results together.


## Decision

A single `/verify` command runs all project verification checks and produces a combined gap analysis report at `docs/4-docs/verification-report_{YYYY-MM-DD}.md`. This ADR is the authoritative specification of every check the report performs.


## Report Sections

### Section 1: Build Health

**Purpose:** Confirm the project compiles without warnings.

**Method:**
1. Run `redo Tavern/build`, capturing full xcodebuild output
2. Grep output for lines matching `warning:`
3. Categorize warnings by type (deprecation, unused variable, implicit conversion, type safety, other)

**Pass criteria:** Zero warnings.

**Output:** Warning count, categorized list of any warnings found.


### Section 2: Test Health

**Purpose:** Confirm all Grade 1+2 tests pass.

**Method:**
1. Run `swift test --enable-code-coverage` in `Tavern/`, skipping Grade 3+ targets:
   ```bash
   cd Tavern && swift test \
     --skip TavernIntegrationTests \
     --skip TavernStressTests \
     --enable-code-coverage 2>&1
   ```
2. Parse Swift Testing output for total/passed/failed/skipped counts
3. Extract failure details (test name, assertion message, file:line)

**Pass criteria:** Zero failures.

**Output:** Total tests, passed, failed, skipped. Failure details if any.

**Note:** This test run also produces coverage data consumed by Section 3. The two sections share a single `swift test` invocation to avoid running the suite twice.


### Section 3: Code Coverage

**Purpose:** Report test coverage metrics as a hierarchical filesystem tree — per-file, per-directory, per-target.

**Method:**
1. After Section 2's test run completes, extract coverage path:
   ```bash
   cd Tavern && swift test --show-codecov-path
   ```
2. Parse the LLVM coverage export JSON with `jq`, filtering to project sources only (exclude ClodKit/ViewInspector checkouts):
   ```bash
   jq '[.data[0].files[]
     | select(.filename | contains("/Tavern/Sources/"))
     | {file: (.filename | split("/Sources/")[1]),
        covered: .summary.lines.covered,
        total: .summary.lines.count,
        percent: .summary.lines.percent}
   ] | sort_by(.file)' < coverage.json
   ```
3. Build a **hierarchical coverage table** mirroring the filesystem:
   - List every file with its lines covered, total lines, and coverage %
   - Roll up directory-level coverage by summing covered/total lines across all files in that directory
   - Roll up target-level coverage (TavernCore/, TavernKit/, Tiles/, Tavern/) the same way
   - Show overall project coverage at the top

**Hierarchy format:**
```
Sources/ (overall)
├── TavernCore/ (directory rollup)
│   ├── Chat/ (directory rollup)
│   │   ├── ChatViewModel.swift (per-file)
│   │   └── FileMentionAutocomplete.swift (per-file)
│   ├── Commands/ (directory rollup)
│   │   ├── ... (each file)
│   ...
├── TavernKit/ (directory rollup)
│   ├── ... (each file)
├── Tiles/ (directory rollup)
│   ├── ChatTile/ (directory rollup)
│   │   ├── ... (each file)
│   ...
└── Tavern/ (directory rollup)
    ├── ... (each file)
```

**Pass criteria:** Report against configurable per-module/file targets. No fixed threshold — targets are set externally and may vary by module. The report shows the numbers; target enforcement is a separate concern.

**Output:** Hierarchical coverage table with per-file, per-directory, and per-target line coverage. Every file appears in the table.


### Section 4: Spec Conformance

**Purpose:** Semantic verification that code satisfies spec properties.

**Method:**
1. Invoke `/attest-report` (swarm-orchestrated attestation across all active spec modules)
2. After completion, read the generated `docs/4-docs/attestation-report_{date}.md`
3. Extract the executive summary table (CONFORMANT / PARTIAL / NON-CONFORMANT / NOT ASSESSED counts)
4. Extract the top gaps list (must-have requirements that are NON-CONFORMANT or have critical unsatisfied properties)

**Pass criteria:** Informational — no pass/fail. The attestation verdicts speak for themselves.

**Output:** Verdict distribution table, overall conformance rate, top 10 gaps ranked by priority.


### Section 5: Pipeline Traceability

**Purpose:** Verify the PRD → spec → code → tests pipeline has no gaps.

**Method:** (replicates `/audit-spec` logic inline)
1. Read `docs/1-prd/prd_2026-01-19.md` and extract all section headers (§1–§21)
2. Read `docs/2-spec/000-index.md` and extract the coverage matrix (PRD section → spec module mapping)
3. For each spec module: read the file, count actual requirement headers (`### REQ-PREFIX-NNN:`), compare against claimed count in index
4. Scan for orphaned provenance markers (MARK comments referencing requirement IDs that don't exist in any spec module)

**Pass criteria:** 100% PRD coverage. Zero claimed-vs-actual count discrepancies. Zero orphaned provenance markers.

**Output:** PRD coverage %, module health table (claimed vs actual counts), orphaned provenance list.


### Section 6: Provenance Coverage

**Purpose:** Measure how thoroughly requirements are traced to code and tests.

**Method:** (replicates `/spec-status` logic inline)
1. Parse all spec modules (`docs/2-spec/002-*.md` through `025-*.md`) for requirement IDs
2. Scan `Tavern/Sources/**/*.swift` for code provenance: `// MARK: - Provenance:.*REQ-[A-Z]+-[0-9]{3}`
3. Scan `Tavern/Tests/**/*.swift` for test provenance:
   - Swift Testing tags: `.tags(.*\.req[A-Z]+[0-9]+)`
   - MARK comments: `// MARK: - Provenance:.*REQ-[A-Z]+-[0-9]{3}`
4. Compute per-module: total requirements, implemented count, tested count
5. Derive status per requirement: `specified` / `implemented` / `tested`

**Pass criteria:** Informational. Coverage improves incrementally per ADR-007 backfill strategy.

**Output:** Per-module table (requirement count, implementation%, test%), overall summary.


### Section 7: Beads Audit

**Purpose:** Snapshot of issue tracking state.

**Method:**
1. Run `~/.claude/scripts/beads_audit.sh` to export all beads
2. Run `bd list -n 0 --json` to get structured bead data (**`-n 0` is mandatory** — without it, bd returns a truncated default page)
3. Compute: total count, status breakdown (open / in_progress / closed), priority distribution (P0–P4)
4. Flag any P0 (critical) open beads

**Pass criteria:** Informational.

**Output:** Bead count, status breakdown table, priority distribution, list of any P0 open beads.


### Section 8: Structural Rules

**Purpose:** Verify code conventions mandated by CLAUDE.md, ADRs, and the honor system.

Eight checks, each producing PASS or WARN:

#### 8a. Test Timeouts

**Rule:** Every `@Suite` declaration must include `.timeLimit()`.
**Source:** Testing best practice — unbounded tests can hang CI.
**Method:** Grep for `@Suite(` in `Tavern/Tests/**/*.swift`. For each match, verify `.timeLimit` appears within the same `@Suite(...)` attribute. Report any `@Suite` without a timeout.
**Canonical pattern:**
```swift
@Suite("My Tests", .timeLimit(.minutes(5)))
```

#### 8b. Preview Blocks

**Rule:** Every SwiftUI `View` struct must have a `#Preview` block in the same file.
**Source:** ADR-006.
**Method:**
1. Find files containing `struct.*:.*View` in `Tavern/Sources/Tavern/Views/` and `Tavern/Sources/Tiles/*/`
2. For each file, check whether `#Preview` also appears
3. Report files with View structs but no preview

#### 8c. Logging

**Rule:** Every source file in TavernCore (excluding Testing/) should have a Logger instance.
**Source:** CLAUDE.md Instrumentation Principle — logs must diagnose issues without screenshots.
**Method:** Grep for `Logger(` or `TavernLogger` in `Tavern/Sources/TavernCore/**/*.swift`, excluding `Testing/` subdirectory. Report files without any logger.

#### 8d. Provenance Markers

**Rule:** Every non-test, non-testing, non-TavernKit source file should have a `// MARK: - Provenance:` comment.
**Source:** ADR-007.
**Method:** Find all `.swift` files in `Tavern/Sources/` excluding `Testing/` and `TavernKit/`. Check each for `// MARK: - Provenance:`. Report files without.

#### 8e. @MainActor on ViewModels

**Rule:** Every file named `*ViewModel.swift` must contain `@MainActor`.
**Source:** CLAUDE.md concurrency rules, ADR-001 layer structure.
**Method:** Glob for `*ViewModel.swift` in `Tavern/Sources/`. Grep each for `@MainActor`. Report any without.

#### 8f. ServitorMessenger Dependency Injection

**Rule:** Every type conforming to `Servitor` protocol must accept `ServitorMessenger` via constructor injection.
**Source:** ADR-003.
**Method:** Find files containing `Servitor` protocol conformance in `Tavern/Sources/TavernCore/Servitors/`. Check init signatures for `ServitorMessenger` or `messenger:` parameter. Report any missing.

#### 8g. No Blocking Calls

**Rule:** No `Thread.sleep` or `DispatchSemaphore.wait` in production source code.
**Source:** CLAUDE.md concurrency rules — these block the cooperative thread pool.
**Method:** Grep `Tavern/Sources/` (excluding `Testing/` and test targets) for `Thread\.sleep` and `DispatchSemaphore.*\.wait`. Report any matches with file:line.

#### 8h. Layer Violations

**Rule:** Import direction must follow the layer model. Violations:
- Tiles must NOT import `TavernCore` (depend on `TavernKit` only)
- `TavernKit` must NOT import `TavernCore` or `ClodKit`
- `TavernCore` must NOT import `Tavern` (the app target)
**Source:** ADR-001 (layer structure), ADR-008 (tileboard architecture).
**Method:** Grep `import` statements in each layer's source files. Report any that violate the dependency direction.


### Section 9: Architecture

**Purpose:** Validate the SPM dependency graph matches the intended layer model.

**Method:**
1. Read `Tavern/Package.swift` and extract target dependency declarations
2. Build the actual dependency graph from `.target(name:, dependencies:)` entries
3. Compare against the intended layer model:
   ```
   TavernKit (foundation, zero dependencies)
     ← ChatTile, ServitorListTile, ResourcePanelTile, PermissionSettingsTile, ApprovalTile (leaf tiles)
     ← TavernBoardTile (composes all tiles)
     ← TavernCore (business logic, depends on ClodKit + TavernKit)
     ← Tavern (app, depends on TavernCore + TavernBoardTile)
   ```
4. Report any dependencies that don't match this model

**Pass criteria:** Zero violations. (SPM enforces this at compile time, but the check documents and verifies the intended architecture explicitly.)

**Output:** Dependency graph summary, any violations listed.


### Section 10: Informational Reports

**Purpose:** Surface useful data without targets or recommendations. Information only.

#### 10a. TODO/FIXME/HACK Audit

**Method:** Grep `Tavern/Sources/` and `Tavern/Tests/` for `TODO`, `FIXME`, `HACK` (case-insensitive). List each with file:line and the comment text.

**Output:** Count per category, full list sorted by file.

#### 10b. Unwired Code Analysis

**Purpose:** Identify code that exists but isn't connected to anything — then diagnose *why*. "Unwired" means the declaration has no callers or references outside its own file. The interesting question isn't "can we delete it?" but "why isn't this wired up?"

**Why this check matters:** In an agent-driven development workflow, a common failure mode is that an agent implements a feature — writes the type, the methods, the tests — but doesn't complete the wiring. The agent's session ends, the code passes review because it compiles and tests pass, but the feature silently sits disconnected. No one notices because the code *looks* done. Over time, the codebase accumulates well-tested, well-written code that doesn't actually do anything at runtime.

This check is the systematic backstop against that failure mode. Every `/verify` run surfaces unwired code that accumulated since the last run, ensuring that incomplete wiring doesn't silently persist across sessions. Most unwired code represents development gaps — features built but not yet connected. The analysis catches what falls through the cracks between implementation sessions and makes the gap visible so it can be addressed.

**Method:** Grep-based analysis (not compiler-level, inherently imprecise — false positives expected):
1. Find all type declarations (`class`, `struct`, `enum`, `protocol`) and function declarations (`func`) across `Tavern/Sources/`
2. For each declaration, search the entire `Tavern/` tree (Sources + Tests) for references outside the declaring file
3. Flag types/functions with zero references outside their own file

**This analysis must be exhaustive.** Every declaration is checked. No sampling, no shortcuts, no "too expensive to run" skipping.

**Categorization:** For each unwired declaration, classify as one of:
- **Development gap** — Code that was written for a purpose that hasn't been wired up yet. The wiring is incomplete, not the code. Examples: error message mappings that exist but aren't called from UI, API surface built ahead of its consumers, provider implementations awaiting integration.
- **Obsolete** — Code that was superseded by a different approach and can be removed. Examples: old implementations replaced during refactoring, experimental code that was abandoned.
- **Premature API** — Public surface area that was declared speculatively but has no consumer yet. May become useful, may not.

In practice, most findings in an actively developed project will be development gaps.

**Output:** Complete list of unwired declarations with file:line, organized by classification. Each entry includes a brief note on why the code appears unwired and which classification applies.

#### 10c. Dependency Freshness

**Method:**
1. `cd Tavern && swift package show-dependencies` to get current versions
2. For ClodKit: `gh api repos/{owner}/{repo}/releases/latest` to check latest release
3. For ViewInspector: same approach
4. Compare current vs latest

**Output:** Table showing dependency, current version, latest version, status (current/outdated).

#### 10d. File Complexity

**Method:**
1. `wc -l` on every `.swift` file in `Tavern/Sources/` — flag files over 500 lines
2. Count `func ` occurrences per file — report top 20 sorted descending

**Output:** Large files table (path, line count), function count table (path, function count). Sorted by count descending.


## Execution Strategy

All independent streams launch in parallel to minimize wall-clock time:

```
Phase 1 — Launch all independent work streams:
  ├─ Stream A: redo Tavern/build (background)              → Section 1
  ├─ Stream B: swift test --enable-code-coverage (background) → Sections 2, 3
  ├─ Stream C: All grep-based structural rules (fast, inline) → Sections 8, 9
  ├─ Stream D: Provenance scan (grep-based, inline)         → Section 6
  ├─ Stream E: Beads audit (background)                     → Section 7
  ├─ Stream F: Informational reports (grep + gh, inline)    → Section 10
  └─ Stream G: Attestation swarm (background agent)         → Section 4

Phase 2 — After Streams A-F complete:
  └─ Stream H: Pipeline traceability (inline)               → Section 5
      (depends on provenance data from Stream D)

Phase 3 — After all streams complete:
  └─ Compile report → docs/4-docs/verification-report_{date}.md
```


## Report Format

```markdown
# Verification Report — {YYYY-MM-DD}

**Generated:** {timestamp}
**Duration:** {elapsed}

## Executive Summary

| Section | Status | Detail |
|---------|--------|--------|
| Build Health | PASS/FAIL | 0 warnings / N warnings |
| Test Health | PASS/FAIL | N/N passed, N failed |
| Code Coverage | INFO | XX% overall |
| Spec Conformance | INFO | N conformant, N partial, N non-conformant, N not assessed |
| Pipeline Traceability | PASS/WARN | N% PRD covered, N discrepancies |
| Provenance Coverage | INFO | N% code, N% test |
| Beads | INFO | N total, N open, N critical |
| Structural Rules | PASS/WARN | N/8 pass, N violations |
| Architecture | PASS/WARN | N violations |
| Informational | — | N TODOs, N large files, deps current/stale |

## Section 1: Build Health
(warning count, categorized list)

## Section 2: Test Health
(total, passed, failed, skipped, failure details)

## Section 3: Code Coverage
(overall %, per-target table, per-file table)

## Section 4: Spec Conformance
(verdict distribution, top gaps)

## Section 5: Pipeline Traceability
(PRD coverage, module health, orphaned provenance)

## Section 6: Provenance Coverage
(per-module implementation% and test%)

## Section 7: Beads Audit
(count, status breakdown, priority distribution, P0 list)

## Section 8: Structural Rules
(per-check PASS/WARN, violation details)

## Section 9: Architecture
(dependency graph, any violations)

## Section 10: Informational
(TODO/FIXME/HACK list, dead code candidates, dependency freshness, file complexity)

## Action Items

Ranked by priority:
1. **CRITICAL** — test failures, build failures
2. **HIGH** — non-conformant must-have requirements, P0 open beads
3. **MEDIUM** — structural rule violations, provenance gaps
4. **LOW** — informational items, suggestions
```

## Alternatives Considered

### Shell script instead of slash command
Rejected. The suite combines mechanical checks (grep, build, test) with analytical work (parsing attestation results, categorizing gaps, ranking action items). A slash command lets Claude handle the analytical parts natively while running bash for mechanical parts.

### Multiple separate commands (status quo)
Rejected. The value is the single combined view. Users who want a specific check can still run the individual commands (`/attest-report`, `/spec-status`, etc.) à la carte.

### CI pipeline
Not rejected, but orthogonal. The `/verify` command is the on-demand version. A CI pipeline could invoke the same checks in the future. The ADR specification would serve as the CI pipeline's requirements document.

### Fixed coverage thresholds
Rejected. Coverage targets vary by module — deferred modules, UI code, and infrastructure layers have different expectations. The report shows numbers; targets are a separate, configurable concern.


## Consequences

- All verification checks are specified in one place (this ADR)
- Adding a new check means updating this ADR and the `/verify` slash command
- The report format becomes a project artifact that tracks health over time
- Individual commands (`/attest-report`, `/spec-status`, `/audit-spec`, `/beads-audit`) remain available for à la carte use


## References

- ADR-001 (Layer Structure) — layer violation checks (8h, Section 9)
- ADR-002 (Testing Grade System) — test execution scope (Section 2)
- ADR-003 (Agent Mocking Strategy) — ServitorMessenger DI check (8f)
- ADR-006 (Preview Requirements) — preview block check (8b)
- ADR-007 (Provenance Tracking) — provenance checks (Sections 5, 6, 8d)
- ADR-008 (Tileboard Architecture) — layer model for tile isolation (8h, Section 9)
- CLAUDE.md Honor System — logging (8c), @MainActor (8e), blocking calls (8g)
- PRD §19.4 (Completeness and Correctness Standards) — pipeline traceability (Section 5)
