extends Node

class_name PressureModel

@export_range(0.15, 1.0, 0.01) var requested_pressure := 0.55

var effective_pressure := 0.55


func _process(delta: float) -> void:
	advance(delta)


## Applies the requested pressure immediately. There is intentionally no reserve,
## exhaustion, recovery, or other resource limit in this slice.
func advance(_delta: float) -> void:
	requested_pressure = clampf(requested_pressure, 0.15, 1.0)
	effective_pressure = requested_pressure
