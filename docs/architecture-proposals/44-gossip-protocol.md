# Gossip Protocol Architecture

**One-line summary:** Decentralized state propagation where agents share state updates with random peers, achieving eventual consistency through epidemic spreading.


## Core Concept

Gossip Protocol architecture eliminates the need for a central state store by having agents propagate state changes through random peer-to-peer communication. When an agent's state changes (task started, commitment made, question raised), it doesn't report to a coordinator or write to a central store. Instead, it "gossips" the update to a random subset of known agents. Those agents incorporate the update and gossip it further. Eventually, all agents learn about all state changes through this epidemic spreading.

The key insight is that gossip protocols achieve remarkable consistency guarantees without any centralized infrastructure. Each agent maintains its own view of system state, constructed from the gossip it has received. Views eventually converge because updates spread exponentially: if each agent tells 2 others, after 10 rounds all 1024 agents in a system know the update. This makes the system highly resilient - there is no single point of failure, no central store to corrupt, no coordinator to become a bottleneck.

For Tavern, this means Jake and the Slop Squad form a gossip network. When Gandalf finishes a task, he gossips this to Legolas and Frodo. Legolas gossips to Jake and Gimli. Within a few rounds, everyone knows Gandalf is done. The UI learns the same way - by subscribing to gossip from any agent. There is no "ask the coordinator for agent list" - the list emerges from gossip about AgentSpawned events.


## Key Components

```mermaid
graph TD
    subgraph "Gossip Network"
        JAKE[Jake<br/>local state: {...}<br/>vector clock: J:5, G:3, L:2]
        GANDALF[Gandalf<br/>local state: {...}<br/>vector clock: J:4, G:4, L:2]
        LEGOLAS[Legolas<br/>local state: {...}<br/>vector clock: J:5, G:3, L:3]
        FRODO[Frodo<br/>local state: {...}<br/>vector clock: J:4, G:3, L:2]
        GIMLI[Gimli<br/>local state: {...}<br/>vector clock: J:5, G:3, L:2]
    end

    subgraph "Gossip Exchange"
        JAKE -->|gossip round| GANDALF
        JAKE -->|gossip round| LEGOLAS
        GANDALF -->|gossip round| FRODO
        GANDALF -->|gossip round| GIMLI
        LEGOLAS -->|gossip round| GIMLI
        FRODO -->|gossip round| JAKE
    end

    subgraph "UI Layer"
        UI[SwiftUI App<br/>gossips with any agent]
    end

    UI -.->|subscribe to gossip| JAKE
    UI -.->|subscribe to gossip| GANDALF
```


## Pros

- **No single point of failure** - System continues operating even if Jake or any other agent crashes; there is no central state to lose

- **Horizontal scalability** - Adding more agents does not increase coordinator load; gossip naturally distributes the burden

- **Network partition tolerance** - Partitioned groups continue operating; when partition heals, gossip reconciles divergent state

- **Simplicity of agent implementation** - Each agent follows same simple protocol: receive gossip, merge into local state, gossip to peers

- **Natural eventual consistency** - State converges without distributed transactions or consensus protocols

- **Bounded message complexity** - O(log N) rounds to propagate to N agents; O(N) total messages per update

- **Resilient to message loss** - Redundant gossip paths mean lost messages are retransmitted by other peers


## Cons

- **Eventual consistency only** - Agents may temporarily disagree; "is Gandalf done?" has no authoritative answer until gossip converges

- **No global ordering** - Events may be observed in different orders by different agents; causal ordering requires vector clocks

- **Verification uncertainty** - Who verifies commitments when there is no authority? Gossip verification results, but disputes are complex

- **Debugging difficulty** - "Why does Jake think Gandalf is idle when Gandalf thinks he is done?" requires understanding gossip lag

- **Gossip protocol complexity** - Anti-entropy, pull vs push, failure detection, clock synchronization add implementation burden

- **Jake's authority challenged** - "The Proprietor" cannot command if there is no central authority; character mismatch

- **PRD hierarchical tension** - Parent-child relationships with oversight assume authority that gossip dissolves


## When to Choose This Architecture

**Choose Gossip Protocol when:**

- **Fault tolerance is paramount** - No agent failure should bring down the system; partial operation is acceptable

- **Scale to many agents is likely** - Dozens or hundreds of concurrent agents where central coordination becomes bottleneck

- **Network partitions are expected** - Agents running across unreliable network boundaries (containers, cloud, mesh)

- **Eventual consistency is acceptable** - Tasks are independent enough that temporary inconsistency does not break workflows

- **Decentralization aligns with product vision** - If Tavern's philosophy embraces agent autonomy over central control


**Avoid Gossip Protocol when:**

- **Strong consistency required** - Commitment verification, task assignment, and completion need authoritative answers

- **Hierarchical control is product feature** - Jake being "in charge" is part of the user experience

- **V1 scope is limited** - Gossip adds significant complexity for features not needed until scale arrives

- **Debugging must be straightforward** - When tracing "who told whom what" matters for development velocity

- **Agent count is small** - With fewer than 10-20 agents, gossip overhead exceeds coordinator overhead
