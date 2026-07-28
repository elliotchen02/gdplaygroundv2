# src/

The actual game. Composes `systems/` building blocks and `assets/` into playable content.

- `main.tscn` — the launch scene (`run/main_scene` in `project.godot`).
- Actors, worlds, and the app shell live here. Group by feature.

## Dependencies

May depend on `systems/` and `assets/`. Must **not** depend on `sandbox/`.

Game-specific logic that is not reusable across projects belongs here, not in `systems/`.
