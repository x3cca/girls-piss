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
	carrot._process(PI / (2.0 * carrot.sway_speed))

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
	carrot._gui_input(touch)

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
	controller._process(0.1)
	Input.action_release("aim_right")

	assert_almost_eq(controller.get_aim_angle(), 0.235, 0.001)


func test_physical_keyboard_events_change_aim_and_pressure() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	var aim_down := InputEventKey.new()
	aim_down.physical_keycode = KEY_D
	aim_down.pressed = true
	controller._input(aim_down)
	controller._process(0.1)
	var aim_up := InputEventKey.new()
	aim_up.physical_keycode = KEY_D
	aim_up.pressed = false
	controller._input(aim_up)

	var pressure_down := InputEventKey.new()
	pressure_down.physical_keycode = KEY_W
	pressure_down.pressed = true
	controller._input(pressure_down)
	controller._process(0.1)
	var pressure_up := InputEventKey.new()
	pressure_up.physical_keycode = KEY_W
	pressure_up.pressed = false
	controller._input(pressure_up)

	assert_almost_eq(controller.get_aim_angle(), 0.235, 0.001)
	assert_almost_eq(Vector2.UP.angle_to(controller.aim_direction), 0.235, 0.001)
	assert_almost_eq(controller.requested_pressure, 0.63, 0.001)
