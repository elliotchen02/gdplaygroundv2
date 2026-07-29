# player

The first-person player actor. Game-specific, so it lives in `src/` (it names input actions indirectly through `InputComponent` defaults and composes `systems/` components); the reusable parts are the components themselves.

## Composition

`player.tscn` is a `CharacterBody3D` assembled from four components plus a camera rig:

- `InputComponent`, `MovementComponent`, `LookComponent`, `CameraSwitchComponent`.
- `CameraPivot` (eye height) carrying a `FirstPersonCamera` and a `SpringArm3D` with a `ThirdPersonCamera`.

`player.gd` is the only node that knows all four exist. It reads the move axis, rotates it into world space with `global_basis`, and hands it to movement; feeds the look delta to look; and connects the request signals. Look runs in `_process` (smooth at display rate); movement runs in `_physics_process`.

## The third-person view

`toggle_camera` (V) cycles `CameraSwitchComponent` between first and third person. The spring arm sits under `CameraPivot`, so it inherits yaw and pitch for free — no follow code. `player.gd` excludes the body's own `RID` from the arm, without which the arm collides with the player's capsule and collapses to zero length. The third-person camera is a development aid for seeing the player; it is not load-bearing and can be removed once a real external-view need is defined.
