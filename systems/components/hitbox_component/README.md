# hitbox_component

An `Area3D` that detects the hurtboxes its volume overlaps and reports each once. The deal side of the hitbox↔hurtbox pair; `hurtbox_component` is the receive side.

## Responsibility

Turn area overlaps into a clean "I struck this hurtbox" signal, filtered so a hit lands once per target and never on the attacker's own body. It decides *what* was struck, not *what that means* — damage, knockback, and the rest are the game's to attach to `hit_detected`.

## Wiring

`ignored_actor: Node` — the attacker, whose own hurtboxes this hitbox skips. Leave empty to hit everything.

The game supplies the `CollisionShape3D` (an attack's reach is its own) and masks this Area3D onto the hurtbox layer. The component names no layer, so it stays portable.

## API

- `hit_detected(hurtbox: HurtboxComponent)` — a fresh hurtbox entered the volume.
- `clear()` — forget every hurtbox struck, so re-activating the hitbox (the next swing) can register them again.

Dedup lives here because `area_entered` fires once per overlap; `clear()` is the seam an attack's lifecycle calls between activations to allow a repeat strike.
