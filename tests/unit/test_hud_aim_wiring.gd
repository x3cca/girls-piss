extends GutTest

const HUD_SCENE := preload("res://scenes/stream_hud.tscn")


func test_carrot_signal_updates_input_controller_without_reset_on_release() -> void:
	var hud := HUD_SCENE.instantiate() as StreamHUD
	add_child_autofree(hud)
	var controller := InputController.new()
	add_child_autofree(controller)
	hud.input_controller = controller
	hud.process_frame(0.0)

	var carrot := hud.carrot_aim_control
	var track := carrot.get_track_rect()
	carrot.begin_drag(Vector2(track.end.x, track.position.y))
	carrot.end_drag()
	controller.set_process(false)
	controller.process_frame(0.2)

	assert_almost_eq(controller.get_aim_angle(), PI / 3.0, 0.001)
	assert_almost_eq(carrot.get_aim_angle(), PI / 3.0, 0.001)
	var pivot := carrot.position + Vector2(carrot.size.x * 0.5, carrot.carrot_base_y)
	var safe := hud.get_viewport_rect().grow(
		-minf(
			hud.safe_margin,
			minf(
				hud.get_viewport_rect().size.x,
				hud.get_viewport_rect().size.y,
			) * 0.04,
		),
	)
	assert_almost_eq(pivot.x, hud.get_viewport_rect().get_center().x, 0.001)
	assert_almost_eq(pivot.y, safe.end.y - 32.0, 0.001)


func test_physical_keyboard_aim_survives_hud_wiring() -> void:
	var hud := HUD_SCENE.instantiate() as StreamHUD
	add_child_autofree(hud)
	var controller := InputController.new()
	add_child_autofree(controller)
	hud.input_controller = controller
	hud.process_frame(0.0)
	controller.set_process(false)

	var aim_down := InputEventKey.new()
	aim_down.physical_keycode = KEY_D
	aim_down.pressed = true
	controller.handle_input_event(aim_down)
	controller.process_frame(0.1)
	hud.process_frame(0.0)

	var aim_up := InputEventKey.new()
	aim_up.physical_keycode = KEY_D
	aim_up.pressed = false
	controller.handle_input_event(aim_up)
	controller.process_frame(0.1)

	assert_almost_eq(controller.get_aim_angle(), 0.235, 0.001)
	assert_almost_eq(carrot_angle(hud), 0.235, 0.001)
	assert_almost_eq(Vector2.UP.angle_to(controller.aim_direction), 0.235, 0.001)


func test_touch_reticle_stays_at_the_raw_finger_position() -> void:
	var hud := HUD_SCENE.instantiate() as StreamHUD
	add_child_autofree(hud)
	var controller := InputController.new()
	add_child_autofree(controller)
	hud.input_controller = controller
	hud.process_frame(0.0)

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 1
	touch_down.position = Vector2(180.0, 420.0)
	touch_down.pressed = true
	controller.handle_input_event(touch_down)

	assert_true(hud.touch_reticle.visible)
	assert_eq(hud.touch_reticle.position, touch_down.position)

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 1
	touch_up.pressed = false
	controller.handle_input_event(touch_up)
	assert_false(hud.touch_reticle.visible)


func carrot_angle(hud: StreamHUD) -> float:
	return hud.carrot_aim_control.get_aim_angle()
