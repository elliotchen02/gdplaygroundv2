# Rule: CLAUDE.md files stay minimal

**Read this before creating or editing any `CLAUDE.md`.**

## Why

`CLAUDE.md` is prepended to the context of *every* session and *every* subagent
that touches its directory. Unlike a file you choose to read, its cost is paid
on every turn, forever, by every agent. A bloated `CLAUDE.md` does not just
waste tokens — it dilutes attention, so the instructions that actually matter
get followed less reliably. Treat it as prompt real estate, not documentation.

## Hard constraints

- **Budget: ~100 lines / ~1500 tokens per file.** Exceeding it requires an
  explicit reason stated to the user, not a silent overrun.
- **Never append without pruning.** Adding a section means checking whether an
  existing one is now stale, redundant, or was never earning its place. Net line
  growth should be the exception.
- **Ask before adding.** Do not write to a `CLAUDE.md` as a side effect of some
  other task. Persisting an instruction for all future sessions is the user's
  call — propose the exact lines and let them approve.

## What belongs

Only things that are **non-obvious** and would otherwise be **repeatedly
rediscovered or gotten wrong**:

- Commands that are not guessable from the repo (build, test, run a single test,
  lint) — the exact invocation, not an explanation of it.
- Project-specific conventions that contradict the language/framework default.
- Environment quirks, required setup steps, known traps and footguns.
- Architectural facts not visible from a single file (where the boundaries are,
  what owns what).

## What does not belong

- Anything derivable by reading the code, the file tree, or `git log`.
- General best practices the model already knows ("write tests", "handle
  errors", "use meaningful names", "follow DRY").
- Exhaustive API/function/class listings or per-file walkthroughs — that is what
  the code is for.
- Changelogs, migration history, "recently we fixed…", session status, TODOs,
  or anything with a shelf life. Those go in issues, commits, or task files.
- Long prose, rationale essays, or restated instructions phrased three ways.

## How to write it

- Short declarative bullets under `##` headings. No paragraphs where a bullet
  works. No filler ("This project is a…", "Note that…").
- Prefer specifics over adjectives: `pytest tests/unit -x` beats "run the fast
  tests".
- Scope down instead of centralizing: directory-specific guidance goes in a
  nested `CLAUDE.md` in that directory, which loads only when that area is in
  play. Keep the root file to what is truly global.
- Use `@path/to/file` imports to reference content rather than duplicating it.
- Reserve emphasis (`IMPORTANT`, bold, caps) for the one or two rules that are
  genuinely costly to break. Emphasis everywhere is emphasis nowhere.

## Review checklist

Before saving any edit to a `CLAUDE.md`, confirm each line:

1. Is it true, and still true?
2. Would an agent get this wrong or waste time without it?
3. Is it unavailable by simply reading the code?
4. Is it the shortest phrasing that stays unambiguous?
5. Is this the narrowest file it could live in?

Any "no" — cut the line.
