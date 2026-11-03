# Authoring x-impl skills

A maintainer's doc, not a skill. Read it before writing a new skill in this set,
editing an existing one, or judging whether one is well formed.

## What a skill is

A reusable procedure for a kind of work — a technique, a discipline, a way of
deciding. Not a story about one time you solved something, not a project
convention (that belongs in AGENTS.md), and not a rule a linter could enforce
(automate that instead and save the prose for judgement calls).

Write one when the technique was not obvious to you, you would reach for it
again across projects, and it is not already well covered elsewhere.

In this set there are eight, and that is deliberate. A skill nobody can
distinguish from its neighbour never gets loaded; `x-build` absorbed isolation,
parallel work and per-task review precisely because they were steps of one job,
not jobs of their own. Before adding a ninth, check whether it is a section of
an existing skill.

## The file

```
skills/x-<name>/
  SKILL.md             required
  prompts/*.md         subagent brief templates, if the skill dispatches any
  references/*.md      heavy reference, only when it is genuinely long
  scripts/*            bundled scripts, if any
```

The directory name is the skill name. Keep SKILL.md short enough to read in one
go; move anything over a hundred lines of pure reference into `references/` and
link to it from the step that needs it. `x-build/references/isolate.md` is the
worked example: the skill carries the four-step summary, the reference carries
the detection snippets and the edge cases.

A prompt template two skills both need lives in one of them and is referenced by
relative path from the other — `x-land` points at
`../x-build/prompts/review.md` rather than keeping a second copy that drifts.

Bundled scripts are invoked through their interpreter in the prose —
`sh scripts/thing`, not `scripts/thing`. Some installers strip executable bits,
and a bare path fails there with a permission error.

## Frontmatter

Two fields, plus one invocation flag on every skill except `x-impl`:

```yaml
---
name: x-example
description: Use when ... - ... .
user-invocable: false
---
```

- **`user-invocable: false`** keeps the skill out of the user's slash commands
  while the model can still load it. `x-impl` is the only skill users invoke
  directly; every other skill is reached by the model. Claude Code and OpenClaw
  honour the flag; harnesses that do not know it ignore it. It is the one
  harness-specific field allowed here. Add no others.

- **`name`** must equal the directory name, and use only lowercase letters,
  digits and hyphens. In this set it starts with `x-`, so these skills do not
  collide with other skill packs installed alongside.
- **`description`** is at most 1024 characters, written in the third person, and
  it says **only when to reach for the skill**: the triggers, the symptoms, the
  situation. Start it with "Use when".

A description that summarises the procedure gets followed *instead of* the
skill — an agent that has read a three-line summary of your workflow feels like
it already knows it and never loads the file. Say when, not how.

Put the words someone would actually have in mind into the description: the
error, the symptom, the tool, the phrase. `x-conclave` names "grill me" because
that is what a user types; `x-land` names "about to commit, push, open a pull
request" because that is the moment it fires.

## Actions, not tools

Skill bodies name **actions**: "dispatch a subagent", "track a todo list",
"load skill x-plan", "run a shell command", "create a worktree". Never a tool
name — no `Task`, no `bash`, no `TodoWrite`. The vocabulary is in
`adapters/actions.md`; the per-harness mapping is in `adapters/<harness>.md`.

This is what lets one skill body run on three harnesses unchanged. If you find
yourself wanting to name a tool, either the action vocabulary is missing a word
— add it to `actions.md` and map it in all three adapters — or the detail
belongs in the adapter, not the skill.

When a skill depends on an optional capability (subagents, todos, worktrees),
say what to do without it. Never let a skill leave an agent inventing a tool
call.

## The announce rule

Every skill's procedure starts with it:

> **Start by announcing:** `Using <skill-name> to <purpose>.`

One line, at the start. It is how a user watching the session knows which
procedure is running, and it is the one portable signal that a skill actually
fired on any harness.

## Tone

Calm. The skill is a thread to follow, not an order. No shouting, no all-caps
emphasis tags, no "there is a 1% chance this applies so you MUST". A skill that
has to threaten the reader is usually a skill that has not explained itself.

State the rule, say why it holds, and give the cost of getting it wrong. That
survives pressure better than emphasis does.

## Match the form to the failure

Before writing the guidance, name the failure you are correcting:

| Failure | Right form | Wrong form |
|---|---|---|
| skips a rule under pressure, knowing better | a plain prohibition plus a rationalisation table | soft hedging — "prefer", "consider" |
| complies, but the output has the wrong shape | a positive recipe: state what the output *is*, its parts, in order | a list of prohibitions |
| omits a required element from something they already produce | a required slot in the template they fill in | a prose reminder near the template |
| behaviour should depend on a condition | a conditional on something observable | an unconditional rule plus exemptions |

Prohibitions backfire on shaping problems: under a competing incentive, "don't
do X" is something to negotiate with. A recipe leaves nothing to negotiate.

And do not soften a rule with a nuance clause. "Don't do X unless it matters"
reopens the whole question. A real exception is its own conditional on something
observable.

## Modes inside one skill

Two skills here carry named modes — `x-conclave` (auto, interactive) and
`x-build` (per-task, inline, parallel). The shape that works: the shared engine
first, under its own heading, then one `## Mode: <name>` section per mode saying
only what differs, then the output or handoff, shared again.

The mode is picked once, stated in one line, and held. A skill that lets the
model drift between modes mid-run produces half of each.

## Rationalisation tables

For discipline skills, the table is the load-bearing part. Each row is an excuse
you have actually seen, in the words it appears in, answered in one line. Write
rows from real failures, not hypothetical ones.

## Examples

One excellent example beats five mediocre ones. Pick the language that fits the
technique. Make it complete, runnable, and from a real situation, commented with
*why* rather than what. Do not write the same example in five languages, and do
not write fill-in-the-blank templates where a concrete case would do.

## Checklist

- [ ] directory name matches `name`, lowercase with hyphens, `x-` prefix
- [ ] `description` starts with "Use when", third person, ≤1024 characters
- [ ] `description` says when, never how
- [ ] `user-invocable: false` unless the skill is `x-impl`, and no other
      harness-specific frontmatter fields
- [ ] the body names actions, not tools
- [ ] optional capabilities have a stated fallback
- [ ] the procedure starts with the announce rule
- [ ] calm tone, no shouting
- [ ] the guidance form matches the failure type
- [ ] one good example, not five
- [ ] heavy reference moved to `references/`, linked from where it is needed
- [ ] bundled scripts invoked through an interpreter
- [ ] no narrative storytelling
- [ ] cross-references use `load skill <name>`, matching the real skill names
- [ ] every relative path the skill names actually exists
- [ ] the index (`x-impl.md` and `skills/x-impl/SKILL.md`), the README table and
      the adapters all name the new skill
