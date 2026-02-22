# Spec Review — Questions 0000

## Q1 — Closed Plugin Set (Doc 003 Req 006)

You say "No one said this was a thing, drop it." But ADR-001 selected "Closed Plugin Set" as one of the 7 architecture shapes, and it's referenced in CLAUDE.md ("all agent types known at compile time").

Is the objection that it shouldn't be a *spec requirement* (since it's already an ADR decision), or that the entire concept is wrong and agents should be dynamically loadable?

> Response:
>
>
 let's just drop it from the architecture shapes and leave this completely unspecifi. . I'm not sure it makes any sense to actually say this so we could probably just cross out the sectionion

---


## Q2 — Combine (Doc 003 Req 007)

You note "isn't Combine the old thing that's not interesting to Apple anymore?" The spec already says "AsyncStream over Combine, long-term direction is language-level concurrency." The current code has Combine bridges at the ViewModel boundary.

Should we remove all Combine references from the spec entirely, or keep the note that Combine bridges exist as a transitional reality at the ViewModel boundary?

> Response:
>
>
Only mention combine where it's strictly necessary because otherwise it's not something that we're planning to use

---


## Q3 — Claude Teams / Two-Level Orchestration (Doc 004 Req 007)

You say this "needs a complete rewrite in light of Claude teams" and that Tavern "runs orthogonally to the stuff this tool does." The current REQ-AGT-007 defines Tavern agents vs Task subagents as two levels.

