class_name FogOverlay
extends Sprite2D

## Renders a FogState as a world-covering overlay. The reveal mask is a one-texel-
## per-tile R8 texture stretched over the world; a shader maps revealed -> alpha.
## Cheap for the GPU even at 1024x1024 and trivially swappable for another backend.

const FOG_SHADER: Shader = preload("res://libs/fog/fog.gdshader")

var _state: FogState
var _mask_image: Image
var _mask_texture: ImageTexture


func setup(state: FogState, tile_size_px: int) -> void:
	_state = state

	_mask_image = Image.create_empty(state.width, state.height, false, Image.FORMAT_R8)
	_mask_image.fill(Color(0, 0, 0))
	_mask_texture = ImageTexture.create_from_image(_mask_image)

	texture = _mask_texture
	centered = false
	position = Vector2.ZERO
	scale = Vector2.ONE * tile_size_px
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 100

	var fog_material := ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	material = fog_material

	state.region_revealed.connect(_on_region_revealed)


func _on_region_revealed(rect: Rect2i) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var value: float = 1.0 if _state.is_revealed(x, y) else 0.0
			_mask_image.set_pixel(x, y, Color(value, 0.0, 0.0))
	_mask_texture.update(_mask_image)
