# x-impl

A local, agent-agnostic engineering workflow harness. Eight skills, a
bootstrap index, a per-harness tool adapter, and a shell installer. It runs on
Claude Code, Codex CLI, OpenCode and OpenClaw, and it talks to nothing.

## Philosophy

**A thread you follow, not a cage.** These skills describe how work goes well.
They do not seize control of the session, and nothing here shouts at the model
to make it comply.

**An index, not orders.** The bootstrap lists what exists and when each thing is
useful. Picking the right one is still a judgement call.

**User instructions win.** AGENTS.md, CLAUDE.md, and anything the user asks for
directly override these skills. The skills in turn override default habits.
Nothing here owns someone else's process.

**Actions, not tools.** Skill bodies say "dispatch a subagent" and "run a shell
command". `adapters/<harness>.md` maps those to the tools a given harness
actually has. One skill body, four harnesses, no edits.

**Evidence before claims.** Nothing is done, fixed or passing until the command
that proves it has been run in this turn and its output read. A subagent's
report is a claim; a green run from an hour ago proves the tree it ran on.

## The pipeline

```
x-conclave → x-plan → x-build → x-land
```

Join it wherever the work starts; skip what does not apply.

| Skill | For |
|---|---|
| `x-impl` | The index itself, as a loadable skill. |
| `x-conclave` | Settling an open-ended design — autonomously, or by grilling you. |
| `x-plan` | Turning a design into small verifiable tasks. |
| `x-build` | Isolating the workspace and running the work: per task, inline, or several independent problems in parallel. |
| `x-tdd` | Red / green / refactor. |
| `x-debug` | Root cause before fixes. |
| `x-answer` | Handling review feedback technically. |
| `x-land` | Verifying, reviewing, and landing the work. |

`x-impl` is the only skill you invoke yourself. The other seven carry
`user-invocable: false`: the model loads them when the work calls for them, but
they are not slash commands. Claude Code and OpenClaw enforce this. OpenCode
ignores the flag, and Codex has no equivalent, so there they stay reachable by
name.

`x-tdd` and `x-debug` are what `x-build` uses inside each task. `x-answer`
handles whatever a review sends back, from a reviewer subagent, a colleague, or
a PR thread. For a review without a landing, ask for a review only; `x-land` then runs its
review step alone.

### The conclave

`x-conclave` is the piece that differs most from a normal design interview. A
closed council: the questions get deliberated privately, and the session comes
back out with decisions.

The session model builds the decision tree, resolves one branch at a time, looks
the facts up — facts are never asked — and drafts every question with real
options and a recommendation. Then one of two things happens.

**Auto, the default.** The answers come from a **decider**: a subagent pinned to
the strongest reasoning configuration available, returning an answer, a
rationale, a confidence level, and an escalate flag. Only six things get
escalated: irreversible or outward-facing work, spending money, security and
privacy, genuinely ambiguous intent, a conflict with an explicit instruction,
and the decider's own low confidence. Escalations go out once, as a batch, at
the end, each as a yes/no or a pick-one with the recommendation first. Zero
escalations means the session does not stop at all. When nobody can answer, it
proceeds on the recommendation and tags the row `ASSUMED`, which `x-land`
re-surfaces before anything outward-facing.

**Interactive.** Ask to be grilled and you answer every question yourself, one
at a time, each with the recommendation attached. Same tree, same log — it is
simply auto mode with every question escalated.

Either way it ends in a design doc with a decision log, and a `Decided by`
column saying which rows were yours. Overriding one row reopens only that
branch.

## Install

One line, no checkout:

```sh
curl -fsSL https://raw.githubusercontent.com/rrqsoft/x-impl/master/install.sh | sh
curl -fsSL https://raw.githubusercontent.com/rrqsoft/x-impl/master/install.sh | sh -s -- --harness openclaw
X_IMPL_VERSION=v0.1.0 curl -fsSL https://raw.githubusercontent.com/rrqsoft/x-impl/master/install.sh | sh
```

That downloads the latest release tarball, checks it against the published
`SHA256SUMS`, unpacks it under `~/.x-impl/releases/<tag>/`, points
`~/.x-impl/current` at it, and then runs the installer from the unpacked copy.
Because the installed symlinks resolve through `current`, upgrading is just
re-running the one-liner. It stops without installing anything if the checksum
does not match.

