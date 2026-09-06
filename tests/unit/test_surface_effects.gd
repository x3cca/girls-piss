extends GutTest

const LEVEL_SCENE := preload("res://scenes/level_1.tscn")


func _level() -> Level1:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	return level


func test_all_bathroom_surfaces_have_independent_reusable_shaders() -> void:
	var level := _level()
	var effects := level.surface_effects
	var bowl := effects.get_surface_material(SurfaceEffects.SURFACE_BOWL)
	var seat := effects.get_surface_material(SurfaceEffects.SURFACE_SEAT)
	var floor := effects.get_surface_material(SurfaceEffects.SURFACE_FLOOR)
	var wall := effects.get_surface_material(SurfaceEffects.SURFACE_WALL)
	var tank := effects.get_surface_material(SurfaceEffects.SURFACE_TANK)

	assert_not_null(bowl)
	assert_not_null(seat)
	assert_not_null(floor)
	assert_not_null(wall)
	assert_not_null(tank)
	assert_not_same(bowl, seat)
	assert_not_same(seat, floor)
	assert_not_same(floor, wall)
	assert_not_same(wall, tank)
	assert_not_same(
		effects.get_surface_stain_map(SurfaceEffects.SURFACE_BOWL),
		effects.get_surface_stain_map(SurfaceEffects.SURFACE_SEAT),
	)
	assert_eq(
		(bowl.shader as Shader).resource_path,
		"res://shaders/surface_paint.gdshader",
	)
	assert_eq(effects.get_surface_node(SurfaceEffects.SURFACE_BOWL).name, "Bowl")
	assert_eq(bowl.get_shader_parameter("water_mask_enabled"), 1.0)
	var water := effects.get_water_material(SurfaceEffects.SURFACE_BOWL)
	assert_not_null(water)
	assert_eq(
		(water.shader as Shader).resource_path,
		"res://shaders/surface_ripple.gdshader",
	)
	assert_almost_eq(water.get_shader_parameter("water_yellowness"), 0.0, 0.001)
	assert_eq(
		(seat.shader as Shader).resource_path,
		"res://shaders/surface_paint.gdshader",
	)
	assert_eq(
		(floor.shader as Shader).resource_path,
		"res://shaders/surface_paint.gdshader",
	)
	assert_eq(
		(wall.shader as Shader).resource_path,
		"res://shaders/surface_drips.gdshader",
	)
	assert_eq(
		(tank.shader as Shader).resource_path,
		"res://shaders/surface_drips.gdshader",
	)
	assert_eq(bowl.get_shader_parameter("stain_color"), SurfaceEffects.DEFAULT_STAIN_COLOR)
	assert_eq(bowl.get_shader_parameter("stain_opacity"), SurfaceEffects.DEFAULT_STAIN_OPACITY)
	assert_eq(water.get_shader_parameter("ripple_age"), 0.0)
	assert_eq(seat.get_shader_parameter("stain_color"), SurfaceEffects.DEFAULT_STAIN_COLOR)
	assert_eq(seat.get_shader_parameter("stain_opacity"), SurfaceEffects.DEFAULT_STAIN_OPACITY)


func test_endpoint_classification_uses_alpha_and_wall_floor_boundary() -> void:
	var level := _level()
	var effects := level.surface_effects
	var bowl := level.get_node("PissToilet/Bowl") as Sprite2D
	var seat := level.get_node("PissToilet/Seat") as Sprite2D
	var tank := level.get_node("PissToilet/Tank") as Sprite2D
	var wall := level.get_node("Level1Background/BackWall") as Sprite2D
	var floor := level.get_node("Level1Background/Floor") as Sprite2D

	# Derive samples from the authored sprites so this remains deterministic when
	# the test viewport is resized by the runner.
	assert_eq(effects.detect_surface(bowl.global_position), SurfaceEffects.SURFACE_BOWL)
	assert_eq(
		effects.detect_surface(
			seat.to_global(Vector2(0.0, seat.texture.get_height() * 0.5 - 20.0)),
		),
		SurfaceEffects.SURFACE_SEAT,
	)
	assert_eq(effects.detect_surface(tank.global_position), SurfaceEffects.SURFACE_TANK)
	assert_eq(effects.detect_surface(wall.to_global(Vector2(10.0, 10.0))), SurfaceEffects.SURFACE_WALL)
	assert_eq(
		effects.detect_surface(
			floor.to_global(Vector2(10.0, floor.texture.get_height() - 10.0)),
		),
		SurfaceEffects.SURFACE_FLOOR,
	)


