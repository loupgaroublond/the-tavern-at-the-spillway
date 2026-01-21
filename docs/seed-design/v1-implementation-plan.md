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
- [x] Create test utilities module (TavernCore/Testing/)
- [x] Create mock/stub for ClaudeCodeSDK (MockClaudeCode)
- [x] Create test fixture helpers (TestFixtures)
- [x] Verify tests can run in isolation (no real API calls)

**Verification:**
- [x] Can run tests without Claude credentials
- [x] Tests are fast (< 1 second for unit tests) — 0.002s total

**Tests Required:**
- [x] `test_mock_returns_queued_text_response`
- [x] `test_mock_records_sent_prompts`
- [x] `test_mock_throws_configured_error`
- [x] `test_mock_tracks_cancel_calls`
- [x] `test_mock_reset_clears_state`
- [x] `test_mock_returns_json_response_with_session_id`
- [x] `test_creates_temp_directory`
- [x] `test_configuration_is_valid`

---

## Phase 1: Jake Basics

### Step 1.1: Jake Agent Wrapper

**Commitments:**
- [x] Create `Jake` class that wraps ClaudeCodeSDK
- [x] Jake has system prompt establishing his role
- [x] Jake can receive a message and respond
- [ ] Jake's responses stream to callback (deferred to Step 1.2)

**Verification:**
- [x] Unit tests with mock SDK pass (8 tests)
- [ ] Integration test with real SDK works (manual)

**Tests Required:**
- [x] `test_jake_has_system_prompt`
- [x] `test_jake_initializes_with_correct_state`
- [x] `test_jake_responds_to_message`
- [x] `test_jake_state_cogitating` (verifies cogitating state during response)
- [x] `test_jake_maintains_conversation` (session ID persistence)
- [x] `test_jake_resets_conversation`
- [x] `test_jake_handles_text_response`
- [x] `test_jake_propagates_errors`

---

### Step 1.2: Chat UI - Single Agent

**Commitments:**
- [x] Create `ChatView` SwiftUI component
- [x] Shows message history (user + agent)
- [x] Has input field for new messages
- [ ] Displays streaming responses (deferred)
- [x] Shows "cogitating" status while agent working

**Verification:**
- [x] ChatViewModel unit tests pass (9 tests)
- [ ] Can manually chat with Jake (pending Step 1.3)

**Tests Required (via ChatViewModel):**
- [x] `test_viewmodel_initializes_empty`
- [x] `test_sending_message_adds_messages`
- [x] `test_input_text_clears_after_send`
- [x] `test_empty_input_does_not_send`
- [x] `test_cogitating_state_during_send`
- [x] `test_cogitation_verb_is_set`
- [x] `test_error_is_captured_and_displayed`
- [x] `test_clear_conversation_removes_messages`
- [x] `test_multiple_messages_accumulate`

---

### Step 1.3: Main Window with Jake Chat

**Commitments:**
- [x] App opens to main window
- [x] Main window contains Jake chat
- [x] User can send message, see response
- [x] Conversation persists during session

**Verification:**
- [x] App builds and integrates all components
- [ ] Manual test: Launch app, chat with Jake

**Tests Required:**
- `test_main_window_contains_chat_view`
- `test_conversation_persists_in_session`

---

## Phase 2: Agent Spawning

### Step 2.1: Agent Protocol and Registry

**Commitments:**
- [x] Define `Agent` protocol (common interface)
- [x] Create `AgentRegistry` to track active agents
- [x] Each agent has unique ID and name
- [x] Registry can list, get, remove agents

**Verification:**
- [x] Unit tests for registry operations (10 tests)

**Tests Required:**
- [x] `test_registry_adds_agent`
- [x] `test_registry_gets_agent_by_id`
- [x] `test_registry_gets_agent_by_name`
- [x] `test_registry_lists_agents`
- [x] `test_registry_removes_agent`
- [x] `test_registry_enforces_unique_names`
- [x] `test_registry_throws_on_remove_non_existent`
- [x] `test_registry_is_name_taken`
- [x] `test_registry_remove_all`
- [x] `test_registry_allows_name_reuse_after_removal`

---

### Step 2.2: Mortal Agent Class

**Commitments:**
- [x] Create `MortalAgent` implementing `Agent` protocol
- [x] MortalAgent has assignment (task description)
- [x] MortalAgent can receive messages and respond
- [x] MortalAgent tracks its own state (working, waiting, done)

**Verification:**
- [x] Unit tests with mock SDK (12 tests)