A piped run has no meaningful project directory, so it defaults to `--global`.
Everything else still works: pass `--project DIR` for a project install, and
any other flag below after `sh -s --`. `X_IMPL_VERSION` pins a release;
`X_IMPL_HOME` moves `~/.x-impl`; `X_IMPL_REPO` points at a fork.

To uninstall what the one-liner installed:

```sh
sh ~/.x-impl/current/install.sh --global --uninstall
rm -rf ~/.x-impl
```

Or from a checkout, which never touches the network:

```sh
sh install.sh                       # this project, all harnesses
sh install.sh --global              # the per-user skill directories instead
sh install.sh --harness openclaw    # one harness only
sh install.sh --copy                # copy instead of symlink
sh install.sh --bootstrap           # also wire the index into the instruction file
sh install.sh --dry-run             # print what would happen
sh install.sh --uninstall           # remove exactly what we installed
```

`--harness` takes `claude`, `codex`, `opencode`, `openclaw` or `all`, and `all`
is the default.

**Where the skills go.** Claude Code reads `.claude/skills/`; Codex, OpenCode
and OpenClaw all read `.agents/skills/`. The installer puts each `skills/x-*`
directory into whichever of those the chosen harnesses need, as a symlink by
default. With `--global` it uses `~/.claude/skills` and `~/.agents/skills`.

**One exception to symlinking.** OpenClaw ignores a symlink in a project skills
directory whose target resolves outside the workspace, so a project-scope
install that covers OpenClaw — `--harness openclaw`, or `--harness all` —
*copies* into `.agents/skills` and prints a one-line note saying why.
`.claude/skills` still gets symlinks, and `--global` links everywhere. `--copy`
forces copying for everything and silences the note.

Copies carry a `.x-impl-copy` marker file. Re-running replaces a marked copy
wholesale, so changed files land and dropped files go away; the tree afterwards
matches the source either way.

**What `--bootstrap` adds.** It copies `x-impl.md` and `adapters/` into
`.x-impl/`, then appends **one line** to an instruction file you already have:
`@.x-impl/x-impl.md` for Claude Code, or
`Read .x-impl/x-impl.md for the x-impl workflow skills.` for the rest. Every
appended line carries an `<!-- x-impl -->` marker.

The installer never creates CLAUDE.md or AGENTS.md. If the file it wants is not
there it prints the line and leaves the decision to you.

Re-running changes nothing. A directory of the same name that we did not create
is left alone, with a warning. `--uninstall` removes only our own symlinks and
copies, the `.x-impl/` files we wrote, and lines carrying the marker.

## Harnesses

Installing the skills is enough on its own, everywhere: all four harnesses
discover `SKILL.md` natively and list what they found. `--bootstrap` is
reinforcement for sessions that would otherwise never look at the index, and
hooks are an optional layer nobody needs — `docs/porting.md` has the shapes.

What follows is one section per harness. Read yours and skip the others.

### Claude Code

```sh
curl -fsSL https://raw.githubusercontent.com/rrqsoft/x-impl/master/install.sh | sh -s -- --harness claude
sh install.sh --harness claude --bootstrap   # from a checkout
```

Skills land in `.claude/skills/` as symlinks, or `~/.claude/skills/` with
`--global`.

**Bootstrap.** Appends `@.x-impl/x-impl.md` to an existing CLAUDE.md, which
Claude Code expands inline. With no CLAUDE.md it appends the pointer form to
AGENTS.md instead — and Claude Code reads AGENTS.md *only* while no CLAUDE.md
exists, so adding one later silently orphans that line.

**Hooks.** A `SessionStart` hook could re-inject the index after `/clear` and
compaction. Possible, not shipped.

**Subagents** are available as a tool, several per message running in parallel.
**The decider** is one of those with `model` set explicitly to the strongest
model the session can reach; an omitted model inherits the session's, which
defeats the point. **Todo tracking** has a native tool. **Worktrees** have a
native tool too, and `x-build` prefers it over `git worktree add`.

