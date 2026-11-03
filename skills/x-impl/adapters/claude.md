# Adapter: Claude Code

## Action map

| Action | Tool |
|---|---|
| read a stage file | `Read` on `stages/<name>.md` in the x-impl skill directory |
| read a file | `Read` |
| write a file | `Write` |
| edit a file | `Edit` |
| run a shell command | `Bash` |
| search | `Grep`, `Glob` |
| fetch a web page | `WebFetch`, `WebSearch` |
| dispatch a subagent | `Agent` (a general-purpose subagent), one call per agent; several calls in one message run in parallel |
| dispatch a high-reasoning decider | `Agent` with `model` set to the strongest model available in this session (an Opus-class model); see below |
| track a todo list | `TodoWrite` |
| create a worktree | `EnterWorktree` if present, otherwise `git worktree add` via `Bash` |

## The decider

The conclave stage's auto mode needs a decider that reasons harder than the
questioner.

Dispatch an `Agent` with `model` set explicitly to the strongest model this
session can reach — an Opus-class model — and pass it
the skill's `prompts/decider.md` filled in. Always set `model`
explicitly: an omitted model inherits the session's, which defeats the point
when the session is running on something cheaper.

Give the decider the question batch as a file path rather than pasting it, so
the batch does not also sit in your own context.

**No subagent available** (tool policy denies `Agent`, or you are already a
subagent at the nesting limit): run the decider pass inline — a separate,
explicitly labelled pass over the drafted questions, producing the same
answer/rationale/confidence/escalate record. Say in the design doc that the
decider ran inline.

## Worktrees

The build stage's Isolate step asks for the native tool first. Here that is
`EnterWorktree` / `ExitWorktree`, which own placement, branch creation, and
cleanup. Prefer them. Reaching for `git worktree add` while a native tool exists
leaves state the harness cannot see or clean up — and the land stage cleanup step
will then leave it alone, because it is not ours to remove.

## How the bootstrap gets loaded

Two independent paths; either is enough.

1. **Skill discovery.** `install.sh` links `skills/x-impl` into
   `.claude/skills/` (or `~/.claude/skills/` with `--global`). Claude Code lists
   the installed skill's name and description, so `x-impl` is discoverable by
   description alone and can be loaded with `Skill`. It is the only skill
   installed: the stage files under it carry no frontmatter and are read as
   plain files, so nothing else shows up in the skill list.
2. **Instruction file**, with `--bootstrap`. The installer appends a single
   line to an **existing** CLAUDE.md:
   `For engineering work, use the x-impl skill (.claude/skills/x-impl/SKILL.md).`

Claude Code reads AGENTS.md only when no CLAUDE.md exists. If the project has
only AGENTS.md, the installer appends there and that is where Claude will read
it; if both exist, CLAUDE.md is the one that counts.

A `SessionStart` hook that re-injects the index after `/clear` and compaction is
possible but is not shipped here — see `docs/porting.md`.
