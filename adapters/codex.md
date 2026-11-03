# Adapter: Codex CLI

## Action map

| Action | Tool |
|---|---|
| load skill `<name>` | Codex's native skill discovery; failing that, read `.agents/skills/<name>/SKILL.md` |
| read a file | the file-read tool |
| write a file | `apply_patch` (add-file) |
| edit a file | `apply_patch` |
| run a shell command | `shell` |
| search | `shell` with `rg` / `ls` |
| fetch a web page | the web tool, when enabled |
| dispatch a subagent | `spawn_agent`, then `wait_agent` / `followup_task` |
| dispatch a high-reasoning decider | `spawn_agent` with explicit `model` **and** `reasoning_effort: "high"` |
| track a todo list | the plan/todo tool if present, otherwise a scratch markdown file |
| create a worktree | `git worktree add` via `shell` |

## Subagents need multi-agent turned on

Subagent dispatch is gated. The user has to enable it in `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

Without it, `spawn_agent` is simply absent — take the no-subagent fallback in
each skill rather than inventing a call.

Spawn children with a clean context (the spawn tool's "no forked turns" option);
the default copies your whole transcript into the child, which is exactly what
the self-contained-brief rule exists to avoid.

Trust your actual tool list over this table. Codex's multi-agent surface has
shipped in more than one shape, and tool names move.

## The decider

Set **both** `model` and `reasoning_effort: "high"` on the spawn. Setting
`model` alone silently resets effort to that model's default. Check the model
name against the session's current spawn allowlist before using it — a stale
model name is a hard error, not a fallback.

**No subagent available:** run the decider pass inline, separately labelled,
with the same answer/rationale/confidence/escalate contract, and note in the
design doc that it ran inline.

## Waiting

`wait_agent` is an event subscription, not a poll. Keep doing local work while
children run; when genuinely idle, wait in long bounded stretches and reconcile
between them. Short repeated polls buy nothing and cost a turn each.

## Worktrees

Codex has no native worktree tool, so `x-build`'s Isolate step takes the git
fallback. Detect the environment before creating anything:

```sh
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree; do not create another.
- `BRANCH` empty → **detached HEAD**. The Codex App manages its own workspace
  this way. You cannot branch or push from it. Commit the work, then tell the
  user to use the App's own "create branch" or hand-off-to-local controls. You
  can still run tests, stage files, and print a suggested branch name, commit
  message, and PR description for them to use. `x-land` has a two-option menu
  for this case, and it never removes a workspace the App owns.

## How the bootstrap gets loaded

1. **Skill discovery.** `install.sh` links each `skills/x-*` directory into
   `.agents/skills/` (or `~/.agents/skills/` with `--global`), which Codex reads
   natively.
2. **Instruction file**, with `--bootstrap`. The installer copies `x-impl.md`
   and `adapters/` into `.x-impl/` and appends one line to an existing
   AGENTS.md: `Read .x-impl/x-impl.md for the x-impl workflow skills.`
   Codex has no `@`-include, so this is a pointer the model follows, not an
   inline expansion.

AGENTS.md is capped around 32 KiB. The appended line is one line; keep it that
way rather than inlining the index.

A `SessionStart` hook in `.codex/hooks.json` could re-inject the index, but the
user has to trust hooks before they run. Not shipped — see `docs/porting.md`.
