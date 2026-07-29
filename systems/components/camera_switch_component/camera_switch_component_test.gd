extends GdUnitTestSuite

## Unit tests for CameraSwitchComponent: initial activation, cycling, single-active
## invariant, the activation signal, and empty-list safety.

var _activated: Array[Camera3D] = []


func before_test() -> void:
	_activated = []


func _make_switch(count: int) -> CameraSwitchComponent:
	var component: CameraSwitchComponent = auto_free(CameraSwitchComponent.new())
	var cameras: Array[Camera3D] = []
	for _i: int in count:
		var camera: Camera3D = auto_free(Camera3D.new())
		add_child(camera)
		cameras.append(camera)
	component.cameras = cameras
	component.camera_activated.connect(func(camera: Camera3D) -> void: _activated.append(camera))
	add_child(component)
	return component


func test_first_camera_is_current_on_ready() -> void:
	var component: CameraSwitchComponent = _make_switch(2)
	assert_bool(component.cameras[0].current).is_true()
	assert_bool(component.cameras[1].current).is_false()


func test_next_cycles_and_wraps() -> void:
	var component: CameraSwitchComponent = _make_switch(2)
	component.next()
	assert_bool(component.cameras[1].current).is_true()
	component.next()
	assert_bool(component.cameras[0].current).is_true()


func test_activate_leaves_exactly_one_current() -> void:
	var component: CameraSwitchComponent = _make_switch(3)
	component.activate(2)
	var current_count: int = 0
	for camera: Camera3D in component.cameras:
		if camera.current:
			current_count += 1
	assert_int(current_count).is_equal(1)


func test_signal_carries_the_newly_active_camera() -> void:
	var component: CameraSwitchComponent = _make_switch(2)
	component.next()
	assert_array(_activated).contains([component.cameras[0], component.cameras[1]])


func test_empty_list_is_a_no_op() -> void:
	var component: CameraSwitchComponent = _make_switch(0)
	component.next()
	component.activate(0)
	assert_object(component.active_camera()).is_null()
