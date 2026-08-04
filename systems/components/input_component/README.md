# input_component

Turns raw device input into movement intent, so no actor ever names an input action itself. It is the single device boundary: remapping, and later input-blocking (menus, cutscenes), happen in one place.

## Responsibility

Read the InputMap and expose intent. Nothing else. It does not move, rotate, or know what an actor is.

## Wiring

Six action names arrive via `@export` (`move_left/right/forward/back`, `jump`, `toggle_camera`) with conventional defaults. `_get_configuration_warnings()` checks each against `InputMap.has_action()`, so a typo or a missing project action shows in the Scene dock instead of as silent no-input.

## API

- `get_move_axis() -> Vector2` — pulled each frame. X strafes (+ right), Y is forward/back (- forward, matching Godot's -Z).
- `consume_look_delta() -> Vector2` — accumulated mouse motion since the last call, drained on read. Call exactly once per frame.
- `jump_requested`, `camera_toggle_requested` — edge-triggered signals emitted from `_unhandled_input`, so a press is never double-read or dropped when tick rate and frame rate disagree.

Continuous state is pulled; discrete events are pushed. Gamepad look would be added here as another source feeding `consume_look_delta()`, with no change to consumers.

## Runtime

`reads_input` (default true) gates `_unhandled_input` via its setter. A neutral flag naming no networking concept: the game clears it on player copies it does not own so a remote player never reads this machine's keyboard or mouse.
