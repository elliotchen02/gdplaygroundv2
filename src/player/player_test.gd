extends GdUnitTestSuite

## Scene-level tests for player.tscn. Unlike the component suites, which build
## their nodes by hand, these drive the real scene through the project's
## InputMap — so the wiring in the .tscn (component NodePaths, the signal hookup
## in Player._ready) is under test alongside the scripts.

const _PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
## Scene value on MovementComponent; the components' own suites cover tuning.
const _MAX_SPEED: float = 10.0

var _runner: GdUnitSceneRunner
var _player: Player


func before_test() -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var floor_collision: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(80.0, 1.0, 80.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	# player.tscn carries no floor; the runner's scene shares this default
	# World3D, so a body added here is what the player lands on.
	add_child(floor_body)

	# scene_runner() only frees the scene when it instantiated it from a path.
	# Handed a Node, it leaves ownership here — without auto_free the whole
	# player subtree leaks as orphans after every test.
	_player = auto_free(_PLAYER_SCENE.instantiate()) as Player
	# Named after the owning peer as src/main.gd does. A copy that resolves to
	# anything but OWNER has movement and input switched off, and every assertion
	# below would run against a body that was never going to move.
	_player.name = str(multiplayer.get_unique_id())
	_runner = scene_runner(_player)
	await _runner.simulate_frames(4)


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func test_comes_up_as_owner_with_components_live() -> void:
	# Guards the naming trap in before_test: if this fails, every other test in
	# this suite is meaningless rather than merely failing.
	assert_bool(_player.input_component.reads_input).is_true()
	assert_bool(_player.movement_component.simulates).is_true()


func test_scene_wiring_resolves_every_component() -> void:
	assert_object(_player.input_component).is_not_null()
	assert_object(_player.movement_component).is_not_null()
	assert_object(_player.look_component).is_not_null()
	assert_object(_player.camera_switch_component).is_not_null()


func test_move_forward_action_drives_the_body() -> void:
	await _runner.simulate_frames(30)
	_runner.simulate_action_press(&"move_forward")
	await _runner.simulate_frames(45)

	# -Z is forward in Godot, and the player spawns unrotated.
	assert_float(_player.global_position.z).is_less(-0.5)
	assert_float(_horizontal_speed()).is_greater(1.0)
	assert_float(_horizontal_speed()).is_less_equal(_MAX_SPEED + 0.5)

	_runner.simulate_action_release(&"move_forward")
	await _runner.simulate_frames(60)
	assert_float(_horizontal_speed()).is_less(0.2)


func test_opposing_actions_cancel() -> void:
	await _runner.simulate_frames(30)
	_runner.simulate_action_press(&"move_left")
	_runner.simulate_action_press(&"move_right")
	await _runner.simulate_frames(40)
	assert_float(_horizontal_speed()).is_less(0.2)
	_runner.simulate_action_release(&"move_left")
	_runner.simulate_action_release(&"move_right")


func test_jump_action_reaches_movement_component_through_the_signal() -> void:
	await _runner.simulate_frames(30)
	assert_bool(_player.movement_component.is_grounded()).is_true()

	# The jump path is InputComponent.jump_requested -> MovementComponent.jump,
	# connected in Player._ready. Only a scene-level test covers that hop.
	_runner.simulate_action_pressed(&"jump")
	await _runner.simulate_frames(2)
	assert_float(_player.velocity.y).is_greater(0.0)

	var peak_y: float = _player.global_position.y
	for _i: int in 20:
		await _runner.simulate_frames(1)
		peak_y = maxf(peak_y, _player.global_position.y)
	assert_float(peak_y).is_greater(0.2)


func test_camera_toggle_action_switches_the_active_camera() -> void:
	await _runner.simulate_frames(10)
	var switch: CameraSwitchComponent = _player.camera_switch_component
	var first: Camera3D = switch.cameras[0] as Camera3D
	var second: Camera3D = switch.cameras[1] as Camera3D
	assert_bool(first.current).is_true()

	_runner.simulate_action_pressed(&"toggle_camera")
	await _runner.simulate_frames(4)
	assert_bool(second.current).is_true()
	assert_bool(first.current).is_false()
