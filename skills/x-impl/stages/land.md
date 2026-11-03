# x-impl: land

**When:** implementation looks complete, or you are about to say something is
done, fixed, passing or working, or about to commit, push, open a pull request
or hand off. Also for a review on its own.

Prove it, show what the user has not seen, get it reviewed, then let them decide
how it lands.

**Start by announcing:** `Using x-impl: land — verifying and landing <branch>.`

**Review only?** Run step 3 on its own and stop there. Say
`Using x-impl: land — reviewing <range>, not landing it.` Nothing in steps 4 to 6 runs
until the user asks for it.

## Step 1 — verify, fresh

**The rule:** no completion claim without fresh verification evidence. If you
have not run the command in this message, you cannot say it passes. This covers
exact phrases, paraphrases, synonyms, and anything that merely implies success.

Before stating any status, or expressing any satisfaction:

1. **Identify** — what command proves this claim?
2. **Run it** — the full command, fresh, start to finish. Not a subset.
3. **Read it** — the whole output, the exit code, the failure count.
4. **Check** — does the output actually confirm the claim? No → state the real
   status, with the evidence. Yes → state the claim, with the evidence.
5. **Then**, and only then, say it.

Skipping a step is not verifying. It is asserting.

| Claim | Requires | Not enough |
|---|---|---|
| tests pass | this run's output, 0 failures | an earlier run, "should pass" |
| linter clean | linter output, 0 errors | a partial check |
| build succeeds | build exit 0 | the linter passing |
| bug fixed | the original symptom retested and gone | the code changed |
| regression test works | watched it fail, then pass | it passes once |
| the agent finished | the diff shows the changes | the agent said "done" |
| requirements met | line-by-line against the spec | tests passing |

Note the last two. A subagent's report is a claim about work, not evidence of
it — read the diff. And a green suite says the tests pass, not that the thing
you were asked for exists.

**Red flags — stop:** "should", "probably", "seems to", "looks right"; saying
"done", "great", "perfect" before running anything; about to commit, push or
open a PR without a fresh run; taking a success report at face value;
extrapolating from a partial check; "just this once"; being tired and wanting it
to be over; **any wording that implies success when you have not run the
command**.

**Failing suite?** Report the failures and stop. There is no menu until it is
green.

## Step 2 — surface what the user has not seen

Before the review, in one short block:

- any decision tagged `ASSUMED` by the conclave stage — the user never confirmed
  these, and they are about to become permanent
- the rulings made during the build, if the build stage did not already report
  them
- deferred minor findings

They are deciding how to land the work; they should see what is in it.

## Step 3 — whole-branch review

An independent read of the complete change, before it merges anywhere.

```sh
BASE_SHA=$(git merge-base origin/main HEAD)   # or the commit the work started from
HEAD_SHA=$(git rev-parse HEAD)
{ git log --oneline "$BASE_SHA..$HEAD_SHA"
  git diff --stat "$BASE_SHA..$HEAD_SHA"
  git diff -U10 "$BASE_SHA..$HEAD_SHA"
} > .x-impl/run/review-$(date +%s).diff
```

Use the commit the work actually started from. `HEAD~1` silently drops every
commit but the last.

Dispatch a fresh reviewer with `prompts/review.md` filled in at
**whole-branch scope**, on the strongest model available — this is a judgement
task. Hand it the diff path, not the diff: a diff you read inline is a context
window you no longer have for the work.

**No subagent dispatch?** Do the review yourself as a deliberate separate pass
against the diff file, and say plainly in your report that it was a self-review
by the author. That is weaker than a fresh reader, and the user decides whether
it is enough.

Then act on the findings, re-grading severities first — the reviewer's labels
are advice, the gate is yours, and the grade is what a real user gets if this
ships:

- **Critical** — fix now, before anything else. Never land with one unfixed.
- **Important** — fix before the menu.
- **Minor** — note it; the user decides whether it is worth the churn.
- **Wrong** — push back with technical reasoning. Read `stages/answer.md`.

Any fix here sends you back to step 1. A tree that changed since the last green
run is an unverified tree.

If the user asked for a review and not a landing, stop here and report.

## Step 4 — detect the environment

```sh
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)   # capture now; you change directory later
BRANCH=$(git branch --show-current)
```

| State | Menu | Cleanup |
|---|---|---|
| `GIT_DIR == GIT_COMMON` | the three options | nothing to clean up |
| linked worktree, named branch | the three options | yours if under `.worktrees/` |
| linked worktree, detached HEAD | the two options (no local merge) | externally managed — leave it |

**The base branch.** Whatever this work forked from: usually named in the plan,
the conversation, or the branch's upstream. If it is not already known, ask —
"this split from `main`, correct?" Merging into the wrong base is expensive to
undo.

