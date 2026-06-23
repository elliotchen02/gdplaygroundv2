@abstract class_name WorldGenerator
extends RefCounted

## Contract for turning a chunk coordinate into terrain data. This is the single
## swap point for performance work: reimplement as C#/GDExtension if profiling
## ever requires it, with no changes to callers.

@abstract func generate_chunk(chunk_pos: Vector2i, config: WorldGenConfig) -> ChunkData
