# CLAUDE.md

Guidance for Claude Code when working in this repository.

`gdskeleton` is a Godot 4.7 multiplayer 3D skeleton: a component-composition
architecture with a client-simulated, server-validated network model.

Remote: **<https://github.com/elliotchen02/gdplaygroundv2>**
(`git@github.com:elliotchen02/gdplaygroundv2.git`, verified via `git remote -v`).
All work reaches `main` through a pull request — see
[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).

---

## Working Style

These five rules govern every response and every change in this repo.

**1. Think step by step before making any change or claim.**
State the reasoning before the edit. Read the file before you modify it, and
read the neighbouring `README.md` before you add to a directory. A claim about
how the engine behaves is a claim that needs checking, not a starting premise.

**2. Ask before assuming.**
If context is missing — which node owns a responsibility, whether a component
belongs in `systems/` or `src/`, what the intended tuning value is — ask. A
question costs one turn; a wrong assumption costs a rewrite and leaves an
architecture rule quietly broken.

**3. Cite references for all technical claims.**
Every technical assertion carries a source: official Godot documentation, a
GitHub issue or PR, an RFC, or a link to the source code (in this repo, a
`path/to/file.gd:line` reference). "Godot ticks parents before children" is a
citation-bearing claim; so is any statement about what an addon version does.
No source, no claim.

**4. Never guess a version, flag, API behaviour, or compatibility.**
Verify against the installed engine and the pinned addons before writing code
against them. Check the actual API signature rather than recalling it. When
adding or upgrading a dependency, prefer the most recent stable release, and
confirm its minimum-engine requirement before pulling it in.

**5. Keep comments human-readable and as succinct as possible.**
`##` doc comments state the single responsibility and the non-obvious *why*.
Inline `#` comments explain a decision that the code cannot state itself — a
load-bearing ordering, an engine constraint, a deliberate tolerance. Never
narrate what the next line already says.

---

## Stack

Verified facts, with sources. Do not restate these from memory — re-check them.

| Fact | Value | Source |
| --- | --- | --- |
| Engine | Godot **4.7.stable.official** | `godot --version`; `config/features` in `project.godot` |
| Language | **GDScript only** — no C# | `.cursor/rules/project-structure.mdc` |
| Renderer | Forward+ | `project.godot` → `config/features` |
| 3D physics | Jolt Physics | `project.godot` → `[physics] 3d/physics_engine` |
| Physics interpolation | enabled | `project.godot` → `[physics] common/physics_interpolation` |
| Main scene | `res://src/main.tscn` | `project.godot` → `run/main_scene` |
| Test framework | gdUnit4 **6.1.3** | `addons/gdUnit4/plugin.cfg` |
| Editor bridge | Godot MCP **4.0.1** (requires engine ≥ 4.5) | `addons/godot_mcp/plugin.cfg` |
| Autoloads | `InstanceWindow`, `AutoMove` (both `hack/`), `MCPGameBridge` | `project.godot` → `[autoload]` |
| Godot binary (macOS) | `/Applications/Godot.app/Contents/MacOS/Godot`, overridable via `GODOT_BIN` | `hack/run-headless.sh`, `hack/run-changed-tests.sh` |

---

## Project structure

Every directory carries its own `README.md` and that file is authoritative for
its contents. Summaries below; read the source `README.md` before working in a
directory.

### Top level

- **`systems/`** — portable, game-agnostic building blocks. Hard portability
  contract: it must lift into another Godot project **unchanged**, so nothing
  here may reference `src/`, `ui/`, `sandbox/`, or `assets/`, or hardcode an
  input action, collision layer, group name, or autoload. Anything the game must
  configure arrives via `@export` or a method call. (`systems/README.md`)
- **`systems/components/`** — attachable node components, one folder each. A
  component extends the Godot node it needs to be, owns one responsibility, and
  is fundamental enough to reuse across unrelated objects. Also documents the
  "Runtime toggles" pattern — neutral flags (`reads_input`, `simulates`,
  `activates_on_ready`) the game clears on copies it does not own, naming no
  networking concept. (`systems/components/README.md`)
- **`src/`** — the actual game: actors, worlds, and the app shell, composing
  `systems/` and `assets/`. Game-specific logic that is not reusable belongs
  here, never in `systems/`. (`src/README.md`)
- **`src/net/`** — session-level multiplayer glue. Documents the model in full:
  client-simulated, server-validated; clients simulate locally with zero input
  latency and report the *resulting* transform; the server never simulates a
  player and never sees an input, only checks reachability. Contains three
  load-bearing rules (owner excluded from `StateSynchronizer`, authority derived
  identically on every peer in `_enter_tree`, claims land in mirror properties).
  (`src/net/README.md`)
