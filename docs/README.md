# docs/

Every Markdown file that is not a directory `README.md` lives here.

Directory `README.md`s stay next to the code they describe (`src/net/README.md`,
`systems/components/<name>_component/README.md`, ...) — they document *what a
directory is*. `docs/` holds everything else: design write-ups, feature plans,
and operational procedures.

- `CONTRIBUTING.md` — the git workflow: branching off `main`, worktrees, and
  the pull-request process. Authoritative; `../CLAUDE.md` only points at it.
- `plans/` — one Markdown file per large feature, written **before** the code.
- `runbooks/` — step-by-step operational procedures for tasks that get repeated.

Not shipped; contains no scripts and no engine resources.
