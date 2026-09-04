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


func test_space_only_gates_pissing_and_does_not_change_target() -> void:
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
	assert_false(controller.is_pissing())


func test_one_touch_places_crosshair_directly_and_gates_stream() -> void:
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
	assert_eq(controller._touch_index, 1)

	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 2
	second_touch.position = Vector2(540.0, 900.0)
	second_touch.pressed = true
	controller.handle_input_event(second_touch)
	assert_eq(controller.get_target_position(), touch_down.position)
	assert_eq(controller._touch_index, 1)

	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(540.0, 900.0)
	controller.handle_input_event(drag)
	assert_eq(controller.get_target_position(), drag.position)

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 1
	touch_up.pressed = false
	controller.handle_input_event(touch_up)
	assert_false(controller.is_pissing())
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
