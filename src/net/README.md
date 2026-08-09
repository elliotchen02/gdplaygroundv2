# net

Session-level multiplayer glue for the game. Game-specific, so it lives in `src/`; the reusable, game-agnostic parts live in `systems/components/` (`movement_validator_component`, `snapshot_buffer_component`).

## The model: client-simulated, server-validated

Each client simulates its own player exactly as it would in single player — zero input latency, no prediction machinery. It reports the *resulting* transform; the server never simulates a player and never sees an input. It only checks that each reported position was physically reachable, and corrects the rare cases that were not. Other clients see the server's accepted state, so a rejected motion never reaches them.

- Clients are not trusted: speedhacks, teleports, and flight are caught by arithmetic on the server (`MovementValidatorComponent`).
- The server stays cheap: a few float comparisons per player per tick, no `move_and_slide()`, no input evaluation.
- Upgrading later to full client-side prediction means adding input replication and server simulation on top of this same node topology — nothing here is thrown away.

**Validation is currently parked** while the transport is proven; see `src/player/README.md` for what that means and how to switch it back on.

## `net_session.gd` (`NetSession`)

Owns only the session lifecycle: `host(port)`, `join(address, port)`, `leave()`, and the `session_started` / `session_ended` signals. No keybinds and no UI, so a future `ui/` menu drives the exact same methods. On `_ready` it reads the command line (deferred, so listeners connect first) and starts a session from `--host`, `--join=<ip>`, and optional `--port=<n>` (defaulting to hosting if no network flag is passed so a bare F5 launch works). This pairs with the editor's *Debug > Customize Run Instances* per-instance arguments — a two-peer launch is one click.

## Spawning (`src/main.gd`, `src/main.tscn`)

`Main` connects `NetSession`'s signals plus `multiplayer.peer_connected` / `peer_disconnected`, and owns spawning because it holds the scene refs. `peer_connected` never fires for peer 1, so the host spawns its own player on `session_started`.

Spawning goes through a **custom `MultiplayerSpawner.spawn_function`**. The server calls `spawn({"id", "position"})`; `_build_player` runs on every peer — the server directly, each client when the packet arrives — and sets the node name, the spawn position, and `PlayerNetwork.owner_id` before the node enters the tree.

Both facts travel in the spawn packet deliberately:

- **Placement**, because a synchronizer's `spawn = true` state is subject to visibility, and visibility cannot be trusted to deliver to one peer and withhold from another (see `src/player/README.md`).
- **Ownership**, because deriving it from the node name is lossy: a `player.tscn` loaded from disk is named `"Player"`, which `to_int()` reads as peer 0, and the copy then silently resolves to `SERVER_RECORD` and never moves. The name still mirrors the peer id, because replication addresses nodes by path — but it is no longer the source of truth.

## Send rates

`ClaimSynchronizer` reports at 30 Hz, `StateSynchronizer` broadcasts at 20 Hz (`replication_interval` in `player_network.tscn`). The default of `0.0` means *every network process frame* — an idle frame, and `max_fps` is unset, so that is as fast as the machine will go. Observers absorb the gap with `SnapshotBufferComponent`; sending faster does not make them smoother, because what makes a remote player smooth is the receive-side buffer, not the packet rate.

## Load-bearing rules

1. **The server's accepted state never lands on a transform directly.** It travels in `PlayerNetwork.net_*` and each role chooses whether to apply it. A visibility filter is not a substitute — see `src/player/README.md` for the measurement.
2. **Authority is derived identically on every peer** from `owner_id`, delivered in the spawn data, because `set_multiplayer_authority` is not replicated. It is pinned in `_enter_tree`, never `_ready`, or the spawner rejects a synchronizer for having no network ID. Every call is non-recursive: the two synchronizers need opposite authorities, and a recursive set on any ancestor flattens them.
3. **Claims land in mirror properties** (`claimed_*`), never the real transform, so a claim can never bypass validation by overwriting the server's record.
4. **Remote copies do not collide.** Their transform is written from the network each tick, which makes them teleporting colliders; `player.gd` disables the collider on every copy this peer does not drive.

## Verification

`./hack/run-headless.sh 2 --auto-move --duration 12`, then read `hack/logs/`. A healthy two-peer run prints, on **both** peers, one `[spawn]` line per player at its own marker:

```
[net] hosting on port 24545
[spawn] peer=1 owner=1 at (0, 0.1, 0)
[spawn] peer=1 owner=<client> at (3, 0.1, 0)
```

Both players appearing on both peers is what proves spawning and replication; that used to be indistinguishable from silence.

The harness wraps one engine invocation per peer, which is still the direct route:

```bash
"$GODOT_BIN" --headless --path . -- --host
"$GODOT_BIN" --headless --path . -- --join=127.0.0.1
```

For the visual check, launch two instances via *Debug > Customize Run Instances*. Expect each window to drive only its own player, neither view hijacked by the other's camera, and remote players to move smoothly rather than stutter.
