extends Node2D

class_name PissMeter

signal depleted

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)

@export_range(1.0, 1800.0, 1.0) var duration_seconds := 60.0
@export var meter_position := Vector2(38.0, 1400.0)
@export_range(0.0, 1.0, 0.01) var starting_value := 1.0

var input_controller: InputController
var stream: LiquidStream
var gameplay_active := false
var time_remaining := 0.0

@onready var _fill: TextureProgressBar = $Fill
@onready var _liquid: TextureRect = $Liquid
@onready var _frame: Sprite2D = $Frame
@onready var _lemon: Sprite2D = $Lemon
@onready var _drip_one: Sprite2D = $DripOne
@onready var _drip_two: Sprite2D = $DripTwo
var _layout_signature := Vector2.ZERO


func _ready() -> void:
	time_remaining = duration_seconds * clampf(starting_value, 0.0, 1.0)
	_layout()
	_update_fill()
	set_process(true)


func _process(delta: float) -> void:
	_layout()
	if not gameplay_active or input_controller == null:
		return
	if not input_controller.is_stream_input_held():
		return
	if stream != null and not stream.is_live_enabled():
		return
	if time_remaining <= 0.0:
		return
	time_remaining = maxf(time_remaining - maxf(delta, 0.0), 0.0)
	_update_fill()
	if time_remaining <= 0.0:
		depleted.emit()


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active


func reset_meter() -> void:
	time_remaining = duration_seconds * clampf(starting_value, 0.0, 1.0)
	_update_fill()


func get_time_remaining() -> float:
	return time_remaining


func get_progress() -> float:
	return clampf(time_remaining / maxf(duration_seconds, 0.001), 0.0, 1.0)


func is_depleted() -> bool:
	return time_remaining <= 0.0


func _update_fill() -> void:
	var progress := get_progress()
	if is_instance_valid(_fill):
		_fill.value = progress
	if is_instance_valid(_liquid):
		var liquid_material := _liquid.material as ShaderMaterial
		if liquid_material:
			liquid_material.set_shader_parameter("fluid_amount", progress)


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if viewport_size == _layout_signature:
		return
	_layout_signature = viewport_size
	var composition_scale := Vector2(
		viewport_size.x / REFERENCE_SIZE.x,
		viewport_size.y / REFERENCE_SIZE.y,
	)
	position = meter_position * composition_scale
	scale = composition_scale