- **`src/player/`** — the first-person player actor: a `CharacterBody3D`
  composed of four components plus a camera rig, with `player_network.gd`
  owning everything network-related and resolving one of three roles (owner /
  server record / observer). (`src/player/README.md`)
- **`ui/`** — menus, HUD, and other `Control`-based screens. The UI observes
  gameplay via signals; it does not drive game logic. (`ui/README.md`)
- **`sandbox/`** — playground for developing new features, throwaway by default.
  What pans out is promoted into `src/`, or extracted into a `systems/`
  component if it proves reusable and game-agnostic. Never shipped.
  (`sandbox/README.md`)
- **`assets/`** — art and audio, **no scripts**; referenced as `res://assets/...`.
  Everything outside `third_party/` is first-party by convention.
  (`assets/README.md`)
- **`assets/third_party/`** — downloaded packs, marketplace, and CC assets.
  Keep license/attribution alongside each pack. (`assets/third_party/README.md`)
- **`hack/`** — dev and test tooling: shell scripts and debug-only autoloads
  (window tiling, headless input bots, test runners). Never shipped; the
  autoloads guard themselves so they are inert in release builds. Its README is
  the headless multiplayer testing guide — which log holds which signal, why
  headless can show rejected claims and corrections but never jitter, and the
  `MCPGameBridge` contention caveat. (`hack/README.md`)
- **`docs/`** — all Markdown that is not a directory `README.md`: the git
  workflow (`docs/CONTRIBUTING.md`), feature plans under `docs/plans/`, and
  operational procedures under `docs/runbooks/`. Write a plan in `docs/plans/`
  before implementing any large feature. (`docs/README.md`)
- **`addons/`** — third-party plugins (`gdUnit4`, `godot_mcp`). Vendored; do not
  edit, and skip when scanning for project code.
- **`reports/`** — gdUnit4 HTML/XML output. Generated, git-ignored, disposable.
- **`.cursor/rules/`** — the source-of-truth rule files this document
  summarises: `base-godot-rules.mdc`, `component-architecture.mdc`,
  `project-structure.mdc`. Keep them and this file in step.

### Dependency rules (one-way, enforced by convention)

```
systems/  →  depends on NOTHING else in the repo
src/      →  may depend on systems/, assets/
ui/       →  may depend on systems/, src/
sandbox/  →  may depend on anything;  NOTHING may depend on sandbox/
hack/     →  may depend on anything;  NOTHING may depend on hack/
assets/   →  contains no scripts
```

Source: `.cursor/rules/project-structure.mdc`, `systems/README.md`.

### Adding a feature

Build the reusable, game-agnostic part as a component in
`systems/components/`; compose it into the game under `src/`. Prototype in
`sandbox/` first when unsure, then promote. For anything large, write the plan
in `docs/plans/` first.

---

## Architecture rules

Full text in `.cursor/rules/base-godot-rules.mdc` and
`.cursor/rules/component-architecture.mdc`.

- **Composition over inheritance.** Actors are built by attaching components as
  child nodes. There are **no intermediate or abstract base classes** — Godot
  has single inheritance, so the component *is* the node it extends.
- **One responsibility per component.** Anything needing game-specific knowledge
  is not a `systems/` component.
- **Script by default.** A component gets a `.tscn` only when it bundles a
  multi-node assembly that would otherwise be rebuilt by hand at every use site.
  State why in the file header.
- **Wiring via `@export`.** Never `get_node("../../Thing")` chains. Prefer
  `@export` or `%UniqueNode`. Always give a script a `class_name`.
- **Signals up, calls down.** Signals are named in past tense and pass the
  minimum a listener needs; the host drives components downward by calling them.
- **Autoloads are for global services only** (event bus, save, audio). Never
  scene-specific state.
- **Editor warnings are fatal.** Treat every GDScript warning as an error.
- **No heavy work per frame.** No raycasts, shapecasts, file I/O, or array
  scans in `_process` / `_physics_process`. This rule is why geometry path
  validation is deferred in `movement_validator_component`.
- **`preload()` for what is known at compile time**, `load()` only for dynamic
  runtime instantiation.
- **Set properties before `add_child()`** to avoid tree update cascades.

### Adding a component

1. Copy `systems/components/template_component/` — it is the canonical anatomy,
   not a base class. Nothing inherits from it.
