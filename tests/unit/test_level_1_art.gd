extends GutTest

const LEVEL_SCENE := preload("res://scenes/level_1.tscn")
const METER_SCENE := preload("res://scenes/piss_meter.tscn")
const STRIKE_EFFECT := preload("res://scenes/strike_vignette.tscn")
const SUCCESS_EFFECT := preload("res://scenes/success_vignette.tscn")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")
const BOWL_SHADER := preload("res://shaders/surface_paint.gdshader")
const WATER_SHADER := preload("res://shaders/surface_ripple.gdshader")


func test_level_1_uses_the_authored_target_set_and_background() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)

	assert_eq(level.shape_trace.normalized_points.size(), 10)
	assert_eq(level.shape_trace.target_textures.size(), 10)
	assert_eq(level.shape_trace.checkpoint_look_ahead, 1)
	assert_almost_eq(level.shape_trace.look_ahead_opacity, 0.25, 0.001)
	assert_almost_eq(level.shape_trace.look_ahead_opacity_falloff, 0.5, 0.001)
	assert_eq(
		level.input_controller.get_target_position(),
		level.shape_trace.get_checkpoint_position(0),
	)
	var target_texture_paths: Array[String] = []
	for texture in level.shape_trace.target_textures:
		target_texture_paths.append(texture.resource_path)
	for expected_texture_path in [
		"res://assets/art/drive/RedTicket.png",
		"res://assets/art/drive/Floss.png",
		"res://assets/art/drive/Gum.png",
		"res://assets/art/drive/Cigarette.png",
		"res://assets/art/drive/Lollipop.png",
		"res://assets/art/drive/Condom.png",
		"res://assets/art/drive/Bandaid.png",
		"res://assets/art/drive/Fly.png",
		"res://assets/art/drive/Straw.png",
		"res://assets/art/drive/Tampon.png",
	]:
		assert_true(target_texture_paths.has(expected_texture_path))
	assert_almost_eq(level.shape_trace.native_target_scale, 0.75, 0.001)
	assert_eq(level.target_offsets.size(), 10)
	assert_false(level.draw_neutral_canvas)
	assert_false(level.get_node("DepthMap").debug_visualization)
	assert_gt(level.shape_trace.z_index, level.get_node("PissToilet/Bowl").z_index)
	assert_lt(level.shape_trace.z_index, level.get_node("PissToilet/Seat").z_index)
	assert_gt(level.line_replay.z_index, level.get_node("Level1Chrome").z_index)
	assert_gt(level.line_replay.z_index, level.shape_trace.z_index)
	assert_eq(level.get_node("PissToilet/Outside").scale, Vector2.ONE * 0.75)
	assert_eq(level.get_node("PissToilet/Bowl").scale, Vector2.ONE * 0.75)
	assert_eq(level.get_node("PissToilet/Seat").scale, Vector2.ONE * 0.75)
	assert_eq(level.get_node("PissToilet/Tank").scale, Vector2.ONE * 0.8)
	# These transforms are authored in piss_toilet.tscn. The runtime layout pass
	# must preserve the hand-tuned bowl/seat placement.
	assert_eq(level.get_node("PissToilet/Bowl").position, Vector2(0.0, -92.125))
	assert_eq(level.get_node("PissToilet/Seat").position, Vector2(0.0, -92.875))
	assert_eq(level.get_node("PissToilet/Tank").position, Vector2(0.0, -720.0))
	assert_eq(
		level.get_node("Level1Background/BackWall").texture.resource_path,
		"res://assets/art/drive/BackWalll.png",
	)
	assert_eq(
		level.get_node("Level1Background/Floor").texture.resource_path,
		"res://assets/art/drive/Floor.png",
	)
	assert_eq(
		level.get_node("Level1Chrome/VolumeIcons/Volume3").texture.resource_path,
		"res://assets/art/drive/Volume3.png",
	)
	assert_eq(
		level.get_node("Level1Chrome/Back").texture.resource_path,
		"res://assets/art/drive/Back1.png",
	)
	level.shape_trace.process_frame(0.0)
	assert_true(level.shape_trace._targets[0].visible)
	assert_false(level.shape_trace._targets[1].visible)
	assert_false(level.shape_trace._targets[2].visible)
	assert_false(level.shape_trace._targets[3].visible)
	for index in level.shape_trace.target_textures.size():
		assert_eq(
			level.shape_trace._targets[index].get_node("Sprite").texture,
			level.shape_trace.target_textures[index],
		)
	assert_almost_eq(level.shape_trace._targets[0].modulate.a, 1.0, 0.001)
	for index in level.shape_trace.normalized_points.size():
		assert_eq(
			level.shape_trace._targets[index].position,
			level.shape_trace.get_checkpoint_position(index),
		)
		var toilet := level.get_node("PissToilet") as PissToilet
		var expected_position := toilet.to_global(
			toilet.get_bowl_anchor_local() + level.target_offsets[index],
		)
		assert_almost_eq(
			level.shape_trace.get_checkpoint_position(index).distance_to(expected_position),
			0.0,
			0.001,
		)


