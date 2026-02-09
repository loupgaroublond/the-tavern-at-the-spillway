# Team Coordinator Prompt

## Original (from ClodKit session 84f88d36)

there's a bunch of open beads, and you are the coordinator for getting them done. you will not work directly on them yourself, but create a workteam to do them

here's the catch: eithre everyone will work on the same shared code, and you will need to make sure they don't step on each other's toes, or they will need to build worktrees, my suggestion is build them as subdirs from this dir, matching the branch name. you can run as many members of the team you think you can, as long as all the other constraints are met.

you need to look at all the beads for structure and flow, to see what areas of the code will be altered in which bead. then, create team members, assign them individual or several beads, what ever makes sense to develop a git commit. focus on smaller, incremental changes, and it's ok to spend more time waiting on tests, if the team is testing smaller incremental git commits. if all the open tickets focus on the same area, for instance, you probably can only run one team member at a time, but if there are elements that can be parallelized, you can run multiple. spin them up and down as you need them. a team member should work on multiple beads making multiple changes, if they are all related. otherwise, try to use fresh agents when moving to new areas.

you must use your judgement how to assign the beads, how to organize the team, which ones to do on main, vs worktrees, and even, what model the agent should use, some beads might be ok to run on sonnet or haiku, you can take a look. while the team members may talk to each other to collaborate, you are the ultimate arbiter of questions

finally, as these workers work on their task, your job is to coodinate merging into main. each worker must make sure all their commits will FF merge to main, ie, their shared root is the HEAD of main. if their code is behind main, they must rebase it first, before they can merge. you will decide in what order each agent may merge into main. you will allow each agent to merge only when it is their turn to do so, however, it is their responsibility to be aware of changes to main, to make sure their work is compatible with it. you may however proactively communicate about changes to the team.

please try to keep everyone working as efficiently as possible, so things you may do, do those things where it will help efficiency. these are not suggestions, the word "may" here means simply you have permission. you will do all of these things here

note that there's more than 50 open beads, so you must use -n 0 when querying it. also note, the task is to complete all open beads, from all epics

---

## Adapted for Tavern

There's a bunch of open beads, and you are the coordinator for getting them done. You will not work directly on them yourself, but create a workteam to do them.

Here's the catch: either everyone will work on the same shared code, and you will need to make sure they don't step on each other's toes, or they will need to build worktrees. My suggestion is build them as subdirs from this dir, matching the branch name. You can run as many members of the team as you think you can, as long as all the other constraints are met.

You need to look at all the beads for structure and flow, to see what areas of the code will be altered in which bead. Then, create team members, assign them individual or several beads, whatever makes sense to develop a git commit. Focus on smaller, incremental changes, and it's ok to spend more time waiting on tests, if the team is testing smaller incremental git commits. If all the open tickets focus on the same area, for instance, you probably can only run one team member at a time, but if there are elements that can be parallelized, you can run multiple. Spin them up and down as you need them. A team member should work on multiple beads making multiple changes, if they are all related. Otherwise, try to use fresh agents when moving to new areas.

You must use your judgement how to assign the beads, how to organize the team, which ones to do on main, vs worktrees, and even, what model the agent should use — some beads might be ok to run on sonnet or haiku, you can take a look. While the team members may talk to each other to collaborate, you are the ultimate arbiter of questions.

Finally, as these workers work on their task, your job is to coordinate merging into main. Each worker must make sure all their commits will FF merge to main, i.e., their shared root is the HEAD of main. If their code is behind main, they must rebase it first, before they can merge. You will decide in what order each agent may merge into main. You will allow each agent to merge only when it is their turn to do so, however, it is their responsibility to be aware of changes to main, to make sure their work is compatible with it. You may however proactively communicate about changes to the team.

Please try to keep everyone working as efficiently as possible, so things you may do, do those things where it will help efficiency. These are not suggestions, the word "may" here means simply you have permission. You will do all of these things here.

**Scope:** Complete all open beads from these epics and standalone items — EXCLUDING the feature backlog epic (`the-tavern-at-the-spillway-azu`):

- Epic `vpn`: Fill formal spec modules from PRD and reader (16 tasks)
- Epic `hq1`: Epic 1: Message Rendering Overhaul (9 tasks)
- Epic `jhm`: Epic 2: Streaming Responses (4 tasks)
- Epic `cgv`: Epic 3: Input Enhancement (2 tasks)
- Epic `m3o`: Epic 4: Permissions Subsystem (5 tasks)
- Epic `cxg`: Epic 5: Slash Command Infra + Core Commands (9 tasks)
- Epic `l2q`: Epic 6: Custom Slash Commands (4 tasks)
- Epic `2ah`: Epic 7: Management UIs (3 tasks)
- Epic `6ts`: Epic 8: Side Pane — TODOs & Background Tasks (3 tasks)
- Epic `vpv`: Epic 9: Chat UX Polish (4 tasks)
- Standalone: `gfg` (Jake prompt bug), `dec` (ClodKit rename), `iy1` (apostrophe bug), `96m` (SDK testing), `dd4` (real commitments), `p70` (agent spawning), `7g6` (streaming)

Use `bd list -n 0 --status open --json` when querying beads. Use `bd show <id> --json` to get full details on individual beads. Use `bd update <id> --status in_progress` when claiming, and `bd close <id> --reason "..."` when done.

Build and test commands (redo-based, each command includes everything above it):

```bash
redo Tavern/xcodegen     # Regenerate Xcode project from project.yml
redo Tavern/build        # + compile the project (xcodebuild)
redo Tavern/test-core    # + run TavernCoreTests only (framework layer — fast)
redo Tavern/test         # + run ALL Grade 1+2 unit tests (TavernCore + app-level)
redo Tavern/run          # + kill any running instance + launch the app
```

Use `test-core` when changes are limited to `Sources/TavernCore/` — it's the fastest feedback loop, covering only the framework layer. Use `test` when changes touch the app target (`Sources/Tavern/`) or you want full unit test coverage before merging. Both skip integration tests (Grade 3+) which hit real Claude API.
