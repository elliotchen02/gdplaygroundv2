class_name FogState
extends RefCounted

## Persistent "explored" fog: once a tile is revealed it stays revealed. Pure
## data + signals; rendering lives in FogOverlay so the backend is swappable.

## Emitted with the bounding rect of changed tiles so renderers update minimally.
signal region_revealed(rect: Rect2i)

var width: int
var height: int

var _revealed: PackedByteArray


func _init(size_tiles: Vector2i) -> void:
	width = size_tiles.x
	height = size_tiles.y
	_revealed = PackedByteArray()
	_revealed.resize(width * height)


func is_revealed(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	return _revealed[y * width + x] != 0


func reveal_rect(rect: Rect2i) -> void:
	var clamped: Rect2i = rect.intersection(Rect2i(0, 0, width, height))
	if not clamped.has_area():
		return
	for y: int in range(clamped.position.y, clamped.end.y):
		for x: int in range(clamped.position.x, clamped.end.x):
			_revealed[y * width + x] = 1
	region_revealed.emit(clamped)


func reveal_circle(center_tile: Vector2i, radius_tiles: int) -> void:
	var bounds := Rect2i(
		center_tile - Vector2i(radius_tiles, radius_tiles), Vector2i.ONE * (radius_tiles * 2 + 1)
	)
	var clamped: Rect2i = bounds.intersection(Rect2i(0, 0, width, height))
	if not clamped.has_area():
		return
	var radius_sq: int = radius_tiles * radius_tiles
	for y: int in range(clamped.position.y, clamped.end.y):
		for x: int in range(clamped.position.x, clamped.end.x):
			var offset: Vector2i = Vector2i(x, y) - center_tile
			if offset.x * offset.x + offset.y * offset.y <= radius_sq:
				_revealed[y * width + x] = 1
	region_revealed.emit(clamped)
