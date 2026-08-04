class_name PlayerNetwork
extends Node

## Decides what a player copy is on this peer — the one we own, the server's
## authoritative record, or a remote observer — and gates the actor's components
## to match. Owners simulate locally and report the resulting transform; the
## server validates those reports and corrects only the impossible ones. It
## keeps player.gd the thin composition root it already is.
##
## Replication (player.tscn) refers to the synced properties below BY NAME:
## claimed_position / claimed_velocity / claimed_yaw here, and position /
## velocity / rotation on the player root. Renaming one alone breaks replication
## silently, with no error — keep the marked block and the .tscn in step.

enum Role {
	## The player this peer drives. Simulates locally and reports its transform.
	OWNER,
	## The server's authoritative copy of a client's player. Validates claims.
	SERVER_RECORD,
	## A remote player's copy on a client. Passive; shows server state.
	OBSERVER,
}

@export_group("Wiring")
## Synchronizer the owner uses to report its claimed transform to the server.
@export var claim_synchronizer: MultiplayerSynchronizer
## Synchronizer the server uses to broadcast accepted state to observers.
@export var state_synchronizer: MultiplayerSynchronizer
## Server-side reachability check applied to a client's incoming claims.
@export var movement_validator: MovementValidatorComponent
## Spring arm carrying the third-person camera. Raycasts every frame, so it is
## switched off on copies no one looks through.
@export var camera_arm: SpringArm3D
## Visual mesh, slid back toward its pre-correction pose so a snap reads as a
## tug rather than a teleport.
@export var mesh: Node3D
## Camera pivot, offset alongside the mesh during a correction.
@export var camera_pivot: Node3D

@export_group("Tuning")
## Seconds a correction's visual offset takes to decay to nothing.
@export_range(0.0, 1.0, 0.01) var correction_smoothing: float = 0.15

# --- Synced block: replicated BY NAME from player.tscn. Do not rename alone. ---
## Position the owner claims to have reached; read by the server's validator.
var claimed_position: Vector3 = Vector3.ZERO
## Velocity the owner claims; recorded by the server for later queries.
var claimed_velocity: Vector3 = Vector3.ZERO
## Body yaw the owner claims; a float because a config cannot sync one Vector3
## component. The server writes it back onto `rotation.y`.
var claimed_yaw: float = 0.0
# --- End synced block. ---

var _player: Player
var _owner_id: int = 1
var _role: Role = Role.OBSERVER
var _visual_offset: Vector3 = Vector3.ZERO
var _mesh_base: Vector3 = Vector3.ZERO
var _pivot_base: Vector3 = Vector3.ZERO


func _enter_tree() -> void:
	_player = get_parent() as Player
	# The spawner names the node after the owning peer, so every peer derives the
	# same authority with no replication of `set_multiplayer_authority`.
	_owner_id = _player.name.to_int()
	_player.set_multiplayer_authority(_owner_id)
	# Authority must be pinned here, not in _ready: the spawner starts
	# replication right after _enter_tree, and a synchronizer whose authority
	# changes later has no network ID yet. Claims flow up from the owner, state
	# flows down from the server.
	claim_synchronizer.set_multiplayer_authority(_owner_id)
	state_synchronizer.set_multiplayer_authority(1)
	# Silence the camera before CameraSwitchComponent._ready runs (children ready
	# before parents); only the owner should ever claim the viewport.
	if _player.camera_switch_component != null:
		_player.camera_switch_component.activates_on_ready = _owner_id == multiplayer.get_unique_id()


func _ready() -> void:
	if mesh != null:
		_mesh_base = mesh.position
	if camera_pivot != null:
		_pivot_base = camera_pivot.position

	_role = _resolve_role()
	_apply_role()


func _physics_process(delta: float) -> void:
	match _role:
		Role.OWNER:
			# Mirror truth after MovementComponent has moved the body this tick;
			# PlayerNetwork is ordered after it in the scene.
			claimed_position = _player.global_position
			claimed_velocity = _player.velocity
			claimed_yaw = _player.rotation.y
			_decay_visual_offset(delta)
		Role.SERVER_RECORD:
			var accepted: Vector3 = movement_validator.submit(claimed_position, delta)
			_player.global_position = accepted
			_player.velocity = claimed_velocity
			_player.rotation.y = claimed_yaw
		Role.OBSERVER:
			pass


func _resolve_role() -> Role:
	if multiplayer.get_unique_id() == _owner_id:
		return Role.OWNER
	if multiplayer.is_server():
		return Role.SERVER_RECORD
	return Role.OBSERVER


func _apply_role() -> void:
	var is_owner: bool = _role == Role.OWNER
	var is_server_record: bool = _role == Role.SERVER_RECORD

	if _player.input_component != null:
		_player.input_component.reads_input = is_owner
	if _player.movement_component != null:
		_player.movement_component.simulates = is_owner
	if camera_arm != null:
		# SpringArm3D shapecasts on an internal tick; disabling the node is the
		# only way to silence that on a copy no one looks through.
		camera_arm.process_mode = Node.PROCESS_MODE_INHERIT if is_owner else Node.PROCESS_MODE_DISABLED

	if is_owner:
		_start_owner()
	elif is_server_record:
		_start_server_record()

	# Owners mirror their truth; the server judges claims. Observers do neither
	# and only receive state, so they need no physics tick.
	set_physics_process(is_owner or is_server_record)


func _start_owner() -> void:
	var switch: CameraSwitchComponent = _player.camera_switch_component
	if switch != null and not switch.cameras.is_empty():
		switch.activate(0)
	# Report only to the server, nobody else.
	claim_synchronizer.public_visibility = false
	claim_synchronizer.set_visibility_for(1, true)
	claimed_position = _player.global_position
	claimed_velocity = _player.velocity
	claimed_yaw = _player.rotation.y


func _start_server_record() -> void:
	movement_validator.anchor(_player.global_position)
	movement_validator.claim_rejected.connect(_on_claim_rejected)
	# Observers see the accepted state; the owner is excluded here and corrected
	# by RPC instead, so the server's record never overwrites its local sim.
	state_synchronizer.public_visibility = true
	state_synchronizer.add_visibility_filter(_is_visible_to)


func _is_visible_to(peer_id: int) -> bool:
	return peer_id != _owner_id


func _on_claim_rejected(_claimed: Vector3, corrected: Vector3) -> void:
	force_state.rpc_id(_owner_id, corrected, Vector3.ZERO)


## Server-issued, reliable, rare: snap the owner's body onto the accepted state
## and start sliding the picture back from where it was.
@rpc("any_peer", "call_remote", "reliable")
func force_state(position: Vector3, velocity: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var previous: Vector3 = _player.global_position
	_player.global_position = position
	_player.velocity = velocity
	claimed_position = position
	claimed_velocity = velocity
	_visual_offset = previous - position
	_apply_visual_offset()


func _decay_visual_offset(delta: float) -> void:
	if _visual_offset.is_zero_approx():
		return
	var t: float = 1.0
	if correction_smoothing > 0.0:
		t = clampf(delta / correction_smoothing, 0.0, 1.0)
	_visual_offset = _visual_offset.lerp(Vector3.ZERO, t)
	if _visual_offset.length() < 0.001:
		_visual_offset = Vector3.ZERO
	_apply_visual_offset()


func _apply_visual_offset() -> void:
	if mesh != null:
		mesh.position = _mesh_base + _visual_offset
	if camera_pivot != null:
		camera_pivot.position = _pivot_base + _visual_offset
