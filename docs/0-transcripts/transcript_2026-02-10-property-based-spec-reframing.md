# Transcript: Property-Based Spec Reframing

**Date:** 2026-02-10
**Type:** Specification methodology / properties vs workflows

---

[U] Going through the prds and specs, I want to make sure we're framing all of these more in terms of properties that must hold, than just in mechanical step by step workflows. Can you give me a gap analysis on where the spec is today vs what I want?

[C] Let me explore the PRDs and specs to understand their current framing.

*[T] Launched parallel exploration of PRD and spec documents to identify sections framed as properties/invariants versus sections framed as mechanical workflows. The goal is property-based specifications: "whenever X, then Y" rather than "first do A, then B, then C."*

[C] After thorough analysis of both PRD and all 16 spec modules, here's the gap analysis:

**The PRD is already ~80% property-based** — it's in good shape. The specs are mixed.

**Four gaps identified:**

1. **Prose is procedural, testable assertion is the actual property** — The biggest pattern. 18 REQs across 6 specs narrate step-by-step procedures, then state the real property as an afterthought in the testable assertion. The fix: promote the property to be the primary framing.

2. **Section 3 (Behavior) is universally mechanical workflows** — Every spec has flowcharts and sequence diagrams showing "first A, then B, then C." These should become property tables or state invariant descriptions.

3. **Mixing "what must hold" with "how to implement"** — Several specs describe implementation details that should live in code, not spec. The spec should state properties; implementation proves the properties.

4. **Example workflows conflated with procedural specs** — Some illustrative examples (like "Gang of Experts" workflow sketch) are valuable for showing what the system supports, but they're mixed with actual requirements.

**Priority order for rewriting:**
1. deterministic-shell.md (most workflow-heavy)
2. spawning.md
3. operating-modes.md
4. lifecycle.md
5. communication.md
6. user-experience.md
7. Remaining specs

The approach: For each requirement, adopt property-first structure. Drop narrative prose, make properties the spec. Replace Section 3 flowcharts with property tables or state invariants. Keep state machine diagrams (they ARE properties). Preserve illustrative workflow examples as "what this looks like in practice."

[U] Do it.

[C] Let me read the remaining specs I need to modify, then start rewriting in priority order.

*[T] Reading all 16 spec files to prepare for systematic property-based refactoring. Will work through them in waves: highest-priority workflow-heavy specs first, then moderate cases, then lighter touches.*

[C] I have all the files read. Let me rewrite the four highest-priority specs first — deterministic-shell, spawning, operating-modes, and lifecycle — all in parallel.

*[T] Rewriting specs with new structure: Requirements now lead with **Properties:** blocks (the properties ARE the spec). Narrative prose removed; what remains is property statements. "Section 3: Behavior" renamed contextually and converted from flowcharts to property tables/state invariants.*

[C] Wave 1 done. Now wave 2 — the remaining specs that need moderate work. I'll rewrite communication, user-experience, agents, sandbox, observability, doc-store, and view-architecture in parallel.

[C] Wave 2 done. Now the remaining specs that need lighter touches: system-architecture, invariants, quality, workflows, and v1-scope.

[U] I think you misunderstood some things. One of the features in the app is workflows, and there you want to show what good example workflows look like, as well as the properties that define workflows. That gang of experts pattern was a sketch of an example workflow.

[C] You're right — I conflated "illustrative example of what the system supports" with "procedural spec of how the system works." The Gang of Experts diagram isn't specifying internal mechanics, it's showing what a workflow looks like when you use the system. That's valuable context that belongs in the spec.

Let me fix workflows.md to restore the example workflow sketches alongside the properties.

*[T] Key insight: There's a difference between (1) procedural specs of how the system works internally, and (2) illustrative examples showing what the system enables users to do. The former should be properties; the latter should remain as examples/sketches. The Gang of Experts workflow diagram is type (2) — it illustrates what multi-agent orchestration looks like in practice, not how the system implements it.*

[C] V1-scope is actually fine structurally — the scope map and verification flow are both illustrative (what v1 looks like in action). But the requirements need property framing. Let me update it and system-architecture.md together.

[C] All 16 specs are updated. Here's a summary of what changed across the board:

**Structural changes (all specs):**
- Requirements now lead with **Properties:** blocks — the properties ARE the spec
- Narrative prose removed; what remains is property statements
- "Section 3: Behavior" renamed contextually (Model/Properties/Examples) and converted from flowcharts to property tables
- State machine diagrams kept (they're property specifications)
- Sequence diagrams removed when they showed internal implementation steps
- Illustrative workflow examples kept (they show what the system enables)

**Content preserved:**
- Example workflows (Gang of Experts, Rule of Five, Verification Layers) as illustrations of what the workflow system supports
- V1 verification flow as an end-to-end user experience example
- Scope maps showing feature boundaries

**The key distinction:** Properties specify what must hold. Examples show what it looks like in practice. Both belong in specs, but with different purposes.

___

[S] **Property-based specification methodology.** The shift from procedural workflows to property-based specs means requirements state "whenever X, then Y" (testable invariants) rather than "first do A, then B, then C" (implementation recipes). Properties are composable, implementation-agnostic, and verifiable.

[S] **Two types of diagrams.** State machine diagrams ARE property specifications (they show valid states and transition constraints). Sequence diagrams showing step-by-step internal mechanics should become property tables. But illustrative examples showing what the system enables users to do should remain — they provide valuable context without constraining implementation.

[S] **The testable assertion pattern.** When a requirement had narrative prose describing steps, then a "testable assertion" stating the actual property, the property was being buried. The fix: promote the property to be the primary framing. The prose can stay as background context, but the property leads.

[S] **Four-gap framework.** (1) Prose procedural, assertion has the property → promote property. (2) Section 3 flowcharts → property tables. (3) "What must hold" mixed with "how to implement" → separate. (4) Example workflows conflated with specs → distinguish illustrative from prescriptive.