2. Rename the folder, the `.gd` file, and the `class_name` together.
3. State the single responsibility in the header `##` docstring.
4. `extends` the Godot node the component needs to be.
5. Group `@export`s into `@export_group("Wiring")` and `@export_group("Tuning")`.
6. Name signals in past tense; pass the minimum payload.
7. Delete the placeholder behaviour and anything unused.
8. Write the component's `README.md` — every other component has one.
9. Add a colocated `_test.gd` suite.
10. Add it to the catalog in `systems/components/README.md`.

`@tool` is required for `_get_configuration_warnings()` and is **not**
inherited — each component needing editor validation declares its own, and
guards runtime-only work with `if Engine.is_editor_hint(): return`.

---

## Code style

Source: `.cursor/rules/project-structure.mdc`, `.gdlintrc`, `.gdformatrc`,
`.editorconfig`, and the
[GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

- **Strict static typing on every variable, parameter, and return type** —
  including loop variables (`for arg: String in args:`) and locals. This is
  stricter than the engine default; match the existing code.
- **Tabs** for indentation. **100 columns** max.
- `PascalCase` classes, `snake_case` variables/functions/signals,
  `SCREAMING_SNAKE_CASE` constants, `_leading_underscore` for private members.
- `##` doc comments on classes, exported properties, and non-obvious functions.
  The class docstring names the single responsibility in one sentence.
- `StringName` literals (`&"move_left"`, `&"ui_cancel"`) for action names.
- Linting/formatting via [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit);
  the `class-definitions-order` rule is deliberately disabled (`.gdlintrc`).

---

## Testing

gdUnit4 6.1.3 ([docs](https://github.com/MikeSchulze/gdUnit4)), configured with
test discovery on and no separate lookup folder (`project.godot` → `[gdunit4]`).

- Tests are **colocated** with the code they test, using a `_test` suffix:
  `movement_component.gd` → `movement_component_test.gd`.
- A suite `extends GdUnitTestSuite`; test methods start with `test_`.
- Prefer pure-arithmetic components that unit-test without a scene (see
  `movement_validator_component`, which holds no multiplayer references at all).
  Where behaviour only exists inside the physics loop — gravity, floor
  detection, `move_and_slide()` — build a real body over a static floor and step
  frames (see `systems/components/movement_component/movement_component_test.gd`).

```bash
./hack/run-changed-tests.sh              # tests for unstaged + staged changes
./hack/run-changed-tests.sh --staged     # staged only (pre-commit)
./hack/run-changed-tests.sh --base main  # branch diff vs main
./addons/gdUnit4/runtest.sh -a res://path/to/suite_test.gd   # one suite
```

Results land in `reports/report_<n>/` (git-ignored).

### Headless multiplayer testing

Read `hack/README.md` in full before doing this — it explains which log holds
which signal.

```bash
./hack/run-headless.sh 2 --auto-move --duration 15
grep -nE 'REJECT|force_state|strikes|ERROR|WARNING' hack/logs/*.log
```

Headless **can** show rejected claims, `force_state` corrections, spawned roles,
positions over time, and errors. It **cannot** show anything visual —
interpolation jitter is a rendering artifact and needs a windowed run.

---

## Contributing

**Read [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) before touching git.** It
is authoritative for the branch, worktree, and PR workflow. In short: never
commit or push to `main` — branch off `main`, use a separate worktree when
other work is in flight, and land every change through a PR against `main`.
Commits follow Conventional Commits, scoped to the top-level directory touched.

Never commit, push, or open a PR without being asked.

---

## Gotchas

Each of these has bitten this project already; the cited file explains why.

- **Replication is configured against property names.** Renaming a `claimed_*`
  variable or moving `position` breaks replication *silently*. Keep the marked
  synced block in `src/player/player_network.gd` and the `SceneReplicationConfig`s
  in `src/player/player.tscn` in step. (`src/player/README.md`)
- **Authority is pinned in `_enter_tree`, never `_ready`** — the spawner rejects
  synchronizers that have no network ID yet. (`src/net/README.md`)
- **The owner is excluded from `StateSynchronizer`** or it rubber-bands its own
  local simulation every tick. (`src/net/README.md`)
- **`MCPGameBridge` runs in every game instance** and fights the editor for the
  single MCP bridge slot. Close the editor, or remove the autoload line for the
  run, before a clean headless session. (`hack/README.md`)
- **Component-runtime flags name no networking concept** (`reads_input`,
  `simulates`, `activates_on_ready`) — that neutrality is what keeps the
  components inside the `systems/` portability contract.
  (`systems/components/README.md`)
