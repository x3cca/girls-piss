extends Node

class_name InputController

## Unified desktop/touch input for the portrait prototype.
## Keyboard WASD moves the stream's target. Space gates the stream and lets the
## pressure ramp toward that target. On touch, one finger controls both axes:
## horizontal position selects aim and vertical position selects pressure.

signal aim_angle_changed(angle: float)
signal touch_target_changed(position: Vector2, active: bool)

const AIM_HALF_CONE_RADIANS := PI / 3.0

@export var aim_turn_speed := 2.35
@export var pressure_speed := 0.8
@export var aim_smoothing_speed := 8.0
@export var pressure_smoothing_speed := 3.5
@export var safe_margin := 28.0

var aim_direction := Vector2.UP
var requested_pressure := 0.55
var pressure_target := 0.55
var input_mode := "desktop"
var touch_controls_visible := false

var _touch_index := -1
var _touch_position := Vector2.ZERO
var _aim_angle_value := 0.0
var _aim_target_angle := 0.0
var _aim_left_pressed := false
var _aim_right_pressed := false
var _pressure_down_pressed := false
var _pressure_up_pressed := false
var _space_pressed := false
var _pissing := false
var _stream_source_position := Vector2.ZERO
var _stream_minimum_length := 190.0
var _stream_maximum_length := 1080.0
var _stream_launch_speed_min := 560.0
var _stream_launch_speed_max := 1120.0
var _stream_gravity_y := 360.0
var _stream_geometry_configured := false


func _ready() -> void:
	# DisplayServer reports false on desktop and in headless checks. The visual
	# touch guides remain out of the desktop render path in that case.
	touch_controls_visible = DisplayServer.is_touchscreen_available()
	input_mode = "touch" if touch_controls_visible else "desktop"


func _process(delta: float) -> void:
	process_frame(delta)


func process_frame(delta: float) -> void:
	if _touch_index == -1:
		var keyboard_aim_axis := float(_aim_right_pressed) - float(_aim_left_pressed)
		var aim_axis := keyboard_aim_axis if absf(keyboard_aim_axis) > 0.01 else Input.get_axis(
			"aim_left",
			"aim_right",
		)
		if absf(aim_axis) > 0.01:
			set_aim_target_angle(_aim_angle() + aim_axis * aim_turn_speed * delta)

		var keyboard_pressure_axis := float(_pressure_up_pressed) - float(_pressure_down_pressed)
		var pressure_axis := (
				keyboard_pressure_axis
				if absf(keyboard_pressure_axis) > 0.01
				else Input.get_axis("pressure_down", "pressure_up")
		)
		if absf(pressure_axis) > 0.01:
			pressure_target = clampf(
				pressure_target + pressure_axis * pressure_speed * delta,
				0.15,
				1.0,
			)

	var previous_angle := _aim_angle_value
	_aim_angle_value = move_toward(
		_aim_angle_value,
		_aim_target_angle,
		aim_smoothing_speed * delta,
	)
	aim_direction = Vector2.UP.rotated(_aim_angle_value).normalized()
	if not is_equal_approx(previous_angle, _aim_angle_value):
		aim_angle_changed.emit(_aim_angle_value)

	# Space (or a held touch) opens the stream. Pressure itself has inertia: it
	# rises toward the WASD/touch target while held and eases back down on release.
	var desired_pressure := pressure_target if _pissing else 0.15
	requested_pressure = move_toward(
		requested_pressure,
		desired_pressure,
		pressure_smoothing_speed * delta,
	)


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
			_update_touch_controls(drag.position)


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
		KEY_SPACE:
			_space_pressed = event.pressed
	_update_pissing()


func set_aim_angle(angle: float) -> void:
	## Set the current and target angle immediately. Useful for scene setup and
	## compatibility with authored controls; normal play uses the target setter.
	var constrained := clampf(angle, -AIM_HALF_CONE_RADIANS, AIM_HALF_CONE_RADIANS)
	_aim_angle_value = constrained
	_aim_target_angle = constrained
	aim_direction = Vector2.UP.rotated(constrained).normalized()
	aim_angle_changed.emit(constrained)


func set_aim_target_angle(angle: float) -> void:
	## Set where the aim should go. The live direction eases toward this target.
	_aim_target_angle = clampf(angle, -AIM_HALF_CONE_RADIANS, AIM_HALF_CONE_RADIANS)


func set_pressure_target(value: float) -> void:
	pressure_target = clampf(value, 0.15, 1.0)


func set_stream_geometry(
	source_position: Vector2,
	minimum_length: float,
	maximum_length: float,
	launch_speed_min: float,
	launch_speed_max: float,
	gravity: Vector2,
) -> void:
	## Give touch targeting the same geometry used by LiquidStream so its raw
	## screen point is the predicted landing point, including gravity.
	_stream_source_position = source_position
	_stream_minimum_length = minimum_length
	_stream_maximum_length = maximum_length
	_stream_launch_speed_min = launch_speed_min
	_stream_launch_speed_max = launch_speed_max
	_stream_gravity_y = gravity.y
	_stream_geometry_configured = true


func is_pissing() -> bool:
	return _pissing


