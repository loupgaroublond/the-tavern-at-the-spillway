# Transcript: Servitor Naming & MCP Tools Implementation

**Date:** 2026-02-02 16:50

---

## Part 1: Naming the Worker Agents

**[U]** we recently gave jake the ability to spawn new agents. let's come up with a new word for them, btw. we have "daemons" meaning anything running in this framework, but that's overloaded with unix background processes. we have agents, but that's overloaded with subagents and other things in LLM space. we need a name for these actors working inside a tavern, all supervised by jake or another actor with delegation.

also, we had to hack around a lack of mcp tool support previously, and have jake wrap his responses in an extra envelope that can have us spawn another actor. since then, we've updated the SDK, so now we should be able to create in process mcp servers from method / functions. let's start with creating a few tools to spawn these new actors, and dismiss them. plus, get a list of them. only jake has access to these tools.

general principle, when we dismiss an agent, they're effectively paused and don't show up in the window anymore, but we should be able to resummon an agent, by some session id, that effectively "resumes" the agent. we'll talk about what a general "resume after resummon" means later. for now we're just dimsissing with no intent to resume, yet.

the spawn api should strongly discourage jake from providing a custom name or anything. in fact, if we have any parameters at all at this point, they should be named something like "optional" or other language that tells jake most of the time, to simply use no params, as much as possible, ecxetp maybe setting a description or something

**[T]** *The user is setting up multiple parallel concerns:*

1. *Terminology: Need a name for spawned worker agents that doesn't clash with "daemons" (unix) or "agents" (LLM subagents)*
2. *Architecture: Replacing JSON envelope hack with native MCP tools now that SDK supports it*
3. *Functionality: summon + dismiss tools, with future resummon capability*
4. *UX principle: Jake should usually spawn with NO parameters — auto-generated names preferred*

---

**[C]** *Claude launched three parallel exploration agents to understand the codebase:*

1. **Explore agent spawning code** — How current JSON envelope works
2. **Explore Jake's current tool usage** — System prompt and JSON wrapper
3. **Explore ClaudeCodeSDK MCP support** — What SDK provides

*Agents encountered errors (classifyHandoffIfNeeded is not defined) and were interrupted by user.*

---

**[U]** jake is gonna call them the regulars, but lets explore more technical terms like runners, operators, and the like, for the canonical name

**[C]** Great framing! So we're looking for two layers:

1. **Jake's voice** (character flavor): "The Regulars"
2. **Canonical code name** (the actual type/class): ?

Here are technical options for the canonical name:

**Worker-focused:**
- **Servitor** — implies service/serving, fits the tavern theme
- **Operator** — professional, task-oriented
- **Runner** — fast/ephemeral connotation

**Role-focused:**
- **Delegate** — Jake delegates to them
- **Handler** — they handle specific tasks
- **Worker** — straightforward

**Tavern-themed:**
- **Patron** — someone at the tavern
- **Regular** (as code name too) — could work if not confusing
- **Hand** — tavern hand, hired help

**My recommendation:** **Servitor**

Rationale:
- Fits tavern service theme
- Distinct from "daemon", "agent", "subagent"
- Implies they serve Jake's coordination
- Sounds professional in code (`ServitorSpawner`, `dismissServitor()`)
- Jake can still call them "Regulars" in his patter

**[U]** servitor it is

---

## Part 2: MCP Tool Design

**[T]** *The plan document shows a comprehensive Phase 1 implementation:*

- *Rename MortalAgent → Servitor (code)*
- *Jake calls them "Regulars" (character voice)*
- *All worker agents collectively: "Slop Squad"*
- *Create `TavernMCPServer.swift` with `summon_servitor` and `dismiss_servitor` tools*
- *Replace JSON envelope hack with native MCP tool handling*
- *Delete `JakeToolHandler.swift` and continuation loop*

---

**[C]** Let me explore the ClaudeCodeSDK to understand the MCP implementation we'll use.

*Claude reads Package.swift files from both projects, gap analysis from ClodeMonster, session history storage implementation.*

