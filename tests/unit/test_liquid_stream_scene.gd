extends GutTest

func test_liquid_stream_scene_builds_playable_nodes() -> void:
	var scene := load("res://scenes/smoke_test.tscn") as PackedScene
	assert_not_null(scene, "The portrait prototype scene should be loadable.")

	var instance := scene.instantiate()
	add_child_autofree(instance)

	assert_true(instance is Node2D)
	assert_eq(instance.name, "LiquidStreamPrototype")
	assert_not_null(instance.get_node_or_null("InputController"))
	assert_not_null(instance.get_node_or_null("PressureModel"))
	assert_not_null(instance.get_node_or_null("LiquidStream"))
	assert_not_null(instance.get_node_or_null("HUDLayer/HUD"))
	var hud := instance.get_node_or_null("HUDLayer/HUD")
	assert_not_null(hud.get_node_or_null("CarrotAimControl") if hud else null)
	assert_not_null(hud.get_node_or_null("PressureFader") if hud else null)
	var carrot := hud.get_node_or_null("CarrotAimControl") if hud else null
	var carrot_sprite := carrot.get_node_or_null("CarrotSprite") if carrot else null
	assert_true(carrot_sprite is TextureRect)
	assert_not_null(carrot_sprite.texture if carrot_sprite is TextureRect else null)
	var pressure_fader := hud.get_node_or_null("PressureFader") if hud else null
	assert_not_null(pressure_fader.get_node_or_null("Track") if pressure_fader else null)
	assert_not_null(pressure_fader.get_node_or_null("Knob") if pressure_fader else null)
	var edge := instance.get_node_or_null("LiquidStream/EdgeRibbon")
	var body := instance.get_node_or_null("LiquidStream/BodyRibbon")
	var highlight := instance.get_node_or_null("LiquidStream/HighlightRibbon")
	assert_true(edge is MeshInstance2D)
	assert_true(body is MeshInstance2D)
	assert_true(highlight is MeshInstance2D)
	assert_not_null(body.texture if body is MeshInstance2D else null)
	assert_not_null(instance.get_node_or_null("LiquidStream/Droplets"))
	assert_not_null(instance.get_node_or_null("LiquidStream/SputterBurst"))
	assert_not_null(instance.get_node_or_null("LiquidStream/ImpactBurst"))
	assert_not_null(instance.get_node_or_null("WettablePlot01/CollisionBody/CollisionShape2D"))
	assert_not_null(instance.get_node_or_null("BroadMoonLight"))
	assert_not_null(instance.get_node_or_null("StreamImpactLight"))
	var impact := instance.get_node_or_null("LiquidStream/ImpactBurst") as CPUParticles2D
	assert_not_null(impact)
	if impact:
		assert_false(impact.one_shot)
		assert_not_null(impact.texture)
	var first_plot := instance.get_node_or_null("WettablePlot01")
	assert_not_null(first_plot)
	if first_plot:
		assert_eq(first_plot.name, "WettablePlot01")