func reset_input() -> void:
	_touch_index = -1
	_touch_position = Vector2.ZERO
	_space_pressed = false
	_pissing = false
	_aim_left_pressed = false
	_aim_right_pressed = false
	_pressure_down_pressed = false
	_pressure_up_pressed = false
	_aim_angle_value = 0.0
	_aim_target_angle = 0.0
	aim_direction = Vector2.UP
	pressure_target = 0.55
	requested_pressure = 0.55
	aim_angle_changed.emit(0.0)
	touch_target_changed.emit(Vector2.ZERO, false)


func set_swayed_aim_angle(angle: float) -> void:
	## Set the live stream angle without changing the player's base aim.
	var constrained := clampf(angle, -AIM_HALF_CONE_RADIANS, AIM_HALF_CONE_RADIANS)
	aim_direction = Vector2.UP.rotated(constrained).normalized()


func get_aim_angle() -> float:
	return _aim_angle_value


func _claim_touch(index: int, position: Vector2) -> void:
	if _touch_index != -1:
		return
	_touch_index = index
	_pissing = true
	_update_touch_controls(position)


func _release_touch(index: int) -> void:
	if index == _touch_index:
		_touch_index = -1
		_touch_position = Vector2.ZERO
		touch_target_changed.emit(Vector2.ZERO, false)
		_update_pissing()


func _update_touch_controls(position: Vector2) -> void:
	_touch_position = position
	touch_target_changed.emit(position, true)
	var safe := _safe_rect()
	var x := clampf(position.x, safe.position.x, safe.end.x)
	var y := clampf(position.y, safe.position.y, safe.end.y)
	var aim_fraction := inverse_lerp(safe.position.x, safe.end.x, x)
	var target_controls := _direct_touch_controls(y, aim_fraction)
	if _stream_geometry_configured:
		target_controls = _ballistic_touch_controls(x, y)
	set_aim_target_angle(float(target_controls["angle"]))
	set_pressure_target(float(target_controls["pressure"]))


func _direct_touch_controls(y: float, aim_fraction: float) -> Dictionary:
	return {
		"angle": lerpf(-AIM_HALF_CONE_RADIANS, AIM_HALF_CONE_RADIANS, aim_fraction),
		"pressure": lerpf(
			0.15,
			1.0,
			inverse_lerp(_safe_rect().end.y, _safe_rect().position.y, y),
		),
	}


func _ballistic_touch_controls(x: float, y: float) -> Dictionary:
	var horizontal_delta := x - _stream_source_position.x
	var low_pressure := 0.15
	var high_pressure := 1.0
	var low_landing_y := _touch_landing_y(low_pressure, horizontal_delta)
	var high_landing_y := _touch_landing_y(high_pressure, horizontal_delta)
	var pressure := low_pressure
	if y <= high_landing_y:
		pressure = high_pressure
	elif y >= low_landing_y:
		pressure = low_pressure
	else:
		# Landing height is monotonic over the playable pressure range. Bisecting
		# the actual trajectory removes the pronounced high-screen shortfall.
		var lower := low_pressure
		var upper := high_pressure
		for _iteration in 12:
			var midpoint := (lower + upper) * 0.5
			if _touch_landing_y(midpoint, horizontal_delta) > y:
				lower = midpoint
			else:
				upper = midpoint
		pressure = (lower + upper) * 0.5

	var length := _touch_stream_length(pressure)
	var horizontal_fraction := clampf(
		horizontal_delta / maxf(length, 1.0),
		-sin(AIM_HALF_CONE_RADIANS),
		sin(AIM_HALF_CONE_RADIANS),
	)
	return {
		"angle": asin(horizontal_fraction),
		"pressure": pressure,
	}


func _touch_landing_y(pressure: float, horizontal_delta: float) -> float:
	var length := _touch_stream_length(pressure)
	var horizontal_fraction := clampf(
		horizontal_delta / maxf(length, 1.0),
		-sin(AIM_HALF_CONE_RADIANS),
		sin(AIM_HALF_CONE_RADIANS),
	)
	var vertical_fraction := sqrt(maxf(1.0 - horizontal_fraction * horizontal_fraction, 0.0))
	var speed := lerpf(
		_stream_launch_speed_min,
		_stream_launch_speed_max,
		clampf(pressure, 0.0, 1.0),
	)
	var travel_time := length / maxf(speed, 1.0)
	return _stream_source_position.y - vertical_fraction * length + _stream_gravity_y * travel_time * travel_time * 0.5


func _touch_stream_length(pressure: float) -> float:
	return lerpf(
		_stream_minimum_length,
		_stream_maximum_length,
		clampf(pressure, 0.0, 1.0),
	)


func _aim_angle() -> float:
	return _aim_target_angle


func _set_aim_angle(angle: float) -> void:
	# Keep the old private entry point available to callers from the prototype
	# while making the public API explicit for scene-authored controls.
	set_aim_angle(angle)


func _update_pissing() -> void:
	_pissing = _space_pressed or _touch_index != -1


func _safe_rect() -> Rect2:
	var viewport_rect := get_viewport().get_visible_rect()
	var inset := minf(safe_margin, minf(viewport_rect.size.x, viewport_rect.size.y) * 0.04)
	return viewport_rect.grow(-inset)
