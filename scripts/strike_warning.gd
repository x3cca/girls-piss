extends Control

class_name StrikeWarning

## Immediate, short-lived warning bubbles for the first three mistakes.
##
## The warning art is intentionally kept as three independently visible panels:
## the red treatment has a different text layout from the yellow and orange
## treatments, and direct visibility changes make the feedback appear on the
## same frame as the strike. The artwork and child alignment live in the three
## standalone warning scenes; this controller only places and scales each scene.

const YELLOW_WARNING := 1
const ORANGE_WARNING := 2
const RED_WARNING := 3

@export_range(0.0, 10.0, 0.01) var warning_duration := 4.0
@export_range(0.0, 0.2, 0.005) var right_margin_ratio := 0.035
@export_range(0.2, 0.6, 0.01) var bubble_width_ratio := 0.44
@export_range(180.0, 480.0, 1.0) var max_bubble_width := 360.0
@export_range(0.1, 1.0, 0.01) var min_bubble_width := 220.0
@export_range(0.05, 1.0, 0.01) var entrance_shake_duration := 0.28
@export_range(0.0, 80.0, 1.0) var entrance_shake_amplitude := 26.0
@export_range(0.0, 0.2, 0.005) var entrance_shake_rotation := 0.035

@onready var yellow_warning: Control = $YellowWarning
@onready var orange_warning: Control = $OrangeWarning
@onready var red_warning: Control = $RedWarning
@onready var _light_pounds: AudioStreamPlayer = $LightPounds
@onready var _medium_pounds: AudioStreamPlayer = $MediumPounds
@onready var _heavy_pounds: AudioStreamPlayer = $HeavyPounds

var _active_warning := 0
var _remaining := 0.0
var _shake_elapsed := 0.0
var _shake_offset := Vector2.ZERO
var _shake_rotation := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	hide_warning()
	_layout_warnings()


func _process(delta: float) -> void:
	process_frame(delta)


func process_frame(delta: float) -> void:
	_advance_entrance_shake(maxf(delta, 0.0))
	_layout_warnings()
	if _active_warning == 0:
		return
	_remaining = maxf(_remaining - maxf(delta, 0.0), 0.0)
	if is_zero_approx(_remaining):
		_remaining = 0.0
		hide_warning()


func show_warning(strike: int, duration := -1.0) -> void:
	hide_warning()
	if strike < YELLOW_WARNING or strike > RED_WARNING:
		return
	_active_warning = strike
	_remaining = warning_duration if duration < 0.0 else maxf(duration, 0.0)
	_warning_for(strike).visible = true
	_play_pounding_warning(strike)
	_start_entrance_shake()
	_layout_warnings()
	if _remaining <= 0.0:
		hide_warning()


func hide_warning() -> void:
	_active_warning = 0
	_remaining = 0.0
	_stop_pounding_warnings()
	_reset_entrance_shake()
	if is_instance_valid(yellow_warning):
		yellow_warning.visible = false
	if is_instance_valid(orange_warning):
		orange_warning.visible = false
	if is_instance_valid(red_warning):
		red_warning.visible = false


func get_active_warning() -> int:
	return _active_warning


func get_remaining_duration() -> float:
	return _remaining


func is_warning_visible(strike: int) -> bool:
	return strike == _active_warning and is_instance_valid(_warning_for(strike)) and _warning_for(strike).visible


func get_warning_assets(strike: int) -> Dictionary:
	## Exposes the authored selection so tests and future HUD tooling can inspect it.
	match strike:
		YELLOW_WARNING:
			return {
				"bubble": $YellowWarning/Bubble.texture,
				"text": $YellowWarning/Text.texture,
			}
		ORANGE_WARNING:
			return {
				"bubble": $OrangeWarning/Bubble.texture,
				"text": $OrangeWarning/Text.texture,
			}
		RED_WARNING:
			return {
				"bubble": $RedWarning/Bubble.texture,
				"text": $RedWarning/RedText1.texture,
				"row": [
					$RedWarning/RedTextRow/RedText2.texture,
					$RedWarning/RedTextRow/RedText3.texture,
				],
				"emergency": $RedWarning/RedText4.texture,
			}
	return { }


func get_warning_rect(strike: int) -> Rect2:
	var warning := _warning_for(strike)
	if not is_instance_valid(warning):
		return Rect2()
	return Rect2(warning.position, warning.size * warning.scale)


func _warning_for(strike: int) -> Control:
	match strike:
		YELLOW_WARNING:
			return yellow_warning
		ORANGE_WARNING:
			return orange_warning
		RED_WARNING:
			return red_warning
	return null


func _play_pounding_warning(strike: int) -> void:
	var player := _pounding_player_for(strike)
	if is_instance_valid(player):
		player.play()


func _stop_pounding_warnings() -> void:
	for player in [_light_pounds, _medium_pounds, _heavy_pounds]:
		if is_instance_valid(player):
			player.stop()


func _pounding_player_for(strike: int) -> AudioStreamPlayer:
	match strike:
		YELLOW_WARNING:
			return _light_pounds
		ORANGE_WARNING:
			return _medium_pounds
		RED_WARNING:
			return _heavy_pounds
	return null


func _layout_warnings() -> void:
	if not is_instance_valid(yellow_warning):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var bubble_width := clampf(
		viewport_size.x * bubble_width_ratio,
		min_bubble_width,
		max_bubble_width,
	)
	var right_margin := maxf(viewport_size.x * right_margin_ratio, 16.0)
	var right_position := viewport_size.x - right_margin - bubble_width

	_layout_warning(yellow_warning, right_position, bubble_width, viewport_size.y)
	_layout_warning(orange_warning, right_position, bubble_width, viewport_size.y)
	_layout_warning(red_warning, right_position, bubble_width, viewport_size.y)


func _layout_warning(warning: Control, right_position: float, width: float, viewport_height: float) -> void:
	if not is_instance_valid(warning) or warning.size.x <= 1.0:
		return
	var is_active := warning == _warning_for(_active_warning)
	var scale_factor := width / warning.size.x
	var centered_y := (viewport_height - warning.size.y * scale_factor) * 0.5
	warning.position = Vector2(right_position, centered_y) + (_shake_offset if is_active else Vector2.ZERO)
	warning.scale = Vector2.ONE * scale_factor
	warning.pivot_offset = warning.size * 0.5
	warning.rotation = _shake_rotation if is_active else 0.0


func _start_entrance_shake() -> void:
	_shake_elapsed = 0.0
	_apply_entrance_shake()


func _advance_entrance_shake(delta: float) -> void:
	if _shake_elapsed >= entrance_shake_duration:
		return
	_shake_elapsed = minf(_shake_elapsed + delta, entrance_shake_duration)
	_apply_entrance_shake()


func _apply_entrance_shake() -> void:
	if entrance_shake_duration <= 0.0 or _shake_elapsed >= entrance_shake_duration:
		_reset_entrance_shake()
		return
	var progress := clampf(_shake_elapsed / entrance_shake_duration, 0.0, 1.0)
	var envelope := pow(1.0 - progress, 2.2)
	var horizontal_wave := sin(progress * TAU * 4.5 + PI * 0.5)
	var vertical_wave := sin(progress * TAU * 6.0)
	_shake_offset = Vector2(horizontal_wave, vertical_wave * 0.65) * entrance_shake_amplitude * envelope
	_shake_rotation = sin(progress * TAU * 5.0 + PI * 0.5) * entrance_shake_rotation * envelope


func _reset_entrance_shake() -> void:
	_shake_elapsed = entrance_shake_duration
	_shake_offset = Vector2.ZERO
	_shake_rotation = 0.0
