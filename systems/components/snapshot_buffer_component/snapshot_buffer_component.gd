class_name SnapshotBufferComponent
extends Node

## Holds the last N states an actor was reported in, keyed by tick, and answers
## what it looked like at any point on that timeline — including between two
## reports.
##
## Networked state arrives in bursts: several updates in one frame, none in the
## next. Applying each one the moment it lands makes a body stutter by exactly
## the irregularity of the network. Buffering instead, and reading back a little
## behind the newest arrival, turns those bursts into continuous motion. The
## caller decides how far behind to read: the delay must exceed the gap between
## arrivals, then trades latency for jitter absorption. Gaffer On Games puts the
## practical floor near 100 ms at 60 Hz — https://gafferongames.com/post/snapshot_interpolation/
##
## Pure arithmetic — no multiplayer, no physics queries, no clock of its own —
## so it obeys the systems/ dependency rule and unit-tests without a
## MultiplayerAPI or a scene. It stores and interpolates; deciding *when* "now"
## is belongs to whoever owns the connection.

@export_group("Tuning")
## States retained. Must cover the read-behind delay plus the worst burst gap;
## 32 is a little over half a second at 60 Hz. Changing it clears the buffer.
@export_range(4, 256, 1) var capacity: int = 32
## Ticks the buffer will project past its newest state before holding still.
## Extrapolation guesses along the last velocity and is wrong the moment the
## actor turns, jumps, or lands, so it covers a dropped packet and no more.
@export_range(0, 30, 1) var max_extrapolation_ticks: int = 4
## Seconds one tick represents. Only used to turn a velocity in units-per-second
## into a distance while extrapolating. Match the project's physics tick rate.
@export var seconds_per_tick: float = 1.0 / 60.0

## Position at the tick last passed to `sample`. Meaningless until it returns true.
var sampled_position: Vector3 = Vector3.ZERO
## Yaw at the tick last passed to `sample`. Meaningless until it returns true.
var sampled_yaw: float = 0.0
## Pitch at the tick last passed to `sample`. Meaningless until it returns true.
var sampled_pitch: float = 0.0

var _ticks: PackedInt64Array = PackedInt64Array()
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _yaws: PackedFloat32Array = PackedFloat32Array()
var _pitches: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0
var _count: int = 0


func _ready() -> void:
	set_physics_process(false)
	set_process(false)


## Records the state reported for `tick`. Ignores anything not newer than what is
## already held, so a duplicate or a packet that overtook its predecessor cannot
## drag the timeline backwards.
func push(
	tick: int, position: Vector3, velocity: Vector3, yaw: float, pitch: float = 0.0
) -> void:
	_ensure_storage()
	if _count > 0 and tick <= newest_tick():
		return
	_ticks[_next] = tick
	_positions[_next] = position
	_velocities[_next] = velocity
	_yaws[_next] = yaw
	_pitches[_next] = pitch
	_next = (_next + 1) % capacity
	_count = mini(_count + 1, capacity)


## Reads the timeline at `render_tick`, which may fall between two recorded
## ticks. Writes `sampled_position`, `sampled_yaw` and `sampled_pitch` and
## returns true; returns false only when nothing has been recorded yet, in which
## case the caller should leave its actor where it is rather than adopt a default.
##
## Returns a bool and writes to fields instead of returning a struct so that a
## per-tick call for every remote actor allocates nothing.
func sample(render_tick: float) -> bool:
	if _count == 0:
		return false
	var newest: int = _count - 1
	if render_tick >= float(_tick_at(newest)):
		_extrapolate_from(newest, render_tick)
		return true
	if render_tick <= float(_tick_at(0)):
		# Before anything we hold: the actor's history starts here as far as we
		# know, so show its oldest known state rather than inventing one.
		sampled_position = _positions[_physical(0)]
		sampled_yaw = _yaws[_physical(0)]
		sampled_pitch = _pitches[_physical(0)]
		return true
	var older: int = _index_at_or_before(render_tick)
	var newer: int = older + 1
	var span: float = float(_tick_at(newer) - _tick_at(older))
	var weight: float = (render_tick - float(_tick_at(older))) / span
	sampled_position = _positions[_physical(older)].lerp(_positions[_physical(newer)], weight)
	sampled_yaw = lerp_angle(_yaws[_physical(older)], _yaws[_physical(newer)], weight)
	sampled_pitch = lerp_angle(_pitches[_physical(older)], _pitches[_physical(newer)], weight)
	return true


## Highest tick recorded. Zero when empty — callers should check `is_empty`.
func newest_tick() -> int:
	if _count == 0:
		return 0
	return _tick_at(_count - 1)


## Lowest tick still retained. Zero when empty.
func oldest_tick() -> int:
	if _count == 0:
		return 0
	return _tick_at(0)


func is_empty() -> bool:
	return _count == 0


## States currently held, up to `capacity`.
func size() -> int:
	return _count


## Drops every recorded state. The next `sample` returns false until something is
## pushed, so a caller that reconnects starts from a clean timeline.
func clear() -> void:
	_next = 0
	_count = 0


## Projects along the last known velocity, for at most `max_extrapolation_ticks`,
## then holds. Holding a stale pose reads as a brief pause; projecting further
## reads as an actor sliding through walls, so the cap is the lesser evil.
func _extrapolate_from(newest: int, render_tick: float) -> void:
	var physical: int = _physical(newest)
	var ahead: float = minf(
		render_tick - float(_tick_at(newest)), float(max_extrapolation_ticks)
	)
	sampled_position = _positions[physical] + _velocities[physical] * ahead * seconds_per_tick
	sampled_yaw = _yaws[physical]
	sampled_pitch = _pitches[physical]


## Newest logical index whose tick is at or before `render_tick`. Only called
## once the caller has ruled out both ends, so a bracketing pair always exists.
## Linear from the newest end: the answer is within a few entries of it in every
## steady-state frame, and a scan beats a binary search at this size.
func _index_at_or_before(render_tick: float) -> int:
	var index: int = _count - 2
	while index > 0 and float(_tick_at(index)) > render_tick:
		index -= 1
	return index


## Ring slot holding logical entry `index`, counting 0 as the oldest retained.
func _physical(index: int) -> int:
	return (_next - _count + index + capacity * 2) % capacity


func _tick_at(index: int) -> int:
	return _ticks[_physical(index)]


## Sizes the ring on first use and after `capacity` changes. Not in `_ready`, so
## a buffer built with `new()` in a test works without entering a scene tree.
func _ensure_storage() -> void:
	if _ticks.size() == capacity:
		return
	_ticks.resize(capacity)
	_positions.resize(capacity)
	_velocities.resize(capacity)
	_yaws.resize(capacity)
	_pitches.resize(capacity)
	_next = 0
	_count = 0
