class_name WorldChunkManager
extends Node

## Game-side composer wiring worldgen + model + fog + view to the scene tree.
##
## Architecture: chunks are generated on worker threads (pure data, no node/scene
## access), pushed onto a mutex-guarded queue, then drained on the main thread to
## blit into the authoritative WorldModel and paint the TileMapLayer view. The
## model is written on the main thread only, so there are no cross-thread writes
## (and no copy-on-write races) on its buffers. Generation is lazy: only chunks
## touched by fog reveals are ever produced.

@export var config: WorldGenConfig
@export var terrain_layer_path: NodePath
@export var fog_overlay_path: NodePath

## Source of truth for the world; simulation systems read/write this.
var model: WorldModel
var fog_state: FogState

var _generator: WorldGenerator
var _renderer: TerrainRenderer
var _terrain_layer: TileMapLayer
var _fog_overlay: FogOverlay

## chunk_pos -> true once submitted (dedupes generation across reveals).
var _requested_chunks: Dictionary = {}
var _result_mutex: Mutex
var _pending_results: Array[ChunkData] = []
var _active_task_ids: Array[int] = []


func _ready() -> void:
	assert(config != null, "WorldChunkManager requires a WorldGenConfig")
	_terrain_layer = get_node(terrain_layer_path)
	_fog_overlay = get_node(fog_overlay_path)

	_generator = PipelineWorldGenerator.new()
	_renderer = TerrainRenderer.new()
	_terrain_layer.tile_set = TileSetBuilder.build(config.terrain_catalog, config.tile_size_px)

	model = WorldModel.new(config.world_size_tiles)
	_result_mutex = Mutex.new()

	fog_state = FogState.new(config.world_size_tiles)
	_fog_overlay.setup(fog_state, config.tile_size_px)
	fog_state.region_revealed.connect(_on_region_revealed)


func _exit_tree() -> void:
	# Drain workers before the shared queue/model can be freed.
	for task_id: int in _active_task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)
	_active_task_ids.clear()


func _process(_delta: float) -> void:
	if _pending_results.is_empty():
		return
	_result_mutex.lock()
	var ready_chunks: Array[ChunkData] = _pending_results
	_pending_results = []
	_result_mutex.unlock()

	for chunk: ChunkData in ready_chunks:
		model.blit_chunk(chunk)
		_renderer.paint_chunk(_terrain_layer, model, chunk.chunk_pos, config.chunk_size)


## Reveal an explored area; terrain for newly touched chunks is queued for
## generation on worker threads.
func reveal(center_tile: Vector2i, radius_tiles: int) -> void:
	fog_state.reveal_circle(center_tile, radius_tiles)


func _on_region_revealed(rect: Rect2i) -> void:
	var chunk_size: int = config.chunk_size
	var first_chunk := Vector2i(
		floori(rect.position.x / float(chunk_size)), floori(rect.position.y / float(chunk_size))
	)
	var last_chunk := Vector2i(
		floori((rect.end.x - 1) / float(chunk_size)), floori((rect.end.y - 1) / float(chunk_size))
	)

	for chunk_y: int in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x: int in range(first_chunk.x, last_chunk.x + 1):
			_request_chunk(Vector2i(chunk_x, chunk_y))


func _request_chunk(chunk_pos: Vector2i) -> void:
	if _requested_chunks.has(chunk_pos):
		return
	if not _is_chunk_in_world(chunk_pos):
		return
	_requested_chunks[chunk_pos] = true
	var task_id: int = WorkerThreadPool.add_task(_generate_chunk_task.bind(chunk_pos))
	_active_task_ids.append(task_id)


## Runs on a worker thread. Touches only pure data (config is read-only, passes
## are stateless), never the scene tree.
func _generate_chunk_task(chunk_pos: Vector2i) -> void:
	var chunk: ChunkData = _generator.generate_chunk(chunk_pos, config)
	_result_mutex.lock()
	_pending_results.append(chunk)
	_result_mutex.unlock()


func _is_chunk_in_world(chunk_pos: Vector2i) -> bool:
	if chunk_pos.x < 0 or chunk_pos.y < 0:
		return false
	var origin: Vector2i = chunk_pos * config.chunk_size
	return origin.x < config.world_size_tiles.x and origin.y < config.world_size_tiles.y
