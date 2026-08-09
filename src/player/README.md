# player

The first-person player actor. Game-specific, so it lives in `src/` (it names input actions indirectly through `InputComponent` defaults and composes `systems/` components); the reusable parts are the components themselves.

## Composition

`player.tscn` is a `CharacterBody3D` assembled from four components, a camera rig, and one instanced sub-scene:

- `InputComponent`, `MovementComponent`, `LookComponent`, `CameraSwitchComponent`.
- `CameraPivot` (eye height) carrying a `FirstPersonCamera` and a `SpringArm3D` with a `ThirdPersonCamera`.
- `PlayerNetwork` — `player_network.tscn`, holding everything networking needs.

Networking lives in its own scene so that adding to it does not add to this one. `player.tscn` stayed at eight children while gaining a snapshot buffer, tick counters and pitch replication.

`player.gd` is the only node that knows all of them exist. It reads the move axis, rotates it into world space with `global_basis`, and hands it to movement; feeds the look delta to look; and connects the request signals. Look runs in `_process` (display rate, owner only); movement runs in `_physics_process`.

## Multiplayer: `player_network.tscn` (`PlayerNetwork`)

```
PlayerNetwork  (player_network.gd)   ← body, owner_id
├── MovementValidatorComponent       (parked)
├── SnapshotBufferComponent          (observers only)
├── ClaimSynchronizer                owner → server, 30 Hz
└── StateSynchronizer                server → observers, 20 Hz
```

`PlayerNetwork` takes a `body` and an `owner_id` and touches nothing else in the actor. It reports a role; `player.gd` decides what that role means and gates its own components. That direction matters: were `PlayerNetwork` reaching into four sibling components to gate them, testing it would mean supplying all four. As it stands, `player_network_test.gd` drives the whole network stack against a bare `CharacterBody3D` — no cameras, no `InputMap`, no floor, no multiplayer peer.

Both are set by `Main`'s spawn function before the node enters the tree, from data the `MultiplayerSpawner` replicates, so every peer derives the same authority without replicating `set_multiplayer_authority`. Authority is pinned in `_enter_tree`, never `_ready`, or the spawner rejects a synchronizer for having no network ID.

| role | reads input | simulates | camera | collider | shows |
| --- | --- | --- | --- | --- | --- |
| owner (client or host) | yes | yes | yes | yes | its own simulation |
| server record (server, not owner) | no | no | no | no | the claim it received |
| observer (client, not owner) | no | no | no | no | a buffered, delayed sample |

The **owner** simulates locally with zero latency and mirrors its transform into `claimed_*` each tick. The **server record** takes that claim as accepted and republishes it as `net_*`; a listen-server host does the same for the player it owns itself, since nothing else is in a position to. **Observers** feed `net_*` into `SnapshotBufferComponent` and draw a sample taken a fixed delay behind the newest arrival.

### Why state travels in `net_*` and not on the transform

This is the load-bearing decision, and it was arrived at from a bug rather than a preference.

Replicating `.:position` directly meant the server broadcast accepted state to *every* peer, the owning one included, and it landed on the owner's body between physics ticks. The owner's own simulation was dragged back onto a lagged echo of its own claim on roughly half of all ticks — measured drift of exactly one tick's worth of movement, halving the client's speed while `velocity` still read a correct 10 m/s. The host, having no such echo, was perfectly smooth. That asymmetry is what "the client is jittery and the host isn't" actually was.

A visibility filter is *supposed* to prevent this and does not: two synchronizers sharing a `root_path` cannot hold divergent per-peer visibility, so excluding the owner from `StateSynchronizer` while the `ClaimSynchronizer` on the same node stays visible to it achieves nothing. Adding the missing `update_visibility()` call changed nothing either.

Mirror properties make it structural. State arrives on every peer; each role *chooses* what to apply, and the owner's branch never reads `net_*`. `test_owner_ignores_server_state_written_onto_it` pins that shut.

### Ordering

Two rules survive, and only one is a convention:

- The synchronizers are *inside* `player_network.tscn`, so a parent's `_enter_tree` necessarily precedes theirs. This can no longer be broken by dragging a node.
- The `PlayerNetwork` instance must sit *below* `MovementComponent` in `player.tscn`, so its per-tick claim mirror reads an already-moved body. Still a convention.

Replication is configured against property names — rename a `claimed_*` or `net_*` var and replication breaks silently. Keep the marked synced block in `player_network.gd` and the two `SceneReplicationConfig`s in `player_network.tscn` in step.

### Pitch

Pitch lives on `CameraPivot`, not the body, so the actor carries it both ways: the owner reports `look_component.pitch()` into `claimed_pitch`, and remote copies apply `player_network.observed_pitch()` back onto the pivot through `LookComponent.set_pitch()`. Keeping that in `player.gd` is what lets `PlayerNetwork` stay body-only.

### Validation is parked

`MovementValidatorComponent` is wired but not called: `_record_claim` takes each claim verbatim. It was switched off so a correction snap could never be mistaken for jitter while the transport was being fixed, and it stays off until the transport is proven. The component, its README and its seven tests are untouched and passing.

Re-enabling is two edits, both marked in `player_network.gd`: call `movement_validator.submit(claimed_position, delta)` in `_record_claim`, and connect `claim_rejected` to `_on_claim_rejected` in `_ready`. `force_state` is deliberately left in place, unused, so the RPC's position in the wire contract does not shift when it comes back. Two known defects to fix at the same time: the correction zeroes velocity unconditionally, and `movement_validator.anchor()` is never re-called afterwards even though its own docstring says it must be.

When it returns, `state_corrected` is the seam for presentation — it carries where the body was, so the actor can slide the mesh back rather than cutting. Nothing connects it today.

## The third-person view

`toggle_camera` (V) cycles `CameraSwitchComponent` between first and third person. The spring arm sits under `CameraPivot`, so it inherits yaw and pitch for free — no follow code. `player.gd` excludes the body's own `RID` from the arm, without which the arm collides with the player's capsule and collapses to zero length. The third-person camera is a development aid for seeing the player; it is not load-bearing and can be removed once a real external-view need is defined.
