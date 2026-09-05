extends CanvasLayer

class_name TitleScreen

## A transparent title treatment that lets the first level remain visible behind
## it. Input is intentionally handled by InputController so the same title works
## with keyboard, mouse, touch, and controllers.

signal start_requested(source: int)
signal transition_completed(source: int)
signal start_completed(source: int)
signal exit_completed(source: int)

const DEFAULT_SOURCE := 0

@export var autoplay := true
@export_range(0.1, 2.0, 0.05) var entry_duration := 0.75
@export_range(0.0, 1.0, 0.05) var start_delay := 0.2
@export_range(0.1, 1.5, 0.05) var exit_duration := 0.5

@onready var _overlay: Control = $Overlay
@onready var _logo: TextureRect = $Overlay/Logo
@onready var _start: TextureRect = $Overlay/Start

var active := false
var start_locked := false
var _completed := false
var _start_source := DEFAULT_SOURCE
var _entry_tween: Tween
var _exit_tween: Tween
var _logo_final_position := Vector2.ZERO
var _start_final_position := Vector2.ZERO


func _ready() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if autoplay:
		show_title()


func show_title() -> void:
	if not is_instance_valid(_overlay):
		return
	if _entry_tween:
		_entry_tween.kill()
	if _exit_tween:
		_exit_tween.kill()
	_completed = false
	active = true
	start_locked = false
	visible = true
	_layout_elements()

	var viewport_size := get_viewport().get_visible_rect().size
	_logo.position = _logo_final_position + Vector2(-viewport_size.x - _logo.size.x, 0.0)
	_start.position = _start_final_position + Vector2(0.0, viewport_size.y + _start.size.y)
	_logo.modulate.a = 1.0
	_start.modulate.a = 1.0

	_entry_tween = create_tween().set_parallel()
	_entry_tween.tween_property(_logo, "position", _logo_final_position, entry_duration).set_trans(
		Tween.TRANS_QUAD,
	).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_property(_start, "position", _start_final_position, entry_duration).set_delay(start_delay).set_trans(
		Tween.TRANS_QUAD,
	).set_ease(Tween.EASE_OUT)


func request_start(source: int) -> bool:
	if not active or start_locked:
		return false
	start_locked = true
	_start_source = source
	start_requested.emit(source)

	if _entry_tween:
		_entry_tween.kill()
	if _exit_tween:
		_exit_tween.kill()
	_exit_tween = create_tween().set_parallel()
	_exit_tween.tween_property(
		_logo,
		"position",
		_logo_final_position + Vector2(-get_viewport().get_visible_rect().size.x - _logo.size.x, 0.0),
		exit_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_exit_tween.tween_property(
		_start,
		"position",
		_start_final_position + Vector2(0.0, get_viewport().get_visible_rect().size.y + _start.size.y),
		exit_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_exit_tween.finished.connect(_finish_transition)
	return true


func skip_to_gameplay(source := DEFAULT_SOURCE) -> bool:
	if _completed and not active:
		return false
	if _entry_tween:
		_entry_tween.kill()
	if _exit_tween:
		_exit_tween.kill()
	_start_source = source
	start_locked = false
	_finish_transition()
	return true


func is_active() -> bool:
	return active


func is_title_active() -> bool:
	return active


func is_start_locked() -> bool:
	return start_locked


func is_transitioning() -> bool:
	return active and start_locked


func get_start_source() -> int:
	return _start_source


func _finish_transition() -> void:
	if _completed:
		return
	_completed = true
	active = false
	start_locked = false
	visible = false
	transition_completed.emit(_start_source)
	start_completed.emit(_start_source)
	exit_completed.emit(_start_source)


func _layout_elements() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = Vector2(720.0, 1280.0)

	var logo_width := minf(viewport_size.x * 0.88, 620.0)
	var logo_ratio := float(_logo.texture.get_height()) / maxf(float(_logo.texture.get_width()), 1.0)
	_logo.size = Vector2(logo_width, logo_width * logo_ratio)
	_logo_final_position = Vector2(
		(viewport_size.x - _logo.size.x) * 0.5,
		viewport_size.y / 3.0 - _logo.size.y * 0.5,
	)

	var start_width := minf(viewport_size.x * 0.82, 570.0)
	var start_ratio := float(_start.texture.get_height()) / maxf(float(_start.texture.get_width()), 1.0)
	_start.size = Vector2(start_width, start_width * start_ratio)
	_start_final_position = Vector2(
		(viewport_size.x - _start.size.x) * 0.5,
		viewport_size.y * 0.69,
	)
