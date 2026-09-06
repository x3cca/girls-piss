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
	trace.target_texture = _solid_texture()
	add_child_autofree(trace)
	trace.process_frame(0.0)
	var checkpoint := trace.get_checkpoint_position(0)

	trace.observe_drawing_point(checkpoint, true, 0.34)
	assert_eq(trace.completed_steps, 0)
	assert_almost_eq(trace.get_checkpoint_contact_progress(), 0.34 / 0.35, 0.001)
	trace.observe_drawing_point(checkpoint, true, 0.01)

	assert_eq(trace.completed_steps, 1)
	assert_eq(trace.get_checkpoint_contact_elapsed(), 0.0)


func test_negative_contact_strikes_on_first_endpoint_contact() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var bad_position := Vector2(120.0, 220.0)

	# A single committed frame in the negative region is enough.
	level.evaluate_stream_endpoint(bad_position, true, 0.0)
	assert_eq(level.get_strikes(), 1)
	assert_true(level.stream.is_strike_flash_active())
	level.evaluate_stream_endpoint(bad_position, true, 1.0)
	assert_eq(level.get_strikes(), 1)

	# Contact that stays in the bad zone remains blocked during the safety
	# cooldown. Once it expires, the held endpoint can trigger the next strike.
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


func test_third_strike_waits_for_red_warning_then_stops_gameplay() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	var bad_position := Vector2(120.0, 220.0)

	for strike_index in 3:
		if strike_index > 0:
			level.evaluate_stream_endpoint(Vector2.ZERO, false, 0.0)
			level._process(level.safety_cooldown)
		level.evaluate_stream_endpoint(bad_position, true, 0.35)

	assert_eq(level.max_strikes, 3)
	assert_eq(level.get_strikes(), 3)
	assert_eq(level.state, Main.FAILED)
	assert_true(
		level.hud.strike_warning.is_warning_visible(StrikeWarning.RED_WARNING)
	)
	assert_eq(
		level.hud.strike_warning.get_remaining_duration(),
		Main.FINAL_STRIKE_WARNING_DURATION,
	)
	assert_false(level.input_controller.is_gameplay_input_enabled())
	assert_false(level.hud.game_over.visible)

	level.hud.strike_warning.process_frame(Main.FINAL_STRIKE_WARNING_DURATION - 0.01)
	assert_eq(level.state, Main.FAILED)
	assert_true(
		level.hud.strike_warning.is_warning_visible(StrikeWarning.RED_WARNING)
	)
	level.hud.strike_warning.process_frame(0.01)

	assert_eq(level.state, Main.FAILED)
	assert_false(level.input_controller.is_gameplay_input_enabled())
	assert_true(level.hud.game_over.visible)
	assert_true(level.hud.game_over.is_showing())

	var retry_button := level.hud.game_over.get_node("Presentation/RetryButton") as TextureButton
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


func test_left_bracket_debug_shortcut_triggers_an_instant_strike() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)

	var left_bracket := InputEventKey.new()
	left_bracket.physical_keycode = KEY_BRACKETLEFT
	left_bracket.pressed = true
	level._unhandled_input(left_bracket)
	level._unhandled_input(left_bracket)

	assert_eq(level.get_strikes(), 2)


func test_right_bracket_debug_shortcut_completes_immediately() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)

	var right_bracket := InputEventKey.new()
	right_bracket.physical_keycode = KEY_BRACKETRIGHT
	right_bracket.pressed = true
	level._unhandled_input(right_bracket)

	assert_eq(level.state, Main.COMPLETE)
	assert_true(level.hud.completion_card.visible)


func test_completion_card_shows_while_tracking_replay_runs_behind_it() -> void:
	var level := LEVEL_SCENE.instantiate() as Main
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)
	level.line_recorder._strokes = [
		[
			{ "position": Vector2(0.1, 0.2), "timestamp": 0.0 },
			{ "position": Vector2(0.4, 0.2), "timestamp": 5.0 },
		],
	]

	level._on_trace_completed()

	assert_eq(level.state, Main.REPLAYING)
	assert_true(level.hud.completion_card.visible)
	assert_true(level.line_replay.is_replaying())

	level.line_replay.process_frame(level.line_replay.get_duration())

	assert_eq(level.state, Main.COMPLETE)
	assert_true(level.hud.completion_card.visible)


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
	var target_position := _find_target_pixel(level.shape_trace)
	controller.set_target_position(target_position)
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

	controller.set_target_position(_find_target_pixel(level.shape_trace))
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


func _find_target_pixel(trace: ShapeTrace) -> Vector2:
	# The smoke-test aimer is a hollow ring, so its checkpoint center is
	# intentionally transparent. Choose a stable point from the rendered alpha
	# mask instead of teaching the test to use a center estimate.
	trace.set_process(false)
	for target in trace._targets:
		target.set_process(false)
	var target := trace._targets[trace.completed_steps]
	var center := target.global_position
	var best_position := center
	var best_score := -1
	for y in range(-128, 129):
		for x in range(-128, 129):
			var candidate := center + Vector2(x, y)
			if not target.contains_point(candidate):
				continue
			var score := 0
			for neighbor in [
				Vector2(-1.0, 0.0),
				Vector2(1.0, 0.0),
				Vector2(0.0, -1.0),
				Vector2(0.0, 1.0),
			]:
				if target.contains_point(candidate + neighbor):
					score += 1
			if score > best_score:
				best_score = score
				best_position = candidate
	return best_position


func _solid_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
