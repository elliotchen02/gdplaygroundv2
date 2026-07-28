# ui/

The game's UI: menus, HUD, and other `Control`-based screens.

## Dependencies

May depend on `systems/` and `src/`. Must **not** depend on `sandbox/`.

Prefer listening to signals from gameplay code over reaching into it; the UI observes, it does not drive game logic.
