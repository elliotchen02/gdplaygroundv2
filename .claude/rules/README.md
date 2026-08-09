# Rules

Durable, project-wide working agreements for Claude Code in this repo.

- One rule per file, kebab-case filename, scoped to a single concern.
- Rules are **not** auto-loaded. They are referenced from the root `CLAUDE.md`
  by a one-line pointer so an agent reads a rule only when the work touches it.
  This keeps always-on context cost near zero.
- A rule states what to do and why, in the fewest lines that still make it
  actionable. If a rule needs more than ~60 lines, it is probably two rules.

| Rule | Applies when |
| --- | --- |
| [claude-md-maintenance.md](claude-md-maintenance.md) | Creating or editing any `CLAUDE.md` |
