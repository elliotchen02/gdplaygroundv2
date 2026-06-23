class_name BiomeClassifyPass
extends WorldGenPass

## Maps (height, moisture) fields to terrain ids via simple thresholds. Swap this
## pass for a more advanced classifier (Whittaker diagram, etc.) without touching
## the rest of the pipeline.

@export var height_field: String = "height"
@export var moisture_field: String = "moisture"

@export var water_level: float = 0.32
@export var rock_level: float = 0.78
@export var dry_threshold: float = 0.40
@export var wet_threshold: float = 0.62

@export var water_id: int = 0
@export var sand_id: int = 1
@export var dirt_id: int = 2
@export var grass_id: int = 3
@export var rock_id: int = 4


func apply(context: GenContext) -> void:
	var height: PackedFloat32Array = context.get_field(height_field)
	var moisture: PackedFloat32Array = context.get_field(moisture_field)
	var ids: PackedInt32Array = context.terrain_ids

	for i: int in ids.size():
		var elevation: float = height[i]
		var wetness: float = moisture[i] if i < moisture.size() else 0.5

		var terrain_id: int = dirt_id
		if elevation < water_level:
			terrain_id = water_id
		elif elevation > rock_level:
			terrain_id = rock_id
		elif wetness < dry_threshold:
			terrain_id = sand_id
		elif wetness > wet_threshold:
			terrain_id = grass_id
		ids[i] = terrain_id

	context.terrain_ids = ids
