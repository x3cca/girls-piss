extends GutTest

const SMOKE_TEST_SCENE := preload("res://scenes/smoke_test.tscn")


func test_liquid_stream_scene_builds_playable_nodes() -> void:
	var scene := SMOKE_TEST_SCENE
	assert_not_null(scene, "The portrait prototype scene should be loadable.")

	var instance := scene.instantiate()
	add_child_autofree(instance)

	assert_true(instance is Node2D)
	assert_eq(instance.name, "LiquidStreamPrototype")
	assert_not_null(instance.get_node_or_null("InputController"))
	assert_not_null(instance.get_node_or_null("LiquidStream"))
	assert_not_null(instance.get_node_or_null("HUDLayer/HUD"))
	var stream := instance.get_node("LiquidStream") as LiquidStream
	var visible_size := instance.get_viewport().get_visible_rect().size
	assert_gt(stream.to_global(stream.source_position).y, visible_size.y)
	var input_controller := instance.get_node_or_null("InputController") as InputController
	var shape_trace := instance.get_node_or_null("ShapeTrace") as ShapeTrace
	assert_not_null(shape_trace)
	assert_not_null(input_controller)
	if shape_trace:
		assert_false(shape_trace.show_outline)
		assert_eq(shape_trace.target_size, 144.0)
	if shape_trace and input_controller:
		assert_eq(
			input_controller.get_target_position(),
			shape_trace.get_checkpoint_position(0),
		)
	var hud := instance.get_node_or_null("HUDLayer/HUD")
	var aim_reticle := hud.get_node_or_null("AimReticle") if hud else null
	assert_true(aim_reticle is TouchReticle)
	assert_not_null(aim_reticle.get_node_or_null("Sprite") if aim_reticle else null)
	var carrot_marker := hud.get_node_or_null("CarrotMarker") if hud else null
	assert_true(carrot_marker is TextureRect)
	assert_not_null(carrot_marker.texture if carrot_marker is TextureRect else null)
	var edge := instance.get_node_or_null("LiquidStream/EdgeRibbon")
	var body := instance.get_node_or_null("LiquidStream/BodyRibbon")
	var highlight := instance.get_node_or_null("LiquidStream/HighlightRibbon")
	assert_true(edge is MeshInstance2D)
	assert_true(body is MeshInstance2D)
	assert_true(highlight is MeshInstance2D)
	assert_true(instance.get_node_or_null("LiquidStream/DoubleEdgeRibbon") is MeshInstance2D)
	assert_true(instance.get_node_or_null("LiquidStream/DoubleBodyRibbon") is MeshInstance2D)
	assert_true(instance.get_node_or_null("LiquidStream/DoubleHighlightRibbon") is MeshInstance2D)
	assert_not_null(body.texture if body is MeshInstance2D else null)
	assert_not_null(instance.get_node_or_null("LiquidStream/Droplets"))
	assert_not_null(instance.get_node_or_null("LiquidStream/ImpactBurst"))
	assert_not_null(instance.get_node_or_null("LiquidStream/ImpactBurstSecondary"))
	assert_null(instance.get_node_or_null("WettablePlot01"))
	assert_null(instance.get_node_or_null("WettablePlot02"))
	assert_null(instance.get_node_or_null("WettablePlot03"))
	assert_not_null(instance.get_node_or_null("BroadMoonLight"))
	assert_not_null(instance.get_node_or_null("StreamImpactLight"))
	var impact := instance.get_node_or_null("LiquidStream/ImpactBurst") as CPUParticles2D
	assert_not_null(impact)
	if impact:
		assert_false(impact.one_shot)
		assert_not_null(impact.texture)
		if impact.texture:
			assert_eq(
				impact.texture.resource_path,
				"res://assets/art/drive/YellowTextFX1.png",
			)
	var secondary_impact := instance.get_node_or_null(
		"LiquidStream/ImpactBurstSecondary",
	) as CPUParticles2D
	assert_not_null(secondary_impact)
	if secondary_impact:
		assert_false(secondary_impact.one_shot)
		assert_not_null(secondary_impact.texture)
		assert_eq(secondary_impact.amount, 1)
		assert_eq(
			secondary_impact.emission_shape,
			CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE,
		)
		assert_almost_eq(secondary_impact.emission_sphere_radius, 28.0, 0.001)
		assert_almost_eq(secondary_impact.lifetime, 0.18, 0.001)
		assert_almost_eq(secondary_impact.lifetime_randomness, 0.45, 0.001)
		assert_eq(secondary_impact.direction, Vector2.DOWN)
		assert_eq(secondary_impact.spread, 180.0)
		assert_true(secondary_impact.particle_flag_align_y)
		assert_almost_eq(secondary_impact.angle_min, 180.0, 0.001)
		assert_almost_eq(secondary_impact.angle_max, 180.0, 0.001)
		assert_almost_eq(secondary_impact.radial_accel_min, -180.0, 0.001)
		assert_almost_eq(secondary_impact.radial_accel_max, 240.0, 0.001)
		assert_almost_eq(secondary_impact.tangential_accel_min, -240.0, 0.001)
		assert_almost_eq(secondary_impact.tangential_accel_max, 240.0, 0.001)
		assert_almost_eq(secondary_impact.scale_amount_min, 0.2, 0.001)
		assert_almost_eq(secondary_impact.scale_amount_max, 0.55, 0.001)
		if secondary_impact.texture:
			assert_eq(
				secondary_impact.texture.resource_path,
				"res://assets/art/drive/YellowTextFX2.png",
			)
	if impact:
		assert_eq(impact.amount, 1)
		assert_eq(impact.emission_shape, CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE)
		assert_almost_eq(impact.emission_sphere_radius, 28.0, 0.001)
		assert_almost_eq(impact.lifetime, 0.18, 0.001)
		assert_almost_eq(impact.lifetime_randomness, 0.45, 0.001)
		assert_eq(impact.direction, Vector2.DOWN)
		assert_eq(impact.spread, 180.0)
		assert_true(impact.particle_flag_align_y)
		assert_almost_eq(impact.radial_accel_min, -180.0, 0.001)
		assert_almost_eq(impact.radial_accel_max, 240.0, 0.001)
		assert_almost_eq(impact.tangential_accel_min, -240.0, 0.001)
		assert_almost_eq(impact.tangential_accel_max, 240.0, 0.001)
		assert_almost_eq(impact.scale_amount_min, 0.2, 0.001)
		assert_almost_eq(impact.scale_amount_max, 0.55, 0.001)