**[C]** Now I have a complete understanding of both SDKs. Let me provide a comprehensive migration plan.

*Claude produces detailed migration plan covering:*

1. **API Comparison** — Protocol-based (current) vs namespace-based (ClodeMonster)
2. **Critical Gaps** — Session history loading, content block parsing, response aggregation, mock infrastructure
3. **Phased Migration Approach:**
   - Phase 0: Gap resolution (port session storage to ClodeMonster)
   - Phase 1: Adapter layer (makes ClodeMonster look like current SDK)
   - Phase 2-9: Core migration, tests, cleanup
4. **Code Transformation Patterns**
5. **Risk Assessment**
6. **Timeline: 12-19 hours estimated**

---

## Part 3: Terminology Decisions

___

**[S]** This session established critical terminology decisions and architectural direction:

### Naming Layer Separation

**Code level (canonical names):**
- **Servitor** — Worker agents spawned by Jake
- **ServitorSpawner** — Factory for creating/dismissing servitors
- **summon** — Verb for creating a servitor
- **dismiss** — Verb for removing a servitor

**Character level (Jake's voice):**
- **"The Regulars"** — Individual servitors (singular/plural)
- **"Slop Squad"** — The whole team of servitors collectively
- **"Summoning"** — Jake's phrasing when spawning

This two-level terminology solves the overloading problem:
- "Daemon" was confusing (Unix background processes)
- "Agent" was overloaded (subagents in LLM space, top-level agents like Jake)
- "Servitor" is distinct and theme-appropriate

### MCP Tool Transition

**From:** JSON envelope hack
```json
{"message": "response", "spawn": {"assignment": "task", "name": "optional"}}
```

**To:** Native MCP tools via `TavernMCPServer`
```swift
summon_servitor(task: String?, name: String?)
dismiss_servitor(id: UUID)
```

**Design principle:** Strongly discourage parameters. Most calls should be `summon_servitor()` with no args — auto-generated names and auto-inferred tasks.

### Phase 1 Scope

Explicitly **NOT** implementing in Phase 1:
- Message forwarding (sending messages to servitors via Jake)
- Resummon (bringing back dismissed servitors)
- Capability distribution (assigning specific tools/permissions)

Phase 1 is **minimal viable dispatcher**: summon + dismiss only.

---

**[S]** The servitor naming decision resolves a fundamental tension in the project's vocabulary:

**The Problem:** Need distinct names for three different agent concepts:
1. Jake (eternal coordinator)
2. Worker agents spawned by Jake
3. Ephemeral subagents within any agent's session

**The Solution:**
- **Jake** — The Proprietor (daemon, per-project)
- **Servitor** — Worker agents (mortal, task-bound, appear in sidebar)
- **Subagent** — Task tool workers (ephemeral, don't persist)

Jake's character voice adds flavor without polluting the code namespace:
- Code: `ServitorSpawner.summon()`
- Jake: "Time to call in one of the Regulars!"
- UI: Sidebar shows "Servitors" or themed names

**[S]** The MCP tool implementation marks a critical architecture evolution:

**Old design:** Jake outputs JSON, `JakeToolHandler` parses it, feedback loop continues until no more actions

**New design:** Jake has native MCP tools registered, SDK handles tool calls directly, no JSON envelope or continuation loop

This eliminates:
- `JakeToolHandler` protocol and `JSONActionHandler` implementation
- Continuation loop in `Jake.send()`
- JSON parsing fragility
- Feedback/continuation mechanism

The new design is cleaner: tools are tools, not hacks disguised as JSON responses.

**[S]** Phase 1 scope discipline prevents feature creep:

The user explicitly deferred message forwarding, resummon, and capability distribution. This keeps Phase 1 focused on the core dispatcher pattern: Jake can summon servitors to appear in the sidebar, and dismiss them when done.

Future phases will add:
- **Phase 2:** Message forwarding (user asks Jake to tell a servitor something)
- **Phase 3:** Resummon (bring back a dismissed servitor)
- **Phase 4:** Capability distribution (specialized tools per servitor type)

This phased approach ensures each increment is shippable and testable.
