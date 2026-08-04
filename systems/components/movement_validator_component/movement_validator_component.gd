class_name MovementValidatorComponent
extends Node

## Judges whether a position a client claims to have reached was physically
## possible, and returns the position the server is willing to accept.
##
## Pure arithmetic — no multiplayer, no physics queries — so it obeys the
## systems/ dependency rule and unit-tests without a MultiplayerAPI or a scene.
## The host feeds it claims each tick via `submit()`; it answers with the
## accepted position and, once rejections pass a threshold, emits
## `claim_rejected` so the host can correct the offender.

## A claim was rejected enough times in a row to warrant correcting the client.
## Carries the rejected claim and the position the server kept instead.
signal claim_rejected(claimed: Vector3, corrected: Vector3)

@export_group("Tuning")
## Top horizontal speed a client may sustain, in m/s. Mirror `MovementComponent`.
@export_range(0.5, 50.0, 0.1) var max_speed: float = 10.0
## Fraction of extra speed tolerated to absorb jitter before a claim is
## overspeed. 1.2 forgives brief 20% bursts.
@export_range(1.0, 3.0, 0.05) var speed_tolerance: float = 1.2
## Most displacement budget that can bank while idle, in metres. Caps how far a
## saved-up allowance can teleport.
@export_range(0.1, 20.0, 0.1) var budget_ceiling: float = 4.0
## Largest single-tick horizontal step accepted regardless of budget, in metres.
@export_range(0.5, 50.0, 0.5) var max_step_distance: float = 8.0
## Fastest downward speed a fall may reach, in m/s.
@export_range(1.0, 200.0, 1.0) var max_fall_speed: float = 60.0
## Fastest upward speed a jump may reach, in m/s.
@export_range(1.0, 200.0, 1.0) var max_rise_speed: float = 30.0
## Lowest world Y a player may occupy before a claim is rejected.
@export var min_y: float = -50.0
## Highest world Y a player may occupy before a claim is rejected.
@export var max_y: float = 500.0
## Consecutive rejections tolerated before `claim_rejected` fires, so a single
## network hitch never yanks a legitimate player.
@export_range(1, 30, 1) var strikes_before_correction: int = 3

var _accepted: Vector3 = Vector3.ZERO
var _budget: float = 0.0
var _strikes: int = 0


func _ready() -> void:
	set_physics_process(false)
	set_process(false)


## Anchors validation at a known-good position, clearing budget and strikes.
## Call once when the record is created, and after forcing a correction.
func anchor(position: Vector3) -> void:
	_accepted = position
	_budget = 0.0
	_strikes = 0


## Judges a claimed position reached over `delta` seconds. Returns the position
## the server accepts: the claim when plausible, the last accepted position when
## not. Emits `claim_rejected` once consecutive rejections reach the threshold.
func submit(claimed: Vector3, delta: float) -> Vector3:
	_budget = minf(_budget + max_speed * delta * speed_tolerance, budget_ceiling)
	var moved: float = Vector2(claimed.x - _accepted.x, claimed.z - _accepted.z).length()
	if (
		moved <= _budget
		and moved <= max_step_distance
		and _is_vertically_plausible(claimed, delta)
		and _is_in_bounds(claimed)
	):
		_budget -= moved
		_strikes = 0
		_accepted = claimed
		return _accepted
	_strikes += 1
	if _strikes >= strikes_before_correction:
		claim_rejected.emit(claimed, _accepted)
	return _accepted


## The position most recently accepted as authoritative.
func accepted_position() -> Vector3:
	return _accepted


func _is_vertically_plausible(claimed: Vector3, delta: float) -> bool:
	var dy: float = claimed.y - _accepted.y
	var cap: float = max_fall_speed if dy < 0.0 else max_rise_speed
	# Budget-free per-tick check with slack for jitter; vertical is validated
	# apart from horizontal because a fall dwarfs walking speed.
	return absf(dy) <= cap * delta * speed_tolerance + 0.05


func _is_in_bounds(claimed: Vector3) -> bool:
	return claimed.y >= min_y and claimed.y <= max_y
