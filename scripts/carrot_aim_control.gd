extends Control

class_name CarrotAimControl

## A persistent, scene-authored aim indicator. Its horizontal drag track maps
## directly to the same 120° upward cone used by the stream.

signal aim_angle_changed(angle: float)
signal swayed_aim_angle_changed(angle: float)

@export var aim_limit_degrees := 60.0
@export var track_padding := 18.0
@export var track_y := 188.0
@export var carrot_base_y := 184.0
@export_range(0.0, 1.0, 0.01) var touch_start_fraction := 0.45
@export var sway_amount_degrees := 2.5
@export var sway_speed := 1.8

var _aim_angle := 0.0
var _sway_time := 0.0
var _mouse_dragging := false
var _touch_index := -1

@onready var _carrot_sprite: TextureRect = $CarrotSprite


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_carrot_transform()


func _process(delta: float) -> void:
	advance_sway(delta)


func advance_sway(delta: float) -> void:
	_sway_time += delta
	_apply_carrot_transform()
	swayed_aim_angle_changed.emit(get_swayed_aim_angle())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_mouse_dragging = true
			_update_from_position(_event_local_position(button.position))
		else:
			_mouse_dragging = false
		accept_event()
		return

	if event is InputEventMouseMotion and _mouse_dragging:
		var motion := event as InputEventMouseMotion
		_update_from_position(_event_local_position(motion.position))
		accept_event()
		return

	# Screen input is owned by InputController so one finger can set both aim and
	# pressure. Keeping it out of this GUI callback also prevents the centered aim
	# readout from stealing the touch before the controller sees it.


func set_aim_angle(angle: float) -> void:
	_aim_angle = clampf(angle, -_aim_limit_radians(), _aim_limit_radians())
	_apply_carrot_transform()


func get_aim_angle() -> float:
	return _aim_angle


func get_swayed_aim_angle() -> float:
	var sway := sin(_sway_time * sway_speed) * deg_to_rad(sway_amount_degrees)
	return clampf(_aim_angle + sway, -_aim_limit_radians(), _aim_limit_radians())


func get_track_rect() -> Rect2:
	var width := size.x
	if width <= 0.0:
		width = custom_minimum_size.x
	return Rect2(track_padding, track_y - 26.0, maxf(width - track_padding * 2.0, 1.0), 52.0)


func angle_for_track_x(x: float) -> float:
	var track := get_track_rect()
	var fraction := inverse_lerp(track.position.x, track.end.x, x)
	return lerpf(-_aim_limit_radians(), _aim_limit_radians(), clampf(fraction, 0.0, 1.0))


func set_drag_position(position: Vector2) -> void:
	## Apply a local drag position and emit its clamped absolute angle.
	_update_from_position(position)


func handle_input_event(event: InputEvent) -> void:
	# Retain this explicit helper for scene/unit callers that exercise the control
	# in isolation. Actual viewport touch events are handled by InputController.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_update_from_position(_event_local_position(touch.position))
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_from_position(_event_local_position(drag.position))
		return
	_gui_input(event)


func begin_drag(position: Vector2) -> void:
	_mouse_dragging = true
	_update_from_position(position)


func end_drag() -> void:
	_mouse_dragging = false
	_touch_index = -1
	# Do not reset _aim_angle: aim remains where the player released it.


func _update_from_position(position: Vector2) -> void:
	var angle := angle_for_track_x(position.x)
	set_aim_angle(angle)
	aim_angle_changed.emit(angle)


func _aim_limit_radians() -> float:
	return deg_to_rad(aim_limit_degrees)


func _apply_carrot_transform() -> void:
	if not is_instance_valid(_carrot_sprite):
		return
	var track := get_track_rect()
	# The indicator is a fixed center-screen readout. Pointer X selects the
	# angle; it does not move the carrot away from its centered base pivot.
	var base_x := track.get_center().x
	_carrot_sprite.pivot_offset = Vector2(_carrot_sprite.size.x * 0.5, _carrot_sprite.size.y)
	_carrot_sprite.position = Vector2(
		base_x - _carrot_sprite.pivot_offset.x,
		carrot_base_y - _carrot_sprite.size.y,
	)
	_carrot_sprite.rotation = get_swayed_aim_angle()


func _event_local_position(position: Vector2) -> Vector2:
	# Control._gui_input delivers pointer positions in this control's local
	# coordinates. Applying the canvas inverse again would subtract the HUD's
	# bottom-right position a second time and clamp every touch to the left edge.
	return position
