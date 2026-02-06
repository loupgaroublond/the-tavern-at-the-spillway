# Plugin Architecture Treatise

A complete analysis of the Plugin Architecture proposal for The Tavern at the Spillway.


## Research Findings


### Current Codebase Structure

The existing implementation reveals a clean but relatively rigid agent system:

**Agent Protocol and Types:**
- `Agent` protocol defines the core interface: `id`, `name`, `state`, `send()`, `resetConversation()`
- `Jake` is the eternal coordinator with a hardcoded system prompt defining his carnival barker persona
- `MortalAgent` is the worker type with assignment-based system prompts and commitment tracking
- `AnyAgent` provides type erasure for heterogeneous collections

**Spawning and Registry:**
- `AgentSpawner` creates mortal agents using a `claudeFactory` and `NameGenerator`
- `AgentRegistry` tracks agents by ID and name with thread-safe access
- `TavernCoordinator` orchestrates spawning, selection, and UI state
- Names come from `NamingTheme` with tiered pools (LOTR, Rick and Morty, Star Trek, Discworld)

**Commitments and Verification:**
- `Commitment` struct with description, assertion (shell command), and status
- `CommitmentVerifier` runs assertions via `ShellAssertionRunner`
- `AssertionRunner` protocol allows injection of mock runners for testing

**Key Observation:** The system already has natural extension points -- protocols for agents and assertion runners, injectable factories, theme-based naming. A plugin architecture would formalize and expand these existing seams.


### PRD Requirements Analysis

The PRD establishes several requirements that a plugin architecture directly addresses:

**Gang of Experts (Section 11):**
> "Specialized prompts applied to agents (not persistent entities): Reviewer, Tester, Architect, etc. 'Pull in the reviewer' = spawn agent with reviewer instructions. User can customize."

This explicitly calls for agent types defined by prompt configuration, not code. A plugin architecture makes "Reviewer" a registered plugin contributing a system prompt fragment rather than a distinct Swift type.

**Workflow Templates (Section 10):**
> "Rule of 5 — 5 agent passes over single output from initial prompt"
> "Verification layers — Progressive gates: linting → code structure → architecture → performance"

Workflows are multi-step orchestrations that combine agent types and verification strategies. A plugin system treats workflows as composable recipes that reference other plugins.

**Progressive Unlocks (Section 8):**
> "Cogitating verbs — Start with a core set, reveal more colorful options over time"
> "Naming themes — Unlock new themes as user engagement deepens"
> "Jake's vocabulary — Expand his repertoire"
> "Easter eggs — Hidden content that only appears after significant use"

Progressive unlocks are fundamentally about gating plugin availability. The unlock system becomes: "which plugins are registered for this user/project?"

**Meta Process (Section 10.2):**
> "Decision layer for selecting which workflows/tools to use for a given task. Goal: improve overall performance through measurement and learning."

A meta process needs to query available workflows, tools, and agent types -- exactly what a plugin registry provides.

**Discovery Sharing (Section 10.3):**
> "Agents prompted to notice oddities and share them via messaging, even while continuing main task."

Discovery behaviors could be injected via a "discovery prompt fragment" plugin that gets composed into agent prompts.


### Extension Points Identified

Analyzing the PRD and current code, these are the natural extension points for a plugin system:

1. **AgentType** -- System prompt, default tools, verification requirements
2. **Tool** -- Claude tool definition, implementation, permissions
3. **Workflow** -- Multi-step orchestration recipe referencing agent types and tools
4. **Verifier** -- Assertion strategy beyond shell commands (API checks, semantic analysis)
5. **NamingTheme** -- Tiered name pools (already modeled as data)
6. **PromptFragment** -- Composable pieces of system prompts (persona, instructions, constraints)
7. **CogitationVerb** -- Words for the "thinking" indicator (already hardcoded in ChatViewModel)
8. **ProgressiveUnlock** -- Gating rules for when content becomes available


## Mapping to Gang of Experts

The Gang of Experts pattern translates directly to plugin composition:

**Current (Implicit):**
```swift
let agent = MortalAgent(
    name: "Frodo",
    assignment: "Review this pull request for correctness",
    claude: claude
)
// System prompt is generic: "You are a worker agent..."
```

