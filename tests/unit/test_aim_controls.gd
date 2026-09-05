extends GutTest

func test_target_position_is_the_only_aim_value() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	controller.set_target_position(Vector2(180.0, 420.0))

	assert_eq(controller.get_target_position(), Vector2(180.0, 420.0))
	assert_false(controller.is_pissing())


func test_wasd_moves_the_crosshair_in_two_dimensions() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.set_target_position(Vector2(360.0, 640.0))

	var right := InputEventKey.new()
	right.physical_keycode = KEY_D
	right.pressed = true
	controller.handle_input_event(right)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_W
	up.pressed = true
	controller.handle_input_event(up)
	controller.process_frame(0.1)

	assert_almost_eq(controller.get_target_position().x, 403.8406, 0.001)
	assert_almost_eq(controller.get_target_position().y, 596.1594, 0.001)

	var right_up := InputEventKey.new()
	right_up.physical_keycode = KEY_D
	right_up.pressed = false
	controller.handle_input_event(right_up)
	var up_up := InputEventKey.new()
	up_up.physical_keycode = KEY_W
	up_up.pressed = false
	controller.handle_input_event(up_up)


func test_space_starts_pissing_and_release_does_not_stop_by_default() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.set_target_position(Vector2(250.0, 300.0))

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)

	assert_true(controller.is_pissing())
	assert_eq(controller.get_target_position(), Vector2(250.0, 300.0))

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	assert_true(controller.is_pissing())


func test_one_touch_places_crosshair_directly_and_keeps_stream_active() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 1
	touch_down.position = Vector2(180.0, 420.0)
	touch_down.pressed = true
	controller.handle_input_event(touch_down)

	assert_true(controller.is_pissing())
	assert_eq(controller.get_target_position(), touch_down.position)
	assert_true(controller.is_touch_active())

	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 2
	second_touch.position = Vector2(540.0, 900.0)
	second_touch.pressed = true
	controller.handle_input_event(second_touch)
	assert_eq(controller.get_target_position(), touch_down.position)
	assert_true(controller.is_touch_active())

	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(540.0, 900.0)
	controller.handle_input_event(drag)
	assert_eq(controller.get_target_position(), drag.position)

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 1
	touch_up.pressed = false
	controller.handle_input_event(touch_up)
	assert_true(controller.is_pissing())
	assert_eq(controller.get_target_position(), drag.position)


func test_target_is_clamped_to_the_viewport_edges() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	controller.set_target_position(Vector2(-100.0, -100.0))
	assert_eq(controller.get_target_position(), Vector2.ZERO)
	controller.set_target_position(Vector2(99999.0, 99999.0))
	var viewport_size := controller.get_viewport().get_visible_rect().size
	assert_eq(controller.get_target_position(), viewport_size)


func test_mouse_motion_places_crosshair_directly_and_clamps_it() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(180.0, 420.0)
	controller.handle_input_event(motion)
	assert_eq(controller.get_target_position(), motion.position)

	motion.position = Vector2(-100.0, 99999.0)
	controller.handle_input_event(motion)
	var viewport_size := controller.get_viewport().get_visible_rect().size
	assert_eq(controller.get_target_position(), Vector2(0.0, viewport_size.y))


func test_left_mouse_button_is_an_additive_pissing_input() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.force_pissing_after_start = false

	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.position = Vector2(180.0, 420.0)
	mouse_down.pressed = true
	controller.handle_input_event(mouse_down)
	assert_true(controller.is_pissing())
	assert_eq(controller.get_target_position(), mouse_down.position)

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	controller.handle_input_event(mouse_up)
	assert_true(controller.is_pissing())

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	assert_false(controller.is_pissing())


func test_left_stick_moves_crosshair_with_analog_strength() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.set_target_position(Vector2(360.0, 640.0))

	var stick_x := InputEventJoypadMotion.new()
	stick_x.device = 0
	stick_x.axis = JOY_AXIS_LEFT_X
	stick_x.axis_value = 0.5
	controller.handle_input_event(stick_x)
	controller.process_frame(0.1)

	assert_almost_eq(controller.get_target_position().x, 391.0, 0.001)
	assert_eq(controller.get_target_position().y, 640.0)

	var stick_release := InputEventJoypadMotion.new()
	stick_release.device = 0
	stick_release.axis = JOY_AXIS_LEFT_X
	stick_release.axis_value = 0.0
	controller.handle_input_event(stick_release)
	controller.process_frame(0.1)
	assert_almost_eq(controller.get_target_position().x, 391.0, 0.001)


