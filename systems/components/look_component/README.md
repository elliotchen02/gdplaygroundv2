# look_component

Applies a look delta as yaw on one node and clamped pitch on another. It never reads a device — the host feeds it deltas.

## Responsibility

Turn a pixel delta into rotation. Keeping device reading out of it means gamepad look, replays, or scripted camera moves all drive the same code, and the component is trivially unit-testable.

## Wiring

`yaw_node: Node3D` (defaults to the parent) and `pitch_node: Node3D` (defaults to `yaw_node`). The split exists so a first-person actor can yaw its whole body while pitching only the camera pivot — which is what makes movement camera-relative for free.

## Tuning

`sensitivity` (radians per pixel), `max_pitch_degrees` (the up/down clamp), and `inverts_pitch`.

## API

- `look(delta: Vector2)` — X yaws, Y pitches.

Yaw and pitch are tracked as float accumulators and assigned to `rotation`, rather than applied incrementally with `rotate_y()`. Clamping an accumulator is exact; clamping an incrementally-rotated basis drifts and can flip past vertical.
