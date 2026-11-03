# x-impl: debug

**When:** any bug, test failure, build failure, performance regression, or
unexpected behaviour, before proposing or trying a fix.

Find the cause before touching anything. A fix for a symptom is not a fix.

**Start by announcing:** `Using x-impl: debug — finding the root cause of <symptom>.`

**The rule:** no fix before the investigation. If you have not finished phase 1,
you do not get to propose a fix.

Use this especially when it is tempting not to: under time pressure, when the
fix looks obvious, when you have already tried two things, when you do not
really understand what is happening.

## Phase 1 — Find the cause

**Read the error properly.** All of it: the full stack trace, the line numbers,
the error codes. They often contain the answer outright.

**Reproduce it.** Can you trigger it reliably? What exactly are the steps? Does
it happen every time? If you cannot reproduce it, gather more data — do not
start guessing.

**Check what changed.** `git diff`, recent commits, new dependencies, config
changes, a different environment.

**Instrument the boundaries.** In a system with several components — CI → build
→ sign, request → service → database — add logging at each boundary before
proposing anything: what goes in, what comes out, whether the config and
environment actually propagate. Run it once. The evidence tells you which layer
is failing. Then investigate *that* layer.

**Trace the bad value backwards.** Where did it originate? What called that with
it? Keep walking up until you find the source. Fix it there, not where it
surfaced.

## Phase 2 — Compare against something that works

Find similar code in the same codebase that works. If you are implementing a
known pattern, read the reference implementation completely — skimming
guarantees you will miss the line that matters.

List every difference between working and broken, however small. Do not decide
in advance that one cannot matter. Check what the working version depends on
that the broken one does not: config, environment, ordering, assumptions.

## Phase 3 — One hypothesis at a time

State it plainly: *I think X is the cause, because Y.*

Test it with the **smallest possible change**. One variable. Do not fix three
things and run the suite.

Did it work? Go to phase 4. Did it not? Form a **new** hypothesis — do not pile
another fix on top of the last one.

If you do not understand something, say "I don't understand X" rather than
proceeding as if you do.

## Phase 4 — Fix it

1. **Write the failing test first.** The simplest reproduction you can manage;
   a one-off script if there is no framework. Read `stages/tdd.md`. You need this
   before the fix, not after.
2. **One fix, at the root cause.** No bundled refactoring, no "while I'm here".
3. **Verify.** The new test passes, nothing else broke, the original symptom is
   actually gone. Run the command that proves each of those in this message and
   read its output before claiming anything — `stages/land.md` carries the full
   discipline.

**If the fix did not work:** stop and count. Under three attempts → back to
phase 1 with what you just learned. **Three or more → stop and question the
design.**

## After three failed fixes

This is not a failed hypothesis. It is the wrong architecture, and the signs are
recognisable: every fix uncovers new coupling somewhere else, every fix needs
"just a bit of refactoring" to land, every fix creates a new symptom elsewhere.

Stop fixing. Ask whether the pattern is sound at all, or whether it is being
kept out of inertia, and whether refactoring beats another round of symptom
patching. Raise it with the user before attempting fix number four.

## Red flags — stop and go back to phase 1

- "quick fix now, investigate later"
- "let me just try changing X"
- "I'll make several changes and run the tests"
- "skip the test, I'll check by hand"
- "it's probably X"
- "I don't fully understand this but it might work"
- listing fixes before tracing the data flow
- "one more attempt" when you have already made two

## Rationalisations

| Excuse | Reality |
|---|---|
| "It's simple, I don't need the process" | Simple bugs have causes too, and the process is fast for them. |
| "Emergency, no time" | Systematic is faster than guess-and-check. Thrashing is what costs the day. |
| "I'll investigate after confirming the fix works" | The first fix sets the pattern. Do it right. |
| "I'll write the test once the fix works" | Untested fixes do not stay fixed. |
| "Several fixes at once saves time" | You cannot tell which one worked, and you have added new bugs. |
| "The reference doc is long, I'll adapt the gist" | Partial understanding guarantees bugs. Read it. |
| "I can see the problem" | Seeing the symptom is not understanding the cause. |

## When there really is no root cause

Sometimes the investigation genuinely lands on "environmental", "timing", or
"external". Then: document what you investigated, implement the right handling
(a retry, a timeout, a clear error message), and add logging for next time.

Most of the time, though, "no root cause" means the investigation stopped early.
