# Work-Stealing Pool Architecture

**One-line summary:** Agent pools with work queues where idle agents steal work from busy ones, optimizing throughput through dynamic load balancing.


## Core Concept

The Work-Stealing Pool architecture treats agents as pooled resources attached to work queues rather than individual task owners. When a parent decomposes work into units, those units enter a shared queue. A pool of drone agents consumes from the queue, with idle agents "stealing" work items from overloaded queues to maximize throughput.

This model aligns directly with the PRD's concept of drones as "Meeseeks-style, one task then terminate" agents. Rather than spawning a new agent per task, a pool of warm agents sits ready. When work appears, the next available drone claims it, executes, and either terminates (returning to pool) or immediately claims the next item. The pool size adapts based on queue depth and saturation metrics.

Work stealing specifically addresses the problem of uneven task distribution. If Queue A has 50 items and Queue B has 2, agents attached to Queue B can steal from Queue A when they finish. This prevents the bottleneck scenario where some agents sit idle while others are overwhelmed.


## Key Components

```mermaid
graph TD
    subgraph "Coordination Layer"
        Jake[Jake - Proprietor]
        WQM[WorkQueueManager]
        PS[PoolSupervisor]
    end

    subgraph "Work Queues"
        Q1[Queue: build-tasks]
        Q2[Queue: test-tasks]
        Q3[Queue: review-tasks]
    end

    subgraph "Drone Pool"
        D1[Drone 1]
        D2[Drone 2]
        D3[Drone 3]
        D4[Drone N...]
    end

    subgraph "DocStore"
        WI1[WorkItem 1]
        WI2[WorkItem 2]
        WI3[WorkItem N...]
    end

    Jake -->|creates queues| WQM
    WQM -->|manages| Q1
    WQM -->|manages| Q2
    WQM -->|manages| Q3

    PS -->|scales| D1
    PS -->|scales| D2
    PS -->|scales| D3
    PS -->|scales| D4

    D1 -.->|claims from| Q1
    D2 -.->|claims from| Q1
    D3 -.->|steals from| Q2
    D4 -.->|claims from| Q3

    Q1 --> WI1
    Q1 --> WI2
    Q2 --> WI3

    D1 -->|results| Jake
    D2 -->|results| Jake
```


## Pros

- **Maximum throughput** - Work never waits while agents sit idle; stealing ensures full utilization

- **Elastic scaling** - Pool size adjusts to queue depth; spin up more drones when backlog grows

- **Cheap failure** - Drones are disposable; failed work item returns to queue for retry

- **Natural batching** - Similar tasks can share a queue, enabling specialized drone configurations

- **Reduced spawn overhead** - Warm pool means no per-task agent initialization cost

- **Metric-friendly** - Amplification factor is directly visible as concurrent drone count


## Cons

- **Coordination complexity** - Work stealing requires distributed locking or careful CAS operations

- **State isolation challenges** - Agents processing from same queue may have conflicting sandbox states

- **Less task affinity** - Agent that started a task may not finish it if stolen

- **Debugging difficulty** - Work can bounce between agents, making trace harder to follow

- **Potential for contention** - High-frequency stealing can create queue lock contention

- **Model mismatch risk** - Some tasks benefit from conversational continuity that stealing breaks


## When to Choose This Architecture

Choose Work-Stealing Pool when:

- Tasks are homogeneous and well-defined (same shape, different data)

- High amplification is the primary goal (many drones, minimal human attention)

- Individual task failure is cheap and retryable

- You have many small tasks rather than few large ones

- Work distribution is naturally uneven and unpredictable

Avoid when:

- Tasks require conversational continuity across multiple turns

- Task state is expensive to checkpoint/restore

- Agent specialization matters more than throughput

- Work items have complex interdependencies that stealing would break
