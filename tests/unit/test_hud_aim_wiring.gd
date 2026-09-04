extends GutTest

const HUD_SCENE := preload("res://scenes/stream_hud.tscn")


func test_hud_has_one_crosshair_and_no_mode_controls() -> void:
	var hud := HUD_SCENE.instantiate() as StreamHUD
	add_child_autofree(hud)

	assert_not_null(hud.get_node_or_null("AimReticle"))
	assert_null(hud.get_node_or_null("CarrotAimControl"))
	assert_null(hud.get_node_or_null("PressureFader"))


func test_crosshair_tracks_keyboard_target() -> void:
	var hud := HUD_SCENE.instantiate() as StreamHUD
	add_child_autofree(hud)
	var controller := InputController.new()
	add_child_autofree(controller)
	hud.input_controller = controller
	hud.process_frame(0.0)

	var target := Vector2(180.0, 420.0)
	controller.set_target_position(target)
	hud.process_frame(0.0)

	assert_true(hud.aim_reticle.visible)
	assert_eq(hud.aim_reticle.position, target)


func test_crosshair_stays_at_the_raw_touch_position() -> void:
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

	assert_true(hud.aim_reticle.visible)
	assert_eq(hud.aim_reticle.position, touch_down.position)

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 1
	touch_up.pressed = false
	controller.handle_input_event(touch_up)
	assert_true(hud.aim_reticle.visible)
