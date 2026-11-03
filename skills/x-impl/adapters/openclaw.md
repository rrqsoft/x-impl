# Adapter: OpenClaw

OpenClaw discovers `SKILL.md` natively, so the skills alone are a complete
install. Everything below is about tool names and the few places the harness
behaves differently from the others.

## Action map

| Action | Tool |
|---|---|
| load the x-impl skill | `read` on the location shown in the `<available_skills>` index; `skills_read` / `skills_search` when the index was trimmed for budget |
| read a stage file | `read` on `stages/<name>.md` in that same skill directory |
| read a file | `read` |
| write a file | `write` |
| edit a file | `edit`, or `apply_patch` |
| run a shell command | `exec`, with `process` for anything left running |
| search | `exec` with `rg` or `grep` — there is no dedicated file-search tool |
| fetch a web page | `web_fetch`; `web_search` for queries |
| dispatch a subagent | `sessions_spawn`, then `sessions_yield` to wait |
| dispatch a high-reasoning decider | `sessions_spawn` with an explicit `model`; see below |
| track a todo list | `progress_card` in a main session, a scratch markdown file in a subagent |
| create a worktree | `sessions_spawn` with `worktree: true`, or `git worktree add` via `exec` |
| ask the user | `ask_user` — main session only |

Running the `claude-cli` backend? The same tools are there under
`mcp__openclaw__<name>` — `mcp__openclaw__exec`, `mcp__openclaw__sessions_spawn`
and so on. Trust the tool list you actually have over this table.

## Subagents

`sessions_spawn` takes `context: "isolated"` for a clean child — use it. The
`"fork"` alternative copies your transcript into the child, which is the thing
the self-contained-brief rule exists to prevent. Add `label` for the UI and
`taskName` when you need a stable handle to send follow-ups to.

Wait with `sessions_yield`, which ends your turn until the child reports. Do not
poll `subagents(action=list)` in a loop; that is for debugging a child that went
quiet, not for waiting.

Several independent children can be spawned in one go — the build stage's parallel
mode works as written.

## The decider

The conclave stage's auto mode needs a decider that reasons harder than the
questioner. Spawn it with `model` set explicitly to the strongest model
configured here — typically a configured alias such as `fable` or `opus` — and
hand it the skill's `prompts/decider.md` filled in, as a file path.

**Check the spawn result.** An unknown model name does not fail; OpenClaw falls
back to the session default and logs a warning. Read `resolvedModel` in the
result and confirm it is the model you asked for. A decider silently running on
the session model is the questioner grading its own questions.

**No subagent available** (tool policy denies `sessions_spawn`, or you are
already a child at the nesting limit): run the decider pass inline, separately
labelled, with the same answer/rationale/confidence/escalate contract, and say
in the design doc that it ran inline.

## Escalations

`ask_user` is a close match for the conclave stage's batched escalation: one to three
questions, two to four options each, recommendation first with `(Recommended)`
in the label. That is the batch, sent once, exactly as the skill describes it.

It exists only in a main session. From a subagent, return the escalations in
your report and let the parent put them to the user — a child that tries to
interrogate the user has nowhere to send the question.

## Todo tracking

`progress_card` is main-session only too. In a subagent, take the documented
fallback and keep the list in a scratch markdown file.

## Worktrees

Two routes, and the build stage's Isolate step prefers the first.

**Native:** `sessions_spawn` with `worktree: true`, plus `worktreeName` and
`worktreeBaseRef` when you care about either. OpenClaw prepares the checkout
before the child's first turn and cleans it up afterwards. This only helps when
the isolated work is going to a child anyway.

**In this session:** there is no tool that gives the *current* session a
worktree, so take the git fallback in the skill's `references/isolate.md` —
`git worktree add` through `exec`, after the step 0 detection.

## How the bootstrap gets loaded

1. **Skill discovery.** `install.sh` puts `skills/x-impl` into
   `<project>/.agents/skills/` (or `~/.agents/skills/` with `--global`).
   OpenClaw reads, highest precedence first: `<workspace>/skills`,
   `<workspace>/.agents/skills`, `~/.agents/skills`, the state directory's
   `skills`, then workshop, bundled and configured extra directories. A name
   found in a higher tier wins outright. Grouped layouts are found several
   levels down, and `{baseDir}` in a skill body expands to that skill's folder.
   The model sees an `<available_skills>` index — name, description, location —
   and loads one by reading that location. `x-impl` is the only entry x-impl
   installs: OpenClaw scans nested directories several levels down, and the
   stage files are deliberately not named `SKILL.md` and carry no frontmatter,
   so they are never discovered as skills of their own. The user can name the
   skill as `$x-impl`.
2. **Instruction file**, with `--bootstrap`. The installer appends one line to
   an existing AGENTS.md:
   `For engineering work, use the x-impl skill (.agents/skills/x-impl/SKILL.md).`

A watcher picks up new and changed skills on the next turn, so neither an
install nor an edit needs a restart.

### Caveats worth knowing

- **Symlinks are skipped in the project directories.** Under
  `<workspace>/skills`, `<workspace>/.agents/skills` and configured extra
  directories, a symlink whose target resolves outside that root is ignored
  unless the target is listed in `skills.load.allowSymlinkTargets`. This is why
  `install.sh` copies rather than links for a project-scope OpenClaw install.
  `~/.agents/skills` and the state directory accept symlinked skill folders, so
  `--global` links normally.
- **Agent allowlists replace the defaults.** If an agent has a non-empty
  `skills` list in its configuration, only those names load — `x-impl` has to be
  added to that list before it appears.
- **Injected workspace files** are AGENTS.md, SOUL.md, IDENTITY.md, USER.md,
  BOOTSTRAP.md and MEMORY.md. **CLAUDE.md is not one of them**, and there is no
  import syntax, so the pointer line goes to AGENTS.md and stays a pointer the
  model follows. Each file is capped at 20,000 characters, 60,000 across all of
  them. Subagents receive AGENTS.md only.
- **Restricted runs lose native skills.** A run with a restricted tool list — a
  cron job with `toolsAllow`, for instance — has skill loading disabled. Those
  sessions need the brief inline.
- **The `claude-cli` backend** needs nothing extra: OpenClaw packages the
  eligible skills as a temporary plugin for that run.

## Hooks

OpenClaw has two places the index could be re-injected: an internal
`agent:bootstrap` hook with a mutable list of bootstrap files, and a plugin
`before_prompt_build` hook returning context to prepend or append. Neither is
needed — skill discovery plus the AGENTS.md pointer already cover it — and
nothing is shipped here. The shapes are in `docs/porting.md`. Note that the
bundled bootstrap-extra-files mechanism accepts only a whitelist of basenames,
so it will not pick up a file of x-impl's.

## Telemetry

x-impl sends nothing anywhere. OpenClaw itself has two things to know about:

- **Update check**, `update.checkOnStart`, **on by default**: one request every
  24 hours to `telemetry.openclaw.ai` carrying the version and platform. Turn it
  off with `OPENCLAW_NO_AUTO_UPDATE=1` or `update.checkOnStart: false`.
- **Feature statistics**, `telemetry.enabled`, off by default. `DO_NOT_TRACK=1`
  forces it off regardless of configuration.

`openclaw telemetry show` prints what would be sent.
