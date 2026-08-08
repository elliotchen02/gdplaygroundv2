# Runtime testing

**Purpose.** Decide which runtime-testing tier answers the question in front of
you, and drive it correctly. gdUnit4 covers logic and single-scene behaviour; a
headless engine run covers multiplayer; godot-mcp covers everything that only
exists in a rendered frame.

**Preconditions.** `GODOT_BIN` set, or Godot at
`/Applications/Godot.app/Contents/MacOS/Godot`. Tier 3 additionally needs the
Godot editor open with the **Godot MCP** plugin enabled, and Node.js 20+.

## Which tier

Pick by what the question *is*, not by what is convenient:

| Question | Tier | Editor? | CI? |
| --- | --- | --- | --- |
| Does this component's logic hold? | 1 — gdUnit4 suite | no | yes |
| Does this **scene** behave when driven by real input actions? | 2 — gdUnit4 scene runner | no | yes |
| Does the client/server claim-and-correct loop hold across peers? | 3a — headless engine run | no | not yet |
| Does it *look* right — jitter, camera, framing, a visual bug? | 3b — godot-mcp | yes | no |

The rule: **if you would want to run the check again next week, it is a gdUnit4
test.** If it only exists in a rendered frame, it is godot-mcp. Reaching for
godot-mcp to answer a question tier 1 or 2 could have answered produces an
observation nobody can reproduce.

---

## Tier 1 & 2 — gdUnit4

Both tiers run headless through the same entry points. Tests are colocated with
a `_test` suffix (`../../CLAUDE.md`).

```bash
./hack/run-changed-tests.sh                                  # tests for changed .gd files
./addons/gdUnit4/runtest.sh -a res://path/to/suite_test.gd    # one suite
```

**Tier 1** builds the nodes under test by hand and steps
`get_tree().physics_frame`. See
`systems/components/movement_component/movement_component_test.gd` — a
`CharacterBody3D` over a `StaticBody3D` floor, stepped through real physics.
That is the right shape for a component in isolation.

**Tier 2** loads an actual `.tscn` and drives it through the **InputMap**, so
the wiring in the scene file is under test too — not just the scripts. Use
`scene_runner()`:

```gdscript
var runner := scene_runner(player)          # a path or an instantiated Node
runner.simulate_action_pressed(&"move_forward")
runner.simulate_frames(60)                  # or set_time_factor(4) to fast-forward
assert_float(runner.get_property("velocity").length()).is_greater(0.0)
await runner.await_signal_on(component, "jumped", [], 2000)
```

Full API in `addons/gdUnit4/src/GdUnitSceneRunner.gd`:
`simulate_action_press`/`_release`/`_pressed`, `simulate_key_*`,
`simulate_mouse_*`, `simulate_frames(frames, delta_milli)`, `set_time_factor`,
`simulate_until_signal`, `await_func_on`, `invoke`, `get_property`,
`find_child`.

### The `player.tscn` trap

`PlayerNetwork._enter_tree()` derives authority from the **node name**
(`_owner_id = _player.name.to_int()`). A scene loaded straight from disk is
named `Player`, so `to_int()` yields `0`, no peer matches it, and the offline
peer id of `1` makes `_resolve_role()` return `SERVER_RECORD` — which sets
`movement_component.simulates = false` and `input_component.reads_input =
false`. The test then passes or fails against a player that was never going to
move, with no error printed.

Name the instance after the owning peer before handing it to the runner, the
same way `src/main.gd:_spawn_player` does:

```gdscript
var player: Player = preload("res://src/player/player.tscn").instantiate()
player.name = "1"                            # == multiplayer.get_unique_id() offline -> Role.OWNER
var runner := scene_runner(player)
```

`src/player/player_test.gd` does this and asserts the role took, so the trap
fails loudly instead of silently.

`player.tscn` also carries no floor. Add a `StaticBody3D` to the suite — it
shares the default `World3D`, so the runner's scene collides with it.

---

## Tier 3a — headless multiplayer

For anything involving two peers. godot-mcp **cannot** do this: it drives a
single game instance and the bridge enforces one client at a time.

Peers are plain OS processes — run the engine headless once per peer and capture
each one's stdout. There is no wrapper script to learn; the whole contract is
the flags `src/net/net_session.gd:65` parses, after the `--` separator:

| Flag | Effect |
| --- | --- |
| `--host` | start an ENet server |
| `--join` / `--join=<address>` | connect to a server (`--join` alone uses `127.0.0.1`) |
| `--port=<n>` | override the port; default `24545` |

No network flag means **host** — running the main scene directly starts a local
session, so a peer launched without one is never idle.

