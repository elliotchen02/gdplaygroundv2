# systems/

Portable, game-agnostic building blocks.

## Portability contract (hard rule)

`systems/` must lift into another Godot project **unchanged**. Therefore nothing here may:

- reference `src/`, `ui/`, `sandbox/`, or `assets/`;
- hardcode an input action name, collision layer/mask number, group name, or autoload singleton.

Anything the game must configure (input actions, layers, payloads) is supplied by the game via `@export` or method calls. If a piece of code needs game-specific knowledge, it does not belong here — it belongs in `src/`.

## Contents

- `components/` — attachable node components. See `components/README.md`.
