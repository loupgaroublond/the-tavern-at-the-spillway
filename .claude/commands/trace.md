# Requirement Traceability Chain

Trace a single requirement through every pipeline stage: PRD → spec → code → tests.

**Usage:** `/trace REQ-AGT-003`

## Process

### 1. Parse the Requirement ID

Extract the requirement ID from: $ARGUMENTS

The ID must match `REQ-[A-Z]+-[0-9]{3}`. If no valid ID is provided, list available prefixes from `docs/2-spec/000-index.md` and ask the user to specify one.

### 2. Find in Spec

Search `docs/2-spec/*.md` for a heading matching `### REQ-PREFIX-NNN:`. Extract the full requirement block:
- Title
- Source field (PRD section reference)
- Priority
- Properties (all bullet points)
- Testable assertion

Display the full block.

### 3. Trace to PRD

From the `**Source:**` field, extract the PRD section reference (e.g., `PRD §4.1`). Read `docs/1-prd/prd_2026-01-19.md` and find the corresponding section. Extract and display the relevant paragraph(s) that this requirement derives from.

### 4. Search Code Provenance

Search `Tavern/Sources/**/*.swift` for:
```
// MARK: - Provenance:.*REQ-PREFIX-NNN
```

For each match, show:
- File path (relative to `Tavern/`)
- The MARK line itself
- 5 lines of surrounding context (the declaration or function near the marker)

If no matches: report "No code provenance found."

### 5. Search Test Provenance

Search `Tavern/Tests/**/*.swift` for both patterns:

**Tags** (convert `REQ-AGT-003` → `.reqAGT003`):
```
\.tags\(.*\.reqPREFIXNNN
```

**MARK comments:**
```
// MARK: - Provenance:.*REQ-PREFIX-NNN
```

For each match, show:
- File path (relative to `Tavern/`)
- Test function name (look for the nearest `@Test` or `func test` above the match)

If no matches: report "No test provenance found."

### 6. Output Traceability Chain

Summarize as a linear chain:

```
## Traceability: REQ-AGT-003

PRD §4.1 (Agent Types)
  ↓
Spec 004-agents.md — "Drone Agents" [deferred]
  ↓
Code: (none)
  ↓
Tests: (none)
  ↓
Status: specified
```

### 7. Heuristic Mode (Only When Explicitly Requested)

If the user asks for heuristic matching, also search by class/function name patterns derived from the requirement title. For example, for "Jake Daemon Agent", search for `class Jake`, `struct Jake`, etc.

Clearly label all heuristic matches:
```
### Heuristic Matches (not verified by provenance)
- Tavern/Sources/TavernCore/Agents/Jake.swift — contains `class Jake`
```

Do NOT run heuristic mode unless the user explicitly requests it.

## Key Files

- `docs/2-spec/000-index.md` — prefix-to-module mapping
- `docs/2-spec/*.md` — spec modules
- `docs/1-prd/prd_2026-01-19.md` — PRD
- `Tavern/Sources/**/*.swift` — code
- `Tavern/Tests/**/*.swift` — tests

## Output

Display the full trace directly in the conversation.
