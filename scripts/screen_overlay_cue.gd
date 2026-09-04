extends Resource

class_name ScreenOverlayCue

## A timeline entry that instantiates one overlay effect at a given time.

@export_range(0.0, 3600.0, 0.01, "or_greater") var start_time := 0.0
@export var effect_scene: PackedScene
