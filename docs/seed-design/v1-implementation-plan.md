# Tavern V1 Implementation Plan

**Created:** 2026-01-20
**Status:** In Progress


## Process Commitment

This plan follows the same standards we're building into the product:
- Every step has explicit commitments
- Commitments are verified by independent assertion (subagent or tests)
- Plan is updated as features are added
- No feature ships without tests


## Phase 0: Project Setup

### Step 0.1: Initialize Swift Package

**Commitments:**
- [x] Create Swift package with SwiftUI app target
- [x] Add ClaudeCodeSDK as dependency
- [x] Verify package builds and runs empty window
- [x] Create test target with Swift Testing

**Verification:**
- [x] `swift build` succeeds (29.15s)
- [x] `swift test` runs and passes (2 tests)
- [ ] App launches and shows window (manual verification pending)

**Tests Required:**
- [x] `test_version_is_set` in TavernCoreTests
- [x] `test_placeholder` in TavernTests

---

### Step 0.2: Set Up Test Infrastructure

**Commitments:**
- [ ] Create test utilities module
- [ ] Create mock/stub for ClaudeCodeSDK
- [ ] Create test fixture helpers
- [ ] Verify tests can run in isolation (no real API calls)

**Verification:**
- Can run tests without Claude credentials
- Tests are fast (< 1 second for unit tests)

**Tests Required:**
- Test that mock SDK works
- Test that fixtures load correctly

---

## Phase 1: Jake Basics

### Step 1.1: Jake Agent Wrapper

**Commitments:**
- [ ] Create `Jake` class that wraps ClaudeCodeSDK
- [ ] Jake has system prompt establishing his role
- [ ] Jake can receive a message and respond
- [ ] Jake's responses stream to callback

**Verification:**
- Unit tests with mock SDK pass
- Integration test with real SDK works (manual)

**Tests Required:**
- `test_jake_initializes_with_system_prompt`
- `test_jake_responds_to_message`
- `test_jake_streams_response`

---

### Step 1.2: Chat UI - Single Agent

**Commitments:**
- [ ] Create `ChatView` SwiftUI component
- [ ] Shows message history (user + agent)
- [ ] Has input field for new messages
- [ ] Displays streaming responses
- [ ] Shows "cogitating" status while agent working

**Verification:**
- UI tests verify components render
- Can manually chat with Jake

**Tests Required:**
- `test_chat_view_displays_messages`
- `test_chat_view_shows_input_field`
- `test_chat_view_shows_cogitating_status`

---

### Step 1.3: Main Window with Jake Chat

**Commitments:**
- [ ] App opens to main window
- [ ] Main window contains Jake chat
- [ ] User can send message, see response
- [ ] Conversation persists during session

**Verification:**
- Launch app, chat with Jake, verify conversation works

**Tests Required:**
- `test_main_window_contains_chat_view`
- `test_conversation_persists_in_session`

---

## Phase 2: Agent Spawning

### Step 2.1: Agent Protocol and Registry

**Commitments:**
- [ ] Define `Agent` protocol (common interface)
- [ ] Create `AgentRegistry` to track active agents
- [ ] Each agent has unique ID and name
- [ ] Registry can list, get, remove agents

**Verification:**
- Unit tests for registry operations

**Tests Required:**
- `test_agent_registry_adds_agent`
- `test_agent_registry_gets_agent_by_id`
- `test_agent_registry_lists_agents`
- `test_agent_registry_removes_agent`
- `test_agent_names_are_unique`

---

### Step 2.2: Mortal Agent Class

**Commitments:**
- [ ] Create `MortalAgent` implementing `Agent` protocol
- [ ] MortalAgent has assignment (task description)
- [ ] MortalAgent can receive messages and respond
- [ ] MortalAgent tracks its own state (working, waiting, done)

**Verification:**
- Unit tests with mock SDK

**Tests Required:**
- `test_mortal_agent_has_assignment`
- `test_mortal_agent_responds_to_messages`
- `test_mortal_agent_tracks_state`
- `test_mortal_agent_state_transitions`

---

### Step 2.3: Jake Spawns Mortal Agents

**Commitments:**
- [ ] Jake can spawn a new mortal agent via tool call
- [ ] Spawn includes: assignment, name from theme
- [ ] New agent registered in AgentRegistry
- [ ] Jake's response indicates agent was spawned

**Verification:**
- Unit test: Jake tool call creates agent in registry
- Integration: Tell Jake to do something, verify agent spawned

**Tests Required:**
- `test_jake_spawn_tool_creates_agent`
- `test_spawned_agent_has_assignment`
- `test_spawned_agent_registered`
- `test_spawned_agent_gets_themed_name`

---

### Step 2.4: Naming Theme System

**Commitments:**
- [ ] Create `NamingTheme` struct with name lists
- [ ] Create a few starter themes (LOTR, Rick and Morty, etc.)
- [ ] Theme tracks which names are used
- [ ] Names are globally unique across system

