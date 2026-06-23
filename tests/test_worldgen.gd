extends SceneTree

## Headless checks for the world generator. Run with:
##   godot --headless --script tests/test_worldgen.gd

const CONFIG_PATH: String = "res://src/world/levels/test_world/world_gen_config.tres"

var _failures: int = 0


func _init() -> void:
	var config: WorldGenConfig = load(CONFIG_PATH)
	_check(config != null, "config loads")

	var generator := PipelineWorldGenerator.new()

	_test_determinism(generator, config)
	_test_seed_changes_world(generator, config)
	_test_seam_free(generator, config)
	_test_ids_in_range(generator, config)

	if _failures == 0:
		print("worldgen: ALL TESTS PASSED")
	else:
		printerr("worldgen: %d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_determinism(generator: WorldGenerator, config: WorldGenConfig) -> void:
	var a: ChunkData = generator.generate_chunk(Vector2i(2, 3), config)
	var b: ChunkData = generator.generate_chunk(Vector2i(2, 3), config)
	_check(a.terrain_ids == b.terrain_ids, "same seed + chunk -> identical output")


func _test_seed_changes_world(generator: WorldGenerator, config: WorldGenConfig) -> void:
	var other: WorldGenConfig = config.duplicate(true)
	other.world_seed = config.world_seed + 1
	var a: ChunkData = generator.generate_chunk(Vector2i(2, 3), config)
	var b: ChunkData = generator.generate_chunk(Vector2i(2, 3), other)
	_check(a.terrain_ids != b.terrain_ids, "different seed -> different output")


func _test_seam_free(generator: WorldGenerator, config: WorldGenConfig) -> void:
	# The same global tile must classify identically regardless of how the world
	# is chunked. Compare a tile via chunk_size 32 vs a re-chunked size 16.
	var coarse: WorldGenConfig = config.duplicate(true)
	coarse.chunk_size = 32
	var fine: WorldGenConfig = config.duplicate(true)
	fine.chunk_size = 16

	# Global tile (40, 20): in coarse it's chunk (1,0) local (8,20);
	# in fine it's chunk (2,1) local (8,4).
	var coarse_chunk: ChunkData = generator.generate_chunk(Vector2i(1, 0), coarse)
	var fine_chunk: ChunkData = generator.generate_chunk(Vector2i(2, 1), fine)
	var coarse_id: int = coarse_chunk.get_id(8, 20)
	var fine_id: int = fine_chunk.get_id(8, 4)
	_check(coarse_id == fine_id, "tile is seam-free across chunk sizes")


func _test_ids_in_range(generator: WorldGenerator, config: WorldGenConfig) -> void:
	var max_id: int = config.terrain_catalog.max_id()
	var chunk: ChunkData = generator.generate_chunk(Vector2i(0, 0), config)
	var ok: bool = true
	for terrain_id: int in chunk.terrain_ids:
		if terrain_id < 0 or terrain_id > max_id:
			ok = false
			break
	_check(ok, "all terrain ids within catalog range")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		_failures += 1
		printerr("  FAIL: ", label)
