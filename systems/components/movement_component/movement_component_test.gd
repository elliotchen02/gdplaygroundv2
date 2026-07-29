extends GdUnitTestSuite

## Integration tests for MovementComponent. A CharacterBody3D over a static floor
## is stepped through real physics frames, since gravity, floor detection, and
## move_and_slide() only mean anything inside the physics loop.

const _MAX_SPEED: float = 5.0
const _REST_Y: float = 0.9

var _body: CharacterBody3D
var _movement: MovementComponent
var _jumped_count: int = 0
var _landed_count: int = 0


func before_test() -> void:
	_jumped_count = 0
	_landed_count = 0

	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var floor_collision: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 1.0, 40.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	_body = auto_free(CharacterBody3D.new())
	_body.floor_snap_length = 0.3
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	collision.shape = shape
	_body.add_child(collision)
	_body.position = Vector3(0.0, 1.0, 0.0)

	_movement = MovementComponent.new()
	_movement.max_speed = _MAX_SPEED
	_body.add_child(_movement)
	_movement.jumped.connect(func() -> void: _jumped_count += 1)
	_movement.landed.connect(func() -> void: _landed_count += 1)
	add_child(_body)


func _step(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


func _horizontal_speed() -> float:
	return Vector2(_body.velocity.x, _body.velocity.z).length()


func test_falls_under_gravity_when_airborne() -> void:
	_body.global_position = Vector3(0.0, 8.0, 0.0)
	await _step(8)
	assert_float(_body.velocity.y).is_less(0.0)
	assert_float(_body.global_position.y).is_less(8.0)


func test_accelerates_toward_but_never_past_max_speed() -> void:
	await _step(30)
	_movement.set_move_direction(Vector3(1.0, 0.0, 0.0))
	await _step(2)
	assert_float(_horizontal_speed()).is_greater(0.0)
	await _step(60)
	assert_float(_horizontal_speed()).is_less_equal(_MAX_SPEED + 0.01)
	assert_float(_horizontal_speed()).is_greater(_MAX_SPEED - 0.5)


func test_decelerates_to_rest_on_zero_direction() -> void:
	await _step(30)
	_movement.set_move_direction(Vector3(1.0, 0.0, 0.0))
	await _step(40)
	_movement.set_move_direction(Vector3.ZERO)
	await _step(40)
	assert_float(_horizontal_speed()).is_less(0.1)


func test_jump_while_grounded_rises_and_emits() -> void:
	await _step(30)
	assert_bool(_body.is_on_floor()).is_true()
	_movement.jump()
	var peak_y: float = _body.global_position.y
	for _i: int in 20:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, _body.global_position.y)
	assert_int(_jumped_count).is_greater(0)
	assert_float(peak_y).is_greater(_REST_Y + 0.2)


func test_jump_while_airborne_is_ignored() -> void:
	_body.global_position = Vector3(0.0, 8.0, 0.0)
	await _step(2)
	_movement.jump()
	await _step(4)
	assert_int(_jumped_count).is_equal(0)
	assert_float(_body.velocity.y).is_less(0.0)


func test_landed_fires_on_touchdown() -> void:
	_body.global_position = Vector3(0.0, 4.0, 0.0)
	await _step(90)
	assert_bool(_body.is_on_floor()).is_true()
	assert_int(_landed_count).is_greater(0)


func test_vertical_input_produces_no_horizontal_movement() -> void:
	await _step(30)
	_movement.set_move_direction(Vector3(0.0, 9.0, 0.0))
	await _step(30)
	assert_float(_horizontal_speed()).is_less(0.1)


func test_direction_magnitude_does_not_scale_speed() -> void:
	await _step(30)
	# A length-5 direction must be normalised, or the body would race past max_speed.
	_movement.set_move_direction(Vector3(3.0, 0.0, 4.0))
	await _step(80)
	assert_float(_horizontal_speed()).is_less_equal(_MAX_SPEED + 0.5)
