# Pandemonia

Godot 4.7 stable, 2D-first project.

## Setup (run once per clone)

Git hooks are version-controlled in `.githooks/` but, for security, git never
runs tracked hooks until you opt in **per clone/machine**:

```bash
./hack/setup.sh
```

This creates a project-local `.venv/` (gitignored) with
[pinned gdtoolkit](hack/requirements-gdtoolkit.txt) and sets `core.hooksPath`
to `.githooks`, enabling:

- **pre-commit** — auto-formats staged `.gd` files with `gdformat`, then lints
  them with `gdlint` (only files you are committing; existing debt is untouched)
- **commit-msg** — enforces Conventional Commits

Requires Python 3.7+. On macOS, the system Python is fine; Homebrew `python3`
also works.

Skip hook setup and commits simply won't be validated locally.

## Layout

- `libs/` — reusable, domain-agnostic systems & abstractions
- `src/` — the composed game that wires those systems together
- `assets/` — raw imports, mirroring the `src/` buckets
- `addons/` — editor plugins
- `hack/` — dev-only automation (not shipped)
- `tests/` — headless test scripts

See `.cursor/rules/` for the full structure and commit conventions.
