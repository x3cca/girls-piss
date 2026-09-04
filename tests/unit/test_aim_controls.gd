extends GutTest

const CARROT_SCENE := preload("res://scenes/carrot_aim_control.tscn")


func test_drag_track_maps_left_center_and_right_to_the_120_degree_cone() -> void:
	var carrot := CARROT_SCENE.instantiate() as CarrotAimControl
	add_child_autofree(carrot)
	var track := carrot.get_track_rect()

	assert_almost_eq(carrot.angle_for_track_x(track.position.x), -PI / 3.0, 0.001)
	assert_almost_eq(carrot.angle_for_track_x(track.get_center().x), 0.0, 0.001)
	assert_almost_eq(carrot.angle_for_track_x(track.end.x), PI / 3.0, 0.001)


func test_drag_position_clamps_outside_track_edges() -> void:
	var carrot := CARROT_SCENE.instantiate() as CarrotAimControl
	add_child_autofree(carrot)
	var track := carrot.get_track_rect()

	carrot.set_drag_position(Vector2(track.position.x - 400.0, track.position.y))
	assert_almost_eq(carrot.get_aim_angle(), -PI / 3.0, 0.001)
	carrot.set_drag_position(Vector2(track.end.x + 400.0, track.position.y))
	assert_almost_eq(carrot.get_aim_angle(), PI / 3.0, 0.001)


func test_carrot_stays_at_its_base_pivot_when_angle_changes() -> void:
	var carrot := CARROT_SCENE.instantiate() as CarrotAimControl
	add_child_autofree(carrot)
	var track := carrot.get_track_rect()
	var center_base := track.get_center().x

	carrot.set_drag_position(Vector2(track.end.x, track.position.y))

	assert_almost_eq(carrot.get_node("CarrotSprite").position.x + 28.0, center_base, 0.001)


func test_carrot_sway_updates_live_direction_and_stays_subtle() -> void:
	var carrot := CARROT_SCENE.instantiate() as CarrotAimControl
	add_child_autofree(carrot)
	var controller := InputController.new()
	add_child_autofree(controller)
	carrot.swayed_aim_angle_changed.connect(controller.set_swayed_aim_angle)
	carrot.set_process(false)
	carrot.set_aim_angle(0.0)
	carrot.advance_sway(PI / (2.0 * carrot.sway_speed))

	assert_almost_eq(carrot.get_aim_angle(), 0.0, 0.001)
	assert_almost_eq(controller.get_aim_angle(), 0.0, 0.001)
	assert_almost_eq(Vector2.UP.angle_to(controller.aim_direction), deg_to_rad(2.5), 0.001)
	assert_almost_eq(
		carrot.get_node("CarrotSprite").rotation,
		deg_to_rad(2.5),
		0.001,
	)
	assert_true(carrot.sway_amount_degrees < 3.0)


func test_aim_angle_persists_after_drag_release() -> void:
	var carrot := CARROT_SCENE.instantiate() as CarrotAimControl
	add_child_autofree(carrot)
	var track := carrot.get_track_rect()

	carrot.begin_drag(Vector2(track.end.x, track.position.y))
	carrot.end_drag()

	assert_almost_eq(carrot.get_aim_angle(), PI / 3.0, 0.001)


func test_gui_touch_position_is_local_even_when_control_is_moved() -> void:
	var carrot := CARROT_SCENE.instantiate() as CarrotAimControl
	add_child_autofree(carrot)
	carrot.position = Vector2(420.0, 820.0)
	var track := carrot.get_track_rect()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = Vector2(track.end.x, track.position.y)
	touch.pressed = true
	carrot.handle_input_event(touch)

	assert_almost_eq(carrot.get_aim_angle(), PI / 3.0, 0.001)


func test_input_controller_accepts_absolute_angles_and_clamps_cone() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)

	controller.set_aim_angle(-PI)
	assert_almost_eq(controller.get_aim_angle(), -PI / 3.0, 0.001)
	controller.set_aim_angle(PI)
	assert_almost_eq(controller.get_aim_angle(), PI / 3.0, 0.001)
	controller.set_aim_angle(0.0)
	assert_eq(controller.aim_direction, Vector2.UP)