**Telemetry.** Claude Code's own, not x-impl's. Opt out with
`DISABLE_TELEMETRY=1`, `DISABLE_ERROR_REPORTING=1` and
`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`.

Details: `adapters/claude.md`.

### Codex CLI

```sh
curl -fsSL https://raw.githubusercontent.com/rrqsoft/x-impl/master/install.sh | sh -s -- --harness codex
sh install.sh --harness codex --bootstrap   # from a checkout
```

Skills land in `.agents/skills/` as symlinks, or `~/.agents/skills/` with
`--global`.

**Bootstrap.** Appends `Read .x-impl/x-impl.md for the x-impl workflow skills.`
to an existing AGENTS.md. Codex has no include syntax, so this is a pointer the
model follows rather than an inline expansion — which is the right shape anyway,
because AGENTS.md is capped around 32 KiB combined and the index would eat it.

**Hooks.** A `SessionStart` entry in `.codex/hooks.json` is possible, but Codex
will not run a hook until you have trusted it through `/hooks`. Not shipped.

**Subagents** are gated behind `multi_agent = true` in `~/.codex/config.toml`;
without it the spawn tool is simply absent and the skills take their
no-subagent fallback. **The decider** needs both `model` and
`reasoning_effort: "high"` on the spawn — setting `model` alone quietly resets
effort to that model's default. **Todo tracking** uses the plan tool when
present, a scratch file otherwise. **Worktrees** have no native tool, so
`x-build` takes the git fallback; watch for the detached-HEAD workspace the
Codex App manages, which you cannot branch or push from.

**Telemetry.** Codex's own. Turn it off with `[analytics] enabled = false` in
`config.toml`.

Details: `adapters/codex.md`.

### OpenCode

```sh
curl -fsSL https://raw.githubusercontent.com/rrqsoft/x-impl/master/install.sh | sh -s -- --harness opencode
sh install.sh --harness opencode --bootstrap   # from a checkout
```

Skills land in `.agents/skills/` as symlinks, or `~/.agents/skills/` with
`--global`. OpenCode reads `.agents/skills`, `.claude/skills` and
`.opencode/skills`, so one link set covers it alongside Codex.

**Bootstrap.** Appends the same AGENTS.md pointer line. OpenCode falls back to
CLAUDE.md when there is no AGENTS.md.

**Hooks.** A local plugin could inject the index at session start, but the
plugin API differs between OpenCode generations and none of it is confirmed
here. Treat as experimental; not shipped.

**Subagents** exist in both generations, under different tool names. **The
decider** is a named `decider` agent with a pinned model, because OpenCode takes
a subagent's model from the agent definition rather than the dispatch call —
copy `adapters/opencode/decider.md` into your agents directory and set its
`model:`. **Todo tracking** has a native tool in v1 and a scratch file in v2.
**Worktrees** have no native tool; git fallback.

**Telemetry.** OpenCode does not document an opt-out. That is worth knowing
before running it somewhere that matters.

Details: `adapters/opencode.md`.

### OpenClaw

```sh
curl -fsSL https://raw.githubusercontent.com/rrqsoft/x-impl/master/install.sh | sh -s -- --harness openclaw
sh install.sh --harness openclaw --bootstrap   # from a checkout
```

The one-liner is a `--global` install, so it links `~/.agents/skills/`, which
OpenClaw accepts. For the project-scope copy behaviour described next, run it
with `--project .` or from a checkout.

Skills land in `.agents/skills/` **as copies**, because OpenClaw skips a project
symlink pointing outside the workspace unless its target is explicitly
allowlisted. `--global` writes `~/.agents/skills/` as symlinks, which OpenClaw
does accept. A watcher picks up new and changed skills on the next turn, so
neither case needs a restart.

Two caveats. OpenClaw searches several skill directories in precedence order and
a higher tier wins by name, so a stale `x-build` in the workspace's own `skills/`
shadows the installed one. And if an agent has a non-empty `skills` allowlist in
its configuration, that list *replaces* the defaults — the `x-*` names have to
be added to it before they load.

**Bootstrap.** Appends the AGENTS.md pointer line, and only there: OpenClaw does
not read CLAUDE.md at all, and there is no import syntax. Injected files are
capped at 20,000 characters each and 60,000 together, which a one-line pointer
costs nothing against. Subagents receive AGENTS.md only.