**Plugin Architecture:**
```swift
// ReviewerPlugin registers at startup
pluginRegistry.register(AgentTypePlugin(
    id: "reviewer",
    displayName: "Code Reviewer",
    systemPrompt: """
        You are a meticulous code reviewer. Focus on:
        - Correctness: Does the code do what it claims?
        - Edge cases: What inputs might break it?
        - Maintainability: Is this code readable and well-structured?
        ...
        """,
    defaultTools: ["git-diff", "ast-query", "test-runner"],
    verificationRequirements: ["lint-pass", "tests-pass"]
))

// Jake spawns via plugin lookup
let agent = spawner.spawn(
    type: "reviewer",  // Plugin lookup
    assignment: "Review PR #42",
    theme: currentTheme  // Also a plugin
)
```

**Expert Composition:**
Experts can compose by layering prompt fragments:
```swift
// Spawn a reviewer with security focus
let agent = spawner.spawn(
    type: "reviewer",
    modifiers: ["security-audit", "performance-conscious"],
    assignment: "Review auth changes in PR #42"
)
// Resulting prompt = base reviewer + security fragment + performance fragment
```


## Mapping to Workflow Requirements

Workflow templates become first-class plugins that orchestrate other plugins:

**Rule of 5 Workflow:**
```swift
WorkflowPlugin(
    id: "rule-of-5",
    displayName: "Rule of 5",
    description: "5 agent passes over single output from initial prompt",
    steps: [
        .spawn(type: "implementer", assignment: "$PROMPT"),
        .await(until: .done),
        .spawn(type: "reviewer", assignment: "Review: $PREV_OUTPUT"),
        .await(until: .done),
        .spawn(type: "refiner", assignment: "Address feedback: $PREV_OUTPUT"),
        .await(until: .done),
        .spawn(type: "tester", assignment: "Write tests for: $PREV_OUTPUT"),
        .await(until: .done),
        .spawn(type: "finalizer", assignment: "Polish: $PREV_OUTPUT"),
        .await(until: .done),
        .verify(["tests-pass", "lint-pass"]),
        .complete
    ]
)
```

**Verification Layers Workflow:**
```swift
WorkflowPlugin(
    id: "verification-layers",
    displayName: "Verification Layers",
    steps: [
        .spawn(type: "implementer", assignment: "$PROMPT"),
        .await(until: .done),
        .gate("lint-pass", onFail: .returnToAgent("Fix lint errors")),
        .gate("structure-check", onFail: .returnToAgent("Restructure code")),
        .gate("architecture-review", onFail: .returnToAgent("Revise architecture")),
        .gate("performance-check", onFail: .returnToAgent("Optimize performance")),
        .complete
    ]
)
```


## Trade-offs Considered


### Plugin Discovery and Loading

**Option A: Compile-time registration (bundled plugins)**
- All plugins linked into the app binary
- Registration happens in `TavernApp.init()`
- Fast, type-safe, but requires app rebuild to add plugins

**Option B: Runtime discovery (file-based)**
- Plugins are Swift packages or configuration files in known directories
- `~/.tavern/plugins/`, `$PROJECT/.tavern/plugins/`
- Dynamic, user-extensible, but slower startup and version compatibility concerns

**Option C: Hybrid (recommended)**
- Bundled plugins for core experts and workflows
- File-based plugins for per-project customization
- Clear precedence rules (project overrides user overrides bundled)

**Trade-off:** Hybrid adds complexity but matches the PRD's vision of user customization while maintaining a solid foundation.


### Plugin Interface Stability

Once plugins exist, their interfaces become contracts:

```swift
public protocol AgentTypePlugin {
    var id: String { get }
    var displayName: String { get }
    var systemPrompt: String { get }
    var defaultTools: [String] { get }
    var verificationRequirements: [String] { get }
}
```

**Risk:** Changing this protocol breaks all existing plugins.

**Mitigation Strategies:**
- Version the plugin protocol (`AgentTypePluginV1`, `AgentTypePluginV2`)
- Use extension protocols for optional capabilities
- Provide migration utilities for plugin authors


