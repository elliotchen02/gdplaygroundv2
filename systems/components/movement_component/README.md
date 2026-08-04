# movement_component

Moves a `CharacterBody3D`: accelerates toward a requested direction, applies gravity, and jumps. It owns the body's single `move_and_slide()` call.

## Responsibility

Translate a world-space direction and a jump request into velocity and motion. It reads no input and knows nothing about cameras.

## Wiring

`body: CharacterBody3D`, defaulting to the parent. Naming the engine class is honest, not coupling: the component fundamentally needs `velocity`, `is_on_floor()`, and `move_and_slide()`. The rule against assuming the host's class is about game classes like `Player`.

## Tuning

`max_speed`, `acceleration`, `deceleration`, `air_control`, and `jump_height` (in metres — converted to launch velocity via `sqrt(2 * g * height)`, so designers tune height, not impulse). Gravity comes from `body.get_gravity()`, so gravity areas and project settings are respected without reading `ProjectSettings`.

## API

- `set_move_direction(direction: Vector3)` — flattened and normalised, so vector length cannot scale speed. A zero or purely vertical direction means "no input".
- `jump()` — latches a jump, honoured on the next physics tick if grounded. This latch is where jump buffering and coyote time go later.
- `is_grounded() -> bool`.
- `jumped`, `landed` — edge-detected floor-transition signals.

Godot ticks a parent before its children, so intent set in the host's `_physics_process` lands in the same tick.

## Runtime

`simulates` (default true) gates `_physics_process` via its setter. When false the component stops driving the body — no gravity, no `move_and_slide()` — so the body becomes a passive record whose transform is written from outside (e.g. an authoritative network state). A neutral flag naming no networking concept.
