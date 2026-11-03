---
name: x-build
description: Use when an implementation plan exists and the work is about to be done, or when several genuinely independent problems need working at once. Sets up an isolated workspace first, then runs the work in one of three modes - a fresh implementer subagent per task followed by a spec and quality review and a bounded fix loop, inline in this session where subagents are unavailable, or one subagent per independent problem running concurrently. Keeps a ledger that survives compaction, records rulings instead of stalling, stops only on real blockers, and hands the finished branch to x-land.
user-invocable: false
---

# x-build

Implement the work, task by task, until it is done.

**Start by announcing:** `Using x-build to implement <plan path>.`

**Input:** a plan from `x-plan`. No plan and the work needs one? Load skill
`x-plan` first. Parallel mode is the exception — independent problems do not
need a plan document.

## Isolate

Work does not start on the user's current checkout by accident.

1. **Detect** whether you are already in a linked worktree. If you are, do not
   create another.
2. **Prefer the harness's own worktree feature** over `git worktree add` — see
   `adapters/<harness>.md`. The native tool owns placement, branch creation and
   cleanup.
3. **Fall back** to `git worktree add ".worktrees/$BRANCH" -b "$BRANCH"`, after
   confirming `.worktrees/` is gitignored. An unignored worktree directory
   commits the whole tree into the repo.
4. **Install dependencies and run the suite once** as a baseline. A dirty
   baseline makes every later failure ambiguous.

Never start implementing on `main` without the user saying so. Blocked by a
sandbox, or the user declines isolation? Work in place and say so.

The detection snippets, the directory precedence rules, the submodule case and
the detached-HEAD case are in `references/isolate.md`. Read it the first time,
or any time the detection is not obvious.

## Pick a mode

- **Per-task** — a plan exists and you can dispatch subagents. A fresh
  implementer per task, then a review of that task, then the next. Costs a fresh
  context per task and per review; buys an independent pass on every task.
- **Inline** — a plan exists but you cannot dispatch subagents, or the user
  asked for the cheap path. You implement every task yourself, with one review
  of the whole branch at the end.
- **Parallel** — not a plan at all, but two or more genuinely independent
  problems. One subagent per problem, all at once.

Say which mode you are in and why, in one line. Then stay in it.

## Ledger

Before the first task, in per-task and inline mode:

1. Create `.x-impl/run/<plan-slug>/progress.md`, first line
   `# x-impl ledger — plan: <plan path>`. Make sure `.x-impl/run/` is
   gitignored.
2. If a ledger for this plan already exists, every task with a
   `Task N: complete` line is done — resume at the first one without it, and
   trust the ledger and `git log` over your own memory.
3. **Read the plan once.** Note its Global constraints. Read the design it names.
4. **Track a todo list** — one item per task.
5. **Pre-flight.** For every task that consumes what an earlier task produces,
   check the Interfaces blocks against each other. One ledger line per pair,
   with what you found. A plan whose tasks share nothing gets the single line
   `Pre-flight: no shared interfaces`.

The ledger exists because conversation memory does not survive compaction. A
builder that loses its place re-implements tasks whose commits already exist.

## Keep going

Do not check in between tasks. The user asked for the plan to be executed.
Progress summaries and "shall I continue?" spend their time and buy nothing.

**Decide, don't stall.** Conflicts, ambiguities and plan defects are yours to
settle: the design is the authority, the plan is its argument, your judgement
covers the rest. Record each as
`Task N: Ruling: <what you decided> — <why> — <cost if wrong>` and keep going.
A deviation without a ledgered ruling is a decision made in secret.

**Four things stop you, and only these:**

1. an irreversible or destructive operation
2. a security-sensitive action
3. a side effect outside this workspace that norms say you ask about first — a
   merge, a push to a shared branch, a publish
4. a plan so broken that every path forward is a guess

## Mode: per-task

### 1. Dispatch the implementer

Record BASE (`git rev-parse HEAD`) before dispatching; the review range is cut
from it, never from `HEAD~1`.

Extract the task's full text from the plan into its own brief file. Dispatch a
fresh implementer with `prompts/implementer.md` filled in. The dispatch carries:

- one line on where this task fits
- the **brief path**, introduced as "read this first — it is your requirements,
  with the exact values to use verbatim"