### Performance Considerations

Plugin lookups add indirection:

**Before (direct):**
```swift
let prompt = MortalAgent.systemPrompt  // Compile-time resolved
```

**After (plugin):**
```swift
let plugin = registry.lookup("reviewer")  // Runtime dictionary lookup
let prompt = plugin?.systemPrompt         // Optional unwrap
```

**Impact:** Negligible for agent spawning (happens infrequently). Could matter for hot paths like tool invocation.

**Mitigation:** Cache resolved plugins per-agent at spawn time. The agent carries its tools, not plugin references.


### Composition vs. Configuration

Plugins can be configured or composed:

**Configuration:** A Reviewer plugin has settings (strictness level, focus areas)
```swift
spawner.spawn(type: "reviewer", config: ["strictness": "high", "focus": ["security"]])
```

**Composition:** Combine independent plugins (Reviewer + SecurityAudit + PerformanceCheck)
```swift
spawner.spawn(types: ["reviewer", "security-audit", "performance-check"])
```

**Trade-off:** Composition is more powerful but harder to predict (conflicting instructions). Configuration is simpler but less flexible.

**Recommendation:** Start with composition for prompt fragments, configuration for behavior settings.


## Implementation Complexity


### Phase 1: Core Plugin Infrastructure (Moderate)

**New Types:**
- `PluginRegistry` -- Central storage for all registered plugins
- `PluginLoader` -- Discovery and loading logic
- `PluginContext` -- Dependency injection container for plugins

**Modified Types:**
- `AgentSpawner` -- Accept agent type IDs, look up in registry
- `MortalAgent` -- Accept composed system prompt from plugins
- `CommitmentVerifier` -- Delegate to verifier plugins

**Estimated Effort:** 2-3 weeks for core infrastructure


### Phase 2: Agent Type Plugins (Low-Moderate)

**Extract from current code:**
- Jake's system prompt becomes a bundled `JakePersonaPlugin`
- MortalAgent's generic prompt becomes `DefaultWorkerPlugin`
- Add `ReviewerPlugin`, `TesterPlugin`, `ArchitectPlugin`

**Testing:**
- Each plugin testable in isolation
- Spawner tests verify plugin lookup and prompt composition

**Estimated Effort:** 1-2 weeks


### Phase 3: Workflow Plugins (Moderate-High)

**New Types:**
- `WorkflowPlugin` protocol
- `WorkflowStep` enum (spawn, await, gate, complete)
- `WorkflowEngine` -- Executes workflow definitions
- `WorkflowState` -- Tracks progress through workflow

**Integration:**
- Jake learns to invoke workflows by ID
- UI shows workflow progress

**Estimated Effort:** 3-4 weeks


### Phase 4: Tool and Verifier Plugins (Moderate)

**Tool Plugins:**
- Bridge Claude tools to plugin system
- Each tool plugin provides: schema, implementation, permission requirements

**Verifier Plugins:**
- Beyond shell commands: API assertions, semantic checks
- Composable verification strategies

**Estimated Effort:** 2-3 weeks


### Total Implementation: 8-12 weeks

This is substantial but delivers a foundation for all future extensibility.


## Migration Path from Current State


### Step 1: Introduce PluginRegistry (Non-breaking)

Add `PluginRegistry` as a new component that initially mirrors existing behavior:

```swift
class PluginRegistry {
    private var agentTypes: [String: AgentTypePlugin] = [:]

    func register(_ plugin: AgentTypePlugin) {
        agentTypes[plugin.id] = plugin
    }

    func agentType(id: String) -> AgentTypePlugin? {
        agentTypes[id]
    }
}
```

Register current behavior as plugins:
```swift
registry.register(DefaultWorkerPlugin())  // Wraps current MortalAgent prompt
```


### Step 2: Modify AgentSpawner to Accept Type IDs (Backward-compatible)

```swift
func spawn(assignment: String) throws -> MortalAgent  // Existing
func spawn(type: String, assignment: String) throws -> MortalAgent  // New
```

The new method looks up the type in the registry; the old method uses "default-worker".


