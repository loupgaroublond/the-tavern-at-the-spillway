# Stress Testing Guide

This document describes the stress tests for The Tavern at the Spillway and how to run them.


## Overview

Stress tests validate that the app performs correctly under load. They are separate from unit and integration tests because they:

- Take longer to run (not suitable for every build)
- Generate synthetic load that could overwhelm CI runners
- Measure performance baselines for regression detection

**When to run stress tests:**
- End of development cycle
- Before releases
- After significant refactoring
- When performance issues are suspected


## Running Stress Tests

```bash
cd Tavern

# Run only stress tests
swift test --filter TavernStressTests

# Run all tests including stress tests
swift test

# Run with verbose output
swift test --filter TavernStressTests -v
```


## Test Descriptions


### ChatStressTests

**`testManyMessagesInSingleChat`**

Simulates a long conversation with many messages.

- Sends 1000 messages to a single agent
- Verifies memory doesn't grow unboundedly
- Confirms last message renders correctly
- Expected: Completes without crash, bounded memory growth


**`testLargeMessageHistory`**

Tests UI responsiveness with large message history.

- Creates 10,000 message entries
- Measures time to access messages at various indices
- Expected: O(1) access time regardless of history size


### AgentSpawnerStressTests

**`testManyAgentsSpawned`**

Tests spawning many agents in sequence.

- Spawns 100 agents
- Verifies all spawn successfully
- Confirms registry consistency (no duplicates, no missing)
- Expected: All agents registered, names unique


**`testRapidSpawnDismissCycle`**

Tests rapid creation and destruction of agents.

- Spawns 50 agents
- Immediately dismisses each after spawning
- Verifies no orphaned state
- Confirms names are recycled correctly
- Expected: Clean slate after cycle, no resource leaks


### ConcurrencyStressTests

**`testConcurrentAgentMessages`**

Tests message sending from multiple agents simultaneously.

- Creates 10 agents
- Each sends 100 messages concurrently
- Verifies no race conditions
- Confirms all messages delivered
- Expected: 1000 total messages, no data corruption


**`testConcurrentSpawnDismiss`**

Tests concurrent spawn and dismiss operations.

- Multiple tasks spawning and dismissing simultaneously
- Verifies registry remains consistent
- Expected: No crashes, consistent state after completion


## Performance Baselines

*Baselines established 2026-01-21 on Apple Silicon (M-series). Update when hardware or significant code changes occur.*

| Test | Metric | Baseline | Threshold |
|------|--------|----------|-----------|
| `testManyMessagesInSingleChat` | Duration (1000 messages) | 0.10s | < 10s |
| `testLargeMessageHistory` | Access time (10K messages) | 5.4s | < 30s |
| `testManyAgentsSpawned` | Duration (100 agents) | 0.001s | < 5s |
| `testRapidSpawnDismissCycle` | Duration (50 cycles) | 0.001s | < 3s |
| `testThemeExhaustion` | Duration (500 agents) | 0.016s | < 5s |
| `testConcurrentAgentMessages` | Duration (10×100 messages) | 0.01s | < 30s |
| `testConcurrentSpawnDismiss` | Duration (5×20 ops) | 0.003s | < 5s |
| `testRegistryThreadSafety` | Duration (1000 iterations) | 0.09s | < 5s |

**Notes:**
- All tests use `MockClaudeCode` — no real API calls
- `testLargeMessageHistory` includes 10K message setup time + access tests


## Interpreting Results


### Pass Criteria

- Test completes without crash
- Memory usage stays within threshold
- Duration stays within threshold
- No data corruption or inconsistency detected


### Failure Investigation

If a stress test fails:

1. Check Console.app logs (`subsystem:com.tavern.spillway`)
2. Look for `.error` entries during the test
3. Check for memory warnings or leaks
4. Profile with Instruments if memory-related


### Updating Baselines

When hardware changes or after major refactoring:

1. Run stress tests 3 times
2. Take the median value for each metric
3. Update the baseline table above
4. Commit the updated baselines