```bash
"$GODOT_BIN" --headless --path . -- --host           > /tmp/host.log 2>&1 &
"$GODOT_BIN" --headless --path . -- --join=127.0.0.1 > /tmp/client.log 2>&1 &
```

Then read the logs, and kill the processes when done:

```bash
grep -nE 'REJECT|force_state|strikes|ERROR|WARNING' /tmp/host.log /tmp/client.log
```

### Which log holds which signal

Roles are split across processes, so the evidence is too. The correction path
only runs on the peer *being* corrected:

- **Client log** — its own player is the `OWNER`. `force_state` lines mean a
  server correction landed and yanked this client. A healthy client shows none.
- **Host log** — its own player is an `OWNER`; every other peer's player is a
  `SERVER_RECORD` it validates. Validator `REJECT`/`strikes` lines live here.

So "the server rejected a claim" is host-side evidence and "the client got
tugged backward" is client-side. Watch both.

### What headless cannot show

Anything visual. Physics-interpolation jitter on observer bodies and the camera
rig is a rendering artifact and is invisible here — that is a tier 3b question.
Conversely, if the logs show the server rejecting legitimate movement, that is
validator logic (`systems/components/movement_validator_component/`) and no
amount of looking at the game will show it.

---

## Tier 3b — godot-mcp

An exploratory instrument, not a test harness: it needs the editor open, it is
not reproducible, and it does not run in CI. Use it for what logs cannot show.

**Never drive the game in real time and screenshot it.** The game races ahead
between tool calls and every frame costs vision tokens. Own the clock instead:

1. `godot_editor_edit` `run` with `frozen=true` — the clock is frozen from
   frame 0, so no time passes before your first input.
2. `godot_game_time` `freeze` — observe at leisure; nothing moves.
3. `godot_runtime_state` `digest` — structured JSON (positions, velocities,
   custom properties). **This, not a screenshot, is the default observation.**
4. `godot_game_time` `step` (`duration_ms` or `frames`, with `inputs` riding
   inside the window) or `step_until` (`until`, plus `report` to read state in
   the same round-trip).
5. Repeat 3–4. `thaw` when done.

Screenshots are for judging *appearance* — jitter, framing, a wrong-looking
material. Take them in a sub-agent so they do not accumulate in the main
context.

`godot_exec` sets up a scenario directly (spawn an entity, force a state)
instead of playing through the setup by hand.

### Making a component observable

`godot_runtime_state digest` reports what nodes expose through `_mcp_state()`.
A component with none is invisible to the digest and has to be inspected
property by property. Add one where the tuning-relevant state lives — it must
be **cheap and side-effect-free**, since it is called every sample:

```gdscript
## Structured state for the MCP runtime digest. Cheap, no side effects.
func _mcp_state() -> Dictionary:
	return {"speed": _horizontal_speed(), "grounded": is_grounded(), "simulates": simulates}
```

### Version lock

The addon in `addons/godot_mcp/` and the npm server pinned in `.mcp.json` are
released together and **must match** (both `4.1.0` as of 2026-08-08). The MCP
status panel warns when they differ. Bumping is two edits, in this order:

```bash
npx -y @satelliteoflove/godot-mcp@<version> --install-addon .   # addon half
# then update the pin in .mcp.json to the same <version>
```

Restart the Godot editor afterwards, then restart Claude Code to reconnect.

### `MCPGameBridge` does not interfere with headless runs

The `MCPGameBridge` autoload ships in every build, so it is reasonable to worry
it fights the editor for the single bridge slot during a headless run. It does
not: `addons/godot_mcp/game_bridge/mcp_game_bridge.gd:44` returns early unless
`EngineDebugger.is_active()`, which a plain `--headless` launch never sets.

Verified 2026-08-08 — a headless peer run with the editor open and its bridge
active logged no bridge line at all, and the editor kept its listener on `6550`.
There is no need to comment the autoload out.

## Verify

- Tiers 1–2: `./hack/run-changed-tests.sh` exits `0`.
- Tier 3a: both peer processes stay up and the client's log shows no connection
  error. **Note:** on `main` a healthy headless peer prints almost nothing — the
  `[OWNER]` / `[SERVER_RECORD]` / `force_state` lines are debug instrumentation
  that currently lives only on `feat/network-interpolation`. Until that lands,
  tier 3a proves peers connect, not that the correction loop is right; add a
  `print` where you need the signal.
- Tier 3b: the MCP status panel in the editor shows connected, with addon and
  server versions equal.

## Roll back

- MCP misbehaving: disable **Godot MCP** in Project Settings > Plugins. Tiers
  1–3a are unaffected — they never touch the addon.
- Server/addon mismatch after a bump: re-run `--install-addon` with `--force`
  at the older version and restore the `.mcp.json` pin to match.
