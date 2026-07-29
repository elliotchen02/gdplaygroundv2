# camera_switch_component

Owns which of an ordered list of `Camera3D`s is the active one. A viewport honours only one `current` camera, so activating one deactivates the rest on its own.

## Responsibility

Select the active camera. It owns no input and names no game class, which is what makes it a `systems/` component rather than a script bolted onto one actor.

## Wiring

`cameras: Array[Camera3D]` — an ordered list. Index 0 is activated on `_ready()`.

## API

- `activate(index: int)` — makes that camera current; out-of-range indices are ignored.
- `next()` — advances with `wrapi()`, wrapping around. This is what an input toggle calls.
- `active_camera() -> Camera3D`.
- `camera_activated(camera: Camera3D)` — past tense, minimum payload, for anything that reacts to the switch (a viewmodel hiding itself in third person, later).

Keeping an ordered list rather than a two-camera boolean means adding a shoulder or top-down view is a scene edit, not a code change.
