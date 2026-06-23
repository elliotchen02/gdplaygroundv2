class_name NoiseFieldPass
extends WorldGenPass

## Fills a named scalar field in [0, 1] from FastNoiseLite sampled at global tile
## coordinates. Reuse this pass with different field_name/seed_offset to produce
## independent fields (e.g. height, moisture, temperature).

@export var field_name: String = "height"
## Added to the world seed so distinct fields decorrelate.
@export var seed_offset: int = 0
@export var frequency: float = 0.008
@export var octaves: int = 4
@export var lacunarity: float = 2.0
@export var gain: float = 0.5


func apply(context: GenContext) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = context.config.world_seed + seed_offset
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = gain

	var field: PackedFloat32Array = context.make_field()
	for local_y: int in context.size:
		for local_x: int in context.size:
			var world_tile: Vector2i = context.world_tile(local_x, local_y)
			var raw: float = noise.get_noise_2d(world_tile.x, world_tile.y)
			field[context.index(local_x, local_y)] = raw * 0.5 + 0.5

	context.set_field(field_name, field)