func test_right_trigger_is_an_additive_pissing_input() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.force_pissing_after_start = false

	var trigger_down := InputEventJoypadMotion.new()
	trigger_down.device = 0
	trigger_down.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger_down.axis_value = 0.75
	controller.handle_input_event(trigger_down)
	assert_true(controller.is_pissing())

	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	controller.handle_input_event(mouse_down)
	var trigger_up := InputEventJoypadMotion.new()
	trigger_up.device = 0
	trigger_up.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger_up.axis_value = 0.0
	controller.handle_input_event(trigger_up)
	assert_true(controller.is_pissing())

	mouse_down.pressed = false
	controller.handle_input_event(mouse_down)
	assert_false(controller.is_pissing())


func test_last_aim_source_wins_when_inputs_overlap() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.set_target_position(Vector2(360.0, 640.0))

	var keyboard_down := InputEventKey.new()
	keyboard_down.physical_keycode = KEY_D
	keyboard_down.pressed = true
	controller.handle_input_event(keyboard_down)
	controller.process_frame(0.1)
	assert_almost_eq(controller.get_target_position().x, 422.0, 0.001)

	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = Vector2(100.0, 200.0)
	controller.handle_input_event(mouse_motion)
	controller.process_frame(0.1)
	assert_eq(controller.get_target_position(), mouse_motion.position)

	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	controller.handle_input_event(stick)
	controller.process_frame(0.1)
	assert_eq(controller.get_target_position(), Vector2(100.0, 262.0))

	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = Vector2(300.0, 400.0)
	touch.pressed = true
	controller.handle_input_event(touch)
	controller.process_frame(0.1)
	assert_eq(controller.get_target_position(), touch.position)

	controller.handle_input_event(mouse_motion)
	controller.handle_input_event(keyboard_down)
	controller.process_frame(0.1)
	assert_eq(controller.get_target_position(), Vector2(162.0, 200.0))


func test_controller_disconnect_clears_stick_and_trigger_state() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.force_pissing_after_start = false
	controller.set_target_position(Vector2(360.0, 640.0))
	var keyboard_down := InputEventKey.new()
	keyboard_down.physical_keycode = KEY_D
	keyboard_down.pressed = true
	controller.handle_input_event(keyboard_down)

	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	controller.handle_input_event(stick)
	var trigger := InputEventJoypadMotion.new()
	trigger.device = 0
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	controller.handle_input_event(trigger)
	assert_true(controller.is_pissing())

	var target_before_disconnect := controller.get_target_position()
	controller.handle_joy_connection_changed(0, false)
	controller.process_frame(0.1)
	assert_almost_eq(controller.get_target_position().x, target_before_disconnect.x + 62.0, 0.001)
	assert_false(controller.is_pissing())


func test_disabling_force_pissing_restores_release_gating() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	controller.force_pissing_after_start = false

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	assert_true(controller.is_pissing())

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	assert_false(controller.is_pissing())


func test_reset_clears_controller_and_pointer_state() -> void:
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)

	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	controller.handle_input_event(mouse_down)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	controller.handle_input_event(stick)
	assert_true(controller.is_pissing())

	controller.reset_input()
	assert_false(controller.is_pissing())
	var target_after_reset := controller.get_target_position()
	controller.process_frame(0.1)
	assert_eq(controller.get_target_position(), target_after_reset)
	assert_false(controller.is_touch_active())


func test_input_map_declares_keyboard_mouse_and_controller_bindings() -> void:
	for action in ["aim_left", "aim_right", "aim_up", "aim_down", "piss"]:
		assert_true(InputMap.has_action(action))

	var left_events := InputMap.action_get_events("aim_left")
	var has_left_key := false
	var has_left_stick := false
	for event in left_events:
		if event is InputEventKey and event.physical_keycode == KEY_A:
			has_left_key = true
		if (
				event is InputEventJoypadMotion
				and event.axis == JOY_AXIS_LEFT_X
				and event.axis_value < 0.0
		):
			has_left_stick = true
	assert_true(has_left_key)
	assert_true(has_left_stick)

	var piss_events := InputMap.action_get_events("piss")
	var has_mouse := false
	var has_trigger := false
	for event in piss_events:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_mouse = true
		if (
				event is InputEventJoypadMotion
				and event.axis == JOY_AXIS_TRIGGER_RIGHT
				and event.axis_value > 0.0
		):
			has_trigger = true
	assert_true(has_mouse)
	assert_true(has_trigger)
