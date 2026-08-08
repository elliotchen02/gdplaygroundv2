# CLAUDE.md

Godot 4.7 multiplayer 3D skeleton. **GDScript only**, Forward+, Jolt physics.
Engine: `/Applications/Godot.app/Contents/MacOS/Godot`, overridable via
`GODOT_BIN`.

Detailed docs live next to the code: every directory has a `README.md`, and
`systems/` and `src/` have their own `CLAUDE.md` that loads when you read files
there. Read the local `README.md` before working in a directory.

**Keep every `CLAUDE.md` small — durable rules only.** Anything readable from
the code or `project.godot`, any one-off finding, rationale, or note explaining
why an earlier doc was wrong, belongs in `docs/` or a directory `README.md`.
Prefer replacing a line over appending one.

## Working Style

1. **Think step by step before making any change or claim.** Read the file
   before modifying it; read the directory's `README.md` before adding to it.
2. **Ask before assuming.** If context is missing — which node owns a
   responsibility, whether something belongs in `systems/` or `src/`, what a
   tuning value should be — ask rather than guess.
3. **Cite references for all technical claims:** official docs, a GitHub issue,
   an RFC, or a source link (`path/to/file.gd:line` in this repo). No source, no
   claim.
4. **Never guess a version, flag, API behaviour, or compatibility.** Verify
   against the installed engine and pinned addons. Prefer the most recent stable
   release when adding a dependency, and confirm its minimum engine version.
5. **Keep comments human-readable and succinct.** `##` doc comments state the
   single responsibility and the non-obvious *why*. Never narrate what the next
   line already says.

## Commands

```bash
./hack/run-changed-tests.sh                  # gdUnit4 tests for changed .gd files
./hack/run-changed-tests.sh --staged         # staged only (pre-commit)
./addons/gdUnit4/runtest.sh -a res://path/to/suite_test.gd   # one suite
"$GODOT_BIN" --headless --path . -- --host   # headless peer; --join=127.0.0.1 for a client
```

Test reports land in `reports/` (git-ignored).

## Code style

- **Strict static typing on every variable, parameter, and return type**,
  including loop variables (`for arg: String in args:`). Stricter than Godot's
  default — match the existing code.
- Tabs for indentation, 100 columns max (`.gdformatrc`, `.gdlintrc`).
- `PascalCase` classes, `snake_case` members, `SCREAMING_SNAKE_CASE` constants,
  `_leading_underscore` for private.
- `##` doc comments on classes, exported properties, and non-obvious functions.
- `StringName` literals for action names: `&"move_left"`.
- Always give a script a `class_name`.
- **Editor warnings are fatal.** Treat every GDScript warning as an error.

## Architecture

- **Composition over inheritance.** Actors are built by attaching components as
  child nodes. There are **no intermediate or abstract base classes** — a
  component *is* the Godot node it extends.
- **Wire via `@export` or `%UniqueNode`**, never `get_node("../../Thing")`.
- **Signals up (past tense), method calls down.**
- **Never run heavy work per frame.** No raycasts, shapecasts, file I/O, or
  array scans in `_process` / `_physics_process`.
- `preload()` for what is known at compile time; `load()` only for dynamic
  runtime instantiation. Set properties *before* `add_child()`.
- Autoloads are for global services only, never scene-specific state.

### Dependency rules (one-way, YOU MUST NOT break these)

```
systems/  →  depends on NOTHING else in the repo (must lift into another project unchanged)
src/      →  may depend on systems/, assets/
ui/       →  may depend on systems/, src/
sandbox/  →  may depend on anything;  NOTHING may depend on sandbox/
hack/     →  may depend on anything;  NOTHING may depend on hack/
assets/   →  contains no scripts
```

Build the reusable, game-agnostic part as a component in `systems/components/`;
compose it into the game under `src/`. Prototype in `sandbox/` when unsure.

## Testing

gdUnit4. Tests are **colocated** with the code they test using a `_test` suffix
(`movement_component.gd` → `movement_component_test.gd`). A suite
`extends GdUnitTestSuite`; test methods start with `test_`.

### Which runtime tier

**Read `docs/runbooks/runtime-testing.md` before testing at runtime.**

- Component logic → a gdUnit4 suite building its nodes by hand.
- Scene behaviour under real input actions → gdUnit4 `scene_runner()`.
- Multiplayer claim-and-correct → the engine run headless as two peers.
- Looks wrong — jitter, camera, framing → godot-mcp, editor open.

**If you would want to run the check again next week, it is a gdUnit4 test.**
godot-mcp observations are not reproducible and do not run in CI.

`addons/godot_mcp/` and the server pinned in `.mcp.json` must stay version-matched.

## Contributing

**Read `docs/CONTRIBUTING.md` before touching git.** In short: never commit or
push to `main` — branch off `main`, use a separate worktree when other work is
in flight, and land every change through a PR. Conventional Commits, scoped to
the top-level directory touched.

Never commit, push, or open a PR without being asked.

## Docs

`docs/` holds all Markdown that is not a directory `README.md`:
`CONTRIBUTING.md`, `plans/` (write a plan before implementing a large feature),
and `runbooks/` (repeated operational procedures).
