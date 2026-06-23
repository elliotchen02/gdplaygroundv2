class_name PipelineWorldGenerator
extends WorldGenerator

## Default strategy: run the config's ordered list of passes over a fresh
## GenContext. Add capabilities (rivers, caves, ore) by adding passes, not by
## editing this class.


func generate_chunk(chunk_pos: Vector2i, config: WorldGenConfig) -> ChunkData:
	var context := GenContext.new(config, chunk_pos)
	for pass_step: WorldGenPass in config.passes:
		pass_step.apply(context)

	var chunk := ChunkData.new()
	chunk.chunk_pos = chunk_pos
	chunk.size = context.size
	chunk.terrain_ids = context.terrain_ids
	return chunk
