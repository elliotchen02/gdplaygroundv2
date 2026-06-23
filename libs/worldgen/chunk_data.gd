class_name ChunkData
extends RefCounted

## Immutable-ish result of generating one chunk: a flat grid of terrain ids.
## Flat PackedInt32Array is the contract boundary that a future C#/GDExtension
## generator would fill, keeping the rest of the pipeline language-agnostic.

var chunk_pos: Vector2i
var size: int
var terrain_ids: PackedInt32Array


func get_id(local_x: int, local_y: int) -> int:
	return terrain_ids[local_y * size + local_x]
