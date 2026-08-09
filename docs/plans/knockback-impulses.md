# knockback / impulses

Applying external impulses — knockback — to a player: from weapons, explosions,
other players, and the environment. Written before implementation; a living
document until it lands.

## Goal

Any number of sources can launch a player in a direction, and the result is
consistent for every peer.

- A hit applied to player X moves X believably (an arc that decays and slides off
  walls, not a teleport) on **every** peer's screen.
- Cross-player hits are **server-arbitrated**: a client cannot launch another
  player, or itself, by fabricating a message.
- Adding a new impulse source (a new weapon, a trap) requires **no new network
  code** — it funnels through the one seam that already exists.

**How we know it works:** a gdUnit4 suite proves `apply_impulse` adds to velocity
and plays out through the existing `move_and_slide()`; a two-peer headless run
(`hack/run-headless.sh`) shows a scripted hit launching the target on both peers,
with the target's *owner* driving the motion.

## Constraints (from `CLAUDE.md` and the engine)

- **`systems/` depends on nothing game-specific** (no input names, no collision
  layers, no groups, no autoloads). The reusable mechanism goes there; the
  game-specific wiring goes in `src/`.
- **Signals up (past tense), method calls down.** Sibling components never
  reference each other — the actor (`player.gd`) wires them, exactly as at
  `player.gd:52-53`.
- **The server's accepted state never lands on a transform directly** — load-bearing
  rule 1 in `src/net/README.md`. An impulse is not accepted state; it is an input
  *to the owner's simulation*, and the resulting transform still travels the
  normal `claimed_*` → validate → `net_*` path.
- **A `CharacterBody3D` is launched by setting `velocity`, then letting its own
  `move_and_slide()` carry it** — it takes no impulses/forces (that is
  `RigidBody3D`). Only the **owner** simulates (`movement_component.simulates =
  is_owner`), so an impulse only means anything on the owner's copy.

## Structure — the load-bearing decisions

This is the part to review. The whole design is three thin layers, each a
separate concern, wired by the actor.

### 1. `PlayerNetwork` is the template, not the container

Player-affecting RPCs do **not** all move into the `PlayerNetwork` class. That
class is deliberately *body-only* (`player_network.gd:6-7`) so its test drives it
with a bare `CharacterBody3D`; folding in an impulse RPC that reaches into
`MovementComponent` breaks that, mixes two responsibilities (state replication vs
combat events), and reintroduces the growth the network-scene split was built to
prevent (`src/player/README.md:13`).

Instead, each networking concern is its **own component**, copying the shape
`PlayerNetwork` demonstrates: owns its own `@rpc`, sets/relies on its own
authority, depends on as little as possible, testable in isolation. Discoverability
comes from **convention** (networking components grouped under the
`player_network.tscn` subtree) and from **one documented wire-contract table**,
not from one god class.

### 2. Three layers

```
source (weapon / explosion / player)  ──reports hit──▶  SERVER (arbiter, src/)
                                                            │ validates
                                                            ▼
                              ImpulseReceiverComponent.receive_impulse.rpc_id(owner_id, v)
                                                            ▼            (systems/, server-guarded)
                              signal impulse_received(v)  ──up──▶  player.gd
                                                            ▼            (calls down)
                              MovementComponent.apply_impulse(v)   → body.velocity += v
                                                            ▼            (systems/, pure)
                              owner simulates → claimed_* → validate → net_* → every peer
```

- **`MovementComponent.apply_impulse(v)`** — a *plain method*, not an RPC. Adds to
  `body.velocity`; knows nothing about who called it or about the network. Stays in
  `systems/`, stays unit-testable. Knockback is not a networking concept.
- **`ImpulseReceiverComponent`** — a *new* component that owns the one
  server-sanctioned `@rpc` and emits `impulse_received(v)` up. It is the **only**
  thing that turns a network message into an applied impulse. Every source in the
  game funnels through this single seam, so a new weapon adds zero network code.
- **`player.gd`** connects `impulse_receiver.impulse_received` →
  `movement_component.apply_impulse`. Siblings stay ignorant of each other; the
  actor orchestrates.

### 3. Server-sanctioned RPC — follow the `force_state` precedent

`receive_impulse` is a server-issued command, identical in shape to `force_state`
(`player_network.gd:216-228`). We copy that pattern exactly:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func receive_impulse(v: Vector3) -> void:
    if multiplayer.get_remote_sender_id() != server_peer_id:
        return
    impulse_received.emit(v)
