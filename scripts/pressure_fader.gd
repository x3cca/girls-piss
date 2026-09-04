extends Control

class_name PressureFader

## Scene-authored pressure visual. InputController continues to own the left
## touch index and pressure mapping so two-finger touch behavior stays intact.

@export_range(0.15, 1.0, 0.01) var minimum_pressure := 0.15
@export_range(0.15, 1.0, 0.01) var maximum_pressure := 1.0

var pressure := 0.55:
	set(value):
		pressure = clampf(value, minimum_pressure, maximum_pressure)
		_apply_visual()

var _track_top := 178.0
var _track_bottom := 600.0
var _track_x := 72.0

@onready var _track_glow: ColorRect = $TrackGlow
@onready var _track: ColorRect = $Track
@onready var _fill: ColorRect = $Fill
@onready var _knob: Panel = $Knob
@onready var _label: Label = $Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_visual()


func set_pressure(value: float) -> void:
	pressure = value


func set_track_bounds(top: float, bottom: float, x: float = 72.0) -> void:
	_track_top = minf(top, bottom)
	_track_bottom = maxf(top, bottom)
	_track_x = x
	_apply_visual()


func _apply_visual() -> void:
	if not is_instance_valid(_track):
		return
	var knob_y := lerpf(_track_bottom, _track_top, inverse_lerp(
		minimum_pressure,
		maximum_pressure,
		pressure,
	))
	_track_glow.position = Vector2(_track_x - 9.0, _track_top)
	_track_glow.size = Vector2(18.0, maxf(_track_bottom - _track_top, 1.0))
	_track.position = Vector2(_track_x - 2.0, _track_top)
	_track.size = Vector2(4.0, maxf(_track_bottom - _track_top, 1.0))
	_fill.position = Vector2(_track_x - 2.0, knob_y)
	_fill.size = Vector2(4.0, maxf(_track_bottom - knob_y, 1.0))
	_knob.position = Vector2(_track_x - _knob.size.x * 0.5, knob_y - _knob.size.y * 0.5)
	_label.position = Vector2(_track_x - 35.0, _track_top - 30.0)
