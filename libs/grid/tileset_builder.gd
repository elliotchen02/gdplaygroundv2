class_name TileSetBuilder
extends RefCounted

## Builds a TileSet at runtime from a TerrainCatalog by painting one solid-color
## tile per terrain into a generated atlas. Avoids the editor import pipeline so
## placeholder art is fully data-driven (change a color in the catalog, done).
##
## Atlas layout: terrain with id N occupies atlas cell (N, 0).

const SOURCE_ID: int = 0


static func build(catalog: TerrainCatalog, tile_size_px: int) -> TileSet:
	var columns: int = catalog.max_id() + 1
	var atlas_image: Image = Image.create_empty(
		columns * tile_size_px, tile_size_px, false, Image.FORMAT_RGBA8
	)
	atlas_image.fill(Color(0, 0, 0, 0))

	for terrain_def: TerrainDef in catalog.terrains:
		var cell_rect := Rect2i(terrain_def.id * tile_size_px, 0, tile_size_px, tile_size_px)
		atlas_image.fill_rect(cell_rect, terrain_def.color)

	var atlas_texture: ImageTexture = ImageTexture.create_from_image(atlas_image)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = atlas_texture
	atlas_source.texture_region_size = Vector2i(tile_size_px, tile_size_px)
	for terrain_def: TerrainDef in catalog.terrains:
		atlas_source.create_tile(Vector2i(terrain_def.id, 0))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size_px, tile_size_px)
	tile_set.add_source(atlas_source, SOURCE_ID)
	return tile_set
