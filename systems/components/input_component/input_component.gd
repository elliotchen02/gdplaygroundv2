@tool
class_name InputComponent
extends Node

## Turns device input into movement intent so actors never name an action themselves.
##
## Attach as a child of the actor. The host polls `get_move_axis()` and
## `consume_look_delta()` each frame and connects to the request signals. Every
## action name is supplied by the game, keeping this component project-agnostic.

## Jump was pressed this frame.
signal jump_requested
## The perspective-toggle action was pressed this frame.
signal camera_toggle_requested

@export_group("Wiring")
## InputMap action for strafing left. Must exist in the project's InputMap.
@export var move_left_action: StringName = &"move_left"
## InputMap action for strafing right.
@export var move_right_action: StringName = &"move_right"
## InputMap action for moving forward.
@export var move_forward_action: StringName = &"move_forward"
## InputMap action for moving backward.
@export var move_back_action: StringName = &"move_back"
## InputMap action for jumping.
@export var jump_action: StringName = &"jump"
## InputMap action for switching camera perspective.
@export var toggle_camera_action: StringName = &"toggle_camera"

@export_group("Runtime")
## When false, the component ignores this device entirely. The game clears it on
## player copies it does not own, so a remote player never reads this machine's
## keyboard or mouse. A neutral flag — the component names no networking concept.
@export var reads_input: bool = true:
	set(value):
		reads_input = value
		_update_input_processing()

var _look_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	_update_input_processing()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_look_delta += (event as InputEventMouseMotion).relative
		return
	if event.is_action_pressed(jump_action):
		jump_requested.emit()
	elif event.is_action_pressed(toggle_camera_action):
		camera_toggle_requested.emit()


## X is strafe (+ is right), Y is forward/back (- is forward, matching Godot's -Z).
func get_move_axis() -> Vector2:
	return Input.get_vector(
		move_left_action, move_right_action, move_forward_action, move_back_action
	)


## Look input accumulated since the last call, in pixels. Draining read — call
## exactly once per frame.
func consume_look_delta() -> Vector2:
	var delta: Vector2 = _look_delta
	_look_delta = Vector2.ZERO
	return delta


func _update_input_processing() -> void:
	set_process_unhandled_input(reads_input and not Engine.is_editor_hint())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var actions: Array[StringName] = [
		move_left_action,
		move_right_action,
		move_forward_action,
		move_back_action,
		jump_action,
		toggle_camera_action,
	]
	for action: StringName in actions:
		if action.is_empty() or not InputMap.has_action(action):
			warnings.append("Action \"%s\" is not in the project's InputMap." % action)
	return warnings
