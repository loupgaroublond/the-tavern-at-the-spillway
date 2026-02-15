# Transcript: Redo Skill Operationalization

**Date:** 2026-02-14
**Sessions:** Plan creation + execution
**Topic:** Decomposing the redo patterns tutorial into operational Claude config

---

[U] We created `docs/4-docs/redo-patterns-guide.md` — a human-facing tutorial adapted from the up-dawg project. Now: how might we slice and dice it into things like CLAUDE.md or skills, or any other configuration ideas? What would work best for Claude, in Claude's opinion?

[C] Assessed what's already in CLAUDE.md and how the information gets used during sessions. CLAUDE.md already covers the operational essentials well — all 13 build/test commands, the grade system, output paths, the "after changing project.yml" workflow. That handles 95% of cases.

What's genuinely missing: the dependency graph. Knowing that `build` depends on `icon` and `xcodegen` prevents running things out of order. That's 5 compact lines of high-value information.

What the tutorial covers that Claude doesn't need in-session: redo concepts, script parameters, search algorithm, best practices — Claude learns the same things by reading the `.do` files directly. That content is for humans onboarding, not for Claude.

[T] *Initial instinct was minimal: just add the dependency graph to CLAUDE.md and a memory breadcrumb pointing to the tutorial. But a skill would be better — it loads operational context on demand without bloating CLAUDE.md.*

[U] *(Suggested considering a skill approach)*

[C] Studied the existing skill patterns (`/commit`, `/reader`, `/conceive`). They're action/instruction-oriented, loaded on demand. A `/redo` skill could load build system context when working with `.do` files, keeping CLAUDE.md lean.

Proposed a three-layer approach:

1. **CLAUDE.md** (always loaded) — keeps existing commands + adds a compact dependency graph. No tutorial content.

2. **`/redo` skill** (loaded on demand) — operational instructions: full `.do` file table with dependencies, patterns to follow when modifying scripts, redo quick reference. Not a tutorial — a checklist and reference card.

3. **Tutorial doc** (human reference) — stays in `docs/4-docs/` for humans who want to understand redo concepts, redoconf, and best practices.

[U] *(Approved plan)*

___

[S] **Operationalization Principle: Frequency-Based Placement**

Information needed in 95% of sessions stays in CLAUDE.md (always loaded). Specialized context loads on-demand via skills. Tutorials stay as human documentation — Claude can read source files directly and doesn't need educational framing.

**Three audiences, three formats:**
- CLAUDE.md → essential, always-available operational reference
- Skill → on-demand operational checklist for specialized work
- Tutorial doc → human onboarding and deep reference

**The `/redo` skill** contains: table of all 13 `.do` files with dependencies/redo-always/\$3 status, patterns in use (virtual targets, build log capture, test isolation, stderr), modification guidelines, and redo quick reference.

**The dependency graph** in CLAUDE.md is 7 lines showing `run → build → {icon, xcodegen, project.yml, Package.swift}` plus `test-grade4 → build`, `all → build`, `clean → stop`.
