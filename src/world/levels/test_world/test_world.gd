extends Node2D

## Throwaway test harness for the worldgen + fog systems: WASD/arrows pan the
## camera, mouse wheel zooms, left-click reveals fog (and triggers generation).

const CAMERA_SPEED_PX_PER_S: float = 1200.0
const ZOOM_STEP: float = 1.1
const ZOOM_MIN: float = 0.05
const ZOOM_MAX: float = 4.0
const CLICK_REVEAL_RADIUS_TILES: int = 8
const SPAWN_REVEAL_RADIUS_TILES: int = 12

@onready var _chunk_manager: WorldChunkManager = $WorldChunkManager
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	var config: WorldGenConfig = _chunk_manager.config
	var center_tile: Vector2i = config.world_size_tiles / 2
	_camera.position = Vector2(center_tile) * config.tile_size_px
	_chunk_manager.reveal(center_tile, SPAWN_REVEAL_RADIUS_TILES)


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += direction * CAMERA_SPEED_PX_PER_S * delta / _camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_reveal_at_mouse()
			MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(1.0 / ZOOM_STEP)


func _reveal_at_mouse() -> void:
	var tile_size: int = _chunk_manager.config.tile_size_px
	var world_pos: Vector2 = get_global_mouse_position()
	var tile := Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))
	_chunk_manager.reveal(tile, CLICK_REVEAL_RADIUS_TILES)


func _apply_zoom(factor: float) -> void:
	var zoom_level: float = clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2.ONE * zoom_level
