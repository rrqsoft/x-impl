# Porting x-impl to another harness

What it takes to make x-impl work somewhere it has not been tried. Design notes
only — no hook files are shipped yet.

## What is actually required

**One of these two, and that is the whole hard requirement:**

1. **Native skill discovery.** The harness scans a directory of
   `<name>/SKILL.md` files, lists their `name` and `description`, and can load
   one on demand. Point `install.sh` at that directory and you are done: the
   `x-impl` skill's own description is written so it surfaces at the start of an
   engineering task, and every other skill is reachable by name.
2. **An instruction file** the harness always loads — AGENTS.md, CLAUDE.md, or
   its own equivalent. Add one line pointing at `.x-impl/x-impl.md`. If the
   harness has an include syntax, use it; if not, the line is a pointer the
   model follows with a file read.

Both is better than either. Neither means the harness cannot be supported
without the user pasting something every session, which is not support.

**Plus a tool map.** Write `adapters/<harness>.md` against
`adapters/actions.md`. The reliable way to get real tool names is to ask the
running model to list the exact machine names of every tool it can call — not to
assume they match a harness this one was forked from. Forks keep the syntax and
change the semantics more often than you would like.

Three capabilities are optional and each has a stated fallback in the skills
that use them: subagent dispatch, todo tracking, and worktree creation. Say in
the adapter which are missing. Never leave an agent to invent a tool call.

## Checking a port works

The portable signal is the **announce line**. Every x-impl skill's procedure
starts with `Using <skill-name> to <purpose>.` Start a clean session, give it
something a skill clearly covers ("let's build a small todo app"), and look for
that line before any file gets written. Watching for a specific tool event is a
nice extra per harness, but it is not portable and it is not the gate.

A quicker smoke check: ask the session to list the skills it can use. If the
install took, the `x-` names are there.

Prove anything you assume with a unique marker. Put a nonsense token in the
bootstrap, start a fresh session, and ask for it back. If it only comes back
after a file read, the include was not expanded — and "the model usually reads
it" is a different guarantee from "it is always in context".

## Optional layer: re-injecting the index

Instruction files survive compaction on most harnesses, but not all, and not
after every `/clear`. A session-start hook closes that gap. Nothing here needs
one; this is reinforcement.

The principle for all of them: the hook is a local script that reads
`.x-impl/x-impl.md` and prints it as additional context. It takes no arguments,
reads no network, and writes nothing.

### Claude Code

A `SessionStart` hook in `.claude/settings.json`. The matcher covers the three
moments context gets rebuilt:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "sh .x-impl/hooks/session-start.sh",
            "shell": "bash",
            "async": false
          }
        ]
      }
    ]
  }
}
```

The script prints a single JSON object on stdout:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "…contents of x-impl.md, JSON-escaped…"
  }
}
```

Two things to get right. The nesting is Claude-specific — several other
harnesses read a top-level `additionalContext` instead, and emitting both gets
the content injected twice. And a `startup` hook can run with a broken or empty
`PATH`, so a script that depends on `dirname` or `cat` being resolvable will
fail silently at exactly the moment it matters; use shell builtins and derive
the script's own directory from `$0`.

This would be an installer change: `install.sh` currently never edits
`settings.json`, and merging into an existing one safely is the real work.

### Codex CLI

A `SessionStart` entry in `.codex/hooks.json`, same idea. Codex will not run a
hook until the user has trusted it — there is a `/hooks` step they have to go
through — so a hook-based port has a manual enablement step by design. Document
it; do not try to route around it.

AGENTS.md is capped around 32 KiB on Codex. The pointer line is one line;
inlining the index instead would eat into that budget for no benefit.

### OpenCode

A local plugin in `.opencode/plugins/` can register the skills directory and
inject context at session start. The API differs between OpenCode generations —
one exposes a message-transform hook, another a session context hook plus a
skill-registration transform — and nothing here has been verified against a live
install. Treat it as experimental.

Two things worth knowing if you try it: injecting the controller index into
**subagent** sessions makes workers restart design and approval cycles their
parent already settled, so detect child sessions and skip them; and a plugin
that throws during setup can take down the whole plugin generation, so contain
failures per skill rather than letting one bad payload disable everything.

### OpenClaw

Nothing needs porting here — skill discovery plus the AGENTS.md pointer already
cover the gap a hook would close, and `adapters/openclaw.md` is written. This is
only for someone who wants the index re-injected anyway.

Two mechanisms exist, and both are described rather than shipped.

**The internal bootstrap hook.** An `agent:bootstrap` hook receives the list of
workspace files about to be injected and can change it before the prompt is
built. Adding `.x-impl/x-impl.md` to that list puts the index in context on
every session, the same way AGENTS.md gets there. Note that the *bundled*
bootstrap-extra-files helper is not a route to this: it only accepts a whitelist
of known basenames, and `x-impl.md` is not one of them. A hook of your own is
the honest path.

**A plugin `before_prompt_build` hook.** It returns context to prepend or append
for the turn being assembled. Reading `.x-impl/x-impl.md` and returning it as
appended context is a handful of lines, and it fires on every turn rather than
once per session — which is more than is needed and costs tokens each time.
Gate it so it only fires when the index is not already present.

Two things that apply to either. Subagents get AGENTS.md and nothing else by
design; injecting the controller index into them makes workers reopen design
and approval cycles their parent already settled, so detect a child session and
skip it. And the per-file injection cap is 20,000 characters against a 60,000
total, so an index that grows past a page starts competing with the user's own
instruction files — a pointer line does not.

## Rules for any port

- **Never edit the user's global config to bridge a gap.** The installer writes
  into the project (or the per-user skills directory, when asked), appends one
  marked line to an instruction file that already exists, and nothing else.
- **Never edit skill bodies to fit a harness.** If a skill names something your
  harness cannot do, that belongs in the adapter or in the action vocabulary —
  not in a forked copy of the skill.
- **No egress.** Whatever you add stays local: no fetches, no beacons, no
  update checks, no manifests pointing at a registry.
- **No runtime dependencies.** Shell and the harness itself.
