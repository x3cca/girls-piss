extends Node
class_name PressureModel

signal exhaustion_changed(exhausted: bool)

@export_range(0.15, 1.0, 0.01) var requested_pressure := 0.55
@export_range(0.0, 1.0, 0.01) var reserve := 1.0
@export var regeneration_rate := 0.18
@export var drain_rate := 0.22
@export var recovery_unlock := 0.30

var effective_pressure := 0.55
var exhausted := false

func _process(delta: float) -> void:
	requested_pressure = clampf(requested_pressure, 0.15, 1.0)
	# Exhaustion is a recovery state: the reserve must refill even if the player
	# keeps holding maximum pressure, otherwise the hysteresis unlock could never
	# be reached.
	if exhausted or requested_pressure <= 0.55:
		reserve = minf(1.0, reserve + regeneration_rate * delta)
	else:
		var overdrive := inverse_lerp(0.55, 1.0, requested_pressure)
		reserve = maxf(0.0, reserve - overdrive * drain_rate * delta)

	if not exhausted and reserve <= 0.0:
		exhausted = true
		effective_pressure = 0.25
		exhaustion_changed.emit(true)
	elif exhausted and reserve >= recovery_unlock:
		exhausted = false
		exhaustion_changed.emit(false)

	effective_pressure = 0.25 if exhausted else requested_pressure
