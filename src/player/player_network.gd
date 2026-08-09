class_name PlayerNetwork
extends Node

## Decides what a player copy is on this peer — owner, server record, or remote
## observer — and owns every node networking needs. Reports the role; the actor
## gates itself. Touches nothing outside this scene but the body it was handed,
## so a test can drive it with a bare CharacterBody3D.
##
## Replication (player_network.tscn) matches the synced block below BY NAME.
## Renaming one alone breaks replication silently.

enum Role {
	## The player this peer drives. Simulates locally and reports its transform.
	OWNER,
	## The server's authoritative copy of a client's player. Records claims.
	SERVER_RECORD,
	## A remote player's copy on a client. Passive; shows server state.
	OBSERVER,
}

## The server snapped this copy onto an accepted state. Carries where the body
## was, so the actor can slide its picture back instead of cutting.
signal state_corrected(from_position: Vector3)

## Peer id Godot always assigns the host.
const SERVER_PEER_ID: int = 1
## Cap on how far the render clock bends per tick. Under 1.0 so it never reverses.
const _MAX_SLEW_PER_TICK: float = 0.5

@export_group("Wiring")
## The only node outside this scene this script touches.
@export var body: CharacterBody3D
## Reports the owner's claimed transform up to the server.
@export var claim_synchronizer: MultiplayerSynchronizer
## Broadcasts the server's accepted state down to observers.
@export var state_synchronizer: MultiplayerSynchronizer
## Server-side reachability check. Parked — see `_record_claim`.
@export var movement_validator: MovementValidatorComponent
## History observers interpolate over. Owners and server records hold the real
## state and must not be smoothed away from it.
@export var snapshot_buffer: SnapshotBufferComponent

@export_group("Tuning")
## Ticks an observer renders behind the newest state received. The delay is what
## absorbs arrival jitter: it guarantees a state either side of the moment being
## drawn. 6 is 100 ms at 60 Hz. Raise it on a worse connection; the cost is
## remote players lagging further behind where they truly are.
@export_range(0, 30, 1) var interpolation_delay_ticks: int = 6
## Fraction of the render clock's error corrected each tick. Small on purpose:
## state arrives in bursts, so the target climbs as a staircase, and a high gain
## copies each step onto the body — the jitter the buffer just removed.
@export_range(0.005, 1.0, 0.005) var render_clock_slew: float = 0.02
## Error, in ticks, past which the render clock resets instead of slewing.
@export_range(1.0, 200.0, 1.0) var resync_threshold_ticks: float = 20.0

@export_group("Identity")
## Peer that drives this player. Set from replicated spawn data before this node
## enters the tree, so every peer derives the same authority without replicating
## `set_multiplayer_authority`.
@export var owner_id: int = 1

# --- Synced block: replicated BY NAME from player_network.tscn. Do not rename alone. ---
## Owner's tick counter. Without it, no receive-side buffering is possible.
var claimed_tick: int = 0
var claimed_position: Vector3 = Vector3.ZERO
var claimed_velocity: Vector3 = Vector3.ZERO
## A float because a config cannot sync a single Vector3 component.
var claimed_yaw: float = 0.0
## Reported by the actor: pitch lives on the camera pivot, not the body.
var claimed_pitch: float = 0.0
## Tick the accepted state belongs to. Observers key their buffer on it.
var net_tick: int = 0
var net_position: Vector3 = Vector3.ZERO
## Observers extrapolate along this when the buffer starves.
var net_velocity: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var net_pitch: float = 0.0
# --- End synced block. ---

var _role: Role = Role.OBSERVER
var _role_is_resolved: bool = false
var _render_tick: float = 0.0
var _render_clock_started: bool = false


func _enter_tree() -> void:
	# Never in _ready: the spawner starts replication right after _enter_tree, and
	# a synchronizer whose authority changes later has no network ID yet. All
	# non-recursive — the synchronizers need opposite authorities, and a recursive
	# set on an ancestor flattens them.
	set_multiplayer_authority(owner_id, false)
	if body != null:
		body.set_multiplayer_authority(owner_id, false)
	claim_synchronizer.set_multiplayer_authority(owner_id, false)
	state_synchronizer.set_multiplayer_authority(SERVER_PEER_ID, false)


func _ready() -> void:
	# The buffer counts in ticks and owns no clock; the game supplies the rate.
	snapshot_buffer.seconds_per_tick = 1.0 / float(Engine.physics_ticks_per_second)
	# Fallback for standalone use, where nothing outside has asked yet.
	if resolve_role(multiplayer.get_unique_id()) == Role.SERVER_RECORD:
		movement_validator.anchor(body.global_position)


