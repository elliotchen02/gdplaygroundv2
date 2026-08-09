class_name Player
extends CharacterBody3D

## First-person player. Converts local input intent into a world-space movement
## request and drives look and camera switching; all behaviour lives in the
## attached components.
##
## Owns role gating: it asks `PlayerNetwork` what this copy is and clears the
## toggles only the driven copy should keep. In `_enter_tree`, because children
## ready before parents and a remote camera would otherwise claim the viewport
## first. Deciding here is what lets `PlayerNetwork` depend on nothing but a body.

@export var input_component: InputComponent
@export var movement_component: MovementComponent
@export var look_component: LookComponent
@export var camera_switch_component: CameraSwitchComponent
## Networking for this player. Asked for the role; never reaches back in here.
@export var player_network: PlayerNetwork
## Spring arm carrying the third-person camera. Excluded from its own collision.
@export var camera_arm: SpringArm3D
## Switched off on copies this peer does not drive: their transform is written
## from the network each tick, making them teleporting colliders that shove.
@export var collision_shape: CollisionShape3D

var _role: PlayerNetwork.Role = PlayerNetwork.Role.OBSERVER


func _enter_tree() -> void:
	# `multiplayer` is read here, not inside PlayerNetwork: _enter_tree runs
	# parent-first, so that child has no MultiplayerAPI of its own yet.
	_role = player_network.resolve_role(multiplayer.get_unique_id())
	var is_owner: bool = _role == PlayerNetwork.Role.OWNER
	input_component.reads_input = is_owner
	movement_component.simulates = is_owner
	camera_switch_component.activates_on_ready = is_owner
	# Look is a device read, so only the driven copy samples it. Physics still
	# ticks everywhere — a remote copy has a head to point.
	set_process(is_owner)
	if collision_shape != null:
		# Deferred: _enter_tree can land inside a physics flush, which refuses
		# collider state changes.
		collision_shape.set_deferred(&"disabled", not is_owner)
	if camera_arm != null:
		# SpringArm3D shapecasts on an internal tick; disabling the node is the
		# only way to silence that on a copy no one looks through.
		camera_arm.process_mode = (
			Node.PROCESS_MODE_INHERIT if is_owner else Node.PROCESS_MODE_DISABLED
		)


func _ready() -> void:
	input_component.jump_requested.connect(movement_component.jump)
	input_component.camera_toggle_requested.connect(camera_switch_component.next)
	if camera_arm != null:
		camera_arm.add_excluded_object(get_rid())


func _process(_delta: float) -> void:
	look_component.look(input_component.consume_look_delta())


func _physics_process(_delta: float) -> void:
	# Pitch lives on the camera pivot, not the body, so the actor carries it both
	# ways — that is what keeps PlayerNetwork body-only.
	match _role:
		PlayerNetwork.Role.OWNER:
			var axis: Vector2 = input_component.get_move_axis()
			movement_component.set_move_direction(global_basis * Vector3(axis.x, 0.0, axis.y))
			player_network.claimed_pitch = look_component.pitch()
		PlayerNetwork.Role.SERVER_RECORD:
			look_component.set_pitch(player_network.claimed_pitch)
		PlayerNetwork.Role.OBSERVER:
			look_component.set_pitch(player_network.observed_pitch())