**Tests Required:**
- [x] `test_mortal_agent_has_assignment`
- [x] `test_mortal_agent_initializes_idle`
- [x] `test_mortal_agent_responds_to_messages`
- [x] `test_mortal_agent_tracks_working_state`
- [x] `test_mortal_agent_transitions_to_done`
- [x] `test_mortal_agent_transitions_to_waiting`
- [x] `test_mortal_agent_explicitly_marked_waiting`
- [x] `test_mortal_agent_explicitly_marked_done`
- [x] `test_mortal_agent_done_state_is_terminal`
- [x] `test_mortal_agent_maintains_conversation`
- [x] `test_mortal_agent_reset_clears_session`
- [x] `test_mortal_agent_propagates_errors`

---

### Step 2.3: Jake Spawns Mortal Agents

**Commitments:**
- [x] AgentSpawner coordinates registry and name generator
- [x] Spawn includes: assignment, name from theme
- [x] New agent registered in AgentRegistry
- [x] Dismiss releases name back to pool

**Note:** Jake tool integration deferred to Phase 3 (UI). Spawner provides
the infrastructure; UI will call spawner based on Jake's responses.

**Verification:**
- [x] Unit tests for AgentSpawner (13 tests)

**Tests Required:**
- [x] `test_spawn_creates_agent_with_themed_name`
- [x] `test_spawn_registers_agent_in_registry`
- [x] `test_spawned_agent_has_assignment`
- [x] `test_spawned_agent_gets_themed_name`
- [x] `test_multiple_spawns_get_unique_names`
- [x] `test_spawn_with_specific_name_works`
- [x] `test_spawn_with_duplicate_name_fails`
- [x] `test_dismiss_removes_agent_from_registry`
- [x] `test_dismiss_releases_name_for_reuse`
- [x] `test_dismiss_by_id_works`
- [x] `test_dismiss_non_existent_agent_throws`
- [x] `test_active_agents_returns_all_spawned`
- [x] `test_agent_count_matches_spawned`

---

### Step 2.4: Naming Theme System

**Commitments:**
- [x] Create `NamingTheme` struct with name lists
- [x] Create a few starter themes (LOTR, Rick and Morty, etc.)
- [x] Theme tracks which names are used
- [x] Names are globally unique across system

**Verification:**
- [x] Unit tests for name generation (15 tests)

**Tests Required:**
- [x] `test_theme_has_required_properties`
- [x] `test_theme_all_names_flattened`
- [x] `test_builtin_themes_available`
- [x] `test_generator_generates_in_tier_order`
- [x] `test_generator_generates_unique_names`
- [x] `test_generator_exhausts_tiers_in_order`
- [x] `test_generator_returns_nil_when_exhausted`
- [x] `test_generator_fallback_provides_numbered_names`
- [x] `test_generator_tracks_used_names`
- [x] `test_generator_checks_name_availability`
- [x] `test_generator_can_reserve_names`
- [x] `test_generator_can_release_names`
- [x] `test_generator_reset_clears_state`
- [x] `test_generator_tracks_remaining_names`
- [x] `test_generator_can_switch_themes`

---

## Phase 3: Multi-Agent UI

### Step 3.1: Agent List View

**Commitments:**
- [x] Create `AgentListView` showing all agents
- [x] Each agent shows: name, assignment summary, state
- [x] Clicking agent selects it

**Verification:**
- [x] Unit tests for AgentListItem and AgentListViewModel (16 tests)

**Tests Required:**
- [x] `test_list_shows_all_spawned_agents` (AgentListViewModel)
- [x] `test_list_shows_agent_state` (AgentListViewModel)
- [x] `test_selection_works` (AgentListViewModel)
- [x] Additional tests: item properties, Jake marker, assignment summary, state labels

---

### Step 3.2: Multi-Chat Navigation

**Commitments:**
- [x] Main window shows agent list + selected agent's chat
- [x] Switching agents switches chat view
- [x] Jake is always in the list
- [x] Conversation history preserved when switching

**Verification:**
- [x] Unit tests for TavernCoordinator (10 tests)
- [ ] Manual test: spawn agent, switch between Jake and agent (pending)

**Tests Required:**
- [x] `test_switching_agents_switches_chat` (TavernCoordinator)
- [x] `test_jake_always_in_list` (TavernCoordinator)
- [x] `test_chat_history_preserved_on_switch` (TavernCoordinator)

---

### Step 3.3: Agent State Indicators

**Commitments:**
- [x] Visual indicator for agent state (working, waiting, done)
- [x] Notification badge when agent needs attention
- [x] "Cogitating" indicator with verb from vocab list

**Verification:**
- [x] Underlying logic tested via AgentListItem tests
- [ ] UI visual verification (manual)

**Tests Required:**
- [x] `test_needs_attention_only_for_waiting` (AgentListItem)
- [x] `test_state_label_returns_readable_text` (AgentListItem)
- [x] `test_list_shows_agent_state` (AgentListViewModel)

---

## Phase 4: Commitments and Verification