## The role this copy plays for the peer asking. Idempotent, and takes the peer
## id rather than reading `multiplayer` so the composition root can call it from
## its own `_enter_tree` — which runs parent-first, before this node has one.
func resolve_role(local_peer_id: int) -> Role:
	if _role_is_resolved:
		return _role
	if local_peer_id == owner_id:
		_role = Role.OWNER
	elif local_peer_id == SERVER_PEER_ID:
		_role = Role.SERVER_RECORD
	else:
		_role = Role.OBSERVER
	_role_is_resolved = true
	return _role


## The role resolved earlier. `Role.OBSERVER` until `resolve_role` has run.
func role() -> Role:
	return _role


func _physics_process(delta: float) -> void:
	match _role:
		Role.OWNER:
			# Ordered after MovementComponent, so the body has already moved.
			claimed_tick += 1
			claimed_position = body.global_position
			claimed_velocity = body.velocity
			claimed_yaw = body.rotation.y
			# A listen-server owns a player and is also the authority observers
			# read, so it publishes its own state — no other copy will.
			if multiplayer.get_unique_id() == SERVER_PEER_ID:
				_publish_state()
		Role.SERVER_RECORD:
			_record_claim(delta)
		Role.OBSERVER:
			_show_server_state()


## Takes the owner's claim as accepted and republishes it for observers.
##
## PARKED: `movement_validator.submit(claimed_position, delta)` belongs here and
## returns the position to accept instead of the raw claim. Off until the
## transport is proven, so a correction snap cannot be mistaken for jitter.
## Re-enabling is this call plus reconnecting `claim_rejected` in `_ready`.
func _record_claim(_delta: float) -> void:
	body.global_position = claimed_position
	body.velocity = claimed_velocity
	body.rotation.y = claimed_yaw
	_publish_state()


## Only ever called on the server, which holds `state_synchronizer` authority for
## every player — including the one a host drives itself.
func _publish_state() -> void:
	net_tick = claimed_tick
	net_position = claimed_position
	net_velocity = claimed_velocity
	net_yaw = claimed_yaw
	net_pitch = claimed_pitch


## Shows accepted state a fixed delay behind the newest arrival, so bursty
## delivery comes out as continuous motion. Applying each arrival directly
## instead is what makes a remote player stutter.
func _show_server_state() -> void:
	if net_tick == 0:
		# Nothing received. Adopting the default would teleport a freshly spawned
		# player to the world origin.
		return
	snapshot_buffer.push(net_tick, net_position, net_velocity, net_yaw, net_pitch)
	_advance_render_clock()
	if not snapshot_buffer.sample(_render_tick):
		return
	body.global_position = snapshot_buffer.sampled_position
	body.rotation.y = snapshot_buffer.sampled_yaw
	# Never simulated here; carried so anything reading speed sees a real value.
	body.velocity = net_velocity


## Interpolated head pitch. The actor applies it, because the pivot is its node.
func observed_pitch() -> float:
	return snapshot_buffer.sampled_pitch


## Runs the observer's own clock forward a tick, then bends it toward the newest
## arrival minus the delay. Slewing rather than assigning is the point: setting
## the clock from each arrival hands the jitter straight back.
func _advance_render_clock() -> void:
	var target: float = float(snapshot_buffer.newest_tick() - interpolation_delay_ticks)
	if not _render_clock_started:
		_render_tick = target
		_render_clock_started = true
		return
	_render_tick += 1.0
	var error: float = target - _render_tick
	if absf(error) > resync_threshold_ticks:
		# Beyond what the buffer can absorb. Slewing back would take seconds and
		# freeze the actor for all of them, so take the cut.
		_render_tick = target
		return
	_render_tick += clampf(error * render_clock_slew, -_MAX_SLEW_PER_TICK, _MAX_SLEW_PER_TICK)


func _on_claim_rejected(_claimed: Vector3, corrected: Vector3) -> void:
	force_state.rpc_id(owner_id, corrected, Vector3.ZERO)


## Server-issued, reliable, rare: snap the owner onto the accepted state. Kept
## wired while validation is parked so its place in the wire contract holds.
@rpc("any_peer", "call_remote", "reliable")
func force_state(corrected_position: Vector3, corrected_velocity: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != SERVER_PEER_ID:
		return
	var previous: Vector3 = body.global_position
	body.global_position = corrected_position
	body.velocity = corrected_velocity
	# A real teleport, unlike the observer's per-tick writes: without this,
	# interpolation draws the body sliding across the gap it was snapped over.
	body.reset_physics_interpolation()
	claimed_position = corrected_position
	claimed_velocity = corrected_velocity
	state_corrected.emit(previous)
