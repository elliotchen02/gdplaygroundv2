# systems/

Portable, game-agnostic building blocks. See `README.md` here and
`components/README.md` for the full narrative and the component catalog.

## Portability contract (YOU MUST NOT break this)

`systems/` must lift into another Godot project **unchanged**. Nothing here may:

- reference `src/`, `ui/`, `sandbox/`, `assets/`, or `hack/`;
- hardcode an input action name, collision layer/mask, group name, or autoload.

Anything the game must configure arrives via `@export` or a method call. If a
piece of code needs game-specific knowledge, it belongs in `src/`.

## What a component is

- **Extends the Godot node it needs to be** (`Area3D`, `RayCast3D`, `Node3D`,
  plain `Node`). No base classes between it and the engine node — Godot has
  single inheritance, so the component *is* the node.
- **One responsibility**, fundamental enough to reuse across unrelated objects.
- A **script** by default. Add a `.tscn` only when the component bundles a
  multi-node assembly that would otherwise be rebuilt by hand at each use site
  (e.g. an `Area3D` needing a `CollisionShape3D`). State why in the header.
- One folder per component: `components/<name>_component/<name>_component.gd`.

## Adding a component

1. Copy `components/template_component/` — canonical anatomy, **not** a base
   class; nothing inherits from it.
2. Rename the folder, the `.gd` file, and the `class_name` together.
3. State the single responsibility in the header `##` docstring.
4. `extends` the node the component needs to be.
5. Group exports into `@export_group("Wiring")` and `@export_group("Tuning")`.
6. Name signals in past tense; pass the minimum payload.
7. Delete placeholder behaviour and anything unused — warnings are fatal.
8. Write the component's `README.md`, add a colocated `_test.gd`, and add it to
   the catalog in `components/README.md`. All three are required.

## Gotchas

- **`@tool` is not inherited.** Every component wanting
  `_get_configuration_warnings()` declares its own, and guards runtime-only work
  with `if Engine.is_editor_hint(): return`.
- **Runtime toggles name no networking concept.** `reads_input`, `simulates`,
  and `activates_on_ready` are deliberately neutral so the game can clear them
  on copies it does not own. Naming them after multiplayer would breach the
  portability contract.
- **Prefer pure arithmetic over scene-dependent logic.** It is what lets
  `movement_validator_component` unit-test without a `MultiplayerAPI` or a
  scene. Keep new components testable the same way.
