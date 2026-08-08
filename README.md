# gdskeleton

A Godot 4.7 multiplayer 3D skeleton: GDScript only, Forward+ rendering, Jolt
physics. A starting point for a first-person
multiplayer game, built around a **client-simulated, server-validated**
network model and a **composition-over-inheritance** component architecture.

## Requirements

- Godot 4.7 (`config/features` pins this in `project.godot`).
- Engine binary: `/Applications/Godot.app/Contents/MacOS/Godot`, overridable
  via the `GODOT_BIN` environment variable.

## Running it

Open the project in the Godot editor and run `src/main.tscn` (the default
`run/main_scene`). A bare launch hosts a session so a single F5 works.

To try multiplayer, launch two instances via the editor's *Debug > Customize
Run Instances*, or run the engine headless once per peer. The engine binary is
not on `PATH`, so go through `GODOT_BIN`:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . -- --host           > host.log 2>&1 &
"$GODOT_BIN" --headless --path . -- --join=127.0.0.1 > client.log 2>&1 &
```

The flags after `--` are parsed in [`src/net/net_session.gd`](src/net/net_session.gd):
`--host`, `--join[=address]`, `--port=N` (default `24545`). No network flag
means host, so a bare launch starts a local session.

## Architecture

The repo is organized into layers with one-way dependencies:

```
systems/  →  depends on NOTHING else in the repo (must lift into another project unchanged)
src/      →  may depend on systems/, assets/
ui/       →  may depend on systems/, src/
sandbox/  →  may depend on anything;  NOTHING may depend on sandbox/
hack/     →  may depend on anything;  NOTHING may depend on hack/
assets/   →  contains no scripts
```

- **`systems/`** — portable, game-agnostic building blocks, chiefly attachable
  node components (`systems/components/`). Actors are assembled by composing
  components as child nodes; there are no intermediate base classes.
- **`src/`** — the actual game: the launch scene, actors, worlds, and the
  network session/spawn glue that wires `systems/` components together.
- **`ui/`** — menus, HUD, and other `Control`-based screens.
- **`sandbox/`** — throwaway playground for features that haven't proven out
  yet. Never shipped.
- **`assets/`** — art and audio, no scripts.
- **`addons/`** — third-party and internal editor tooling: `gdUnit4` (test
  runner) and `godot_mcp` (an editor MCP bridge for tool-assisted development).
- **`hack/`** — developer scripts, chiefly the changed-file test runner.
- **`reports/`** — generated test output, git-ignored.

See each directory's `README.md` for the full detail, and
[`CLAUDE.md`](CLAUDE.md) for the rules an AI agent (or a human) should follow
when working in this repo.

## The network model

Each client simulates its own player exactly as it would in single player —
zero input latency, no client-side prediction machinery — and reports the
*resulting* transform. The server never simulates a player and never sees an
input; it only checks that each reported position was physically reachable,
correcting the rare cases that were not. Other clients see only the server's
accepted state, so a rejected motion never reaches them.

See [`src/net/README.md`](src/net/README.md) and
[`src/player/README.md`](src/player/README.md) for the full mechanics.

## Testing

[gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), colocated with the code
it tests (`movement_component.gd` → `movement_component_test.gd`).

```bash
./hack/run-changed-tests.sh                  # tests for changed .gd files
./hack/run-changed-tests.sh --staged         # staged only (pre-commit)
./addons/gdUnit4/runtest.sh -a res://path/to/suite_test.gd   # one suite
```

Runtime behaviour is tested in tiers — a gdUnit4 suite, a `scene_runner()` scene
test, a headless multi-peer run, or godot-mcp for what only exists in a rendered
frame. [`docs/runbooks/runtime-testing.md`](docs/runbooks/runtime-testing.md)
says which to reach for.

## Contributing

Read [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) before touching git: never
commit or push to `main`, branch off `main` for every change, and land it
through a PR.