func test_level_1_target_slots_are_spaced_and_edge_weighted() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)

	var edge_slot_count := 0
	for index in level.target_offsets.size():
		var offset: Vector2 = level.target_offsets[index]
		if offset.length() >= Level1.TARGET_SPAWN_EDGE_RADIUS:
			edge_slot_count += 1
		for previous_index in index:
			assert_gte(
				offset.distance_to(level.target_offsets[previous_index]),
				Level1.TARGET_SPAWN_MIN_DISTANCE,
			)

	assert_eq(edge_slot_count, level.target_offsets.size() - 1)


func test_web_export_uses_level_1_as_the_main_scene() -> void:
	var export_presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(
		export_presets.contains(
			'export_files=PackedStringArray("res://scenes/level_1.tscn")',
		),
	)
	assert_true(export_presets.contains("resources/materials/item_outline.tres"))
	assert_true(export_presets.contains("shaders/item_outline.gdshader"))
	assert_true(export_presets.contains("assets/art/drive/Pisstank.png"))
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 540)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 960)


func test_level_1_floor_and_seat_are_bad_but_wall_and_tank_are_neutral() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)

	var wall_position := Vector2(5.0, 150.0)
	var tank_position := Vector2(270.0, 225.0)
	var seat_position := Vector2(60.0, 542.0)
	var floor_position := Vector2(30.0, 930.0)

	level.evaluate_stream_endpoint(wall_position, true, 0.35)
	level.evaluate_stream_endpoint(tank_position, true, 0.35)
	level.evaluate_stream_endpoint(seat_position, true, 0.35)
	assert_eq(level.get_strikes(), 1)

	level.evaluate_stream_endpoint(Vector2.ZERO, false, 0.0)
	level._process(level.safety_cooldown)
	level.evaluate_stream_endpoint(floor_position, true, 0.35)
	assert_eq(level.get_strikes(), 2)


func test_title_composition_keeps_level_1_visible_underneath() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	add_child_autofree(level)

	var title := level.get_node("TitleLayer/TitleScreen") as TitleScreen
	var composition := title.get_node("Overlay/TitleComposition") as TitleComposition
	assert_true(title.is_active())
	assert_true(composition.visible)
	assert_true(level.get_node("Level1Background").visible)
	assert_eq(title.layer, 20)


func test_piss_meter_has_a_thirty_second_continuous_stream_budget() -> void:
	var meter := METER_SCENE.instantiate() as PissMeter
	var controller := InputController.new()
	add_child_autofree(controller)
	add_child_autofree(meter)
	meter.input_controller = controller
	meter.set_gameplay_active(true)

	assert_almost_eq(meter.duration_seconds, 30.0, 0.001)
	assert_almost_eq(meter.get_time_remaining(), 30.0, 0.001)
	var liquid := meter.get_node("Liquid") as TextureRect
	var liquid_material := liquid.material as ShaderMaterial
	var fill := meter.get_node("Fill") as TextureProgressBar
	assert_not_null(liquid_material)
	assert_almost_eq(fill.modulate.a, 50.0 / 255.0, 0.001)
	if liquid_material:
		assert_almost_eq(liquid_material.get_shader_parameter("fluid_amount"), 1.0, 0.001)
		assert_almost_eq(liquid_material.get_shader_parameter("wave_amplitude"), 0.012, 0.001)
	meter._process(10.0)
	assert_almost_eq(meter.get_time_remaining(), 30.0, 0.001)

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)
	meter._process(10.0)
	assert_almost_eq(meter.get_time_remaining(), 20.0, 0.001)
	if liquid_material:
		assert_almost_eq(
			liquid_material.get_shader_parameter("fluid_amount"),
			20.0 / 30.0,
			0.001,
		)

	var space_up := InputEventKey.new()
	space_up.physical_keycode = KEY_SPACE
	space_up.pressed = false
	controller.handle_input_event(space_up)
	meter._process(10.0)
	# Releasing the start control does not pause or recharge the latched stream.
	assert_almost_eq(meter.get_time_remaining(), 10.0, 0.001)