## Step 5 — present the options

**Normal checkout, or a worktree on a named branch:**

```
Implementation complete, suite green, review clean. What would you like to do?

1. Merge back to <base> locally
2. Push and open a pull request
3. Keep the branch as-is

Which?
```

**Detached HEAD:**

```
Implementation complete, suite green, review clean. You're on a detached HEAD
(externally managed workspace).

1. Push as a new branch and open a pull request
2. Keep as-is

Which?
```

Present it exactly as written and wait. The integration decision is the user's.
Discarding the work is not on the menu — it happens only when they ask for it in
so many words.

## Step 6 — do it

### Merge locally

```sh
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git checkout <base> && git pull && git merge <branch>
<test command>
```

Merge first, verify the merged result, *then* remove anything. If the merged
result fails, stop and investigate — nothing has been pushed, the merge is local
and recoverable, and the worktree and branch stay put. Do not assume it is
flaky.

Green: clean up the worktree (step 7), then `git branch -d <branch>`.

### Push and open a PR

**Pushing and opening a PR are outward-facing. Confirm before you do either,
even if the user picked this option a moment ago** — confirm what you are about
to push, to which remote and branch, and that a PR will be visible to whoever
can see that repo.

```sh
git push -u origin <branch>
# from a detached HEAD:
# git push origin HEAD:refs/heads/<new-branch>
```

Then open the pull request against the base with the forge's own tooling, or the
creation URL the push prints. Follow the repo's PR template if it has one.
Report the result back.

Keep the worktree — PR feedback gets fixed there, under `stages/answer.md`.

**A rejected push means the remote moved.** Investigate. Never force-push on
your own initiative.

### Keep as-is

`Keeping branch <name>. Worktree preserved at <path>.`

### If the user asks to discard

Only on an explicit request. Confirm first:

```
This permanently deletes:
- branch <name>
- commits: <list>
- worktree at <path>

Type 'discard' to confirm.
```

Wait for that exact word. "Yeah, bin it" is not it. Then `cd` to the main repo
root, clean up the worktree, and `git branch -D <branch>`.

## Step 7 — cleanup

Runs for a local merge and for a confirmed discard. Options 2 and 3 always keep
the worktree. Run it from outside the worktree, using the values captured in
step 4.

- **`GIT_DIR == GIT_COMMON`** — nothing to clean up.
- **`WORKTREE_PATH` under `.worktrees/` or `worktrees/`** — we created it:

  ```sh
  git worktree remove "$WORKTREE_PATH"
  git worktree prune
  ```

- **Anything else** — the harness or the user owns it. Leave it. If your harness
  has a workspace-exit tool, use that.

**Removal refused** (`contains modified or untracked files`) means files exist
there and nowhere else. Never `--force` on your own initiative. Show them:

```sh
git -C "$WORKTREE_PATH" status --porcelain -uall
```

and ask whether to commit them, move them to the main repo, or delete them.
Then remove the worktree.

## Rationalisations

| Thought | Reality |
|---|---|
| "It should work now" | Run it. |
| "I'm confident" | Confidence is not evidence. |
| "The tests passed earlier" | Run them on the tree you are integrating. |
| "The linter passed" | The linter does not compile anything. |
| "The subagent said it succeeded" | Verify it yourself. Read the diff. |
| "A partial check is enough" | Partial proves nothing about the rest. |
| "I used different words, so the rule doesn't apply" | Spirit over letter. |
| "It's a small change, skip the review" | Small changes are where unreviewed regressions live. |
| "I'll read the diff myself, it's quicker" | You are coordinating. The diff belongs in a reviewer's context; only the findings belong in yours. |
| "The reviewer said Minor, so it's Minor" | That graded the spec's silence, not the effect. Re-grade by what a user gets. |
| "They obviously want it merged" | Integration is their decision. Present the menu and wait. |
| "They seem done with this — I'll offer to discard it" | The menu is complete as written. Discard is theirs to ask for. |
| "'Get rid of it' counts as confirmation" | Only the typed word authorises deletion. |
| "They already chose 'push and PR', so just push" | Pushing publishes. Confirm the remote and branch before it happens. |
| "The PR is up, the worktree is clutter now" | PR feedback gets fixed there. It stays until the work lands. |
| "This other worktree looks stale, I'll tidy it too" | Clean up only what we created. |
| "Removal was refused, `--force` finishes the job" | The refusal means those files exist nowhere else. Ask. |
| "The merged-result failure is probably flaky" | It stops everything. Branch and worktree stay while you investigate. |
| "The push was rejected, force-push will fix it" | The remote moved. Investigate; force-push only when they ask. |
