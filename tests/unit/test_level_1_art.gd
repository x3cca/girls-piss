extends GutTest

const LEVEL_SCENE := preload("res://scenes/level_1.tscn")
const METER_SCENE := preload("res://scenes/piss_meter.tscn")
const STRIKE_EFFECT := preload("res://scenes/strike_vignette.tscn")
const SUCCESS_EFFECT := preload("res://scenes/success_vignette.tscn")


func test_level_1_uses_the_authored_target_set_and_background() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)

	assert_eq(level.shape_trace.normalized_points.size(), 10)
	assert_eq(level.shape_trace.target_textures.size(), 10)
	assert_eq(level.shape_trace.checkpoint_look_ahead, 3)
	assert_almost_eq(level.shape_trace.look_ahead_opacity, 0.25, 0.001)
	assert_almost_eq(level.shape_trace.look_ahead_opacity_falloff, 0.5, 0.001)
	assert_eq(
		level.input_controller.get_target_position(),
		level.shape_trace.get_checkpoint_position(0),
	)
	assert_eq(
		level.shape_trace.target_textures[0].resource_path,
		"res://assets/art/drive/RedTicket.png",
	)
	assert_eq(
		level.shape_trace.target_textures[9].resource_path,
		"res://assets/art/drive/Tampon.png",
	)
	assert_almost_eq(level.shape_trace.native_target_scale, 1.0, 0.001)
	assert_eq(
		level.target_points,
		PackedVector2Array(
			[
				Vector2(0.27, 0.53),
				Vector2(0.34, 0.40),
				Vector2(0.43, 0.41),
				Vector2(0.70, 0.52),
				Vector2(0.46, 0.80),
				Vector2(0.61, 0.43),
				Vector2(0.64, 0.74),
				Vector2(0.69, 0.61),
				Vector2(0.52, 0.59),
				Vector2(0.28, 0.65),
			],
		),
	)
	assert_false(level.draw_neutral_canvas)
	assert_false(level.get_node("DepthMap").debug_visualization)
	assert_gt(level.shape_trace.z_index, level.get_node("PissToilet/Bowl").z_index)
	assert_lt(level.shape_trace.z_index, level.get_node("PissToilet/Seat").z_index)
	assert_gt(level.line_replay.z_index, level.get_node("Level1Chrome").z_index)
	assert_gt(level.line_replay.z_index, level.shape_trace.z_index)
	assert_eq(
		level.get_node("Level1Background/BackWall").texture.resource_path,
		"res://assets/art/drive/BackWalll.png",
	)
	assert_eq(
		level.get_node("Level1Background/Floor").texture.resource_path,
		"res://assets/art/drive/Floor.png",
	)
	assert_eq(
		level.get_node("Level1Chrome/Volume").texture.resource_path,
		"res://assets/art/drive/Volume1.png",
	)
	assert_eq(
		level.get_node("Level1Chrome/Back").texture.resource_path,
		"res://assets/art/drive/Back1.png",
	)
	level.shape_trace.process_frame(0.0)
	assert_true(level.shape_trace._targets[0].visible)
	assert_true(level.shape_trace._targets[1].visible)
	assert_true(level.shape_trace._targets[2].visible)
	assert_false(level.shape_trace._targets[3].visible)
	assert_eq(
		level.shape_trace._targets[0].get_node("Sprite").texture.resource_path,
		"res://assets/art/drive/RedTicket.png",
	)
	assert_eq(
		level.shape_trace._targets[1].get_node("Sprite").texture.resource_path,
		"res://assets/art/drive/Floss.png",
	)
	assert_eq(
		level.shape_trace._targets[2].get_node("Sprite").texture.resource_path,
		"res://assets/art/drive/Gum.png",
	)
	assert_almost_eq(level.shape_trace._targets[0].modulate.a, 1.0, 0.001)
	assert_almost_eq(level.shape_trace._targets[1].modulate.a, 0.25, 0.001)
	assert_almost_eq(level.shape_trace._targets[2].modulate.a, 0.125, 0.001)
	for index in level.shape_trace.normalized_points.size():
		assert_eq(
			level.shape_trace._targets[index].position,
			level.shape_trace.get_checkpoint_position(index),
		)


func test_level_1_floor_is_bad_but_toilet_and_wall_are_neutral() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)

	var wall_position := Vector2(360.0, 200.0)
	var tank_position := Vector2(360.0, 300.0)
	var seat_position := Vector2(360.0, 700.0)
	var floor_position := Vector2(360.0, 1240.0)

	level.evaluate_stream_endpoint(wall_position, true, 0.35)
	level.evaluate_stream_endpoint(tank_position, true, 0.35)
	level.evaluate_stream_endpoint(seat_position, true, 0.35)
	assert_eq(level.get_strikes(), 0)

	level.evaluate_stream_endpoint(floor_position, true, 0.35)
	assert_eq(level.get_strikes(), 1)


func test_title_composition_keeps_level_1_visible_underneath() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	add_child_autofree(level)

	var title := level.get_node("TitleLayer/TitleScreen") as TitleScreen
	var composition := title.get_node("Overlay/TitleComposition") as TitleComposition
	assert_true(title.is_active())
	assert_true(composition.visible)
	assert_true(level.get_node("Level1Background").visible)
	assert_eq(title.layer, 20)


func test_piss_meter_has_a_five_minute_continuous_stream_budget() -> void:
	var meter := METER_SCENE.instantiate() as PissMeter
	var controller := InputController.new()
	add_child_autofree(controller)
	add_child_autofree(meter)
	meter.input_controller = controller
	meter.set_gameplay_active(true)

	assert_almost_eq(meter.duration_seconds, 300.0, 0.001)
	assert_almost_eq(meter.get_time_remaining(), 300.0, 0.001)
	meter._process(10.0)
	assert_almost_eq(meter.get_time_remaining(), 300.0, 0.001)

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	meter._process(10.0)
	assert_almost_eq(meter.get_time_remaining(), 290.0, 0.001)

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	meter._process(10.0)
	assert_almost_eq(meter.get_time_remaining(), 290.0, 0.001)


func test_empty_piss_meter_fails_the_level_like_three_strikes() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	var meter := level.hud.piss_meter
	meter.duration_seconds = 1.0
	meter.reset_meter()

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	level.input_controller.handle_input_event(space_down)
	meter._process(1.0)

	assert_true(meter.is_depleted())
	assert_eq(level.state, Main.FAILED)
	assert_false(level.input_controller.is_gameplay_input_enabled())
	assert_true(level.hud.completion_card.is_failure_card())


func test_feedback_scenes_use_the_downloaded_overlay_art() -> void:
	var strike := STRIKE_EFFECT.instantiate() as ScreenOverlayEffect
	var success := SUCCESS_EFFECT.instantiate() as ScreenOverlayEffect
	add_child_autofree(strike)
	add_child_autofree(success)

	var strike_frames: SpriteFrames = strike.get_node("AnimatedSprite2D").sprite_frames
	var success_frames: SpriteFrames = success.get_node("AnimatedSprite2D").sprite_frames
	assert_eq(strike_frames.get_frame_count(&"default"), 2)
	assert_eq(success_frames.get_frame_count(&"default"), 2)
	assert_eq(
		strike_frames.get_frame_texture(&"default", 0).resource_path,
		"res://assets/art/drive/Dread vignette.png",
	)
	assert_eq(
		success_frames.get_frame_texture(&"default", 1).resource_path,
		"res://assets/art/drive/actionWiggleFlipForAffect.png",
	)
