class_name HitboxComponent
extends Area3D

## Detects the hurtboxes its volume overlaps and reports each one once, so an
## attack learns what it struck. The deal side of the hitbox/hurtbox pair.
##
## Names no layer and carries no shape: the game masks this Area3D onto the
## hurtbox layer and supplies the CollisionShape3D, since an attack's reach is
## its own to define. It decides *what* was struck, never what a hit means —
## damage and knockback are the game's to attach to `hit_detected`.

## A fresh hurtbox entered this volume. Carries the hurtbox so the listener can
## read whose body it belongs to.
signal hit_detected(hurtbox: HurtboxComponent)

@export_group("Wiring")
## Actor whose hurtboxes this hitbox skips — the attacker, so a swing never hits
## its own owner. Leave empty to hit every hurtbox.
@export var ignored_actor: Node

var _struck: Array[HurtboxComponent] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area3D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox == null or hurtbox in _struck:
		return
	if ignored_actor != null and hurtbox.actor == ignored_actor:
		return
	_struck.append(hurtbox)
	hit_detected.emit(hurtbox)


## Forgets every hurtbox already struck, so re-activating the hitbox — the next
## swing — can register them again. `area_entered` fires once per overlap, so an
## attack that lingers relies on this seam to strike again.
func clear() -> void:
	_struck.clear()
