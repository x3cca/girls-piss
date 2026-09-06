extends GutTest

const STREAM_SCENE := preload("res://scenes/liquid_stream.tscn")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")


func test_stream_renderables_use_the_shared_boil_material() -> void:
	assert_true(BOIL_MATERIAL is ShaderMaterial)
	var stream := STREAM_SCENE.instantiate()
	add_child_autofree(stream)

	for node_path in [
		"EdgeRibbon",
		"BodyRibbon",
		"HighlightRibbon",
		"Droplets",
		"ImpactBurst",
		"ImpactBurstSecondary",
	]:
		var canvas_item := stream.get_node(node_path) as CanvasItem
		assert_not_null(canvas_item, "%s should be a canvas item." % node_path)
		assert_true(
			canvas_item.material == BOIL_MATERIAL,
			"%s should use the boil material." % node_path,
		)


func test_boil_material_exposes_the_source_noise_and_motion_parameters() -> void:
	var material := BOIL_MATERIAL as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_not_null(material.shader)
	assert_eq(material.get_shader_parameter("fps"), 6.0)
	assert_eq(material.get_shader_parameter("strength"), 0.5)
	assert_not_null(material.get_shader_parameter("noise"))
