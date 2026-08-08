# Runtime testing

**Preconditions.** `GODOT_BIN`, or Godot at the default macOS path. Tier 3b also
needs the editor open with the **Godot MCP** plugin enabled, and Node.js 20+.

## Which tier

| Question | Tier | Editor? | CI? |
| --- | --- | --- | --- |
| Does this component's logic hold? | 1 — gdUnit4 suite | no | yes |
| Does this **scene** behave when driven by real input actions? | 2 — gdUnit4 scene runner | no | yes |
| Does the client/server claim-and-correct loop hold across peers? | 3a — headless engine run | no | not yet |
| Does it *look* right — jitter, camera, framing? | 3b — godot-mcp | yes | no |

**If you would want to run the check again next week, it is a gdUnit4 test.**
Answering a tier 1 or 2 question with godot-mcp produces an observation nobody
can reproduce.

---

## Tier 1 & 2 — gdUnit4

```bash
./hack/run-changed-tests.sh                                  # tests for changed .gd files
./addons/gdUnit4/runtest.sh -a res://path/to/suite_test.gd    # one suite
```

**Tier 1** builds the nodes under test by hand and steps
`get_tree().physics_frame` — see
`systems/components/movement_component/movement_component_test.gd`.

**Tier 2** loads an actual `.tscn` and drives it through the **InputMap**, so the
wiring in the scene file is under test alongside the scripts. Full API in
`addons/gdUnit4/src/GdUnitSceneRunner.gd`:

```gdscript
var runner := scene_runner(player)          # a path or an instantiated Node
runner.simulate_action_pressed(&"move_forward")
runner.simulate_frames(60)                  # or set_time_factor(4) to fast-forward
assert_float(runner.get_property("velocity").length()).is_greater(0.0)
```

### Two traps

**Authority comes from the node name.** `PlayerNetwork._enter_tree()` reads
`_player.name.to_int()`, so a scene loaded straight from disk is named `Player`,
yields `0`, matches no peer, and resolves to `SERVER_RECORD` — which switches
`movement_component.simulates` and `input_component.reads_input` off. Assertions
then run against a body that was never going to move, with nothing printed. Name
the instance after the owning peer, as `src/main.gd:_spawn_player` does, and
assert the role took; `src/player/player_test.gd` does both.

**`scene_runner()` only frees a scene it loaded from a path.** Handed a Node it
leaves ownership with the caller — `auto_free()` it, or every test leaks the
subtree as orphans.

`player.tscn` carries no floor. Add a `StaticBody3D` to the suite; it shares the
default `World3D`, so the runner's scene collides with it.

---

## Tier 3a — headless multiplayer

For anything involving two peers. godot-mcp **cannot** do this: it drives a
single game instance and the bridge enforces one client at a time.

Peers are plain OS processes — no wrapper script, just the engine once per peer.
The CLI flags are documented at `src/net/README.md`.

```bash
"$GODOT_BIN" --headless --path . -- --host           > /tmp/host.log 2>&1 &
"$GODOT_BIN" --headless --path . -- --join=127.0.0.1 > /tmp/client.log 2>&1 &
grep -nE 'REJECT|force_state|strikes|ERROR|WARNING' /tmp/host.log /tmp/client.log
kill %1 %2
```

### Which log holds which signal

The correction path only runs on the peer *being* corrected, so the evidence is
split across processes:

- **Client log** — its own player is the `OWNER`. `force_state` means a server
  correction landed and yanked this client. A healthy client shows none.
- **Host log** — every other peer's player is a `SERVER_RECORD` it validates.
  Validator `REJECT`/`strikes` lines live here.

### What headless cannot show

Anything visual — that is a tier 3b question. Conversely, logs showing the
server reject legitimate movement are validator logic
(`systems/components/movement_validator_component/`), and looking at the game
will never reveal it.

Before writing smoothing code for observer jitter, check the setting:
`physics/common/physics_interpolation` is unset and defaults to `false`.
Observers are written from the network at physics rate, so with interpolation
off they stutter at any framerate above the tick.

---

## Tier 3b — godot-mcp

**Never drive the game in real time and screenshot it.** The game races ahead
between tool calls and every frame costs vision tokens. Own the clock:

1. `godot_editor_edit` `run` with `frozen=true` — clock frozen from frame 0.
2. `godot_game_time` `freeze` — observe at leisure.
3. `godot_runtime_state` `digest` — structured JSON. **This, not a screenshot,
   is the default observation.**
4. `godot_game_time` `step` (`duration_ms`/`frames`, `inputs` riding inside the
   window) or `step_until` (`until`, plus `report` to read state in the same
   round-trip).
5. Repeat 3–4, then `thaw`.

Screenshots judge *appearance* only; take them in a sub-agent so they do not
accumulate in the main context. `godot_exec` sets up a scenario directly instead
of playing through it.

### Making a component observable

`digest` reports what nodes expose through `_mcp_state()`. A component without
one is invisible to it. Keep the method **cheap and side-effect-free** — it is
called every sample:

```gdscript
## Structured state for the MCP runtime digest. Cheap, no side effects.
func _mcp_state() -> Dictionary:
	return {"speed": _horizontal_speed(), "grounded": is_grounded(), "simulates": simulates}
```

### Version lock

The addon in `addons/godot_mcp/` and the server pinned in `.mcp.json` are
released together and **must match**; the MCP status panel warns when they
differ. Bump the addon first, then the pin:

```bash
npx -y @satelliteoflove/godot-mcp@<version> --install-addon .
```

Restart the editor, then Claude Code.

`.mcp.json` is project-scoped: Claude Code only discovers it when the session
root is the repo itself, not a parent directory.

`MCPGameBridge` does **not** contend with the editor during headless runs — it
gates on `EngineDebugger.is_active()`, which `--headless` never sets (verified
2026-08-08). There is no need to comment the autoload out.

## Verify

- Tiers 1–2: `./hack/run-changed-tests.sh` exits `0`.
- Tier 3a: both peers stay up, client log shows no connection error. On `main` a
  healthy peer prints almost nothing — the `[OWNER]`/`[SERVER_RECORD]` lines are
  instrumentation from `feat/network-interpolation`. Until it lands, tier 3a
  proves peers connect, not that the correction loop is right.
- Tier 3b: the MCP status panel shows connected, versions equal.

## Roll back

- MCP misbehaving: disable **Godot MCP** in Project Settings > Plugins. Tiers
  1–3a never touch the addon.
- Version mismatch after a bump: re-run `--install-addon --force` at the older
  version and restore the `.mcp.json` pin.
