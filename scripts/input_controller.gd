extends Node

class_name InputController

## Unified keyboard, pointer, controller, and touch input for the portrait
## prototype. Keyboard/controller aim moves the crosshair, while pointer/touch
## aim places it directly. The stream owns the easing from this target to the
## actual shot endpoint.

signal aim_target_changed(position: Vector2)
signal touch_target_changed(position: Vector2, active: bool)
signal input_detected(source: int)
signal input_source_changed(source: int)

@export var target_move_speed := 620.0
@export var music_target_offset_max := 200.0
@export var music_target_offset_angle_increment := 45.0
@export var music_target_offset_power := 3
@export var force_pissing_after_start := true
@export var bus_name: String = "Master"

const AIM_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.5

enum AimSource { KEYBOARD, MOUSE, TOUCH, CONTROLLER }

var target_position := Vector2.ZERO
var input_mode := "desktop"
var touch_controls_visible := false
var gameplay_input_enabled := true
var music_target_offset_angle_current := 0.0
var music_direction_toggle := 1
var bus_index := 0

var _previous_input_position := Vector2.ZERO
var _touch_index := -1
var _touch_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _move_left_pressed := false
var _move_right_pressed := false
var _move_up_pressed := false
var _move_down_pressed := false
var _space_pressed := false
var _mouse_pressed := false
var _controller_aim := Vector2.ZERO
var _controller_trigger_pressed := false
var _controller_device := -1
var _last_aim_source := AimSource.KEYBOARD
var _current_input_source := AimSource.KEYBOARD
var _pissing := false
var _has_started_pissing := false
var _music_target_offset_position := Vector2.ZERO

var current_input_source: int:
	get:
		return _current_input_source

var current_source: int:
	get:
		return _current_input_source


func _ready() -> void:
	# DisplayServer reports false on desktop and in headless checks. The visual
	# touch reticle is still useful on desktop as the keyboard-controlled aimer.
	touch_controls_visible = DisplayServer.is_touchscreen_available()
	input_mode = "touch" if touch_controls_visible else "desktop"
	_target_position = _default_target_position()
	target_position = _target_position
	aim_target_changed.emit(target_position)
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
		
	# Get the index of the audio bus and the first effect (index 0) on it
	bus_index = AudioServer.get_bus_index(bus_name)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func _process(delta: float) -> void:
	process_frame(delta)


func process_frame(delta: float) -> void:
	if not gameplay_input_enabled:
		return
	var movement := Vector2.ZERO
	match _last_aim_source:
		AimSource.KEYBOARD:
			movement = Vector2(
				float(_move_right_pressed) - float(_move_left_pressed),
				float(_move_down_pressed) - float(_move_up_pressed),
			)
			if movement.length_squared() > 1.0:
				movement = movement.normalized()
		AimSource.CONTROLLER:
			movement = _controller_aim
	if movement.length_squared() > 0.0:
		_previous_input_position += movement * target_move_speed * delta
	
	# Make the aiming target jiggle from the music
	# make it so that the offset jiggles back and forth every frame
	# and that it spins slowly over time
	music_direction_toggle = -music_direction_toggle
	music_target_offset_angle_current += music_target_offset_angle_increment * delta
	var _db = _get_music_amplitutde()
	var _music_target_offset_value = pow(_db, music_target_offset_power) * music_target_offset_max * music_direction_toggle
	_music_target_offset_position = Vector2.RIGHT.rotated(deg_to_rad(music_target_offset_angle_current)) * _music_target_offset_value
	# _target_position += _music_target_offset_position
	
	set_target_position(_previous_input_position)
		


func _input(event: InputEvent) -> void:
	handle_input_event(event)


