# systems/components/

Attachable node components — the fundamental building blocks actors are composed from.

## What qualifies as a component

- **Extends the Godot node it needs to be** (`Area3D`, `RayCast3D`, `Node3D`, `Node`). No base classes between it and the engine node.
- **One responsibility**, fundamental enough to reuse across unrelated objects.
- **Game-agnostic** — no assumptions about input actions, layers, groups, or autoloads (see `../README.md`).

## Script vs scene

- Default: a single `.gd` script. The host adds a node of the right type and attaches the script.
- Add a `.tscn` **only** when the component bundles a multi-node assembly you would otherwise rebuild by hand at each use site (e.g. an `Area3D` needing a `CollisionShape3D` child). State why in the file header.

## Layout

One folder per component: `<name>_component/<name>_component.gd` (+ `.tscn` when warranted).

## Adding one

Copy `template_component/`, follow its README checklist.

## Catalog

- `template_component/` — the canonical component anatomy to copy. Not used at runtime.
- `input_component/` — turns device input into movement intent (a move axis, look delta, and request signals) so actors never name an action themselves.
- `movement_component/` — moves a `CharacterBody3D`: acceleration, gravity, and jumping via a single `move_and_slide()`.
- `look_component/` — applies a look delta as yaw on one node and clamped pitch on another.
- `camera_switch_component/` — owns which of an ordered list of `Camera3D`s is the active one.
- `movement_validator_component/` — pure server-side arithmetic that decides whether a claimed position was physically reachable, and what to accept instead. Currently parked; see `src/player/player_network.gd`.
- `snapshot_buffer_component/` — keeps the last N states an actor was reported in, keyed by tick, and interpolates between them. Turns bursty network delivery into continuous motion.
- `hitbox_component/` — an `Area3D` that detects the hurtboxes it overlaps and reports each once (`hit_detected`). The deal side of the hitbox↔hurtbox pair.
- `hurtbox_component/` — an `Area3D` marking a hittable region and naming the actor a hit belongs to. The receive side of the pair.

## Runtime toggles

`input_component`, `movement_component`, and `camera_switch_component` each carry a neutral runtime flag (`reads_input`, `simulates`, `activates_on_ready`) in a "Runtime" group. They name no networking concept; the game clears them on player copies it does not own, so a remote player never reads this machine's input, fights the network with its own physics, or steals the viewport.

`look_component` serves the same purpose through a method rather than a flag: `set_pitch()` poses a head from something other than a device — a replay, a cutscene, or a remote player whose pitch arrived over the wire — and clamps it to the same limit `look()` obeys.