```

We use `"any_peer"` + a manual sender guard rather than `@rpc("authority")`
**because** the player subtree's authority is the *owner*, not the server (see
`set_multiplayer_authority(owner_id)` at `player_network.gd:91`); an
`"authority"`-mode RPC there would let only the owner call it — the opposite of
what we need. `server_peer_id` is an `@export` (default `1`) so the component
carries no hardcoded assumption, honoring the `systems/` portability contract.

### 4. Two categories of impulse — only one round-trips the server

- **Contested / cross-player** (weapons, explosions, another player's shove): must
  go through the server arbiter above. The attacker's client is not trusted.
- **Self-inflicted & deterministic** (a jump pad you step on, a wind volume you
  walk into): the owner meets it on its *own* simulation, like touching the
  ground. It calls `apply_impulse` **locally** — no RPC, no round-trip — and the
  result replicates out through the normal claim pipeline anyway. Round-tripping
  these would add latency for no safety gain.

### What `MovementComponent` owns (and does not)

`MovementComponent` owns **owner-simulated translation only** — velocity, gravity,
`move_and_slide()`. It does *not* own rotation (that is `LookComponent`), remote
copies' transforms (written from the network in `PlayerNetwork`), or spawn
placement (`main.gd`). An impulse belongs in `MovementComponent` because it is a
velocity change that plays out as simulated translation — nothing else about the
transform routes through it.

## Rejected alternatives

- **Every source calls an RPC directly on the target's `MovementComponent`.**
  Sprays the wire contract and the anti-cheat surface across every weapon and
  trap; forces gameplay code to reach into another actor's subtree (violates the
  `@export`/`%UniqueNode` wiring rule); makes `MovementComponent` a networking
  node, breaking its `systems/` portability.
- **Put `receive_impulse` in `PlayerNetwork`.** Breaks the body-only property (§1).
- **Push the target's remote copy locally on the attacker's machine.** The copy is
  a transform echo; the owner overwrites it next tick and it snaps back. Impulses
  must land on the owner's simulation.
- **Model the player as `RigidBody3D` so impulses "just work."** Discards the
  client-simulated / server-validated model the whole project is built on; loses
  the deterministic single-player-style movement clients rely on.

## Work breakdown

**`systems/` (reusable mechanism), first:**

1. `MovementComponent.apply_impulse(v: Vector3)` — add the method (`body.velocity
   += v`) and a colocated test proving it accumulates and decays through
   `_physics_process`. Docstring: single responsibility, no network mention.
2. `systems/components/impulse_receiver_component/` — copy `template_component/`.
   Owns `receive_impulse` (server-guarded, per §3), `@export var server_peer_id
   := 1`, signal `impulse_received(v: Vector3)`. Add `README.md`, colocated
   `_test.gd` (assert non-server sender is dropped, server sender emits), and the
   catalog entry in `components/README.md` — all three required.

**`src/` (game composition), after:**

3. Add `ImpulseReceiverComponent` to the player, grouped under the
   `player_network.tscn` subtree; in `player.gd._ready`, connect
   `impulse_received` → `movement_component.apply_impulse` (only the owner
   simulates, and the RPC targets the owner, so the wiring is uniform).
4. Prove the local path first with a **self-inflicted deterministic** source (a
   jump pad `Area3D` in `src/`) calling `apply_impulse` on the owner directly — no
   networking — to validate end-to-end motion and replication.
5. Add the **server arbiter** path: a source reports a hit to the server; the
   server validates and calls `receive_impulse.rpc_id(owner_id, v)`. Keep the
   arbiter in `src/` (game-specific). Source-side hit *detection* (weapon/explosion
   areas) is game-specific and also lives in `src/`.
6. Document the wire contract: add `receive_impulse` (and its authority
   mode/reliability) to a single table in `src/net/README.md`, alongside
   `force_state` and the replicated `claimed_*`/`net_*` block — the "one place"
   for the network surface.

## Open questions

- **Validator interaction.** `MovementValidatorComponent` is parked
  (`src/player/README.md:62-68`); while off, a knockback just works. When it
  returns, a server-sanctioned impulse must be *expected* by the validator, not
  flagged as an illegal velocity spike — the `force_state` seam is the intended
  hook. Decide whether the server records "I just launched X by v" so the next
  claim is judged against it.
- **Host-owned player self-delivery.** When the launched player's owner *is* the
  server (listen-server host getting hit), `receive_impulse.rpc_id(1, v)` targets
  the server's own peer. Verify this executes locally with `"call_remote"`, or
  branch to a direct local call when `owner_id == local_id`. `force_state` has the
  identical shape and the identical question — resolve both together.
- **Collision dependency.** RESOLVED as groundwork for this feature: players are
  now solid to one another (collider kept on every copy; named `world`/`players`
  collision layers), and the `HitboxComponent`/`HurtboxComponent` pair now exists
  as the deal/receive seam (`systems/components/`). What remains deferred is the
  wiring in §2 — `apply_impulse`, `receive_impulse`, and the server arbiter that
  turns a `hit_detected` into a launch.
- **Naming.** This component *receives* impulses (a "hurtbox" role); a source-side
  *hitbox* that deals them is a separate component. Keep the two names distinct to
  avoid conflating deal-side and receive-side.
