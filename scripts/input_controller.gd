extends Node
class_name InputController

## Unified desktop/touch input for the portrait prototype.
## The joystick and fader each own a touch index, so two fingers never swap roles.

@export var aim_turn_speed := 2.35
@export var pressure_speed := 0.8
@export var joystick_radius := 86.0
@export var deadzone := 0.16
@export var safe_margin := 28.0

var aim_direction := Vector2.UP
var requested_pressure := 0.55
var input_mode := "desktop"
var touch_controls_visible := false

var _joystick_touch := -1
var _pressure_touch := -1
var _joystick_position := Vector2.ZERO
var _pressure_position := Vector2.ZERO

func _ready() -> void:
	# DisplayServer reports false on desktop and in headless checks. Touch controls
	# remain entirely out of the desktop render path in that case.
	touch_controls_visible = DisplayServer.is_touchscreen_available()
	input_mode = "touch" if touch_controls_visible else "desktop"

func _process(delta: float) -> void:
	var aim_axis := Input.get_axis("ui_left", "ui_right")
	# A/D is deliberately read directly as well; the project remains usable even
	# when a user has replaced the built-in ui actions in their project settings.
	if Input.is_key_pressed(KEY_A):
		aim_axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		aim_axis += 1.0
	if absf(aim_axis) > 0.01:
		_set_aim_angle(_aim_angle() + aim_axis * aim_turn_speed * delta)

	var pressure_axis := Input.get_axis("ui_down", "ui_up")
	if Input.is_key_pressed(KEY_S):
		pressure_axis -= 1.0
	if Input.is_key_pressed(KEY_W):
		pressure_axis += 1.0
	if absf(pressure_axis) > 0.01:
		requested_pressure = clampf(requested_pressure + pressure_axis * pressure_speed * delta, 0.15, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_claim_touch(touch.index, touch.position)
		else:
			_release_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joystick_touch:
			_update_joystick(drag.position)
		elif drag.index == _pressure_touch:
			_update_pressure_fader(drag.position)

func _claim_touch(index: int, position: Vector2) -> void:
	var safe := _safe_rect()
	var local_x := position.x - safe.position.x
	# Keep the two controls in separate halves; a third touch is ignored.
	if local_x >= safe.size.x * 0.55 and _joystick_touch == -1:
		_joystick_touch = index
		_joystick_position = position
		_update_joystick(position)
	elif local_x <= safe.size.x * 0.45 and _pressure_touch == -1:
		_pressure_touch = index
		_pressure_position = position
		_update_pressure_fader(position)

func _release_touch(index: int) -> void:
	if index == _joystick_touch:
		_joystick_touch = -1
		_joystick_position = Vector2.ZERO
		aim_direction = Vector2.UP
	elif index == _pressure_touch:
		_pressure_touch = -1
		_pressure_position = Vector2.ZERO

func _update_joystick(position: Vector2) -> void:
	_joystick_position = position
	var safe := _safe_rect()
	var center := Vector2(safe.position.x + safe.size.x - 112.0, safe.position.y + safe.size.y - 156.0)
	var offset := position - center
	if offset.length() <= joystick_radius * deadzone:
		aim_direction = Vector2.UP
		return
	var unit := offset.normalized()
	# Screen Y grows downwards, while Vector2.UP is the forward direction.
	var candidate := unit
	var angle := Vector2.UP.angle_to(candidate)
	angle = clampf(angle, -PI * 0.333333, PI * 0.333333)
	aim_direction = Vector2.UP.rotated(angle).normalized()

func _update_pressure_fader(position: Vector2) -> void:
	_pressure_position = position
	var safe := _safe_rect()
	var top := safe.position.y + 178.0
	var bottom := safe.position.y + safe.size.y - 188.0
	var fraction := inverse_lerp(bottom, top, position.y)
	requested_pressure = clampf(lerpf(0.15, 1.0, fraction), 0.15, 1.0)

func _aim_angle() -> float:
	return Vector2.UP.angle_to(aim_direction)

func _set_aim_angle(angle: float) -> void:
	var constrained := clampf(angle, -PI * 0.333333, PI * 0.333333)
	aim_direction = Vector2.UP.rotated(constrained).normalized()

func _safe_rect() -> Rect2:
	var viewport_rect := get_viewport().get_visible_rect()
	var inset := minf(safe_margin, minf(viewport_rect.size.x, viewport_rect.size.y) * 0.04)
	return viewport_rect.grow(-inset)
