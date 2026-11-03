---
name: x-conclave
description: Use when a request is open-ended - a feature, a component, a tool, a rewrite - and the design is not settled yet, before anything gets built and before someone starts guessing. Also use when the user asks to be grilled, asks to be asked, or wants the questions put to them one at a time. Builds a decision tree, looks the facts up, drafts every question with real options and a recommendation, then either answers them with a high-reasoning decider and escalates only genuinely user-owned calls as one batch, or puts every question to the user directly. Writes a design doc with a decision log.
user-invocable: false
---

# x-conclave

A closed council. The questions get deliberated privately and the session comes
back out with decisions, a design doc, and a log of who decided what.

**Start by announcing:** `Using x-conclave to settle the design for <topic>.`

Two modes share one engine. **Auto** is the default: a decider answers, and the
user hears about only the handful of calls that are genuinely theirs.
**Interactive** puts every question to the user, one at a time. Pick the mode
first, say which one you are in, then run the grill loop.

## The grill loop (shared core)

### 1. Look before you ask

Read what the request points at and the code around it, until you can say how
the relevant parts work today and what this change would touch.

**Facts are looked up, never asked** — not of the user, not of the decider. "What
test runner does this use?" is a file read, not a question.

If everything that matters is already in the request ("rename this field"), this
skill is over. Do the work.

### 2. Build the decision tree

List the decisions this work actually requires, in dependency order: what gets
built and for whom, the shape of the thing, how it gets made (language,
platform, libraries, storage), what is explicitly out of scope, and what counts
as done.

Drop branches the existing project already settles. Each surviving node becomes
one question.

### 3. Resolve one branch at a time

A question whose options depend on an earlier answer waits for that answer. You
are walking the tree, not emptying a list. This is what keeps the later
questions real instead of hypothetical.

### 4. Draft each question

Every question carries:

- the question, in plain language, specific to this project
- two or more real options — drop the ones the project rules out
- what each option trades off, grounded in what the code actually does
- **your recommendation**, and one line of why
- the facts you looked up that bear on it

A question with one real option is not a question. Record it as a finding and
move on.

## Mode: auto (default)

The decider answers. The user is interrupted only where the call is theirs.

**Dispatch the decider** with `prompts/decider.md` filled in — a high-reasoning
subagent, model and effort set explicitly (see `adapters/<harness>.md`). Hand it
the batch as a file path where your harness allows it, so the questions do not
also sit in your context.

It returns, per question: **answer**, **rationale**, **confidence**, and an
**escalate** flag.

Send the questions in dependency-order batches — two or three batches is normal;
a batch per question is not.

**If you cannot dispatch a decider,** run the decider pass inline: a separate,
explicitly labelled pass over the drafted questions, producing the same four
fields. Say so in the design doc.

### Escalation — the six, and nothing else

The decider sets `escalate: true` only on these:

1. Irreversible or outward-facing work: deleting data, publishing, pushing to a
   shared branch, sending anything to an external service.
2. It costs money: a paid service, or large compute or token spend.
3. It touches security, privacy, or secrets, or adds a network egress path.
4. Intent is ambiguous in a way that changes what gets built — scope, target
   user, or what counts as success — and the repo, docs and conversation cannot
   settle it.
5. It conflicts with an explicit user instruction, or with AGENTS.md / CLAUDE.md.
6. The decider's confidence is low after one round of looking.

Then:

- **Zero escalations: do not stop.** Write the design doc and hand off.
- **One or more:** send them as a single message once the tree is resolved. Each
  is a yes/no or a pick-one, **recommendation first**. Not one message per
  question.
- **Nobody can answer** (headless, CI, no reply): proceed on the recommendation
  and tag that row `ASSUMED`. `x-land` surfaces ASSUMED rows again before
  anything outward-facing happens.

## Mode: interactive

The user answers every question. Triggered when they ask for it — "ask me",
"grill me", "interactive", "I want to decide this" — or when they say so
mid-session, at which point you switch and keep the answers already settled.

It is the auto mode with every question escalated, so the loop above is
unchanged. What differs:

- **One question per message.** Wait for the answer before sending the next.
  A batch of six questions gets a batch of six half-answers.
- **Still give the recommendation**, with its one line of why. Making them guess
  what you think wastes the round trip.
- **Still look the facts up.** An interactive mode is not permission to ask them
  what their own repo contains.
- **An answer that opens a new branch** gets its questions drafted and asked in
  turn. The tree is still the structure.
- No decider runs. Every row is `Decided by: user`.

## Output

Both modes produce the same two things.

### The design doc

Save to `docs/x-impl/designs/YYYY-MM-DD-<slug>.md`. A user preference for
another location overrides this.

Cover: intent and why; goals, non-goals, anti-goals; constraints; the approaches
considered and which one won; the decisions that are now settled; and what is
deliberately left to the implementer.

### The decision log

Ends the doc. Every question, no exceptions:

| # | Question | Decision | Rationale | Decided by | Confidence |
|---|----------|----------|-----------|------------|------------|
| 1 | … | … | … | decider / user / assumed | high / medium / low |

In auto mode most rows read `decider`, a few read `user`, and a headless run
leaves some `assumed`. In interactive mode every row reads `user`. The column is
not decoration — it is how the user knows which decisions they own.

### Overrides

The user reviews the log whenever they like. An override reopens **only that
row's branch**: re-run the questions that depended on it, leave the rest alone,
update the log in place. Do not restart the tree.

## Hand off

When the design is settled, load skill `x-plan`.

## Rationalisations

| Thought | Reality |
|---|---|
| "I'll just ask the user, it's faster" | In auto mode they are not at the keyboard. Draft the question and send it to the decider. |
| "This feels important enough to escalate" | The six criteria are the list. Feeling important is not on it. |
| "Zero escalations, so I should check in anyway" | A check-in with nothing to decide is an interruption. Write the doc. |
| "I'll ask the decider what the repo uses" | That is a fact. Go look. |
| "They want interactive, so I'll send all eight questions at once" | Eight at once gets eight half-answers. One at a time. |
| "Interactive means I can stop recommending" | The recommendation is most of the value. Give it, then let them disagree. |
| "The decision log is bookkeeping" | It is the only way an override can reopen one branch instead of the whole design. |
| "They said the design sounds good, so I can build" | Approval covers what they saw. Build after the plan, not after a vibe. |