- interfaces and decisions from earlier tasks the brief cannot know
- your resolution of any ambiguity you spotted in the brief
- the report file path

Exact values live in the brief, not in the dispatch. Never paste accumulated
prior-task history into a later dispatch — a fresh implementer needs its task,
the interfaces it touches, and the global constraints. Never make it read the
whole plan.

Set the implementer's model explicitly where your harness allows it: a
well-specified task is transcription plus testing and runs fine on a mid-tier
model; an omitted model silently inherits the session's most expensive one.

Never dispatch two implementers in parallel — they will collide.

### 2. Handle the report

- **DONE** → write the diff for `BASE..HEAD` to a file and go to step 3.
- **DONE_WITH_CONCERNS** → review anyway, and pass the concern to the reviewer
  as a named risk.
- **NEEDS_CONTEXT** → answer it and resume the same implementer. Do not
  re-dispatch a fresh one.
- **BLOCKED** → read what it tried. Either give it what it lacks and resume, or
  re-dispatch on a stronger model, or split the task. If every path is a guess,
  that is stop #4.

Verify the claim against `git log` and the diff. A report saying "done" is a
claim, not evidence.

### 3. Review the task

Dispatch a reviewer with `prompts/review.md` filled in, **per-task scope**: the
brief path, the report path, the diff file path, and the plan's Global
constraints copied verbatim. Hand the diff as a file — it never enters your own
context.

Never skip the task review, and never accept a report missing either verdict:
spec compliance **and** quality are both required. The implementer's self-review
does not replace it.

Do not pre-judge findings for the reviewer. If a prompt you are writing contains
"don't flag", "at most minor", or "the plan chose this" — stop. You are sparing
yourself a review loop.

### 4. Fix loop

Triggered by: spec ❌, any Critical or Important finding, or a "cannot verify"
item you confirmed is a real gap.

Resume the **same** implementer with the findings. It fixes, re-runs the tests
covering the amended code, appends a fix report, and replies. Then re-review,
scoped to the fix diff only.

**Cap: three rounds.** At the cap, stop fixing. Adjudicate each open finding
yourself, record it as a ruling in the ledger, and move on. Past three rounds
the failure is structural, not a matter of one more try. New findings on
untouched code go to the ledger, not into the loop.

### 5. Complete the task

Append to the ledger in the same message as your other bookkeeping:

- `Task N: complete (commits <base7>..<head7>, review clean)`, or
- `Task N: complete (commits <base7>..<head7>, K parked)` after the cap

Mark the todo complete. Next task.

## Mode: inline

Same ledger, same rulings, same stops.

1. Read the task's brief — every task, including ones you think you remember.
   What you remember is a summary; the brief has the exact values.
2. Work the steps in order under `x-tdd`. The failing run is a step, not a
   formality.
3. Every step with an `Expected:` line: run it, read the output, compare.
   - Matches → next step.
   - **Code is wrong** → load skill `x-debug`. Never patch the symptom so the
     output matches.
   - **Plan is wrong** → rule on the smallest change that satisfies the design,
     ledger it, continue.
4. Commit as the plan's commit steps say.
5. Before the completion line, all of this is true with evidence from this
   session: every test the brief names exists and ran; the final run passed and
   you read it; every `Expected:` was compared against real output; every
   deviation has a ruling. If anything is missing, the task is not complete.
6. Ledger `Task N: complete (commits <base7>..<head7>, tests: <command> → <result>)`,
   mark the todo complete, next task.

Redirect long test output to a file and read its tail — everything you print
stays in your context for the rest of the run.

## Mode: parallel

One subagent per independent problem, running at the same time. Three test files
failing for three different reasons; separate subsystems broken independently;
several unrelated questions to research.

Each problem must be understandable without the others, and the agents must not
need to touch the same files.

### When not to

- **The failures might be related.** Fixing one may fix the rest. Investigate
  together first — load skill `x-debug`.
- **You do not yet know what is broken.** Exploratory debugging is one agent's
  job.
- **Shared state.** Two agents editing the same file will clobber each other.
- **Implementing a plan.** That is per-task mode, and its implementers run one
  at a time for exactly this reason.
- **No subagent dispatch.** Work them sequentially and say so.

### The pattern

1. **Split by what is broken** — group by root cause, not by file count. Each
   group becomes one brief.
