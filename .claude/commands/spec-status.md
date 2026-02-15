# Spec Status Dashboard

Scan all spec modules and provenance markers to produce a live coverage dashboard.

## Process

### 1. Parse All Spec Modules

Read every spec file matching `docs/2-spec/002-*.md` through `docs/2-spec/018-*.md`. For each file, extract every requirement block:

- **Requirement ID and title** from lines matching `^### (REQ-[A-Z]+-[0-9]{3}): (.+)$`
- **Priority** from `**Priority:** (must-have|should-have|deferred)` within the requirement block
- **Module number and name** from the filename

Build a master list of all requirements with: module, req ID, title, priority.

### 2. Scan Code for Provenance Markers

Search `Tavern/Sources/**/*.swift` for lines matching:
```
// MARK: - Provenance:.*REQ-[A-Z]+-[0-9]{3}
```

Extract each `REQ-PREFIX-NNN` from matching lines. A single MARK line may contain multiple comma-separated requirement IDs. Map each requirement ID to the file(s) it appears in.

### 3. Scan Tests for Provenance Tags

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

### 4. Derive Status

For each requirement:
- `specified` — exists in spec only (no code markers, no test markers)
- `implemented` — has at least one code provenance marker
- `tested` — has at least one test provenance tag (implies implemented)

### 5. Output Per-Module Tables

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

### 6. Output Summary Table

```
## Summary

| Module | Prefix | Total | Specified | Implemented | Tested | Coverage% |
|--------|--------|-------|-----------|-------------|--------|-----------|
| 002-invariants | REQ-INV | 8 | 8 | 0 | 0 | 0% |
...
| **TOTAL** | | **162** | **162** | **0** | **0** | **0%** |
```

Coverage% = (Tested + Implemented) / Total × 100, rounded to nearest integer.

### 7. Flag Anomalies

After the summary table, list any anomalies found:

- **Orphaned provenance:** Code or test files referencing requirement IDs that don't exist in any spec module
- **Must-have gaps:** Must-have requirements still at `specified` status (expected on first run — note this)
- **Deferred-but-implemented:** Requirements marked `deferred` priority that have implementation markers (not necessarily wrong, but worth flagging)

## Key Files

- `docs/2-spec/000-index.md` — module list and requirement counts (use to verify scan completeness)
- `docs/2-spec/002-*.md` through `docs/2-spec/018-*.md` — spec modules
- `Tavern/Sources/**/*.swift` — code provenance markers
- `Tavern/Tests/**/*.swift` — test provenance tags

## Output

Display the full dashboard directly in the conversation. Do not write to a file unless explicitly asked.