func test_keyboard_aim_actions_still_change_angle() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	Input.action_press("aim_right")
	controller.process_frame(0.1)
	Input.action_release("aim_right")

	assert_almost_eq(controller.get_aim_angle(), 0.235, 0.001)


func test_physical_keyboard_events_change_aim_and_pressure() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	var aim_down := InputEventKey.new()
	aim_down.physical_keycode = KEY_D
	aim_down.pressed = true
	controller.handle_input_event(aim_down)
	controller.process_frame(0.1)
	var aim_up := InputEventKey.new()
	aim_up.physical_keycode = KEY_D
	aim_up.pressed = false
	controller.handle_input_event(aim_up)
	# The aim-only step also exercises the release ramp. Start this pressure
	# assertion from the neutral value so it isolates W/S target movement.
	controller.requested_pressure = 0.55

	var pressure_down := InputEventKey.new()
	pressure_down.physical_keycode = KEY_W
	pressure_down.pressed = true
	controller.handle_input_event(pressure_down)
	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	assert_true(controller.is_pissing())
	controller.process_frame(0.1)
	assert_almost_eq(controller.pressure_target, 0.63, 0.001)
	assert_true(controller.requested_pressure > 0.55)
	var pressure_up := InputEventKey.new()
	pressure_up.physical_keycode = KEY_W
	pressure_up.pressed = false
	controller.handle_input_event(pressure_up)
	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)

	assert_almost_eq(controller.get_aim_angle(), 0.235, 0.001)
	assert_almost_eq(Vector2.UP.angle_to(controller.aim_direction), 0.235, 0.001)
	assert_true(controller.requested_pressure > 0.55)
	assert_false(controller.is_pissing())


func test_keyboard_space_ramps_pressure_down_after_release() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.set_pressure_target(1.0)

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	controller.process_frame(0.1)
	var pressurized := controller.requested_pressure
	assert_true(controller.is_pissing())

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	controller.process_frame(0.1)

	assert_true(controller.requested_pressure < pressurized)
	assert_false(controller.is_pissing())


func test_one_touch_controls_both_axes_with_direct_vertical_mapping() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	var safe := controller._safe_rect()

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 1
	touch_down.position = safe.get_center()
	touch_down.pressed = true
	controller.handle_input_event(touch_down)
	assert_true(controller.is_pissing())

	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(
		safe.end.x,
		safe.position.y + safe.size.y * 0.25,
	)
	controller.handle_input_event(drag)
	controller.process_frame(0.1)

	assert_almost_eq(controller._aim_target_angle, PI / 3.0, 0.001)
	assert_almost_eq(controller.pressure_target, 0.7875, 0.001)
	assert_true(controller.requested_pressure > 0.55)

	# A second finger never takes control from the first finger.
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 2
	second_touch.position = safe.position
	second_touch.pressed = true
	controller.handle_input_event(second_touch)
	assert_eq(controller._touch_index, 1)

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 1
	touch_up.pressed = false
	controller.handle_input_event(touch_up)
	assert_false(controller.is_pissing())


func test_touch_target_compensates_for_gravity_on_high_landings() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	var source := Vector2(360.0, 1328.0)
	var target := Vector2(520.0, 180.0)
	controller.set_stream_geometry(source, 190.0, 2200.0, 560.0, 1120.0, Vector2(0.0, 360.0))

	var controls := controller._ballistic_touch_controls(target.x, target.y)
	var pressure: float = controls["pressure"]
	var angle: float = controls["angle"]
	var length := controller._touch_stream_length(pressure)
	var landing_x := source.x + sin(angle) * length
	var speed := lerpf(560.0, 1120.0, pressure)
	var travel_time := length / speed
	var landing_y := source.y - cos(angle) * length + 180.0 * travel_time * travel_time

	assert_almost_eq(landing_x, target.x, 2.0)
	assert_almost_eq(landing_y, target.y, 2.0)