### Step 3: Extract Naming Themes (Already Data-driven)

`NamingTheme` is already a data structure. Make it a plugin:
```swift
protocol NamingThemePlugin {
    var theme: NamingTheme { get }
}
```

Bundled themes become bundled plugins. Progressive unlock gates plugin availability.


### Step 4: Add First-party Expert Plugins

Implement Reviewer, Tester, Architect as plugins. These become the model for user-defined experts.


### Step 5: Add Workflow Plugins

This is the most disruptive change, introducing the workflow engine.


### Step 6: External Plugin Loading (Optional)

Only if user-defined plugins are a priority for v2.


## Open Questions


### 1. Plugin Distribution Format

If users can create plugins, what format?

- **Swift packages:** Type-safe, powerful, but requires compilation
- **JSON/YAML configuration:** Portable, but limited to prompt/config changes
- **Hybrid:** Swift for tools/verifiers, config for prompts/workflows

**Recommendation:** Start with bundled Swift plugins. Add JSON prompt plugins later for user customization.


### 2. Plugin Dependencies

Can plugins depend on other plugins?

Example: SecurityReviewerPlugin depends on ReviewerPlugin + SecurityAuditPlugin

**Options:**
- No dependencies (flat registry)
- Explicit dependencies with topological loading
- Implicit composition (plugin A uses plugin B's prompt fragment)

**Recommendation:** Start flat. Add composition via prompt fragments. Avoid explicit dependency graphs initially.


### 3. Plugin Versioning

How do plugins declare compatibility with framework versions?

**Options:**
- Semantic versioning with compatibility ranges
- Plugin protocol versions (V1, V2)
- No versioning (plugins just break or work)

**Recommendation:** Protocol versions for compile-time safety. Defer semantic versioning until external plugins exist.


### 4. Plugin State and Persistence

Should plugins have persistent state?

Example: A Reviewer plugin tracks which patterns it's seen across sessions.

**Options:**
- Stateless plugins (all state in DocStore)
- Plugin-scoped storage (sandboxed per-plugin)
- Shared state via DocStore (plugins read/write to known paths)

**Recommendation:** Stateless initially. Plugins contribute to DocStore if they need persistence.


### 5. Security and Sandboxing

User-defined plugins could be malicious or buggy.

**Options:**
- No sandboxing (trust users)
- Capability-based permissions (plugin declares what it needs)
- Full sandboxing (plugins run in isolated processes)

**Recommendation:** Start with bundled-only plugins (trusted). Add capability declarations before allowing external plugins.


### 6. UI for Plugin Management

Should users manage plugins via UI?

**Options:**
- Code/config only (developer-focused)
- Settings panel with toggles
- Full plugin browser with install/uninstall

**Recommendation:** Config-only for v1. UI management is v2+ scope.


## Relationship to Other Proposals

**Flat Coordinator (01):** Plugin architecture is orthogonal. You could have a flat coordinator that uses plugins, or a distributed coordinator that uses plugins.

**Blackboard (06):** Plugins could contribute knowledge sources. The blackboard becomes the shared state that plugins read/write.

**Capability-based (07):** Plugins could declare capabilities they require (file access, network, shell). The capability system gates plugin operations.

**Work-stealing Pool (08):** Workflows become task generators. The pool executes tasks from workflow plugins.


## Conclusion

The Plugin Architecture is a natural fit for Tavern's requirements:

1. **Gang of Experts** is explicitly a plugin pattern
2. **Workflow templates** are composable plugin recipes
3. **Progressive unlocks** gate plugin availability
4. **User customization** is plugin configuration

The implementation cost is significant (8-12 weeks for full implementation), but the architecture provides a foundation for all future extensibility. The migration path is incremental and non-breaking.

The main risk is over-engineering for current needs. If the expert set and workflow options remain bounded, the plugin overhead may not be justified. However, the PRD's emphasis on user customization and extensibility suggests plugins will pay dividends.

**Recommendation:** Pursue plugin architecture, but scope the initial implementation to Phase 1-2 (core infrastructure + agent type plugins). Defer workflows and external plugins until the foundation proves stable.
