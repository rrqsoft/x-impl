---
name: x-impl
description: Use at the start of any engineering task, and again at each point the work turns - an open-ended feature, component, tool or rewrite whose design is not settled; turning a design or spec into an implementation plan; implementing a plan, or several independent problems at once; writing or changing behaviour test-first; a bug, test failure, build failure, performance regression or anything surprising that needs a root cause; review feedback arriving from a reviewer, a colleague or a pull request thread; and whenever you are about to say something is done, fixed, passing or working, or about to commit, push, open a pull request or hand off. Also use when the user asks to be grilled, asked, or questioned one at a time about an engineering decision. This is the single entry point - it routes to the stage the work is actually at, and states the verification rule and the announce rule.
---

# x-impl

One skill, several stages. This file is the entry point: it says which stage the
work is at and sends you to that stage's file. Treat it as a thread you can
follow, not a cage.

You are the only thing the user talks to. They do not pick stages; you do.

**Announce rule.** When you start a stage, say so in one line:
`Using x-impl: <stage> — <purpose>.` Then follow the stage file.

**Verification rule.** Never say something is done, fixed, passing, working or
complete unless you ran the command that proves it in this turn and read its
output. An earlier run proves the tree it ran on, not this one. A subagent's
report is a claim, not evidence. "Should pass" and "looks right" are not claims
you are allowed to make. `stages/land.md` is the full discipline.

**User instructions win.** AGENTS.md, CLAUDE.md, and anything the user asks for
directly override this skill. This skill in turn overrides your default habits.

## The pipeline

```
conclave → plan → build → land
```

`tdd` and `debug` are what `build` uses inside each task. `answer` handles
whatever a review sends back, wherever the review came from.

Join the pipeline wherever the work actually starts. A settled design skips
`conclave`; a one-line fix with an obvious cause skips most of it and still goes
through `land` before anyone calls it done.

## Routing

| The situation in front of you | Read |
|---|---|
| The request is open-ended and the design is not settled | `stages/conclave.md` |
| The user asks to be grilled, asked, or questioned one at a time | `stages/conclave.md`, interactive mode |
| A design or spec exists and needs turning into small verifiable tasks | `stages/plan.md` |
| A plan exists and the work is about to be done | `stages/build.md` |
| Several genuinely independent problems need working at once | `stages/build.md`, parallel mode |
| You are writing or changing behaviour right now | `stages/tdd.md` |
| A bug, failure, or surprise needs a cause before any fix | `stages/debug.md` |
| Review feedback has arrived and needs handling | `stages/answer.md` |
| The work looks complete, or you are about to claim it is | `stages/land.md` |
| You want a review without landing anything | `stages/land.md`, step 3 only |

**Read only the stage you need.** Each stage names the next one at its hand-off;
follow that rather than loading the set. Paths are relative to this skill's own
directory — `stages/plan.md`, `prompts/review.md`, `references/isolate.md`.

**Entering mid-pipeline is normal.** Start at the stage the work is at and say
which one in the announce line. A later stage does not assume the earlier ones
ran; it asks for what it needs.

## Mode hints the user can give

- "ask me everything", "grill me", "I want to decide this" → `stages/conclave.md`
  in interactive mode.
- "just review it", "don't land it" → `stages/land.md`, step 3 alone, then stop.
- "no subagents", "do it inline", "the cheap path" → inline mode in
  `stages/build.md`: a self-review instead of an independent one, said plainly.

## Tool names

These stage files name actions ("dispatch a subagent", "run a shell command"),
never tools. `adapters/actions.md` defines the vocabulary; `adapters/<harness>.md`
maps each action to the tool you actually have — `adapters/claude.md`,
`adapters/codex.md`, `adapters/opencode.md`, `adapters/openclaw.md`. Read yours
once, at the first action that needs mapping.
