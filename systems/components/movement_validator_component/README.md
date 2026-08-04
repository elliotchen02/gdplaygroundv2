# movement_validator_component

Judges whether a position a client claims to have reached was physically possible, and returns the position the server is willing to accept.

## Responsibility

Server-side reachability arithmetic, and nothing else. It reads no input, runs no physics query, and holds **no multiplayer references at all** — which is what keeps it inside the `systems/` dependency rule and makes it unit-testable without a `MultiplayerAPI` or a scene. The game (`PlayerNetwork`) feeds it claims and acts on its verdict.

## API

- `anchor(position)` — anchors validation at a known-good position, clearing budget and strikes. Call when the record is created and after forcing a correction.
- `submit(claimed, delta) -> Vector3` — returns the accepted position: the claim when plausible, the last accepted position when not.
- `accepted_position() -> Vector3`.
- `claim_rejected(claimed, corrected)` — fires once consecutive rejections reach `strikes_before_correction`, so a single network hitch never yanks a legitimate player.

## Tuning

`max_speed` (horizontal, mirror `MovementComponent`), `speed_tolerance`, `budget_ceiling`, `max_step_distance`, `max_fall_speed`, `max_rise_speed`, `min_y` / `max_y`, `strikes_before_correction`.

## Why an error budget, not a per-packet clamp

Per-packet clamping rejects legitimate players on every network hitch or frame spike, because packets bunch up and one tick's displacement genuinely exceeds `max_speed * delta`. Instead the budget accrues each tick and is spent by movement:

```gdscript
_budget = minf(_budget + max_speed * delta * speed_tolerance, budget_ceiling)
if moved <= _budget and moved <= max_step_distance and ...:
	_budget -= moved
```

This tolerates bursts while capping *sustained* speed — which is what a speedhack needs. `budget_ceiling` stops a long idle from banking a teleport; `max_step_distance` rejects a single huge jump regardless of budget. Because the budget accrues from the server's own `delta`, a cheater cannot inflate its allowance by lying about time.

Vertical is validated separately from horizontal: `max_speed` is horizontal only, while a fall easily exceeds it, so folding the two together would reject every jump and drop.

## Not yet

Geometry path validation (a shapecast from accepted to claimed, to catch noclip through walls) is deliberately deferred — it is a spatial query, and one per player per physics tick violates the project's performance rule. Add it later at a low rate or gated on a displacement threshold. This component stops absurd cheating, not centimetre-scale advantage.