**Verification:**
- Unit tests for name generation

**Tests Required:**
- `test_naming_theme_generates_names`
- `test_names_are_unique`
- `test_theme_exhausts_tiers_in_order`

---

## Phase 3: Multi-Agent UI

### Step 3.1: Agent List View

**Commitments:**
- [ ] Create `AgentListView` showing all agents
- [ ] Each agent shows: name, assignment summary, state
- [ ] Clicking agent selects it

**Verification:**
- UI tests verify rendering

**Tests Required:**
- `test_agent_list_shows_all_agents`
- `test_agent_list_shows_agent_state`
- `test_agent_list_selection_works`

---

### Step 3.2: Multi-Chat Navigation

**Commitments:**
- [ ] Main window shows agent list + selected agent's chat
- [ ] Switching agents switches chat view
- [ ] Jake is always in the list
- [ ] Conversation history preserved when switching

**Verification:**
- Manual test: spawn agent, switch between Jake and agent

**Tests Required:**
- `test_switching_agents_switches_chat`
- `test_jake_always_in_list`
- `test_chat_history_preserved_on_switch`

---

### Step 3.3: Agent State Indicators

**Commitments:**
- [ ] Visual indicator for agent state (working, waiting, done)
- [ ] Notification badge when agent needs attention
- [ ] "Cogitating" indicator with verb from vocab list

**Verification:**
- UI tests verify indicators render correctly

**Tests Required:**
- `test_state_indicator_shows_working`
- `test_state_indicator_shows_waiting`
- `test_state_indicator_shows_done`
- `test_notification_badge_when_waiting`

---

## Phase 4: Commitments and Verification

### Step 4.1: Commitment Data Model

**Commitments:**
- [ ] Create `Commitment` struct (description, assertion, status)
- [ ] Agents can have list of commitments
- [ ] Commitments stored in agent's doc store node (file)

**Verification:**
- Unit tests for commitment CRUD

**Tests Required:**
- `test_commitment_created`
- `test_commitment_stored_in_file`
- `test_commitment_loaded_from_file`

---

### Step 4.2: Commitment Verification

**Commitments:**
- [ ] Create verifier that checks commitments
- [ ] Verifier runs assertion (e.g., "tests pass")
- [ ] Verifier updates commitment status
- [ ] Agent not "done" until all commitments verified

**Verification:**
- Unit tests with mock assertions

**Tests Required:**
- `test_verifier_runs_assertion`
- `test_verifier_updates_status`
- `test_agent_not_done_until_verified`

---

### Step 4.3: Agent Completion Flow

**Commitments:**
- [ ] When agent says "done", trigger verification
- [ ] If verification passes, mark agent done
- [ ] If verification fails, agent continues working
- [ ] UI reflects verification status

**Verification:**
- Integration test: agent completes, verification runs

**Tests Required:**
- `test_done_triggers_verification`
- `test_verification_pass_marks_done`
- `test_verification_fail_continues`

---

## Phase 5: Doc Store Basics

### Step 5.1: File-Based Doc Store

**Commitments:**
- [ ] Create `DocStore` class wrapping filesystem
- [ ] Can create, read, update, delete documents (files)
- [ ] Documents are markdown with optional frontmatter
- [ ] Project has designated doc store directory

**Verification:**
- Unit tests with temp directory

**Tests Required:**
- `test_doc_store_creates_file`
- `test_doc_store_reads_file`
- `test_doc_store_updates_file`
- `test_doc_store_deletes_file`
- `test_doc_store_parses_frontmatter`

---

### Step 5.2: Agent Nodes in Doc Store

**Commitments:**
- [ ] Each agent has a file in doc store
- [ ] File contains: ID, name, assignment, state, commitments
- [ ] Agent state synced to file
- [ ] Agent can be restored from file

**Verification:**
- Unit tests for agent serialization

**Tests Required:**
- `test_agent_creates_doc_store_node`
- `test_agent_state_synced_to_file`
- `test_agent_restored_from_file`

---

## Verification Checkpoints

After each phase, request subagent verification:

- [ ] **Phase 0 complete:** Project builds, tests run, infrastructure ready
- [ ] **Phase 1 complete:** Can chat with Jake in UI
- [ ] **Phase 2 complete:** Jake spawns agents, agents registered
- [ ] **Phase 3 complete:** Multi-agent UI works, can switch chats
- [ ] **Phase 4 complete:** Commitments work, verification blocks false "done"
- [ ] **Phase 5 complete:** Doc store works, agents persist to files


## Rules Adherence Checklist

For every step:
- [ ] Tests written before or with feature
- [ ] Tests pass before moving on
- [ ] Commitments explicitly stated
- [ ] Verification method defined
- [ ] No silent failures possible


## Adding New Steps

When adding a new step to this plan:
1. Write explicit commitments
2. Define verification method
3. List required tests
4. Update verification checkpoints if needed
5. Ensure step follows invariants from PRD Section 2
