# Semantic Conformance Attestation

Analyze whether code and tests actually satisfy the behavioral properties specified in requirements — not just whether provenance markers exist.

**Usage:**
- `/attest REQ-AGT-001` — Single requirement
- `/attest REQ-AGT` — All requirements with a prefix (one module)
- `/attest 004` — All requirements in spec module 004

## Process

### Phase 1 — Mechanical Gathering

#### 1. Parse Target

Parse the target from: $ARGUMENTS

Determine the invocation mode:

- **Single ID** (`REQ-XXX-NNN`): Use directly
- **Prefix** (`REQ-XXX`): Find the module in `docs/2-spec/000-index.md` Module Status Overview table by matching the Prefix column. Read that spec file and extract all requirement IDs matching `^### (REQ-[A-Z]+-[0-9]{3}):`
- **Module number** (`NNN`): Look up the filename in `docs/2-spec/000-index.md` Module Status Overview table by matching the Doc # column. Read that spec file and extract all requirement IDs matching `^### (REQ-[A-Z]+-[0-9]{3}):`
- **No argument or invalid**: Read the Module Status Overview from `docs/2-spec/000-index.md`, list the available prefixes and module numbers, and ask the user to pick one

#### 2. Read Spec Blocks

For each requirement ID, read its spec block from the appropriate `docs/2-spec/*.md` file. Extract:

- Title
- Source (PRD section reference)
- Priority
- Status
- Properties list (all bullet points under Properties)
- Testable assertion (the quoted block or assertion text)

#### 3. Find Code Files

Search `Tavern/Sources/**/*.swift` for provenance markers:

```
// MARK: - Provenance:.*REQ-XXX-NNN
```

Read the matched files. For small files (<300 lines), read the full file. For larger files, read targeted sections around each provenance marker (50 lines of context).

#### 4. Find Test Files

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

### Phase 2 — Semantic Analysis

For each requirement, perform two analyses:

#### Property Analysis

For each **property** listed in the requirement's spec block:

1. Read the property statement
2. Examine the gathered code for evidence of satisfaction
3. Assign a verdict:
   - **satisfied** — Code clearly implements the property; cite specific evidence
   - **partial** — Some aspects implemented but incomplete; explain what's missing
   - **unsatisfied** — No evidence the property is implemented
   - **unexamined** — Cannot assess (e.g., requires runtime behavior observation)

#### Assertion Analysis

For each clause of the **testable assertion**:

1. Read the assertion clause
2. Examine the gathered test code for coverage
3. Assign a verdict:
   - **verified** — A test explicitly exercises this assertion clause; cite the test
   - **partial** — Tests touch the area but don't fully verify the clause
   - **unverified** — No test covers this assertion clause

### Phase 3 — Verdict Synthesis

Roll up per-requirement using **weakest-link** logic:

- All properties satisfied + all assertions verified → **CONFORMANT**
- Mix of satisfied/partial/unsatisfied → **PARTIAL**
- No properties satisfied → **NON-CONFORMANT**
- Priority is `deferred` or no code exists → **NOT ASSESSED** (state the reason)

## Output Format

### Per-Requirement Report Card

For each requirement, output:

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
- Each gap identifies what's missing and where
```

### Multi-Requirement Summary Table

When attesting a prefix or module (multiple requirements), prepend a summary table before the individual report cards:

```markdown
## Attestation Summary — Module NNN (Name)

| Req ID | Title | Verdict | Properties | Assertions | Gaps |
|--------|-------|---------|------------|------------|------|
| REQ-XXX-001 | Title | PARTIAL | 4/5 | 1/3 | 3 |
| REQ-XXX-002 | Title | CONFORMANT | 4/4 | 3/3 | 0 |
...

**Module verdict: N conformant, N partial, N non-conformant, N not assessed**
```

Then output individual report cards for each requirement.

## Key Files

- `docs/2-spec/000-index.md` — Prefix-to-module mapping and module listing
- `docs/2-spec/*.md` — Spec modules containing requirement definitions
- `docs/1-prd/prd_2026-01-19.md` — PRD (for source field context)
- `Tavern/Sources/**/*.swift` — Code provenance
- `Tavern/Tests/**/*.swift` — Test provenance

## Output

Display the full attestation directly in the conversation. Do not write to a file unless explicitly asked.
