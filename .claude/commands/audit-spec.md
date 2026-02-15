# Spec Audit — PRD-to-Spec Coverage Verification

Walk the entire pipeline checking for gaps between PRD, spec modules, code, and tests.

## Process

### 1. Extract PRD Section Headers

Read `docs/1-prd/prd_2026-01-19.md` and extract all `## N. Title` and `## N.N Title` section headers. Build a list of all PRD sections with their numbers and titles.

### 2. Load Coverage Matrix

Read `docs/2-spec/000-index.md` and extract:

**PRD Coverage Matrix:** Map each PRD section to its spec module(s) and status. Note which sections are "context-only" (no spec needed).

**Module Status Overview:** Extract the claimed requirement counts per module (the "Requirements Count" column).

### 3. Verify Each Spec Module

For each spec module listed in the index (`002-invariants.md` through `018-spec-fidelity.md`):

1. Read the spec file
2. Count actual requirement headers matching `^### (REQ-[A-Z]+-[0-9]{3}):`
3. Compare against the claimed count in the index
4. Extract the Upstream References section — verify PRD sections are listed
5. Extract the Downstream References section — note claimed code and test directories

### 4. Verify Downstream References

For each spec module's Downstream References:
- Check if claimed code directories exist (e.g., `Tavern/Sources/TavernCore/Agents/`)
- Check if claimed test directories exist (e.g., `Tavern/Tests/TavernCoreTests/`)
- Flag missing directories

### 5. Compute Provenance Coverage

Run the same provenance scanning as `/spec-status`:

- Scan `Tavern/Sources/**/*.swift` for `// MARK: - Provenance:.*REQ-[A-Z]+-[0-9]{3}`
- Scan `Tavern/Tests/**/*.swift` for `.tags(.*\.req([A-Z]+)(\d{3})` and `// MARK: - Provenance:.*REQ-`
- Map requirement IDs to code files and test files
- Derive status per requirement: specified / implemented / tested

### 6. Output Section 1 — PRD Coverage

```
## PRD Coverage

| PRD Section | Title | Spec Module | Index Status | Verified |
|-------------|-------|-------------|--------------|----------|
| §1 | Executive Summary | (context) | — | — |
| §2 | Invariants | 002-invariants.md | complete | ✓ |
...
```

"Verified" column: ✓ if the spec module exists and its Upstream References mention this PRD section. ✗ if not.

### 7. Output Section 2 — Spec Module Health

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

### 8. Output Section 3 — Gap Analysis

Report three categories of issues:

**Critical Gaps** — Must-have requirements with no implementation path:
```
### Critical Gaps
- REQ-AGT-001 (must-have): Jake Daemon Agent — no code provenance
- REQ-AGT-002 (must-have): Mortal Agents — no code provenance
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

### 9. Summary Statistics

```
## Summary

- **PRD sections:** 45 total, 41 covered, 4 context-only
- **Spec modules:** 17 total, all present
- **Total requirements:** 162
- **Implementation coverage:** 0/162 (0%)
- **Test coverage:** 0/162 (0%)
- **Index accuracy:** X/17 modules match claimed counts
- **Downstream references:** X/Y directories verified
```

## Key Files

- `docs/1-prd/prd_2026-01-19.md` — PRD
- `docs/2-spec/000-index.md` — coverage matrix and module index
- `docs/2-spec/002-*.md` through `docs/2-spec/018-*.md` — spec modules
- `Tavern/Sources/**/*.swift` — code provenance
- `Tavern/Tests/**/*.swift` — test provenance

## Output

Display the full audit directly in the conversation. Do not write to a file unless explicitly asked.
