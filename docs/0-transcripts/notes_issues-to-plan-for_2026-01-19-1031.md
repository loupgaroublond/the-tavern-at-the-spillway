# Issues to Plan For

**Created:** 2026-01-19 10:31

These are not current pain points, but anticipated issues that a multi-agent orchestration framework will need to address. Captured from brainstorming during problem statement discussion.


## Framework-Level Concerns

1. **Context handoff** — When one agent discovers something another needs, how does that knowledge transfer? Agents are often isolated.

2. **Debugging failed runs** — Understanding the chain of decisions when an agent goes off the rails. Postmortems are hard.

3. **Cost visibility** — Tracking token spend across agents, budgeting, knowing which tasks are expensive vs cheap.

4. **Priority/attention routing** — Which agent deserves user attention right now? Without this, the user becomes the scheduler.

5. **State persistence** — What happens when a session dies mid-task? Resumption is often "start over with context summary."

6. **Merge/integration pain** — Beyond clobbering, the mechanics of combining work from multiple agents into coherent output.

7. **Validation/testing of agent output** — How do you know the agent did it right before accepting the work?

8. **Rollback** — Undoing agent work that looked fine but wasn't. Git helps but isn't always clean.

9. **"Why did it do that?"** — Visibility into agent reasoning, not just outputs.
