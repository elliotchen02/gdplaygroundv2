@tool
class_name LookComponent
extends Node

## Applies look input as yaw on one node and clamped pitch on another.
##
## Attach as a child of the actor. The host feeds deltas via `look()`; this
## component never reads a device. Split targets exist so a first-person actor
## can yaw its whole body while pitching only the camera pivot.

@export_group("Wiring")
## Node rotated around Y. Leave empty to use the parent.
@export var yaw_node: Node3D:
	set(value):
		yaw_node = value
		update_configuration_warnings()
## Node rotated around X. Leave empty to pitch the yaw node instead.
@export var pitch_node: Node3D

@export_group("Tuning")
## Radians of rotation per pixel of look input.
@export_range(0.0005, 0.02, 0.0005) var sensitivity: float = 0.003
## How far the pitch node may look up or down, in degrees.
@export_range(0.0, 89.9, 0.1) var max_pitch_degrees: float = 89.0
## Inverts vertical look.
@export var inverts_pitch: bool = false

var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if yaw_node == null:
		yaw_node = get_parent() as Node3D
	if pitch_node == null:
		pitch_node = yaw_node
	if yaw_node != null:
		_yaw = yaw_node.rotation.y
	if pitch_node != null:
		_pitch = pitch_node.rotation.x


## Rotates by a look delta in pixels: X yaws, Y pitches.
func look(delta: Vector2) -> void:
	if delta.is_zero_approx():
		return
	var limit: float = deg_to_rad(max_pitch_degrees)
	var pitch_sign: float = 1.0 if inverts_pitch else -1.0
	_yaw = wrapf(_yaw - delta.x * sensitivity, -PI, PI)
	_pitch = clampf(_pitch + delta.y * sensitivity * pitch_sign, -limit, limit)
	yaw_node.rotation.y = _yaw
	pitch_node.rotation.x = _pitch


func _get_configuration_warnings() -> PackedStringArray:
	if yaw_node == null and not (get_parent() is Node3D):
		return ["Needs a Node3D parent, or an explicit yaw node assigned."]
	return []
