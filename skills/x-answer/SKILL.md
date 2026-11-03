---
name: x-answer
description: Use when code review feedback arrives - from a reviewer subagent, a colleague, or a PR comment - before implementing any of it, and especially when a suggestion seems unclear or technically wrong. Verify each item against the codebase, ask about anything unclear before starting, push back with reasoning where the reviewer is wrong, and implement one item at a time without performative agreement.
user-invocable: false
---

# x-answer

Answering a review is a technical act, not a social one.

**Start by announcing:** `Using x-answer to work through the review feedback.`

**The core of it:** verify before implementing, ask before assuming, technical
correctness over social comfort.

## The pattern

1. **Read** the whole thing without reacting.
2. **Understand** — restate each item in your own words, or ask.
3. **Verify** it against what the code actually does.
4. **Evaluate** — is it right *for this codebase*?
5. **Respond** — a technical acknowledgement, or reasoned pushback.
6. **Implement** one item at a time, testing each.

## Don't perform

Skip "you're absolutely right", "great catch", "excellent point", "thanks for
flagging that". Skip gratitude entirely. And skip "let me implement that now"
before you have verified it.

Instead: restate the requirement, ask the question, push back with the reason,
or simply start working. The fixed code is the acknowledgement.

When the feedback was right: "Fixed — `submit()` now trims before the empty
check, `auth.py:42`." That is the whole reply.

## Anything unclear stops everything

If you do not understand item 4, do not implement items 1, 2, 3 and 6 first.
Items are often related, and a partial understanding produces the wrong
implementation of the parts you thought you understood.

> "I understand 1, 2, 3 and 6. I need clarification on 4 and 5 before starting."

## Where it came from matters

**From the user.** Trusted — implement once you understand it. Still ask if the
scope is unclear. Still no performative agreement.

**From a reviewer, human or agent.** Before implementing, check:

- Is it technically correct *for this codebase*?
- Would it break something that currently works?
- Is there a reason the current implementation is the way it is?
- Does it hold on every platform and version this supports?
- Does the reviewer have the full context?

If it looks wrong, push back with the reasoning. If you cannot verify it, say
so: "I can't confirm this without X — should I investigate, or proceed?" If it
contradicts a decision the user already made, stop and raise that first.

## The "do it properly" check

When a reviewer asks you to implement something "properly" — full metrics, date
filters, CSV export — search the codebase for whether anything actually uses it.

Unused: "Nothing calls this endpoint. Remove it instead?" Used: implement it
properly.

You and the reviewer both answer to the user. Building a feature nobody needs
because a reviewer suggested it is not rigour.

## Order

1. Clarify everything unclear, first.
2. Then: blocking issues (breakage, security) → simple fixes (typos, imports) →
   complex fixes (logic, refactoring).
3. Test each fix on its own.
4. Check for regressions. Run the command that proves the fix, in this message,
   and read its output before reporting anything done.

## When to push back

- It breaks existing behaviour.
- The reviewer is missing context.
- It builds something unused.
- It is wrong for this stack, platform, or version.
- There is a compatibility reason for the current code.
- It contradicts an architectural decision the user made.

**How:** technical reasoning, not defensiveness. Specific questions. Point at
the test or the code that proves your case. Escalate to the user if it is
architectural.

If you find yourself reluctant to push back out loud: say that you are, then say
what you saw anyway. The user would rather have it.

## When your pushback was wrong

"You were right — I checked `config.py:88` and it does reset on reload.
Implementing now."

No long apology, no defending why you pushed back, no over-explaining. State the
correction and continue.

## Mistakes

| Mistake | Instead |
|---|---|
| performative agreement | restate the requirement, or just act |
| implementing blind | verify against the codebase first |
| batching without testing | one at a time, test each |
| assuming the reviewer is right | check whether it breaks something |
| avoiding the pushback | technical correctness over comfort |
| partial implementation | clarify everything first |
| cannot verify, proceeding anyway | state the limit, ask for direction |
