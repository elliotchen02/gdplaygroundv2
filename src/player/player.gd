class_name Player
extends CharacterBody3D

## First-person player. Converts local input intent into a world-space movement
## request and drives look and camera switching; all behaviour lives in the
## attached components.

@export var input_component: InputComponent
@export var movement_component: MovementComponent
@export var look_component: LookComponent
@export var camera_switch_component: CameraSwitchComponent
## Spring arm carrying the third-person camera. Excluded from its own collision.
@export var camera_arm: SpringArm3D


func _ready() -> void:
	input_component.jump_requested.connect(movement_component.jump)
	input_component.camera_toggle_requested.connect(camera_switch_component.next)
	if camera_arm != null:
		camera_arm.add_excluded_object(get_rid())


func _process(_delta: float) -> void:
	look_component.look(input_component.consume_look_delta())


func _physics_process(_delta: float) -> void:
	var axis: Vector2 = input_component.get_move_axis()
	movement_component.set_move_direction(global_basis * Vector3(axis.x, 0.0, axis.y))
