class_name TerrainDef
extends Resource

## Data-driven definition of a single terrain type.
## One source of truth for both rendering (color) and gameplay (walkable).

## Stable identifier used by generation passes and as the tile atlas column.
@export var id: int = 0
@export var display_name: String = ""
## Placeholder flat color; later swapped for real tile art.
@export var color: Color = Color.MAGENTA
@export var walkable: bool = true
