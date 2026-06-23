extends SceneTree

## Dev-only: render a region of the generated world to a PNG (one pixel per tile,
## colored by the terrain catalog) so generation can be eyeballed without the
## rendering server. Run with:
##   godot --headless --path . --script hack/preview_worldgen.gd

const CONFIG_PATH: String = "res://src/world/levels/test_world/world_gen_config.tres"
const OUTPUT_PATH: String = "res://hack/worldgen_preview.png"
## How many chunks per side to render into the preview.
const CHUNKS_PER_SIDE: int = 8


func _init() -> void:
	var config: WorldGenConfig = load(CONFIG_PATH)
	var generator := PipelineWorldGenerator.new()

	var chunk_size: int = config.chunk_size
	var pixels_per_side: int = CHUNKS_PER_SIDE * chunk_size
	var image: Image = Image.create_empty(
		pixels_per_side, pixels_per_side, false, Image.FORMAT_RGBA8
	)

	for chunk_y: int in CHUNKS_PER_SIDE:
		for chunk_x: int in CHUNKS_PER_SIDE:
			var chunk: ChunkData = generator.generate_chunk(Vector2i(chunk_x, chunk_y), config)
			for local_y: int in chunk_size:
				for local_x: int in chunk_size:
					var terrain_id: int = chunk.get_id(local_x, local_y)
					var terrain_def: TerrainDef = config.terrain_catalog.get_def(terrain_id)
					var px: int = chunk_x * chunk_size + local_x
					var py: int = chunk_y * chunk_size + local_y
					image.set_pixel(px, py, terrain_def.color)

	var error: int = image.save_png(OUTPUT_PATH)
	if error == OK:
		print("preview saved: %s (%dx%d tiles)" % [OUTPUT_PATH, pixels_per_side, pixels_per_side])
	else:
		printerr("failed to save preview: %d" % error)
	quit(0 if error == OK else 1)
