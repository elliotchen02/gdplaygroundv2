# Contributing

How work gets from a local edit into `main`. Read with `../CLAUDE.md`, which
owns the architecture, style, and testing rules this document assumes.

Remote: `git@github.com:elliotchen02/gdplaygroundv2.git`
(<https://github.com/elliotchen02/gdplaygroundv2>). `main` tracks `origin/main`.

## Never commit to `main`

**Every change starts on a new branch off `main`, and reaches `main` only
through a pull request.** No direct commits to `main`, no direct pushes to
`main` — including for a one-line fix or a docs typo.

```bash
git switch main
git pull --ff-only origin main       # branch from current origin/main, not a stale local main
git switch -c <type>/<short-description>
```

Name the branch after the work, matching the commit scope where it makes sense:
`feat/network-interpolation`, `fix/validator-vertical-budget`,
`docs/component-readmes`.

## Use a worktree when there is in-flight work

If the current checkout has uncommitted changes, or another branch is mid-review
and you need to leave it intact, do **not** stash and switch — create a separate
worktree so both branches stay checked out at once:

```bash
git worktree list                                     # what already exists
git worktree add ../worktrees/<branch> -b <branch> origin/main
# ... work in ../worktrees/<branch> ...
git worktree remove ../worktrees/<branch>             # as soon as the PR merges
```

All worktrees live under the shared `worktrees/` directory, **beside** the
repo (`../worktrees/<branch>`), never inside it — a worktree nested under
`gdskeleton/` would be picked up by Godot as project content. Each worktree is
a full Godot project directory and re-imports into its own `.godot/`, which is
git-ignored and expected.

**Remove the worktree as soon as its PR merges** — `git worktree remove
../worktrees/<branch>`, then `git worktree prune` if the directory was deleted
by hand instead. A stale worktree left behind after merge just accumulates
disk and confuses `git worktree list`.

## Pull requests

1. Commit in logical units using the commit convention below.
2. Push and set upstream: `git push -u origin <branch>`.
3. Open the PR against `main` on GitHub. Plain `git push` prints a *"Create a
   pull request"* URL for the branch — use it. (`gh` is **not installed** on
   this machine as of 2026-08-08, verified via `command -v gh`; if it is
   installed later, `gh pr create --base main` does the same job.)
4. PR description: what changed and **why**, which directories it touches, how
   it was verified (which test suites ran, whether a headless or windowed run
   was needed), and a link to its `plans/` file if it has one.
5. Merge to `main` only after review. Delete the branch and remove its worktree.

Never open a PR, push a branch, or merge without being asked — pushing is
outward-facing and reversing it is noisy.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):
`type(scope): description`. Scope matches the top-level directory touched —
`systems`, `src`, `ui`, `sandbox`, `assets`, `hack`, `docs`, `cursor`.

Only commit when asked. `reports/`, `hack/logs/`, `.godot/`, and `.vscode/` are
git-ignored (`.gitignore`).

## Before you open the PR

- Tests for the changed files pass: `./hack/run-changed-tests.sh`
- No new GDScript editor warnings — they are treated as fatal.
- The dependency rules still hold; in particular `systems/` references nothing
  else in the repo.
- New component? It has a `README.md`, a colocated `_test.gd`, and an entry in
  the catalog in `systems/components/README.md`.
- Large feature? Its plan is in `plans/`.
