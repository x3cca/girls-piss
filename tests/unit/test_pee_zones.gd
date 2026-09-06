extends GutTest

const LEVEL_SCENE := preload("res://scenes/smoke_test.tscn")
const LEVEL_1_SCENE := preload("res://scenes/level_1.tscn")
const ZONE_SCENE := preload("res://scenes/negative_zone.tscn")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")


func test_negative_zone_uses_normalized_polygon_geometry() -> void:
	var zone := ZONE_SCENE.instantiate() as NegativeZone
	zone.normalized_points = PackedVector2Array(
		[Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.75, 0.75), Vector2(0.25, 0.75)],
	)
	add_child_autofree(zone)

	assert_true(zone.contains_point(Vector2(360.0, 640.0)))
	assert_false(zone.contains_point(Vector2(80.0, 80.0)))


func test_checkpoint_requires_sustained_contact() -> void:
	var trace := ShapeTrace.new()
	trace.normalized_points = PackedVector2Array([Vector2(0.5, 0.5)])
	add_child_autofree(trace)
	trace.process_frame(0.0)
	var checkpoint := trace.get_checkpoint_position(0)

	trace.observe_drawing_point(checkpoint, true, 0.34)
	assert_eq(trace.completed_steps, 0)
	assert_almost_eq(trace.get_checkpoint_contact_progress(), 0.34 / 0.35, 0.001)
	trace.observe_drawing_point(checkpoint, true, 0.01)

	assert_eq(trace.completed_steps, 1)
	assert_eq(trace.get_checkpoint_contact_elapsed(), 0.0)


func test_negative_contact_requires_sustained_endpoint_contact() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var bad_position := Vector2(120.0, 220.0)

	level.evaluate_stream_endpoint(bad_position, true, 0.34)
	assert_eq(level.get_strikes(), 0)
	level.evaluate_stream_endpoint(bad_position, true, 0.01)
	assert_eq(level.get_strikes(), 1)
	assert_true(level.stream.is_strike_flash_active())
	level.evaluate_stream_endpoint(bad_position, true, 1.0)
	assert_eq(level.get_strikes(), 1)

	# Contact that stays in the bad zone remains armed during the grace period.
	# Once the cooldown expires, the held endpoint can trigger the next strike.
	level._process(level.safety_cooldown)
	level.evaluate_stream_endpoint(bad_position, true, 0.0)
	assert_eq(level.get_strikes(), 2)


func test_continuous_negative_contact_repeats_after_grace_period() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var bad_position := Vector2(120.0, 220.0)

	level.evaluate_stream_endpoint(bad_position, true, 0.35)
	assert_eq(level.get_strikes(), 1)
	level.evaluate_stream_endpoint(bad_position, true, level.safety_cooldown)
	assert_eq(level.get_strikes(), 1)
	level._process(level.safety_cooldown)
	level.evaluate_stream_endpoint(bad_position, true, 0.0)
	assert_eq(level.get_strikes(), 2)


func test_force_pissing_does_not_merge_separate_holds_for_contact_rules() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var controller := level.input_controller
	var bad_position := Vector2(120.0, 220.0)
	level._frame_delta = 0.35

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	level._on_drawing_point_updated(bad_position, true)
	assert_eq(level.get_strikes(), 1)

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	assert_false(controller.is_pissing())
	assert_false(controller.is_stream_input_held())
	level._on_drawing_point_updated(bad_position, true)
	assert_eq(level.get_strikes(), 1)

	level._process(level.safety_cooldown)
	var second_down := InputEventKey.new()
	second_down.physical_keycode = KEY_SPACE
	second_down.pressed = true
	controller.handle_input_event(second_down)
	level._on_drawing_point_updated(bad_position, true)
	assert_eq(level.get_strikes(), 2)


func test_four_strikes_stop_gameplay_and_show_retry_state() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var bad_position := Vector2(120.0, 220.0)

	for strike_index in 4:
		if strike_index > 0:
			level.evaluate_stream_endpoint(Vector2.ZERO, false, 0.0)
			level._process(level.safety_cooldown)
		level.evaluate_stream_endpoint(bad_position, true, 0.35)

	assert_eq(level.get_strikes(), 4)
	assert_eq(level.state, Main.FAILED)
	assert_false(level.input_controller.is_gameplay_input_enabled())
	assert_true(level.hud.game_over.visible)
	assert_true(level.hud.game_over.is_showing())

	var retry_button := level.hud.game_over.get_node("Presentation/RetryButton") as Button
	retry_button.pressed.emit()
	assert_eq(level.state, Main.PLAYING)
	assert_eq(level.get_strikes(), 0)
	assert_false(level.hud.game_over.visible)


