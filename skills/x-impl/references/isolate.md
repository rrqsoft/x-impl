# Isolating the workspace

The long form of the build stage's Isolate step. Detect first, use the native tool
second, fall back to git third. Never fight the harness.

## Step 0 — are you already isolated?

Check before creating anything:

```sh
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

`GIT_DIR != GIT_COMMON` is also true inside a submodule, so rule that out:

```sh
git rev-parse --show-superproject-working-tree 2>/dev/null
```

A path means you are in a submodule — treat it as a normal repo.

**Already in a linked worktree:** skip to step 2. Do not create another. Report
which: on a branch, `Already isolated at <path> on <branch>`; on a detached
HEAD, `Already isolated at <path> (detached HEAD, externally managed) — a branch
will be needed at landing time`.

**Normal checkout:** has the user already said what they want here — in
AGENTS.md, CLAUDE.md, or the request? Honour it without asking. Otherwise ask
once:

> Want me to set up an isolated worktree? It keeps your current branch
> untouched.

If they decline, work in place and skip to step 2.

## Step 1 — create it

### 1a. Native tool first

Does your harness have its own worktree feature — a tool, a slash command, a
flag? Check `adapters/<harness>.md`. If it does, use it and skip to step 2.

The native tool owns placement, branch creation and cleanup. Reaching for `git
worktree add` past it creates state the harness cannot see or clean up. That is
the single most common mistake here.

### 1b. Git fallback

Only when there is no native tool.

**Pick the directory,** in this order:

1. A location the user has already specified. It beats everything below.
2. An existing `.worktrees/` or `worktrees/` at the project root. If both exist,
   `.worktrees/` wins.
3. Otherwise `.worktrees/`.

**Confirm it is ignored** — this matters:

```sh
git check-ignore -q .worktrees || echo "NOT IGNORED"
```

If it is not ignored, add it to `.gitignore` and commit that before creating
anything. An unignored worktree directory commits the entire tree into the repo.

**Create:**

```sh
git worktree add ".worktrees/$BRANCH_NAME" -b "$BRANCH_NAME"
cd ".worktrees/$BRANCH_NAME"
```

**If it fails with a permission error** — a sandbox refused it — tell the user
the sandbox blocked worktree creation and that you are working in the current
directory instead. Then run setup and the baseline here.

## Step 2 — project setup

Detect and run what this project needs:

```sh
[ -f package.json ]      && npm install
[ -f Cargo.toml ]        && cargo build
[ -f requirements.txt ]  && pip install -r requirements.txt
[ -f pyproject.toml ]    && (poetry install || pip install -e .)
[ -f go.mod ]            && go mod download
```

Nothing to detect? Skip it.

## Step 3 — baseline

Run the project's test suite before writing anything.

**Passing:** report ready. **Failing:** report the failures and ask whether to
proceed or investigate. A dirty baseline makes every later failure ambiguous —
you will not know whether you broke it or found it broken.

```
Workspace ready at <path> on <branch>
Baseline: <N> tests, 0 failures
Ready to implement <feature>
```

## Quick reference

| Situation | Do |
|---|---|
| already in a linked worktree | skip creation |
| in a submodule | treat as a normal repo |
| native worktree tool exists | use it |
| no native tool | `git worktree add` |
| `.worktrees/` exists | use it, verify ignored |
| both directories exist | `.worktrees/` wins |
| neither exists | check instructions, then default to `.worktrees/` |
| directory not ignored | gitignore it and commit first |
| permission error on create | work in place, say so |
| baseline fails | report and ask |

## Rationalisations

| Thought | Reality |
|---|---|
| "Obviously I'm not in a worktree" | Harness-managed isolation and submodules both fool eyeballing. Run step 0. |
| "`git worktree add` is quicker than hunting for the native tool" | The native tool owns cleanup. Bypassing it leaves state nobody can manage. |
| "The directory is surely ignored" | Run `git check-ignore`. Getting this wrong commits the whole tree. |
| "The workspace is fresh, the baseline can wait" | Then every later failure is ambiguous. |
