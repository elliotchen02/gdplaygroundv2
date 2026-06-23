class_name TerrainCatalog
extends Resource

## Registry of every terrain type in a world. Swap the catalog (or edit its
## entries) to re-theme a biome without touching generation or rendering code.

@export var terrains: Array[TerrainDef] = []


func get_def(terrain_id: int) -> TerrainDef:
	for terrain_def: TerrainDef in terrains:
		if terrain_def.id == terrain_id:
			return terrain_def
	return null


func count() -> int:
	return terrains.size()


## Highest id present; used to size the generated tile atlas.
func max_id() -> int:
	var highest: int = 0
	for terrain_def: TerrainDef in terrains:
		highest = maxi(highest, terrain_def.id)
	return highest
