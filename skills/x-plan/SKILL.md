---
name: x-plan
description: Use when a design or spec exists and needs turning into an implementation plan, before any code is written. Produces small verifiable tasks of a few minutes each, with exact files, test-first steps, the exact command to run and the output that means it passed, saved under docs/x-impl/plans/ and handed to x-build.
user-invocable: false
---

# x-plan

Turn a settled design into tasks an implementer who has never seen this codebase
could execute correctly.

**Start by announcing:** `Using x-plan to turn the design into an implementation plan.`

**Input:** a design doc (from `x-conclave`), a spec, or a detailed request.
If the design is not settled, load skill `x-conclave` first.

## What a plan is for

Assume the implementer writes good idiomatic code in this language once they
know the exact interface and the exact test. What they cannot know is what *you*
decided: which files, which names and signatures, which values from the design,
which test proves each task.

A plan records the decisions they cannot make alone. Nothing else. A plan longer
than the code it describes has written the code instead; a line that decides
nothing ("handle edge cases", "add validation", "TBD") is the opposite failure.

## Step 1: Map the files

Before drawing task boundaries, list every file this work creates or modifies
and what each is responsible for. One clear responsibility per file. Files that
change together live together. In an existing codebase, follow the patterns
already there.

## Step 2: Size the tasks

A task is the smallest unit that carries its own test cycle and is worth a
reviewer's gate — roughly two to five minutes of work. Fold setup, config and
docs into the task whose deliverable needs them. Split only where a reviewer
could sensibly reject one task and approve its neighbour. Every task ends with
something independently testable.

## Step 3: Write it

Save to `docs/x-impl/plans/YYYY-MM-DD-<slug>.md`. A user preference overrides
this location.

### Header

```markdown
# <Feature> implementation plan

**Goal:** one sentence.
**Approach:** two or three sentences.
**Stack:** the libraries and tools that matter.
**Design:** path to the design doc this plan implements.

## Global constraints

Project-wide requirements copied verbatim from the design: version floors,
naming rules, exact values, platform limits. One line each. Every task's
requirements implicitly include this section.

## Review focus

The handful of inputs or failure modes the design implies but no task's tests
exercise, most likely to bite a real user first. One line each. Then add the
test for each to the task that owns that code. An empty section means you
checked and found none.
```

### Task shape

````markdown
### Task N: <name>

**Files**
- Create: `exact/path/file.py`
- Modify: `exact/path/existing.py:120-145`
- Test: `tests/exact/path/test_file.py`

**Interfaces**
- Consumes: exact signatures this task relies on from earlier tasks
- Produces: exact names and types later tasks will rely on

- [ ] **Step 1 — write the failing test**

```python
def test_rejects_empty_email():
    assert submit({"email": ""}).error == "Email required"
```

- [ ] **Step 2 — run it and watch it fail**
  Run: `pytest tests/path/test_file.py::test_rejects_empty_email -v`
  Expected: FAIL, "submit is not defined"

- [ ] **Step 3 — implement `submit(data: FormData) -> Result` in `exact/path/file.py`**
  One line on the approach only where the signature and the test leave a real
  choice. A code body only for an algorithm they do not determine.

- [ ] **Step 4 — run it and watch it pass**
  Run: `pytest tests/path/test_file.py::test_rejects_empty_email -v`
  Expected: PASS

- [ ] **Step 5 — commit**
  `git add … && git commit -m "feat: reject empty email"`
````

**A step is done when the implementer can write exactly one reasonable thing
from it.** A test step carries its name and assertions as code, with the
design's exact values. A code step carries the exact signature and file. A
verification step carries the command and the output that means it passed.

## Step 4: Self-review

Run this yourself; do not dispatch it.

1. **Coverage** — point at a task for every requirement in the design. List gaps.
2. **Steps** — every step lets the implementer write exactly one reasonable
   thing, and no more. A line that decides nothing is a gap; a function body the
   signature and test already determine is a transcript. Fix both.
3. **Consistency** — the names, signatures and types used in later tasks match
   what earlier tasks defined. `clearLayers()` in Task 3 and `clearAllLayers()`
   in Task 7 is a bug.
4. **Review focus** — every line there has a test attached to an owning task.
5. **Proportion** — compare the plan's length to the design's. If code blocks
   are most of the document, replace bodies with signatures and test assertions.

Fix what you find inline. No second pass.

## Step 5: Hand off

Save it, tell the user where it is, and load skill `x-build`.

If the user asked to review the plan before implementation, stop here and wait.
Otherwise proceed — they asked for the work, not for a checkpoint.

## Rationalisations

| Thought | Reality |
|---|---|
| "Spelling out the code is being thorough" | It is writing the code in the wrong file. Signatures and tests, not bodies. |
| "'Handle errors appropriately' covers it" | It decides nothing. Name the error and the behaviour. |
| "The implementer will see the whole plan" | They see their task. Interfaces blocks are how they learn the neighbours. |
| "This task is big but it's all one thing" | If a reviewer could reject half of it, it is two tasks. |
| "Self-review is a formality" | Type mismatches between tasks are the most common plan defect and the cheapest to catch here. |
