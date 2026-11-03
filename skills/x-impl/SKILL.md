---
name: x-impl
description: Use at the start of any engineering task to see which x-impl workflow skills apply - building a feature, planning work, fixing a bug, reviewing a change, or landing a branch. Indexes x-conclave, x-plan, x-build, x-tdd, x-debug, x-answer and x-land, states the verification rule and the announce rule, and points at the tool adapter.
---

# x-impl

A small set of engineering workflow skills. This file is the index: what exists,
and when to reach for it. Treat it as a thread you can follow, not a cage.

**Announce rule.** When you start one of these skills, say so in one line:
`Using <skill-name> to <purpose>.` Then follow the skill.

**Verification rule.** Never say something is done, fixed, passing, working or
complete unless you ran the command that proves it in this turn and read its
output. An earlier run proves the tree it ran on, not this one. A subagent's
report is a claim, not evidence. "Should pass" and "looks right" are not
claims you are allowed to make. `x-land` is the full discipline.

**Pipeline order:** x-conclave → x-plan → x-build → x-land.
Join it wherever the work actually starts. Skip the steps that do not apply.

| Skill | Reach for it when |
|---|---|
| `x-conclave` | A request is open-ended and the design needs settling — autonomously, or by grilling the user when they ask for that. |
| `x-plan` | A design exists and needs turning into small, verifiable tasks. |
| `x-build` | A plan exists and you are about to implement it, or several independent problems need working at once. |
| `x-tdd` | Writing or changing behaviour: test first, watch it fail, then implement. |
| `x-debug` | A bug, failure, or surprise needs a root cause before any fix. |
| `x-answer` | Review feedback has arrived and needs technical handling. |
| `x-land` | The work is done and needs verifying, reviewing, and landing somewhere. |

`x-build` gets the work isolated and runs the task loop; `x-tdd` and `x-debug`
are what it uses inside each task. `x-answer` handles whatever a review sends
back, wherever the review came from.

**Want a review mid-stream?** Run `x-land`'s review step on its own and stop
there — say you are reviewing, not landing.

**User instructions win.** AGENTS.md, CLAUDE.md, and anything the user asks for
directly override these skills. These skills in turn override your default habits.

**No skill tool?** If your harness cannot load skills by name, read
`skills/<name>/SKILL.md` directly — that is the whole skill.

**Tool names.** These skills name actions ("dispatch a subagent", "run a shell
command"), never tools. `adapters/actions.md` defines the vocabulary;
`adapters/<harness>.md` maps each action to the tool you actually have —
`claude.md`, `codex.md`, `opencode.md`, `openclaw.md`.
