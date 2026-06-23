class_name WorldGenConfig
extends Resource

## All tuning for a world in one swappable resource. Create a new .tres to make a
## new world archetype; nothing here is hard-coded in logic.

## Master seed; every pass derives its own seed from this for reproducibility.
@export var world_seed: int = 1337
## Bounded world dimensions, in tiles.
@export var world_size_tiles: Vector2i = Vector2i(1024, 1024)
## Tiles per side of a generation chunk (the unit generated at once).
@export var chunk_size: int = 32
## On-screen size of one tile, in pixels.
@export var tile_size_px: int = 64
@export var terrain_catalog: TerrainCatalog
## Ordered generation pipeline; runs front-to-back per chunk.
@export var passes: Array[WorldGenPass] = []
