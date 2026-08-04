# player

The first-person player actor. Game-specific, so it lives in `src/` (it names input actions indirectly through `InputComponent` defaults and composes `systems/` components); the reusable parts are the components themselves.

## Composition

`player.tscn` is a `CharacterBody3D` assembled from four components plus a camera rig:

- `InputComponent`, `MovementComponent`, `LookComponent`, `CameraSwitchComponent`.
- `CameraPivot` (eye height) carrying a `FirstPersonCamera` and a `SpringArm3D` with a `ThirdPersonCamera`.

`player.gd` is the only node that knows all four exist. It reads the move axis, rotates it into world space with `global_basis`, and hands it to movement; feeds the look delta to look; and connects the request signals. Look runs in `_process` (smooth at display rate); movement runs in `_physics_process`.

## Multiplayer: `player_network.gd` (`PlayerNetwork`)

`PlayerNetwork` keeps `player.gd` the thin composition root it already is: it owns everything about the network. On `_enter_tree` it derives the player's authority from the node's name (the peer id the server spawned it under) — identical on every peer, since `set_multiplayer_authority` is not replicated — and pins the two synchronizers' authority there (never in `_ready`, or the spawner rejects a synchronizer for having no network ID). It sits *before* the synchronizers in the tree so its `_enter_tree` runs first, and *after* `MovementComponent` so its per-tick claim mirror reads an already-moved body.

It then resolves one of three roles and gates the components to match:

| role | reads input | simulates | camera | mirrors claims | validates |
| --- | --- | --- | --- | --- | --- |
| owner (client or host) | yes | yes | yes | yes | no |
| server record (server, not owner) | no | no | no | no | yes |
| observer (client, not owner) | no | no | no | no | no |

The **owner** simulates locally with zero latency and each physics tick mirrors its transform into `claimed_position` / `claimed_velocity` / `claimed_yaw`. The `ClaimSynchronizer` (authority = owner, visible only to peer 1) reports those to the server. The **server record** feeds each claim through `MovementValidatorComponent`, writes the accepted result into the real transform, and the `StateSynchronizer` (authority = 1, owner excluded by a visibility filter) broadcasts it to **observers**. A rejected motion never reaches other players; the offender is snapped back with a reliable `force_state` RPC and a decaying visual offset on the `Mesh` and `CameraPivot`.

Replication is configured in `player.tscn` against property names — rename a `claimed_*` var or move `position` and replication breaks silently. Keep the marked synced block in `player_network.gd` and the `SceneReplicationConfig`s in step.

## The third-person view

`toggle_camera` (V) cycles `CameraSwitchComponent` between first and third person. The spring arm sits under `CameraPivot`, so it inherits yaw and pitch for free — no follow code. `player.gd` excludes the body's own `RID` from the arm, without which the arm collides with the player's capsule and collapses to zero length. The third-person camera is a development aid for seeing the player; it is not load-bearing and can be removed once a real external-view need is defined.
