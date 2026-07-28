# template_component

The canonical **shape** of a component. Not a base class — nothing inherits from it. Copy this folder when writing a new component and delete the placeholder charge behaviour; what should survive the copy is the structure.

## Anatomy

- **`@tool` + header docstring** — one sentence naming the single responsibility, then usage notes.
- **Signal** — past tense (`charge_completed`), passing the minimum a listener needs.
- **`@export_group("Wiring")`** — collaborators injected from the host (`actor`, other nodes).
- **`@export_group("Tuning")`** — inspector-editable knobs (`charge_duration`, `starts_charging`).
- **`actor` resolution** — defaults to `get_parent()` at runtime; overridable in the inspector.
- **Public API** — `start_charging()`, `is_charging()`: the host drives the component downward via calls.
- **Editor validation** — `_get_configuration_warnings()` flags mis-wiring in the Scene dock.

## Copy-and-rename checklist

1. Copy this folder; rename the folder, the `.gd` file, and the `class_name` together.
2. State the single responsibility in the header docstring.
3. `extends` the Godot node the component needs to be (`Area3D`, `RayCast3D`, `Node`, ...).
4. Group `@export`s into Wiring and Tuning.
5. Name signals in past tense.
6. Delete the placeholder behaviour and anything unused — editor warnings are fatal.

## Notes on `@tool`

- `@tool` is required for `_get_configuration_warnings()` to run, and it is **not** inherited — every component that wants editor validation needs its own `@tool`.
- With `@tool`, guard runtime-only work with `if Engine.is_editor_hint(): return`, as `_ready()` does here.
- Call `update_configuration_warnings()` from a property setter (see `actor`) so the warning refreshes live instead of only on scene reload.
- The whole validation block is droppable for components with nothing to validate.