func test_contact_builds_bowl_noise_and_keeps_one_ripple() -> void:
	var level := _level()
	var effects := level.surface_effects
	var bowl := level.get_node("PissToilet/Bowl") as Sprite2D
	var seat := level.get_node("PissToilet/Seat") as Sprite2D
	var bowl_position := bowl.global_position

	effects.observe_stream_endpoint(bowl_position, true)
	assert_eq(effects.get_detected_surface(), SurfaceEffects.SURFACE_BOWL)
	assert_true(effects.is_surface_active(SurfaceEffects.SURFACE_BOWL))
	assert_eq(effects.get_surface_strength(SurfaceEffects.SURFACE_BOWL), 1.0)
	assert_eq(effects.get_surface_strength(SurfaceEffects.SURFACE_SEAT), 0.0)
	assert_eq(effects.get_bowl_ripple_count(), 1)
	assert_eq(effects.get_surface_stain_count(SurfaceEffects.SURFACE_BOWL), 1)
	assert_gt(effects.get_surface_stain_value(SurfaceEffects.SURFACE_BOWL, bowl_position), 0.0)
	assert_eq(effects.get_water_material(SurfaceEffects.SURFACE_BOWL).get_shader_parameter("ripple_age"), 0.0)
	var first_ripple_center: Vector2 = effects.get_bowl_ripples()[0]["uv"] as Vector2

	# Continuous endpoint updates add persistent noise without creating another
	# radial ripple or moving the existing ripple center.
	effects.observe_stream_endpoint(bowl_position + Vector2(8.0, 0.0), true)
	assert_eq(effects.get_surface_stain_count(SurfaceEffects.SURFACE_BOWL), 2)
	assert_eq(effects.get_bowl_ripple_count(), 1)
	assert_eq(effects.get_bowl_ripples()[0]["uv"], first_ripple_center)

	# The mark remains after a long pause; only a level reset clears it.
	effects._process(10.0)
	assert_true(effects.is_surface_active(SurfaceEffects.SURFACE_BOWL))
	assert_eq(effects.get_surface_strength(SurfaceEffects.SURFACE_BOWL), 1.0)
	assert_gt(effects.get_surface_stain_value(SurfaceEffects.SURFACE_BOWL, bowl_position), 0.0)
	assert_almost_eq(
		effects.get_water_material(SurfaceEffects.SURFACE_BOWL).get_shader_parameter("ripple_age"),
		10.0,
		0.001,
	)

	# A released re-hit updates the one ripple to the new real impact.
	effects.observe_stream_endpoint(Vector2.ZERO, false)
	var second_bowl_position := (
			bowl
	).to_global(Vector2(80.0, 80.0))
	assert_eq(effects.detect_surface(second_bowl_position), SurfaceEffects.SURFACE_BOWL)
	effects.observe_stream_endpoint(second_bowl_position, true)
	assert_eq(effects.get_bowl_ripple_count(), 1)
	assert_eq(effects.get_surface_stain_count(SurfaceEffects.SURFACE_BOWL), 3)
	assert_ne(effects.get_bowl_ripples()[0]["uv"], first_ripple_center)
	assert_gt(effects.get_surface_stain_value(SurfaceEffects.SURFACE_BOWL, second_bowl_position), 0.0)
	assert_eq(effects.get_surface_strength(SurfaceEffects.SURFACE_SEAT), 0.0)

	# Non-bowl surfaces use their own permanent map as well.
	effects.observe_stream_endpoint(Vector2.ZERO, false)
	var seat_position := seat.to_global(Vector2(0.0, seat.texture.get_height() * 0.5 - 20.0))
	effects.observe_stream_endpoint(seat_position, true)
	assert_eq(effects.get_surface_stain_count(SurfaceEffects.SURFACE_SEAT), 1)
	assert_gt(effects.get_surface_stain_value(SurfaceEffects.SURFACE_SEAT, seat_position), 0.0)
	effects._process(10.0)
	assert_true(effects.is_surface_active(SurfaceEffects.SURFACE_SEAT))
	assert_eq(effects.get_surface_strength(SurfaceEffects.SURFACE_SEAT), 1.0)

	effects.observe_stream_endpoint(Vector2.ZERO, false)
	assert_eq(effects.get_detected_surface(), SurfaceEffects.SURFACE_NONE)
	effects.reset_effects()
	for surface in SurfaceEffects.SURFACES:
		assert_false(effects.is_surface_active(surface))
		assert_eq(effects.get_surface_strength(surface), 0.0)
		assert_eq(effects.get_surface_stain_count(surface), 0)
		assert_eq(effects.get_surface_stain_value(surface, bowl_position), 0.0)
	assert_eq(effects.get_bowl_ripple_count(), 0)


func test_water_yellowness_tracks_remaining_meter() -> void:
	var level := _level()
	var effects := level.surface_effects
	var water := effects.get_water_material(SurfaceEffects.SURFACE_BOWL)

	effects.set_meter_progress(1.0)
	assert_almost_eq(effects.get_water_yellowness(), 0.0, 0.001)
	assert_almost_eq(water.get_shader_parameter("water_yellowness"), 0.0, 0.001)

	effects.set_meter_progress(0.25)
	assert_almost_eq(effects.get_water_yellowness(), 0.75, 0.001)
	assert_almost_eq(water.get_shader_parameter("water_yellowness"), 0.75, 0.001)

	effects.set_meter_progress(0.0)
	assert_almost_eq(effects.get_water_yellowness(), 1.0, 0.001)
	assert_almost_eq(water.get_shader_parameter("water_yellowness"), 1.0, 0.001)
