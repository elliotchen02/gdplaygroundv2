# net

Session-level multiplayer glue for the game. Game-specific, so it lives in `src/`; the reusable, game-agnostic validation lives in `systems/components/movement_validator_component/`.

## The model: client-simulated, server-validated

Each client simulates its own player exactly as it would in single player — zero input latency, no prediction machinery. It reports the *resulting* transform; the server never simulates a player and never sees an input. It only checks that each reported position was physically reachable, and corrects the rare cases that were not. Other clients see the server's accepted state, so a rejected motion never reaches them.

- Clients are not trusted: speedhacks, teleports, and flight are caught by arithmetic on the server (`MovementValidatorComponent`).
- The server stays cheap: a few float comparisons per player per tick, no `move_and_slide()`, no input evaluation.
- Upgrading later to full client-side prediction means adding input replication and server simulation on top of this same node topology — nothing here is thrown away.

## `net_session.gd` (`NetSession`)

Owns only the session lifecycle: `host(port)`, `join(address, port)`, `leave()`, and the `session_started` / `session_ended` signals. No keybinds and no UI, so a future `ui/` menu drives the exact same methods. On `_ready` it reads the command line (deferred, so listeners connect first) and starts a session from `--host`, `--join=<ip>`, and optional `--port=<n>` (defaulting to hosting if no network flag is passed so a bare F5 launch works). This pairs with the editor's *Debug > Customize Run Instances* per-instance arguments — a two-peer launch is one click.

## Spawning (`src/main.gd`, `src/main.tscn`)

`Main` connects `NetSession`'s signals plus `multiplayer.peer_connected` / `peer_disconnected`, and owns spawning because it holds the scene refs. The server spawns a player named `str(peer_id)` per connection at a round-robin `SpawnPoints` marker, under the `Players` container that the `MultiplayerSpawner` replicates. `peer_connected` never fires for peer 1, so the host spawns its own player on `session_started`. Despawn frees the node on the server. A headless server skips mouse capture.

## Load-bearing rules

1. **The owner is excluded from `StateSynchronizer`.** If the server's accepted state reached the peer that owns the player, it would overwrite that peer's local simulation every tick and rubber-band it. The owner receives its initial spawn placement and then only explicit `force_state` corrections.
2. **Authority is derived identically on every peer** from the spawned node's name (`PlayerNetwork._enter_tree`), because `set_multiplayer_authority` is not replicated. Synchronizer authority is pinned in `_enter_tree` (before the synchronizers enter the tree), never in `_ready`, or the spawner rejects them for having no network ID.
3. **Claims land in mirror properties** (`PlayerNetwork.claimed_*`), never the real transform, so a claim can never bypass validation by overwriting the server's authoritative record.

## Verification

Launch two instances via *Debug > Customize Run Instances* with `--host` and `--join=127.0.0.1`, or headless:

```
godot --headless -- --host
godot --headless -- --join=127.0.0.1
```

Expect two players; each window drives only its own; neither view is hijacked by the other's camera; the host sees both move. A deliberate teleport on a client (setting its own `global_position` far away) is rejected by the server, never seen by the other peer, and snapped back on the offender with visual smoothing.
