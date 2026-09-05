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
	var shape_trace := instance.get_node_or_null("ShapeTrace") as ShapeTrace
	assert_not_null(shape_trace)
	if shape_trace:
		assert_false(shape_trace.show_outline)
		assert_eq(shape_trace.target_size, 144.0)
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


func test_stream_pulse_drives_bloom_and_shake_feedback() -> void:
	var scene := SMOKE_TEST_SCENE
	var instance := scene.instantiate()
	add_child_autofree(instance)
	var stream := instance.get_node("LiquidStream") as LiquidStream
	var broad_light := instance.get_node("BroadMoonLight") as PointLight2D
	var base_energy := broad_light.energy
	var base_position: Vector2 = instance.position

	stream.trigger_pulse()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(broad_light.energy > base_energy)
	assert_true(instance.position != base_position)

	for _frame in 30:
		await get_tree().process_frame

	assert_almost_eq(broad_light.energy, base_energy, 0.001)
	assert_eq(instance.position, base_position)
