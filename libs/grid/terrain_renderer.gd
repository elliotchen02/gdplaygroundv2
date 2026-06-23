class_name TerrainRenderer
extends RefCounted

## View updater: reflects a region of the WorldModel into a TileMapLayer. The
## model is the source of truth; this only mirrors it for display. Terrain id
## maps directly to the atlas column produced by TileSetBuilder.


## Paint one chunk-sized region of the model into the layer.
func paint_chunk(
	layer: TileMapLayer, model: WorldModel, chunk_pos: Vector2i, chunk_size: int
) -> void:
	var origin: Vector2i = chunk_pos * chunk_size
	for local_y: int in chunk_size:
		var world_y: int = origin.y + local_y
		if world_y >= model.height:
			break
		for local_x: int in chunk_size:
			var world_x: int = origin.x + local_x
			if world_x >= model.width:
				break
			var terrain_id: int = model.terrain[world_y * model.width + world_x]
			layer.set_cell(
				Vector2i(world_x, world_y), TileSetBuilder.SOURCE_ID, Vector2i(terrain_id, 0)
			)
