# src/

The game. Composes `systems/` and `assets/` into playable content. Game-specific
logic that is not reusable belongs here, never in `systems/`.

Read `net/README.md` and `player/README.md` before changing multiplayer code —
they carry the reasoning these rules compress.

## The network model

Client-simulated, server-validated. Each client simulates its own player exactly
as in single player (zero input latency, no prediction machinery) and reports the
*resulting* transform. The server never simulates a player and never sees an
input; it only checks that each reported position was reachable, and corrects
what was not. Other clients see the server's accepted state.

Each player copy resolves to one of three roles — owner, server record, observer
— in `player/player_network.gd`, which gates the components to match.

## Gotchas

- **Replication is configured against property names.** Renaming a `claimed_*`
  variable or moving `position` breaks replication **silently**. Keep the marked
  synced block in `player/player_network.gd` and the `SceneReplicationConfig`s in
  `player/player.tscn` in step.
- **Pin authority in `_enter_tree`, never `_ready`.** The spawner rejects a
  synchronizer that has no network ID yet. Authority is derived identically on
  every peer from the spawned node's name, because `set_multiplayer_authority`
  is not replicated.
- **The owner is excluded from `StateSynchronizer`** by a visibility filter. If
  the server's accepted state reached the owning peer it would overwrite that
  peer's local simulation every tick and rubber-band it. The owner gets its
  spawn placement, then only explicit `force_state` corrections.
- **Claims land in mirror properties** (`claimed_*`), never the real transform,
  so a claim can never bypass validation.
- **Node order in `player.tscn` is load-bearing.** `PlayerNetwork` sits *before*
  the synchronizers so its `_enter_tree` runs first, and *after*
  `MovementComponent` so its per-tick claim mirror reads an already-moved body.
