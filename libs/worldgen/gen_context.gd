class_name GenContext
extends RefCounted

## Mutable scratchpad shared across a single chunk's generation passes. Passes
## write scalar fields (e.g. "height", "moisture") and ultimately terrain_ids.

var config: WorldGenConfig
var chunk_pos: Vector2i
## Tiles per side.
var size: int
## Tile coordinate of this chunk's top-left corner.
var origin: Vector2i
var terrain_ids: PackedInt32Array

var _fields: Dictionary = {}


func _init(p_config: WorldGenConfig, p_chunk_pos: Vector2i) -> void:
	config = p_config
	chunk_pos = p_chunk_pos
	size = p_config.chunk_size
	origin = p_chunk_pos * size
	terrain_ids = PackedInt32Array()
	terrain_ids.resize(size * size)


func index(local_x: int, local_y: int) -> int:
	return local_y * size + local_x


## Global tile coordinate for a local cell. Position-based noise keyed on this is
## what makes chunks seamless regardless of chunk size or generation order.
func world_tile(local_x: int, local_y: int) -> Vector2i:
	return origin + Vector2i(local_x, local_y)


func make_field() -> PackedFloat32Array:
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(size * size)
	return field


func set_field(field_name: String, values: PackedFloat32Array) -> void:
	_fields[field_name] = values


func get_field(field_name: String) -> PackedFloat32Array:
	return _fields.get(field_name, PackedFloat32Array())