**Hooks.** Both an internal bootstrap hook and a plugin prompt-build hook could
re-inject the index. Available, not needed, not shipped.

**Subagents** spawn with an isolated context and are waited on by yielding the
turn, not by polling. **The decider** takes an explicit strong model — check
`resolvedModel` in the spawn result, because an unknown model name falls back to
the session default with only a warning. **Escalations** map onto the native
ask-user tool: one to three questions, two to four options, recommendation
first. It and **todo tracking** are main-session only; a subagent returns
escalations in its report and keeps its todo list in a scratch file.
**Worktrees** come with a spawned child, or via git in the current session.

**Telemetry.** OpenClaw checks for updates by default — one request a day to
`telemetry.openclaw.ai` with version and platform. Turn it off with
`OPENCLAW_NO_AUTO_UPDATE=1` or `update.checkOnStart: false`. Feature statistics
are off by default, and `DO_NOT_TRACK=1` forces them off.

Details: `adapters/openclaw.md`.

## Privacy

x-impl sends nothing anywhere, and the skills themselves never reach the
network at all.

- No telemetry, analytics, usage reporting, or version beacons of any kind.
- No server, no background process, no browser companion, no auto-update, no
  marketplace manifests.
- No URLs anywhere in the skills, the adapters, or the index.
- No runtime dependencies. The installer is POSIX `sh` and touches only the
  paths named above.

The one exception is the one-liner install, which by its nature downloads
something. Piped in by `curl`, `install.sh` makes exactly these requests, all
to GitHub: the `releases/latest` redirect to learn the tag (skipped when
`X_IMPL_VERSION` is set), then the release tarball and its `SHA256SUMS`, which
it verifies before unpacking. Nothing is uploaded, and no identifier is sent.
Run from a checkout or an unpacked tarball, the same script makes no network
calls at all — `release-check.sh` enforces that those GitHub URLs are the only
ones in the repository.

Everything here is plain text on your disk. What the harness around it does is a
separate question, and each harness section above names its own telemetry and
the opt-out.

## Layout

```
x-impl.md            the bootstrap index
adapters/            action vocabulary + one file per harness
skills/x-*/          the eight skills
install.sh           POSIX sh installer
scripts/             release preflight and build (not shipped)
.github/workflows/   the release workflow (not shipped)
docs/authoring.md    writing and editing skills in this style
docs/porting.md      wiring x-impl into another harness
```

## Releasing

Releases are cut from `master`, by tag.

```sh
sh scripts/release-check.sh      # preflight, locally, first
git tag v1.2.3
git push me v1.2.3
```

`release-check.sh` parses `install.sh`, checks every skill's frontmatter,
resolves the relative paths skills point at, rejects any URL that is not one of
x-impl's own release URLs in `install.sh` or this README, and runs the
installer end to end in a scratch directory — install, re-install, uninstall —
so a broken release fails on your machine rather than in CI.

Pushing a `v*` tag runs `.github/workflows/release.yml`. It refuses the tag
unless it is `vMAJOR.MINOR.PATCH` (an optional `-suffix` marks a prerelease)
*and* its commit is an ancestor of `origin/master`. Then it runs the same
preflight, builds `dist/`, and publishes a GitHub release:

```
x-impl-v1.2.3.tar.gz   README, LICENSE, x-impl.md, install.sh, adapters/, docs/, skills/
NOTES.md               commits since the previous v* tag
SHA256SUMS             verify with `shasum -a 256 -c SHA256SUMS`
```

The tarball is built with `git archive`, so the same tag produces the same
bytes on any machine. The workflow will not overwrite a release that already
exists — delete it by hand, or cut a new tag.

Build the artifacts locally with `sh scripts/release-build.sh v1.2.3`.

## Writing your own

The conventions these eight follow — the frontmatter contract, trigger-first
descriptions, the action vocabulary, the announce rule, picking the form that
matches the failure — are in `docs/authoring.md`. Read it before adding a ninth
skill, and check first whether what you want is a section of an existing one.

## Licence

MIT. See `LICENSE`.