func test_stream_pulse_drives_shake_without_pulsing_lights() -> void:
	var scene := SMOKE_TEST_SCENE
	var instance := scene.instantiate()
	add_child_autofree(instance)
	var stream := instance.get_node("LiquidStream") as LiquidStream
	var broad_light := instance.get_node("BroadMoonLight") as PointLight2D
	var impact_light := instance.get_node("StreamImpactLight") as PointLight2D
	var base_energy := broad_light.energy
	var base_scale := broad_light.texture_scale
	var base_position: Vector2 = instance.position

	stream.trigger_pulse()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_almost_eq(broad_light.energy, base_energy, 0.001)
	assert_almost_eq(broad_light.texture_scale, base_scale, 0.001)
	assert_false(broad_light.enabled)
	assert_false(impact_light.enabled)
	assert_true(instance.position != base_position)

	for frame in 30:
		await get_tree().process_frame

	assert_almost_eq(broad_light.energy, base_energy, 0.001)
	assert_eq(instance.position, base_position)


func test_title_is_active_and_gameplay_is_gated_by_default() -> void:
	var instance := SMOKE_TEST_SCENE.instantiate()
	add_child_autofree(instance)
	var input_controller := instance.get_node("InputController") as InputController
	var hud := instance.get_node("HUDLayer/HUD") as StreamHUD
	var title := instance.get_node("TitleLayer/TitleScreen") as TitleScreen

	assert_true(title.is_active())
	assert_false(input_controller.is_gameplay_input_enabled())
	assert_false(hud.gameplay_controls_visible)


func test_skip_title_screen_starts_directly_and_consumes_initial_input() -> void:
	var instance := SMOKE_TEST_SCENE.instantiate() as Main
	instance.skip_title_screen = true
	add_child_autofree(instance)
	var input_controller := instance.get_node("InputController") as InputController
	var hud := instance.get_node("HUDLayer/HUD") as StreamHUD
	var title := instance.get_node("TitleLayer/TitleScreen") as TitleScreen

	assert_false(title.is_active())
	assert_true(input_controller.is_gameplay_input_enabled())
	assert_true(hud.gameplay_controls_visible)
	assert_true(instance.gameplay_started)

	input_controller.set_process(false)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	input_controller.handle_input_event(key)
	assert_true(input_controller.is_pissing())


func test_title_start_input_is_consumed_before_gameplay_begins() -> void:
	var instance := SMOKE_TEST_SCENE.instantiate() as Main
	add_child_autofree(instance)
	var input_controller := instance.get_node("InputController") as InputController
	var title := instance.get_node("TitleLayer/TitleScreen") as TitleScreen

	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	input_controller.handle_input_event(key)

	assert_true(title.is_start_locked())
	assert_false(input_controller.is_pissing())
	await get_tree().create_timer(0.6).timeout
	assert_true(instance.gameplay_started)
	assert_false(input_controller.is_pissing())
