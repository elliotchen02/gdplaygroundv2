class_name WorldModel
extends RefCounted

## Authoritative, queryable source of truth for the world. Structure-of-Arrays:
## one flat, cache-friendly buffer per attribute over the bounded world. This is
## the data layer simulation systems read/write (and that worker threads may
## touch, unlike the scene tree). The TileMapLayer is only a view of this.
##
## Add new simulated attributes as sibling flat arrays (elevation, temperature,
## fertility, occupancy, ...) sized width * height and indexed via index(x, y).

var width: int
var height: int

## Terrain type id per tile (ids are < 256).
var terrain: PackedByteArray


func _init(size_tiles: Vector2i) -> void:
	width = size_tiles.x
	height = size_tiles.y
	terrain = PackedByteArray()
	terrain.resize(width * height)


func index(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_terrain(x: int, y: int) -> int:
	return terrain[y * width + x]


func set_terrain(x: int, y: int, terrain_id: int) -> void:
	terrain[y * width + x] = terrain_id


## Copy a generated chunk's terrain into the model. Main-thread only.
func blit_chunk(chunk: ChunkData) -> void:
	var origin: Vector2i = chunk.chunk_pos * chunk.size
	for local_y: int in chunk.size:
		var world_y: int = origin.y + local_y
		if world_y >= height:
			break
		var dest_row: int = world_y * width + origin.x
		var src_row: int = local_y * chunk.size
		var columns: int = mini(chunk.size, width - origin.x)
		for local_x: int in columns:
			terrain[dest_row + local_x] = chunk.terrain_ids[src_row + local_x]