2. **Write self-contained briefs.** A subagent inherits nothing from your
   session. Each one gets: **scope**, named precisely ("the three failures in
   `tests/abort_test.py`", not "the flaky tests"); **evidence**, the actual error
   messages and test names pasted in; **goal**, what done looks like;
   **constraints**, what it must not touch ("do not change production code" is
   the common one — without it an agent will refactor its way out of the
   problem); and **output**, what to report back.
3. **Dispatch them together** — all the dispatches in a single message is what
   makes them run concurrently. Set each agent's model explicitly.
4. **Integrate.** Read each report; a report is a claim. Check for conflicts —
   did two agents edit the same file, did one's fix assume behaviour the other
   changed? Run the full suite on the combined result, not each agent's own test
   file. Spot-check the diffs: three agents can make the same systematic error
   three times.

| Weak brief | Strong brief |
|---|---|
| "Fix all the tests" | "Fix the 3 failures in `src/abort.test.ts`" |
| "There's a race condition" | the error output, the test names, the line numbers |
| no constraints | "do not change production code" |
| "fix it" | "report the root cause and what you changed" |

Then go to **Finish** below, as the other modes do.

## Whole-branch review

**Per-task and parallel mode:** when every task is complete, dispatch one
reviewer on the strongest model available, over `merge-base..HEAD`, using
`prompts/review.md` at **whole-branch scope**. Include the plan's Review focus
section verbatim and a pointer to the ledger's `Ruling:` lines.

Fix the range first — the commit the work actually started from, never `HEAD~1`,
which silently drops every commit but the last:

```sh
BASE_SHA=$(git merge-base origin/main HEAD)
HEAD_SHA=$(git rev-parse HEAD)
{ git log --oneline "$BASE_SHA..$HEAD_SHA"
  git diff --stat "$BASE_SHA..$HEAD_SHA"
  git diff -U10 "$BASE_SHA..$HEAD_SHA"
} > .x-impl/run/review-$(date +%s).diff
```

Hand the reviewer that path. A diff you read inline is a context window you no
longer have for the work.

**Inline mode:** the same review, and it is the one fresh context this run buys.
Do not skip it and do not substitute your own read of the diff. Without subagent
dispatch, do the review as a deliberate separate pass, ledger
`Final review: self-review (no subagent dispatch)`, and say so in your final
message — the user decides whether that is enough.

Sort the findings before acting. The reviewer's severities are advice; the gate
is yours, and the grade is what a real user gets if this ships. Critical and
Important enter **one** fix pass, each fix proved by a test that failed first
and a green suite afterwards. Minor goes to the ledger as
`Final: minor (deferred): <one-liner>`. A finding you decide not to fix is a
ruling, with its cost if wrong. A finding you think is simply wrong gets
technical pushback — load skill `x-answer`.

## Finish

1. Run the project's full suite fresh and read its output. Not an earlier run.
2. Collect every `Ruling:` line into your final message under "Rulings I made",
   in order, each with its cost if wrong, and every deferred minor under
   "Deferred minors". Both lists exhaustive. This is the only place those
   decisions reach the user.
3. Delete this plan's ledger directory — git history is the record now. Leave
   sibling directories alone.
4. Load skill `x-land`.

## Rationalisations

| Thought | Reality |
|---|---|
| "I remember what Task 4 says" | You remember a summary. Read the brief. |
| "I'll fix this myself instead of resuming the implementer" | Your fix skips review and burns the context you need to coordinate. Resume it. |
| "One more fix round will converge" | Past the cap it does not. Adjudicate and move. |
| "The fix was small, skip the re-review" | Unreviewed fixes are how regressions land. |
| "The ledger is bookkeeping" | It is what survives compaction. Without it you re-run finished tasks. |
| "Let me check in before the next task" | Only the four stops stop you. |
| "The plan is wrong here, I'll just do the right thing" | Do the right thing *and* ledger the ruling. |
| "I read my own diff carefully, the final review is redundant" | Same author, same blind spots. |
| "Three agents is three times faster" | Only if the problems are independent. Related failures mean three agents fixing one cause three different ways. |
| "Each parallel agent ran its own tests, so we're green" | Agent-local green says nothing about the combination. Run the whole suite. |
| "Obviously I'm not already in a worktree" | Harness-managed isolation and submodules both fool eyeballing. Run the detection. |
