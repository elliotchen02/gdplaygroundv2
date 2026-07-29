@tool
class_name MovementComponent
extends Node

## Moves a CharacterBody3D: accelerates toward a requested direction, applies
## gravity, and jumps.
##
## Attach as a child of the body. The host sets intent via `set_move_direction()`
## and `jump()`; this component owns the `move_and_slide()` call. Godot ticks a
## parent before its children, so intent set in the host's `_physics_process`
## lands in the same tick.

## Left the floor under a jump.
signal jumped
## Touched the floor after being airborne.
signal landed

@export_group("Wiring")
## Body this component moves. Leave empty to use the parent.
@export var body: CharacterBody3D:
	set(value):
		body = value
		update_configuration_warnings()

@export_group("Tuning")
## Top horizontal speed, in metres per second.
@export_range(0.5, 20.0, 0.1) var max_speed: float = 5.0
## Rate horizontal velocity climbs toward `max_speed`, in m/s^2.
@export_range(1.0, 200.0, 1.0) var acceleration: float = 60.0
## Rate horizontal velocity falls to zero when no direction is requested, in m/s^2.
@export_range(1.0, 200.0, 1.0) var deceleration: float = 40.0
## Fraction of acceleration and deceleration that still applies while airborne.
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3
## Height a jump from a standstill reaches, in metres.
@export_range(0.1, 5.0, 0.05) var jump_height: float = 1.2

var _move_direction: Vector3 = Vector3.ZERO
var _jump_queued: bool = false
var _was_on_floor: bool = true


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	if body == null:
		body = get_parent() as CharacterBody3D


func _physics_process(delta: float) -> void:
	var gravity: Vector3 = body.get_gravity()
	var on_floor: bool = body.is_on_floor()

	if on_floor and not _was_on_floor:
		landed.emit()
	_was_on_floor = on_floor

	if not on_floor:
		body.velocity += gravity * delta

	if _jump_queued:
		_jump_queued = false
		if on_floor:
			body.velocity.y = sqrt(2.0 * gravity.length() * jump_height)
			jumped.emit()

	var rate: float = deceleration if _move_direction.is_zero_approx() else acceleration
	if not on_floor:
		rate *= air_control
	var horizontal: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	horizontal = horizontal.move_toward(_move_direction * max_speed, rate * delta)
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z

	body.move_and_slide()


## World-space direction to move in. Flattened and normalised, so vector length
## does not scale speed. A zero or purely vertical direction means "no input".
func set_move_direction(direction: Vector3) -> void:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	_move_direction = flat.normalized() if not flat.is_zero_approx() else Vector3.ZERO


## Queues a jump, honoured on the next physics tick if the body is grounded.
func jump() -> void:
	_jump_queued = true


func is_grounded() -> bool:
	return body != null and body.is_on_floor()


func _get_configuration_warnings() -> PackedStringArray:
	if body == null and not (get_parent() is CharacterBody3D):
		return ["Needs a CharacterBody3D parent, or an explicit body assigned."]
	return []
