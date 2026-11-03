# x-impl: tdd

**When:** implementing any feature, bug fix, or behaviour change, before writing
production code.

Write the test first. Watch it fail. Write the least code that makes it pass.

**Start by announcing:** `Using x-impl: tdd — implementing <what> test-first.`

**The core of it:** a test you never watched fail proves nothing. You do not
know whether it tests the right thing, or whether it tests anything at all.

## The rule

**No production code without a failing test first.**

Wrote the code first? Delete it and start over. Not "keep it as reference", not
"adapt it while writing the test" — that is testing after, with extra steps.
Delete means delete. Implement fresh from the test.

Exceptions worth asking the user about: throwaway spikes, generated code,
configuration. "Just this once" is not one of them.

## Red

Write **one** minimal test showing what should happen.

Good:

```typescript
test('retries a failing operation three times', async () => {
  let attempts = 0;
  const op = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'ok';
  };

  expect(await retry(op)).toBe('ok');
  expect(attempts).toBe(3);
});
```

The name says the behaviour, it exercises real code, and it tests one thing.

Bad: `test('retry works')` driving a mock and asserting the mock was called
three times. That tests the mock.

Requirements: one behaviour, a name that describes it, real code. Mocks only
where there is no alternative. An `and` in the test name means it is two tests.

## Verify red — watch it fail

Not optional. Run it:

```sh
npm test path/to/thing.test.ts
```

Confirm all three:

- it **fails**, rather than erroring out
- the failure message is the one you expected
- it fails because the feature is missing, not because of a typo or a bad import

**It passed?** You are testing behaviour that already exists. Fix the test.
**It errored?** Fix the error and run again until it fails properly.

## Green — minimal code

The simplest thing that makes this test pass. No options parameter nobody asked
for, no second code path, no "while I'm here" refactor of the file next door.

## Verify green — watch it pass

Run it again. Confirm the test passes, nothing else broke, and the output is
pristine — no stray warnings or noise.

**"Nothing else broke" means the project's suite, not your file.** A green run
of the test you just wrote is not a green suite. Before calling the change done,
run the project's own test command. Any failure that run shows — including one
you did not cause — goes in your report by name. A red test you watched scroll
past and did not mention is a report falsified by omission.

**Test fails?** Fix the code, not the test.

## Refactor

Only once green. Remove duplication, improve names, extract helpers. Keep the
tests green and do not add behaviour. Then write the next failing test.

## Checklist

- [ ] every new function has a test
- [ ] you watched each test fail before implementing
- [ ] each failed for the expected reason
- [ ] you wrote the minimum to pass
- [ ] the project's full suite is green
- [ ] output is pristine
- [ ] tests exercise real code
- [ ] edge cases and error paths covered

Cannot tick them all? You skipped TDD.

## When it is hard

| Problem | What it means |
|---|---|
| don't know how to test it | Write the API you wish existed. Write the assertion first. |
| the test is complicated | The design is complicated. Simplify the interface. |
| have to mock everything | The code is too coupled. Inject the dependencies. |
| the setup is enormous | Extract helpers. Still huge? Simplify the design. |

## Rationalisations

| Excuse | Reality |
|---|---|
| "Too simple to break" | Simple code breaks. The test takes thirty seconds. |
| "I'll test after" | Tests written after pass immediately, which proves nothing. You never watched it fail, so you never proved it can catch the bug. |
| "Tests-after achieve the same thing" | Tests-after answer "what does this do?". Tests-first answer "what should this do?" — and they find the cases you would have forgotten. |
| "I already tested it manually" | No record of what you covered, no way to re-run it. "Worked when I tried it" is not coverage. |
| "Deleting four hours of work is wasteful" | That time is spent either way. The choice is rewriting with tests you trust, or keeping code you cannot. |
| "I'll keep it as reference" | You will adapt it. That is testing after. |
| "TDD will slow me down" | Debugging this in production is slower. |
| "Hard to test, so I'll skip it" | Hard to test means hard to use. Listen to the test. |
| "The existing code has no tests either" | You are improving it. Add tests for what you touch. |

Any of these: delete the code and start over.

## With debugging

Found a bug? Write the failing test that reproduces it first, then follow the
cycle. The test proves the fix and stops the regression coming back. Never fix a
bug without one — see `stages/debug.md`.