func handle_input_event(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_claim_input_source(AimSource.KEYBOARD)
		_update_keyboard_state(key)
	elif event is InputEventMouseMotion:
		_update_mouse_target((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if (
				mouse_button.button_index == MOUSE_BUTTON_LEFT
				and mouse_button.pressed
				and not mouse_button.canceled
		):
			_claim_input_source(AimSource.MOUSE)
		_update_mouse_button_state(mouse_button)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_claim_input_source(AimSource.TOUCH)
			_claim_touch(touch.index, touch.position)
		else:
			_release_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_touch_target(drag.position)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed:
			_claim_input_source(AimSource.CONTROLLER)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if _is_meaningful_controller_motion(motion):
			_claim_input_source(AimSource.CONTROLLER)
		_update_controller_motion(motion)


func _update_keyboard_state(event: InputEventKey) -> void:
	if event.echo:
		return
	if not gameplay_input_enabled:
		return
	var key_code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key_code:
		KEY_A:
			_move_left_pressed = event.pressed
			if event.pressed:
				_last_aim_source = AimSource.KEYBOARD
		KEY_D:
			_move_right_pressed = event.pressed
			if event.pressed:
				_last_aim_source = AimSource.KEYBOARD
		KEY_W:
			_move_up_pressed = event.pressed
			if event.pressed:
				_last_aim_source = AimSource.KEYBOARD
		KEY_S:
			_move_down_pressed = event.pressed
			if event.pressed:
				_last_aim_source = AimSource.KEYBOARD
		KEY_SPACE:
			_space_pressed = event.pressed
	_update_pissing()


func _update_mouse_target(position: Vector2) -> void:
	if not gameplay_input_enabled:
		return
	_last_aim_source = AimSource.MOUSE
	_previous_input_position = position
	set_target_position(position)


func _update_mouse_button_state(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not gameplay_input_enabled:
		return
	if event.pressed and not event.canceled:
		_mouse_pressed = true
		_begin_pissing()
		_update_mouse_target(event.position)
	else:
		_mouse_pressed = false
	_update_pissing()


func _update_controller_motion(event: InputEventJoypadMotion) -> void:
	if not gameplay_input_enabled:
		return
	if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
		if _controller_device != -1 and _controller_device != event.device:
			return
		_controller_device = event.device
		var value := event.axis_value
		if absf(value) < AIM_DEADZONE:
			value = 0.0
		if event.axis == JOY_AXIS_LEFT_X:
			_controller_aim.x = value
		else:
			_controller_aim.y = value
		if _controller_aim.length_squared() > 0.0:
			_last_aim_source = AimSource.CONTROLLER
		return
	if event.axis == JOY_AXIS_TRIGGER_RIGHT:
		if _controller_device != -1 and _controller_device != event.device:
			return
		_controller_device = event.device
		_controller_trigger_pressed = event.axis_value >= TRIGGER_DEADZONE
		_update_pissing()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or (_controller_device != -1 and device != _controller_device):
		return
	var controller_was_authoritative := _last_aim_source == AimSource.CONTROLLER
	_clear_controller_state()
	if controller_was_authoritative:
		if (
				_move_left_pressed
				or _move_right_pressed
				or _move_up_pressed
				or _move_down_pressed
		):
			_last_aim_source = AimSource.KEYBOARD
		elif _touch_index != -1:
			_last_aim_source = AimSource.TOUCH
		else:
			_last_aim_source = AimSource.KEYBOARD
	_update_pissing()


func _clear_controller_state() -> void:
	_controller_aim = Vector2.ZERO
	_controller_trigger_pressed = false
	_controller_device = -1


func set_target_position(position: Vector2) -> void:
	_target_position = _clamp_target(position) + _music_target_offset_position
	if target_position == _target_position:
		return
	target_position = _target_position
	aim_target_changed.emit(target_position)


func get_target_position() -> Vector2:
	return target_position


func is_pissing() -> bool:
	return _has_started_pissing if force_pissing_after_start else _pissing


func is_touch_active() -> bool:
	return _touch_index != -1


func handle_joy_connection_changed(device: int, connected: bool) -> void:
	_on_joy_connection_changed(device, connected)


func reset_input() -> void:
	_touch_index = -1
	_touch_position = Vector2.ZERO
	_space_pressed = false
	_mouse_pressed = false
	_clear_controller_state()
	_has_started_pissing = false
	_pissing = false
	_move_left_pressed = false
	_move_right_pressed = false
	_move_up_pressed = false
	_move_down_pressed = false
	_last_aim_source = AimSource.KEYBOARD
	_current_input_source = AimSource.KEYBOARD
	_target_position = _default_target_position()
	target_position = _target_position
	aim_target_changed.emit(target_position)
	touch_target_changed.emit(Vector2.ZERO, false)


func set_gameplay_input_enabled(enabled: bool) -> void:
	gameplay_input_enabled = enabled
	if not enabled:
		_touch_index = -1
		_touch_position = Vector2.ZERO
		_space_pressed = false
		_mouse_pressed = false
		_clear_controller_state()
		_move_left_pressed = false
		_move_right_pressed = false
		_move_up_pressed = false
		_move_down_pressed = false
		_pissing = false
		_has_started_pissing = false
		touch_target_changed.emit(Vector2.ZERO, false)


func is_gameplay_input_enabled() -> bool:
	return gameplay_input_enabled


func get_input_source() -> int:
	return _current_input_source


func get_current_input_source() -> int:
	return _current_input_source


func _claim_touch(index: int, position: Vector2) -> void:
	if not gameplay_input_enabled:
		return
	if _touch_index != -1:
		return
	_touch_index = index
	_begin_pissing()
	_update_touch_target(position)


func _release_touch(index: int) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	_touch_position = Vector2.ZERO
	touch_target_changed.emit(Vector2.ZERO, false)
	_update_pissing()


func _update_touch_target(position: Vector2) -> void:
	if not gameplay_input_enabled:
		return
	_last_aim_source = AimSource.TOUCH
	_touch_position = position
	# The reticle receives the raw pointer position, while the gameplay target
	# only clamps to the viewport so touching near an edge remains one-to-one.
	touch_target_changed.emit(position, true)
	_previous_input_position = position
	set_target_position(position)


func _update_pissing() -> void:
	_pissing = (
			_space_pressed
			or _mouse_pressed
			or _touch_index != -1
			or _controller_trigger_pressed
	)
	if _pissing:
		_has_started_pissing = true


func _begin_pissing() -> void:
	_pissing = true
	_has_started_pissing = true


func _claim_input_source(source: int) -> void:
	if source < AimSource.KEYBOARD or source > AimSource.CONTROLLER:
		return
	input_detected.emit(source)
	if _current_input_source == source:
		return
	_current_input_source = source
	input_source_changed.emit(source)


func _is_meaningful_controller_motion(event: InputEventJoypadMotion) -> bool:
	if (
			event.axis == JOY_AXIS_LEFT_X
			or event.axis == JOY_AXIS_LEFT_Y
			or event.axis == JOY_AXIS_RIGHT_X
			or event.axis == JOY_AXIS_RIGHT_Y
	):
		return absf(event.axis_value) >= AIM_DEADZONE
	if event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT:
		return event.axis_value >= TRIGGER_DEADZONE
	return false


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


func _get_music_amplitutde() -> float:
	# Get peak decibels for left and right channels on the Master bus (index 0)
	var peak_left = AudioServer.get_bus_peak_volume_left_db(bus_index, 0)
	var peak_right = AudioServer.get_bus_peak_volume_right_db(bus_index, 0)
	
	# Average them out or use one channel
	var current_db = (peak_left + peak_right) / 2.0
	var linear_vol = db_to_linear(current_db)
	# print("Volume DB: " + str(linear_vol))
	
	return linear_vol
