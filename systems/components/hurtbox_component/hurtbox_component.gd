@tool
class_name HurtboxComponent
extends Area3D

## Marks a region of an actor as hittable and names the actor a hit belongs to.
## The receive side of the hitbox/hurtbox pair.
##
## Passive: a HitboxComponent does the detecting and reads `actor` to learn whom
## it struck. Names no layer and carries no shape: the game puts this Area3D on
## the hurtbox layer and supplies the CollisionShape3D. Keeping the vulnerable
## region separate from the physical collider lets a body's capsule stay one
## simple shape for movement while its hurtbox is tuned independently.

@export_group("Wiring")
## Actor a hit on this box counts against. Leave empty to use the parent.
@export var actor: Node:
	set(value):
		actor = value
		update_configuration_warnings()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if actor == null:
		actor = get_parent()


func _get_configuration_warnings() -> PackedStringArray:
	if actor == null and get_parent() == null:
		return ["Needs a parent, or an explicit actor assigned."]
	return []
