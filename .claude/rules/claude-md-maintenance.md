---
paths:
  - "CLAUDE.md"
  - "**/CLAUDE.md"
  - "**/CLAUDE.local.md"
---

# Editing CLAUDE.md

CLAUDE.md loads into every session, in full, before any work starts. Length
costs adherence: the longer the file, the less reliably any single line in it
is followed. Edits are subtractive by default.

## Limits

- Target under 200 lines per file.
- Never append without pruning. Adding a section means checking whether an
  existing one is now stale or redundant; net growth is the exception.
- Ask before writing. Persisting an instruction for every future session is the
  user's call — propose the lines, let them approve.
- `/doctor` proposes trims for a checked-in CLAUDE.md. Use it before hand-editing
  a long one.

## Include

- Commands that are not guessable — the exact invocation, not an explanation.
- Conventions that contradict the language or framework default.
- Environment quirks, required setup, known footguns.
- Architecture not visible from a single file: boundaries, what owns what.

## Exclude

- Anything derivable from the code, the file tree, or `git log`.
- Practices Claude already knows ("write tests", "handle errors").
- API listings and per-file walkthroughs.
- Changelogs, migration history, session status, TODOs.

## Write

- Short declarative bullets under `##` headings. No paragraphs, no filler.
- Concrete over vague: `pytest tests/unit -x`, not "run the fast tests".
- Scope down. Directory-specific guidance belongs in that directory's
  `CLAUDE.md`, which loads only when files there are read. `@path` imports
  organize but do not save context — they load at launch too.
- Reserve emphasis for the one or two rules that are costly to break.

Every line must be true, non-obvious, unavailable from the code, and in the
narrowest file it could live in. Otherwise cut it.
