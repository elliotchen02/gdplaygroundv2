extends GdUnitTestSuite

## Unit tests for LookComponent: yaw and pitch accumulation, clamping, inversion.

const _SENSITIVITY: float = 0.003
const _MAX_PITCH_DEGREES: float = 89.0


func _make_look(inverts: bool = false) -> LookComponent:
	var yaw: Node3D = auto_free(Node3D.new())
	var pitch: Node3D = auto_free(Node3D.new())
	add_child(yaw)
	add_child(pitch)
	var component: LookComponent = auto_free(LookComponent.new())
	component.yaw_node = yaw
	component.pitch_node = pitch
	component.sensitivity = _SENSITIVITY
	component.max_pitch_degrees = _MAX_PITCH_DEGREES
	component.inverts_pitch = inverts
	add_child(component)
	return component


func test_positive_x_yaws_negative() -> void:
	var component: LookComponent = _make_look()
	component.look(Vector2(100.0, 0.0))
	assert_float(component.yaw_node.rotation.y).is_equal_approx(-100.0 * _SENSITIVITY, 0.0001)


func test_pitch_clamped_looking_down() -> void:
	var component: LookComponent = _make_look()
	component.look(Vector2(0.0, 100000.0))
	var limit: float = deg_to_rad(_MAX_PITCH_DEGREES)
	assert_float(component.pitch_node.rotation.x).is_equal_approx(-limit, 0.0001)


func test_pitch_clamped_looking_up() -> void:
	var component: LookComponent = _make_look()
	component.look(Vector2(0.0, -100000.0))
	var limit: float = deg_to_rad(_MAX_PITCH_DEGREES)
	assert_float(component.pitch_node.rotation.x).is_equal_approx(limit, 0.0001)


func test_inverts_pitch_flips_vertical() -> void:
	var normal: LookComponent = _make_look(false)
	var inverted: LookComponent = _make_look(true)
	normal.look(Vector2(0.0, 50.0))
	inverted.look(Vector2(0.0, 50.0))
	var flipped: float = -inverted.pitch_node.rotation.x
	assert_float(normal.pitch_node.rotation.x).is_equal_approx(flipped, 0.0001)


func test_zero_delta_is_a_no_op() -> void:
	var component: LookComponent = _make_look()
	component.look(Vector2.ZERO)
	assert_float(component.yaw_node.rotation.y).is_equal(0.0)
	assert_float(component.pitch_node.rotation.x).is_equal(0.0)


func test_yaw_and_pitch_land_on_separate_nodes() -> void:
	var component: LookComponent = _make_look()
	component.look(Vector2(80.0, 60.0))
	assert_float(component.yaw_node.rotation.x).is_equal(0.0)
	assert_float(component.yaw_node.rotation.z).is_equal(0.0)
	assert_float(component.pitch_node.rotation.y).is_equal(0.0)
	assert_float(component.pitch_node.rotation.z).is_equal(0.0)


func test_set_pitch_applies_and_clamps() -> void:
	var component: LookComponent = _make_look()
	component.set_pitch(0.4)
	assert_float(component.pitch_node.rotation.x).is_equal_approx(0.4, 0.0001)
	assert_float(component.pitch()).is_equal_approx(0.4, 0.0001)
	# Same limit `look` obeys, so a pose fed in from elsewhere cannot put a head
	# somewhere the device could never have.
	component.set_pitch(100.0)
	assert_float(component.pitch_node.rotation.x).is_equal_approx(
		deg_to_rad(_MAX_PITCH_DEGREES), 0.0001
	)


func test_look_continues_from_a_pitch_set_directly() -> void:
	var component: LookComponent = _make_look()
	component.set_pitch(0.2)
	component.look(Vector2(0.0, -100.0))
	assert_float(component.pitch_node.rotation.x).is_equal_approx(
		0.2 + 100.0 * _SENSITIVITY, 0.0001
	)
