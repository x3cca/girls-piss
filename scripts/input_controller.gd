extends Node

class_name InputController

## Unified desktop/touch input for the portrait prototype.
## The pressure fader keeps ownership of its left-side touch; the scene-authored
## carrot aim control owns its own mouse/touch drag and sends absolute angles here.

signal aim_angle_changed(angle: float)

const AIM_HALF_CONE_RADIANS := PI / 3.0

@export var aim_turn_speed := 2.35
@export var pressure_speed := 0.8
@export var safe_margin := 28.0

var aim_direction := Vector2.UP
var requested_pressure := 0.55
var input_mode := "desktop"
var touch_controls_visible := false

var _pressure_touch := -1
var _pressure_position := Vector2.ZERO
var _aim_angle_value := 0.0
var _aim_left_pressed := false
var _aim_right_pressed := false
var _pressure_down_pressed := false
var _pressure_up_pressed := false


func _ready() -> void:
	# DisplayServer reports false on desktop and in headless checks. The pressure
	# fader remains out of the desktop render path in that case; the carrot aim
	# control is always visible because it also supports mouse dragging.
	touch_controls_visible = DisplayServer.is_touchscreen_available()
	input_mode = "touch" if touch_controls_visible else "desktop"


func _process(delta: float) -> void:
	process_frame(delta)


func process_frame(delta: float) -> void:
	var keyboard_aim_axis := float(_aim_right_pressed) - float(_aim_left_pressed)
	var aim_axis := keyboard_aim_axis if absf(keyboard_aim_axis) > 0.01 else Input.get_axis(
		"aim_left",
		"aim_right",
	)
	if absf(aim_axis) > 0.01:
		set_aim_angle(_aim_angle() + aim_axis * aim_turn_speed * delta)

	var keyboard_pressure_axis := float(_pressure_up_pressed) - float(_pressure_down_pressed)
	var pressure_axis := (
			keyboard_pressure_axis
			if absf(keyboard_pressure_axis) > 0.01
			else Input.get_axis("pressure_down", "pressure_up")
	)
	if absf(pressure_axis) > 0.01:
		requested_pressure = clampf(
			requested_pressure + pressure_axis * pressure_speed * delta,
			0.15,
			1.0,
		)


func _input(event: InputEvent) -> void:
	handle_input_event(event)


func handle_input_event(event: InputEvent) -> void:
	if event is InputEventKey:
		_update_keyboard_state(event as InputEventKey)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_claim_pressure_touch(touch.index, touch.position)
		else:
			_release_pressure_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _pressure_touch:
			_update_pressure_fader(drag.position)


func _update_keyboard_state(event: InputEventKey) -> void:
	if event.echo:
		return
	var key_code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key_code:
		KEY_A:
			_aim_left_pressed = event.pressed
		KEY_D:
			_aim_right_pressed = event.pressed
		KEY_S:
			_pressure_down_pressed = event.pressed
		KEY_W:
			_pressure_up_pressed = event.pressed


func set_aim_angle(angle: float) -> void:
	## Set an absolute aim angle in radians, constrained to the 120° cone.
	var constrained := clampf(angle, -AIM_HALF_CONE_RADIANS, AIM_HALF_CONE_RADIANS)
	_aim_angle_value = constrained
	aim_direction = Vector2.UP.rotated(constrained).normalized()
	aim_angle_changed.emit(constrained)


func set_swayed_aim_angle(angle: float) -> void:
	## Set the live stream angle without changing the player's base aim.
	var constrained := clampf(angle, -AIM_HALF_CONE_RADIANS, AIM_HALF_CONE_RADIANS)
	aim_direction = Vector2.UP.rotated(constrained).normalized()


func get_aim_angle() -> float:
	return _aim_angle_value


func _claim_pressure_touch(index: int, position: Vector2) -> void:
	var safe := _safe_rect()
	var local_x := position.x - safe.position.x
	# The pressure fader stays on the left side. A carrot touch is handled by
	# CarrotAimControl and is deliberately not claimed or reset here.
	if local_x <= safe.size.x * 0.45 and _pressure_touch == -1:
		_pressure_touch = index
		_pressure_position = position
		_update_pressure_fader(position)


func _release_pressure_touch(index: int) -> void:
	if index == _pressure_touch:
		_pressure_touch = -1
		_pressure_position = Vector2.ZERO


func _update_pressure_fader(position: Vector2) -> void:
	_pressure_position = position
	var safe := _safe_rect()
	var top := safe.position.y + 178.0
	var bottom := safe.position.y + safe.size.y - 188.0
	var fraction := inverse_lerp(bottom, top, position.y)
	requested_pressure = clampf(lerpf(0.15, 1.0, fraction), 0.15, 1.0)


func _aim_angle() -> float:
	return _aim_angle_value


func _set_aim_angle(angle: float) -> void:
	# Keep the old private entry point available to callers from the prototype
	# while making the public API explicit for scene-authored controls.
	set_aim_angle(angle)


func _safe_rect() -> Rect2:
	var viewport_rect := get_viewport().get_visible_rect()
	var inset := minf(safe_margin, minf(viewport_rect.size.x, viewport_rect.size.y) * 0.04)
	return viewport_rect.grow(-inset)