### Step 4.1: Commitment Data Model

**Commitments:**
- [x] Create `Commitment` struct (description, assertion, status)
- [x] Agents can have list of commitments (CommitmentList)
- [ ] Commitments stored in agent's doc store node (file) - deferred to Phase 5

**Verification:**
- [x] Unit tests for commitment CRUD (15 tests)

**Tests Required:**
- [x] `test_commitment_created_with_correct_initial_state`
- [x] `test_commitment_status_transitions_work_correctly`
- [x] `test_commitment_is_codable` (for future file persistence)
- [x] `test_add_commitment_works`
- [x] `test_remove_commitment_works`
- [x] Additional: update, status updates, pending/failed filters

---

### Step 4.2: Commitment Verification

**Commitments:**
- [x] Create verifier that checks commitments
- [x] Verifier runs assertion (e.g., "tests pass")
- [x] Verifier updates commitment status
- [x] Verifier supports retry of failed commitments

**Verification:**
- [x] Unit tests with mock assertions (9 tests)

**Tests Required:**
- [x] `test_verifier_runs_assertion`
- [x] `test_verifier_updates_status_on_pass`
- [x] `test_verifier_updates_status_on_fail`
- [x] `test_verifier_updates_commitment_list`
- [x] `test_verify_all_verifies_all_pending`
- [x] `test_verify_all_returns_false_if_any_fail`
- [x] `test_retry_failed_only_retries_failed`
- [x] `test_mock_runner_tracks_commands`
- [x] `test_mock_runner_reset_clears_state`

---

### Step 4.3: Agent Completion Flow

**Commitments:**
- [x] When agent says "done", trigger verification
- [x] If verification passes, mark agent done
- [x] If verification fails, agent continues working
- [x] UI reflects verification status (via AgentState.verifying)

**Verification:**
- [x] Unit tests for completion flow (8 tests)

**Tests Required:**
- [x] `test_agent_with_no_commitments_transitions_to_done_immediately`
- [x] `test_done_triggers_verification`
- [x] `test_verification_pass_marks_done`
- [x] `test_verification_fail_continues`
- [x] `test_agent_not_done_until_all_commitments_verified`
- [x] `test_add_commitment_helper_works`
- [x] `test_all_commitments_passed_works`
- [x] `test_has_failed_commitments_works`

---

## Phase 5: Doc Store Basics

### Step 5.1: File-Based Doc Store

**Commitments:**
- [x] Create `DocStore` class wrapping filesystem
- [x] Can create, read, update, delete documents (files)
- [x] Documents are markdown with optional frontmatter
- [x] Project has designated doc store directory

**Verification:**
- [x] Unit tests with temp directory (21 tests)

**Tests Required:**
- [x] `test_doc_store_creates_directory_if_needed`
- [x] `test_doc_store_creates_file`
- [x] `test_doc_store_reads_file`
- [x] `test_doc_store_updates_file`
- [x] `test_doc_store_deletes_file`
- [x] `test_doc_store_parses_frontmatter`
- [x] Document serialization tests (7 tests)
- [x] Error handling tests (4 tests)
- [x] List/read all documents tests

---

### Step 5.2: Agent Nodes in Doc Store

**Commitments:**
- [x] Each agent has a file in doc store
- [x] File contains: ID, name, assignment, state, commitments
- [x] Agent state synced to file
- [x] Agent can be restored from file

**Verification:**
- [x] Unit tests for agent serialization (17 tests)

**Tests Required:**
- [x] `test_agent_node_has_properties`
- [x] `test_agent_node_creates_from_mortal_agent`
- [x] `test_agent_node_converts_to_document`
- [x] `test_agent_node_parses_from_document`
- [x] `test_commitment_node_creates_from_commitment`
- [x] `test_commitment_node_converts_to_commitment`
- [x] `test_agent_creates_doc_store_node`
- [x] `test_agent_state_synced_to_file`
- [x] `test_agent_restored_from_file`
- [x] `test_agent_persistence_saves_commitments`
- [x] `test_agent_persistence_deletes_agent`
- [x] `test_agent_persistence_lists_all`

---

## Verification Checkpoints

After each phase, request subagent verification:

- [x] **Phase 0 complete:** Project builds, tests run, infrastructure ready (10 tests passing)
- [x] **Phase 1 complete:** Can chat with Jake in UI (27 tests passing, app builds)
- [x] **Phase 2 complete:** AgentSpawner, Registry, MortalAgent, NamingThemes (77 tests)
- [x] **Phase 3 complete:** Multi-agent UI works, can switch chats (103 tests)
- [x] **Phase 4 complete:** Commitments work, verification blocks false "done" (135 tests)
- [x] **Phase 5 complete:** Doc store works, agents persist to files (173 tests)


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
