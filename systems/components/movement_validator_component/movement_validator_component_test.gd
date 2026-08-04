extends GdUnitTestSuite

## Unit tests for MovementValidatorComponent. Pure arithmetic, so no scene or
## physics loop: each test anchors a start position and feeds claims with a fixed
## delta, asserting what the server accepts and when it flags a correction.

const _DELTA: float = 1.0 / 60.0
const _APPROX: Vector3 = Vector3(0.001, 0.001, 0.001)

var _rejections: int = 0
var _last_corrected: Vector3 = Vector3.ZERO


func before_test() -> void:
	_rejections = 0
	_last_corrected = Vector3.ZERO


func _make() -> MovementValidatorComponent:
	var validator: MovementValidatorComponent = auto_free(MovementValidatorComponent.new())
	validator.claim_rejected.connect(
		func(_claimed: Vector3, corrected: Vector3) -> void:
			_rejections += 1
			_last_corrected = corrected
	)
	return validator


func test_steady_movement_within_speed_is_accepted() -> void:
	var validator: MovementValidatorComponent = _make()
	validator.anchor(Vector3.ZERO)
	var pos: Vector3 = Vector3.ZERO
	for _i: int in 30:
		pos.x += validator.max_speed * _DELTA
		var accepted: Vector3 = validator.submit(pos, _DELTA)
		assert_vector(accepted).is_equal_approx(pos, _APPROX)
	assert_int(_rejections).is_equal(0)


func test_sustained_overspeed_triggers_correction() -> void:
	var validator: MovementValidatorComponent = _make()
	validator.anchor(Vector3.ZERO)
	var pos: Vector3 = Vector3.ZERO
	for _i: int in 5:
		pos.x += 0.5
		validator.submit(pos, _DELTA)
	assert_int(_rejections).is_greater(0)
	assert_vector(validator.accepted_position()).is_equal(Vector3.ZERO)
	assert_vector(_last_corrected).is_equal(Vector3.ZERO)


func test_burst_after_idle_is_tolerated() -> void:
	var validator: MovementValidatorComponent = _make()
	validator.anchor(Vector3.ZERO)
	for _i: int in 30:
		validator.submit(Vector3.ZERO, _DELTA)
	var accepted: Vector3 = validator.submit(Vector3(3.0, 0.0, 0.0), _DELTA)
	assert_vector(accepted).is_equal_approx(Vector3(3.0, 0.0, 0.0), _APPROX)
	assert_int(_rejections).is_equal(0)


func test_teleport_beyond_max_step_is_rejected_despite_budget() -> void:
	var validator: MovementValidatorComponent = _make()
	validator.budget_ceiling = 100.0
	validator.max_step_distance = 8.0
	validator.anchor(Vector3.ZERO)
	validator.submit(Vector3.ZERO, 10.0)  # one fat tick banks the budget to its ceiling
	var accepted: Vector3 = validator.submit(Vector3(20.0, 0.0, 0.0), _DELTA)
	assert_vector(accepted).is_equal(Vector3.ZERO)


func test_falling_within_terminal_speed_is_accepted() -> void:
	var validator: MovementValidatorComponent = _make()
	validator.anchor(Vector3.ZERO)
	var accepted: Vector3 = validator.submit(Vector3(0.0, -0.9, 0.0), _DELTA)
	assert_vector(accepted).is_equal_approx(Vector3(0.0, -0.9, 0.0), _APPROX)
	assert_int(_rejections).is_equal(0)


func test_impossible_rise_is_rejected() -> void:
	var validator: MovementValidatorComponent = _make()
	validator.anchor(Vector3.ZERO)
	for _i: int in 4:
		validator.submit(Vector3(0.0, 5.0, 0.0), _DELTA)
	assert_int(_rejections).is_greater(0)
	assert_vector(validator.accepted_position()).is_equal(Vector3.ZERO)


func test_out_of_bounds_is_rejected() -> void:
	var validator: MovementValidatorComponent = _make()
	validator.anchor(Vector3(0.0, -49.9, 0.0))
	var accepted: Vector3 = validator.submit(Vector3(0.0, -50.1, 0.0), _DELTA)
	assert_vector(accepted).is_equal(Vector3(0.0, -49.9, 0.0))