When you say "orthogonally managing top level claude sessions" — does that mean the Tavern manages its own agent tree and Claude's native team/swarm features are a separate concern we don't wrap or abstract? Or is there an integration surface we should spec (e.g., Tavern being aware of Claude's native team agents)?

> Response:
>
>
We need to rewrite it in a way that is agnostic of however Claude internally implements such features. This was the point behind renaming agents to Servitors, to differentiate them. The tavern has is trees of servitors, and each of those may be running a claude session that has multiple agents and subagents all going at the same time.

---


## Q4 — Failure Boundaries (Doc 004)

You describe a system where: "parent agent may say child has failed, kill it, or declare itself has failed. System reverts as much as possible to the state before they existed." Also, the agent can "consider whether to spare the remaining tokens in its budget, or keep going."

This sounds like it needs its own requirement or section. Where should it live — lifecycle (doc 006), deterministic shell (doc 008), or the new unified state/mode doc you want created?

> Response:
>
>

failure boundaries probably belongs in a new doc for "servitor trees" to more cleanly define what those are, and how the different operating modes dictate the servitors actions at that time in its position in the tree. failure boundaries is a property over parts of the tree, which determines what rules to follow if one of the nodes in that tree fails. in erlang, this is done so a replacement group of actors can be brought back online quickly, in the event of many kinds of failures, and here, we might option sometimes to invalidate a whole gang working on a queue if there's some catastrophic error with just one worker, and in other cases, when breaking down a task, just restarting a worker if the previous one goes off the rails

---


## Q5 — Capability Delegation (Doc 005)

You describe a significant system: summon is async (returns promise ID), then a separate `delegate` command using a handle. The spawned agent's main actor receives the capability handle and waits for session notification that it can invoke things.

You also say "put a pin in the capabilities part, because we need to back write this into the PRDs" (doc 004).

Should we spec capability delegation now (even as a stub section in doc 005 or a new doc), or just note it as pinned for future design?

> Response:
>
>
this needs to be a new doc in the specs, and yes, let's start filling it out. we should also make sure we have PRDs to suit

---


## Q6 — Naming Structure (Doc 005 Reqs 004+006)

You say "each tree may have a different naming scheme, and Jake has to cycle through them" and "tier 1 names is a set of name sets. Jake will rotate through assigning those, until they're depleted or the user unlocks other tiers."

Can you confirm this structure:
- A **name set** = a themed collection (e.g., "The Regulars" cast is one name set)
- **Tier 1** = the collection of all initial name sets available
- Jake **rotates** which set he pulls from for each new agent tree
- Higher tiers unlock when tier 1 is depleted or via user action

Or is the structure different?

> Response:
>
>
Mostly correct. when he assigns a name set to a top level Servitor, all the children take names out of that set. the top servitor asks jake for another nameset, if that one runs out. Multiple trees may be using the same nameset, so we need to manage concurrency issues here.

---


## Q7 — Unified State Doc (Doc 007)

You want all agent states and modes consolidated into a single new spec doc, with redundant sections in docs 004, 006, 007 deprecated. You also identify three orthogonal concepts that the current spec conflates:

1. **Backgrounding** — agent doesn't get a first-class chat window
2. **Perseverance** — agent is not allowed to go idle
3. **User presence** — user has joined or left the agent's session

Questions:
- Should these be modeled as three independent boolean-ish properties that can combine in any permutation?
- Should this new doc also reconcile the inconsistent lifecycle graphs from docs 004, 006, and 007 into one canonical state machine?
- What module number for the new doc — §018 (next available)?

> Response:
>
>
Let's first get a new doc, any next number will do. then, lay out all the current states, including those three booleans. we'll need to work on that to make it cohere after, but i can't do that until i see it all together at once.

---


## Q8 — Continuation Loop (Doc 008 Req 007)

You said "Can you elaborate more on what this is? I don't even understand what it's trying to do here."

REQ-DET-007 describes a mechanism where an agent can perform multiple actions in a single turn with feedback between them — make a tool call, get the result, make another tool call, etc., before yielding back. This is actually how Claude already works natively (multi-step tool use within a single turn).

Should this be:
- **Dropped** as "just describing how Claude works" (like you said about doc 010 Req 005)?
- **Kept but reframed** to spec a deterministic shell property around it (e.g., limits on continuation depth, or the shell's role in providing feedback between steps)?

> Response:
>
>
i think this can just be dropped from the spec

---


## Q9 — Chat Discussion vs Session (Doc 010 Req 005)

You introduce a new first-class concept: "there is a chat discussion that persists for the lifetime of a servitor. Then there are sessions of Claude underneath, where we can sometimes continue a session, or create a new one. However, we'll provide a context window in the app that gives the user a contiguous experience."

This separates the user-visible experience (chat discussion = contiguous) from the underlying implementation (Claude sessions = may be multiple, may expire and be replaced).

Where should this concept live as a requirement — doc store (010), agents (004), or the new unified state/mode doc?

> Response:
>
>
this sounds like a totally new document where we can delineate all the rules

---


## Q10 — "Escaped" (Doc 011)

The spec mentions "escaped" as a potential gap in the sandbox context. You say "define 'escaped' before we discuss whether there's an actual gap here."

My interpretation: "escaped" means an agent's actions reaching outside its sandbox boundary — writing files outside the sandbox, making unauthorized network calls, accessing resources beyond its granted capabilities.

Is that the right definition, or does "escaped" mean something else to you?

> Response:
>
>
if that is the definition of "escaped", shouldn't the sandbox simply make that impossible? the agent should not be able to see paths outside the sandbox. unauthorized network calls must be dropped and reported. there's no escape

but if you meant that it found a vulnerability in the sandbox and broke out, then, putting it back to a question, how would we know?

---


## Q11 — Expert Prompts + Workflow Metrics (Doc 012)

Two things you flagged:

**Expert prompts:** You asked "What the heck are expert prompts?" REQ-WRK-005 defines "Gang of Experts" as specialized prompt templates for specific tasks (e.g., a security review prompt, a performance analysis prompt). These aren't persistent agent entities — they're prompt configurations that get applied to temporary agents for specific workflow steps.

Is the concept clear enough to keep (perhaps rewritten for clarity), or should it be dropped?

**Workflow metrics:** You asked "Why do we need workflow metrics?" Should I interpret this as "drop them" or as a genuine question about their value proposition that you'd like me to answer?

> Response:
>
>
Expert prompts isn't a question. they're part of workflows. drop it.

For metrics, it's both, give me an answer if there's a real discussion to be had, or drop it if it's just extra crap we don't need and can't properly compute

---


## Q12 — New Spec Sections (Doc 013)

You flagged that keyboard shortcuts, accessibility, and search each need their own spec treatment. They're currently absent from the spec entirely.

Should these be:
- **New numbered spec modules** (§018, §019, §020) — gives each topic full weight and room to grow
- **Subsections within the UX spec** (doc 013) — keeps UX concerns co-located but may bloat the doc

> Response:
>
>

new full documents/modules with their own numbers
---


## Q13 — View Terminology (Doc 014 Req 002)

You want a different term than "modes" for view presentations (different visual representations of the same data). "Modes" is overloaded with agent operating modes.

Candidates:
- **presentations** — your initial suggestion
- **facets** — implies different faces of the same thing
- **aspects** — similar to facets
- **perspectives** — more spatial/observer-oriented
- **lenses** — implies filtering/transformation
- **arrangements** — more layout-focused

Preference?

> Response:
>
>

they're called representations, and the language used in the app is "view as ..." which is just the name of the specific representation. ideally, the R-word only needs to show up in code alone, and not in the UI

---


## Q14 — Grade 2.9 (Doc 016)

You say "add grade 2.9 where we use a local LLM that's free."

Can you elaborate:
- What's the local LLM setup? (Ollama, llama.cpp, MLX, etc.)
- What's the purpose? Tests that need LLM behavior but shouldn't cost API money?
- What distinguishes this from Grade 2 (mocked) and Grade 3 (real Claude)?

> Response:
>
>

TBD on exactly the setup, but probably a combo of llama-ish and apple intelligence
the purpose is cheaper ways to do grade 3 testing more frequently, and faster, when doing work that impacts grade 3 tests significantly, saving actual grade 3 runs for wrap up stages in development
it's just slightly less than grade 3, so it's grade 2.9
---


## Q15 — Mutation Testing (Doc 016)

You asked "What is mutation testing?"

Mutation testing is a technique where you deliberately introduce small bugs ("mutations") into the source code — e.g., changing `>` to `>=`, flipping a boolean, removing a line — and then run the test suite. If all tests still pass despite the mutation, that reveals a gap in test coverage (something should have caught it but didn't).

It's thorough but computationally expensive (can take 10-100x longer than normal test runs).

The spec apparently proposed it. Do you want it:
- **Kept** as a future aspiration or Grade 5 concern?
- **Dropped** entirely?
- **Pinned** for later evaluation?

> Response:
>
>
Let's make the language more clear then about what this is. this is definitely the sort of testing we should be doing on this app.

---


## Q16 — Regressions (Doc 016)

You asked: "Regressions are when the tests fall below the requirements? Or do you mean we need to log runs for metrics analysis?"

Both interpretations are valid spec material:
- **A)** Regression = test results falling below a previously-passing baseline (detection + alerting)
- **B)** Regression = logging test runs over time for trend analysis (metrics + dashboards)

Which interpretation should the spec use? Or both?

> Response:
>
>

In this case, a requirement that all tests must continue to pass is a policy and property that prevents most kinds of regressions.