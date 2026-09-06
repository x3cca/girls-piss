extends Node2D

class_name PissMeter

signal depleted

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)
const METER_BOUNDS_RIGHT := 245.0
const METER_SLIDE_MARGIN := 24.0
const METER_SHOW_DURATION := 0.65

@export_range(1.0, 1800.0, 1.0) var duration_seconds := 30.0
## Stream-seconds recovered per real second while the stream is stopped.
@export_range(0.0, 10.0, 0.05) var recharge_rate := 1.0
@export var meter_position := Vector2(38.0, 1460.0)
@export_range(0.0, 1.0, 0.01) var starting_value := 1.0

var input_controller: InputController
var stream: LiquidStream
var gameplay_active := false
var time_remaining := 0.0
var _depletion_announced := false

@onready var _fill: TextureProgressBar = $Fill
@onready var _liquid: TextureRect = $Liquid
@onready var _frame: Sprite2D = $Frame
@onready var _lemon: Sprite2D = $Lemon
@onready var _drip_one: Sprite2D = $DripOne
@onready var _drip_two: Sprite2D = $DripTwo
var _layout_signature := Vector2.ZERO
var _rest_position := Vector2.ZERO
var _hidden_position := Vector2.ZERO
var _meter_revealed := false
var _show_tween: Tween
var _wired_input_controller: InputController


func _ready() -> void:
	time_remaining = duration_seconds * clampf(starting_value, 0.0, 1.0)
	_layout()
	_update_fill()
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	_layout()
	_wire_input_controller()
	if (
			gameplay_active
			and is_instance_valid(input_controller)
			and input_controller.is_stream_input_held()
	):
		_reveal_meter()
	if not gameplay_active or input_controller == null:
		return
	var safe_delta := maxf(delta, 0.0)
	var stream_input_held := input_controller.is_stream_input_held()
	var stream_enabled := stream == null or stream.is_live_enabled()
	if stream_input_held and stream_enabled:
		if time_remaining <= 0.0:
			_announce_depletion()
			return
		time_remaining = maxf(time_remaining - safe_delta, 0.0)
	else:
		# Releasing the stream, including the forced release after depletion, lets
		# the player build the meter back up for the next hold.
		time_remaining = minf(
			duration_seconds,
			time_remaining + safe_delta * maxf(recharge_rate, 0.0),
		)
		if time_remaining > 0.0:
			_depletion_announced = false
	_update_fill()
	if time_remaining <= 0.0:
		_announce_depletion()


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	_wire_input_controller()
	if not active:
		_hide_meter()


func reset_meter() -> void:
	time_remaining = duration_seconds * clampf(starting_value, 0.0, 1.0)
	_depletion_announced = false
	_update_fill()
	_hide_meter()


func get_time_remaining() -> float:
	return time_remaining


func get_progress() -> float:
	return clampf(time_remaining / maxf(duration_seconds, 0.001), 0.0, 1.0)


func is_depleted() -> bool:
	return time_remaining <= 0.0


func _announce_depletion() -> void:
	if _depletion_announced:
		return
	_depletion_announced = true
	_update_fill()
	depleted.emit()


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
	_rest_position = meter_position * composition_scale
	_hidden_position = Vector2(
		-(METER_BOUNDS_RIGHT + METER_SLIDE_MARGIN) * composition_scale.x,
		_rest_position.y,
	)
	position = _rest_position if _meter_revealed else _hidden_position
	scale = composition_scale


func _wire_input_controller() -> void:
	if input_controller == _wired_input_controller:
		return
	if is_instance_valid(_wired_input_controller) and _wired_input_controller.stream_hold_changed.is_connected(
		_on_stream_hold_changed,
	):
		_wired_input_controller.stream_hold_changed.disconnect(_on_stream_hold_changed)
	_wired_input_controller = input_controller
	if is_instance_valid(_wired_input_controller) and not _wired_input_controller.stream_hold_changed.is_connected(
		_on_stream_hold_changed,
	):
		_wired_input_controller.stream_hold_changed.connect(_on_stream_hold_changed)


func _on_stream_hold_changed(active: bool) -> void:
	if active and gameplay_active:
		_reveal_meter()


func _reveal_meter() -> void:
	if _meter_revealed:
		return
	_meter_revealed = true
	visible = true
	position = _hidden_position
	if _show_tween:
		_show_tween.kill()
	_show_tween = create_tween()
	_show_tween.tween_property(
		self,
		"position",
		_rest_position,
		METER_SHOW_DURATION,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_meter() -> void:
	_meter_revealed = false
	if _show_tween:
		_show_tween.kill()
		_show_tween = null
	visible = false
	position = _hidden_position