func test_piss_meter_art_uses_the_shared_boil_material() -> void:
	var meter := METER_SCENE.instantiate() as PissMeter
	add_child_autofree(meter)

	for node_path in ["Fill", "Frame", "Lemon", "DripOne", "DripTwo"]:
		var canvas_item := meter.get_node(node_path) as CanvasItem
		assert_not_null(canvas_item, "%s should be a meter canvas item." % node_path)
		assert_true(canvas_item.material == BOIL_MATERIAL, "%s should use the boil material." % node_path)


func test_completion_card_shows_the_kenney_cursor() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	var completion := level.hud.completion_card
	var play_again_button := completion.get_node("PlayAgainButton") as Button

	completion.show_card()

	assert_true(completion.visible)
	assert_eq(Input.get_mouse_mode(), Input.MOUSE_MODE_VISIBLE)
	assert_eq(play_again_button.mouse_default_cursor_shape, Control.CURSOR_ARROW)


func test_completion_card_bowl_uses_splat_shader_and_water_uses_ripple_shader() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)

	var main_bowl := level.get_node("PissToilet/Bowl") as Sprite2D
	var win_bowl := level.hud.completion_card.get_node(
		"Presentation/Art/GoodJobGroup/Bowl",
	) as Sprite2D
	var main_water := level.get_node("PissToilet/BowlWater") as Sprite2D
	var win_water := level.hud.completion_card.get_node(
		"Presentation/Art/GoodJobGroup/BowlWater",
	) as Sprite2D

	assert_eq((main_bowl.material as ShaderMaterial).shader, BOWL_SHADER)
	assert_eq((win_bowl.material as ShaderMaterial).shader, BOWL_SHADER)
	assert_eq((main_water.material as ShaderMaterial).shader, WATER_SHADER)
	assert_eq((win_water.material as ShaderMaterial).shader, WATER_SHADER)


func test_piss_meter_reveals_with_a_left_slide_when_gameplay_starts() -> void:
	var meter := METER_SCENE.instantiate() as PissMeter
	var controller := InputController.new()
	add_child_autofree(controller)
	add_child_autofree(meter)
	meter.input_controller = controller

	assert_false(meter.visible)
	meter.set_gameplay_active(true)

	assert_true(meter.visible)
	var hidden_x := meter.position.x
	var rest_x := meter._rest_position.x
	assert_lt(hidden_x, 0.0)

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	controller.handle_input_event(space_down)

	assert_true(meter.visible)
	assert_eq(meter.position.x, hidden_x)
	await get_tree().process_frame
	assert_gt(meter.position.x, hidden_x)

	await get_tree().create_timer(0.8).timeout
	assert_almost_eq(meter.position.x, rest_x, 0.01)


func test_empty_piss_meter_stops_stream_and_recharges_without_failing_level() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	var meter := level.hud.piss_meter
	meter.duration_seconds = 1.0
	meter.recharge_rate = 1.0
	meter.reset_meter()

	var space_down := InputEventKey.new()
	space_down.physical_keycode = KEY_SPACE
	space_down.pressed = true
	level.input_controller.handle_input_event(space_down)
	meter._process(1.0)

	assert_true(meter.is_depleted())
	assert_eq(level.state, Main.PLAYING)
	assert_false(level.input_controller.is_stream_input_held())
	assert_true(level.input_controller.is_gameplay_input_enabled())
	assert_false(level.hud.game_over.is_showing())

	meter._process(0.5)
	assert_almost_eq(meter.get_time_remaining(), 0.5, 0.001)


func test_feedback_scenes_use_the_downloaded_strike_and_action_line_art() -> void:
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
	assert_true(strike.get_node("AnimatedSprite2D").material == BOIL_MATERIAL)
	assert_true(success.get_node("AnimatedSprite2D").material == BOIL_MATERIAL)
