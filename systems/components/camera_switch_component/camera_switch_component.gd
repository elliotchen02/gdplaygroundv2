@tool
class_name CameraSwitchComponent
extends Node

## Owns which of an ordered list of cameras is the active one.
##
## Attach as a child of the actor and populate `cameras` in order. The host
## drives it via `next()` or `activate()`; a viewport honours only one `current`
## camera, so activating one deactivates the rest on its own.

## A camera became the active one.
signal camera_activated(camera: Camera3D)

@export_group("Wiring")
## Cameras in switch order. Index 0 is active on ready.
@export var cameras: Array[Camera3D] = []

var _active_index: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not cameras.is_empty():
		activate(0)


## Makes the camera at `index` the current one. Out-of-range indices are ignored.
func activate(index: int) -> void:
	if index < 0 or index >= cameras.size():
		return
	var camera: Camera3D = cameras[index]
	if camera == null:
		return
	_active_index = index
	camera.current = true
	camera_activated.emit(camera)


## Advances to the next camera in the list, wrapping around.
func next() -> void:
	if cameras.is_empty():
		return
	activate(wrapi(_active_index + 1, 0, cameras.size()))


func active_camera() -> Camera3D:
	if cameras.is_empty():
		return null
	return cameras[_active_index]


func _get_configuration_warnings() -> PackedStringArray:
	if cameras.is_empty():
		return ["Assign at least one Camera3D to `cameras`."]
	for camera: Camera3D in cameras:
		if camera == null:
			return ["`cameras` contains an empty slot."]
	return []