func test_strike_forces_the_stream_input_to_release() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	level.input_controller.handle_input_event(space_down)
	assert_true(level.input_controller.is_stream_input_held())

	level._take_strike()

	assert_false(level.input_controller.is_stream_input_held())
	assert_false(level.input_controller.is_pissing())
	assert_eq(level.get_safety_cooldown_remaining(), level.safety_cooldown)


func test_reticle_uses_neutral_negative_and_success_textures() -> void:
	var reticle := TouchReticle.new()
	add_child_autofree(reticle)

	reticle.set_zone_state(TouchReticle.ReticleState.NEUTRAL)
	assert_eq(reticle.get_node("Sprite").texture, TouchReticle.CROSSHAIR_NEUTRAL)
	reticle.set_zone_state(TouchReticle.ReticleState.NEGATIVE)
	assert_eq(reticle.get_node("Sprite").texture, TouchReticle.CROSSHAIR_NEGATIVE)
	reticle.play_success_burst()
	assert_true(reticle.is_success_burst_active())
	assert_eq(reticle.get_node("Sprite").texture, TouchReticle.CROSSHAIR_SUCCESS)


func test_reticle_is_double_sized_and_uses_the_boil_material() -> void:
	var reticle := TouchReticle.new()
	add_child_autofree(reticle)
	var sprite := reticle.get_node("Sprite") as Sprite2D

	assert_eq(reticle.reticle_size, 96.0)
	assert_eq(sprite.material, BOIL_MATERIAL)
	assert_almost_eq(
		sprite.scale.x,
		reticle.reticle_size / float(sprite.texture.get_width()),
		0.001,
	)


func test_live_stream_signal_reaches_a_negative_zone() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var controller := level.input_controller
	var bad_position := Vector2(120.0, 220.0)
	controller.set_target_position(bad_position)
	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	for _frame in 120:
		level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.get_strikes(), 1)


func test_live_stream_signal_reaches_a_positive_checkpoint() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var controller := level.input_controller
	var checkpoint := level.shape_trace.get_checkpoint_position(0)
	controller.set_target_position(checkpoint)
	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	for _frame in 120:
		level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.shape_trace.completed_steps, 1)


func test_initial_stream_to_toilet_does_not_cross_the_floor_first() -> void:
	var level := LEVEL_1_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.stream.set_process(false)
	level.input_controller.set_process(false)

	var checkpoint := level.shape_trace.get_checkpoint_position(0)
	level.input_controller.set_target_position(checkpoint)
	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	level.input_controller.handle_input_event(space_down)
	for _frame in 30:
		level.stream.process_frame(1.0 / 60.0)

	assert_eq(level.get_strikes(), 0)
	assert_false(level.stream.has_active_stream_endpoint())


func test_live_mouse_stream_signal_reaches_a_negative_zone() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var controller := level.input_controller
	var bad_position := Vector2(120.0, 220.0)
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.position = bad_position
	mouse_down.pressed = true
	controller.handle_input_event(mouse_down)
	for _frame in 120:
		level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.get_strikes(), 1)


func test_live_stream_can_switch_from_negative_hold_to_positive_hold() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var controller := level.input_controller
	var bad_position := Vector2(120.0, 220.0)
	controller.set_target_position(bad_position)
	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	for _frame in 120:
		level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.get_strikes(), 1)

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	level._process(level.safety_cooldown)

	controller.set_target_position(level.shape_trace.get_checkpoint_position(0))
	controller.handle_input_event(space_down)
	for _frame in 120:
		level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.shape_trace.completed_steps, 1)


func test_live_stream_stops_after_a_negative_strike_until_repressed() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var controller := level.input_controller
	var bad_position := Vector2(120.0, 220.0)
	controller.set_target_position(bad_position)
	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	for _frame in 120:
		level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.get_strikes(), 1)

	level._process(level.safety_cooldown)
	level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.get_strikes(), 1)

	level.input_controller.handle_input_event(space_down)
	for _frame in 120:
		level.stream.process_frame(1.0 / 60.0)
	assert_eq(level.get_strikes(), 2)
