extends SceneTree

## Headless checks for the WorldModel data layer. Run with:
##   godot --headless --path . --script tests/test_world_model.gd

const CONFIG_PATH: String = "res://src/world/levels/test_world/world_gen_config.tres"

var _failures: int = 0


func _init() -> void:
	var config: WorldGenConfig = load(CONFIG_PATH)
	var generator := PipelineWorldGenerator.new()

	var model := WorldModel.new(config.world_size_tiles)
	var expected_cells: int = config.world_size_tiles.x * config.world_size_tiles.y
	_check(model.terrain.size() == expected_cells, "model sized to world")
	_check(model.get_terrain(500, 500) == 0, "model starts zeroed")

	# Blit a chunk and confirm the model mirrors it exactly at the right offset.
	var chunk_pos := Vector2i(3, 2)
	var chunk: ChunkData = generator.generate_chunk(chunk_pos, config)
	model.blit_chunk(chunk)

	var origin: Vector2i = chunk_pos * config.chunk_size
	var matches: bool = true
	for local_y: int in config.chunk_size:
		for local_x: int in config.chunk_size:
			var expected: int = chunk.get_id(local_x, local_y)
			var actual: int = model.get_terrain(origin.x + local_x, origin.y + local_y)
			if expected != actual:
				matches = false
				break
	_check(matches, "blit_chunk mirrors chunk into model at correct offset")

	# A different region stays untouched.
	_check(model.get_terrain(0, 0) == 0, "unblitted region untouched")

	# Edge clamp: blitting the last chunk must not overrun the buffer.
	var last_chunk := Vector2i(
		config.world_size_tiles.x / config.chunk_size - 1,
		config.world_size_tiles.y / config.chunk_size - 1
	)
	var edge_chunk: ChunkData = generator.generate_chunk(last_chunk, config)
	model.blit_chunk(edge_chunk)
	_check(true, "edge blit completes without overrun")

	_check(model.in_bounds(0, 0) and not model.in_bounds(-1, 0), "in_bounds guards edges")

	if _failures == 0:
		print("world_model: ALL TESTS PASSED")
	else:
		printerr("world_model: %d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		_failures += 1
		printerr("  FAIL: ", label)
