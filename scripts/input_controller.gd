extends Node

class_name InputController

## Unified desktop/touch input for the portrait prototype.
## WASD moves one crosshair target, a single touch places that target directly,
## and Space/holding a touch gates the stream. The stream owns the easing from
## this target to the actual shot endpoint.

signal aim_target_changed(position: Vector2)
signal touch_target_changed(position: Vector2, active: bool)

@export var target_move_speed := 620.0

var target_position := Vector2.ZERO
var input_mode := "desktop"
var touch_controls_visible := false

var _touch_index := -1
var _touch_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _move_left_pressed := false
var _move_right_pressed := false
var _move_up_pressed := false
var _move_down_pressed := false
var _space_pressed := false
var _pissing := false


func _ready() -> void:
	# DisplayServer reports false on desktop and in headless checks. The visual
	# touch reticle is still useful on desktop as the keyboard-controlled aimer.
	touch_controls_visible = DisplayServer.is_touchscreen_available()
	input_mode = "touch" if touch_controls_visible else "desktop"
	_target_position = _default_target_position()
	target_position = _target_position
	aim_target_changed.emit(target_position)


func _process(delta: float) -> void:
	process_frame(delta)


func process_frame(delta: float) -> void:
	if _touch_index == -1:
		var movement := Vector2(
			float(_move_right_pressed) - float(_move_left_pressed),
			float(_move_down_pressed) - float(_move_up_pressed),
		)
		if movement.length_squared() > 1.0:
			movement = movement.normalized()
		if movement.length_squared() > 0.0:
			set_target_position(_target_position + movement * target_move_speed * delta)

	var clamped_target := _clamp_target(_target_position)
	if clamped_target != _target_position:
		_target_position = clamped_target
	if target_position != _target_position:
		target_position = _target_position
		aim_target_changed.emit(target_position)


func _input(event: InputEvent) -> void:
	handle_input_event(event)


func handle_input_event(event: InputEvent) -> void:
	if event is InputEventKey:
		_update_keyboard_state(event as InputEventKey)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_claim_touch(touch.index, touch.position)
		else:
			_release_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_touch_target(drag.position)


func _update_keyboard_state(event: InputEventKey) -> void:
	if event.echo:
		return
	var key_code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key_code:
		KEY_A:
			_move_left_pressed = event.pressed
		KEY_D:
			_move_right_pressed = event.pressed
		KEY_W:
			_move_up_pressed = event.pressed
		KEY_S:
			_move_down_pressed = event.pressed
		KEY_SPACE:
			_space_pressed = event.pressed
	_update_pissing()


func set_target_position(position: Vector2) -> void:
	_target_position = _clamp_target(position)
	if target_position == _target_position:
		return
	target_position = _target_position
	aim_target_changed.emit(target_position)


func get_target_position() -> Vector2:
	return target_position


func is_pissing() -> bool:
	return _pissing


func reset_input() -> void:
	_touch_index = -1
	_touch_position = Vector2.ZERO
	_space_pressed = false
	_pissing = false
	_move_left_pressed = false
	_move_right_pressed = false
	_move_up_pressed = false
	_move_down_pressed = false
	_target_position = _default_target_position()
	target_position = _target_position
	aim_target_changed.emit(target_position)
	touch_target_changed.emit(Vector2.ZERO, false)


func _claim_touch(index: int, position: Vector2) -> void:
	if _touch_index != -1:
		return
	_touch_index = index
	_pissing = true
	_update_touch_target(position)


func _release_touch(index: int) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	_touch_position = Vector2.ZERO
	touch_target_changed.emit(Vector2.ZERO, false)
	_update_pissing()


func _update_touch_target(position: Vector2) -> void:
	_touch_position = position
	# The reticle receives the raw pointer position, while the gameplay target
	# only clamps to the viewport so touching near an edge remains one-to-one.
	touch_target_changed.emit(position, true)
	set_target_position(position)


func _update_pissing() -> void:
	_pissing = _space_pressed or _touch_index != -1


func _default_target_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = Vector2(720.0, 1280.0)
	return viewport_size * Vector2(0.5, 0.5)


func _clamp_target(position: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = Vector2(720.0, 1280.0)
	return Vector2(
		clampf(position.x, 0.0, viewport_size.x),
		clampf(position.y, 0.0, viewport_size.y),
	)
