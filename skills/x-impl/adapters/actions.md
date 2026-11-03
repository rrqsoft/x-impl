# Action vocabulary

x-impl's stage files are written in actions, not tool names, so the same text
runs unchanged on every harness. Each harness file in this directory maps these
actions to its real tools.

| Action | Meaning |
|---|---|
| **read a stage file** | Bring the full text of `stages/<name>.md` — inside the x-impl skill directory, alongside this one — into context and follow it. |
| **read a file** | Read a file's contents, or part of it. |
| **write a file** | Create a file, or replace one wholesale. |
| **edit a file** | Change part of an existing file in place. |
| **run a shell command** | Execute a command in the workspace and read its output and exit status. |
| **search** | Find files by name or content across the tree. |
| **fetch a web page** | Retrieve a URL's content. Optional: no x-impl skill requires it. |
| **dispatch a subagent** | Start a fresh agent with a self-contained brief and an isolated context, and get its report back. |
| **dispatch a high-reasoning decider** | Dispatch a subagent pinned to the strongest reasoning configuration available, used for judgement calls rather than for doing work. |
| **track a todo list** | Keep a visible list of the current task's items and their state. |
| **create a worktree** | Obtain an isolated checkout of the repository to work in. |

## Degradation

Three of these are optional. When a harness lacks one, the skill that wants it
says what to do instead — never invent a tool call:

- **dispatch a subagent** missing → do the work inline, in this session, and say
  that no independent pass happened.
- **dispatch a high-reasoning decider** missing → run a separate decider pass
  inline over the drafted questions, keeping the same contract (answer,
  rationale, confidence, escalate flag).
- **track a todo list** missing → keep the list in a scratch markdown file.
- **create a worktree** missing or blocked → work in place and say so.

The rest (read, write, edit, shell, search) are assumed. A harness without them
cannot run these skills.
