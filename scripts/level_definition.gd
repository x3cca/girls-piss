extends Resource

class_name LevelDefinition

## Stable metadata for an entry in the app's ordered level catalog.
@export var level_id: StringName = &""
@export var display_name := ""
@export var scene: PackedScene
@export_range(0, 999, 1) var progression_order := 0
