extends GutTest

const TOILET_SCENE := preload("res://scenes/piss_toilet.tscn")
const LEVEL_1_SCENE := preload("res://scenes/level_1.tscn")


func test_piss_toilet_layers_use_the_requested_depth_order() -> void:
	var toilet := TOILET_SCENE.instantiate()
	add_child_autofree(toilet)

	assert_eq(toilet.get_node("Outside").z_index, 0)
	assert_eq(toilet.get_node("Bowl").z_index, 1)
	assert_eq(toilet.get_node("Tank").z_index, 2)
	assert_eq(toilet.get_node("Seat").z_index, 3)

	assert_eq(
		(toilet.get_node("Outside") as Sprite2D).texture.resource_path,
		"res://assets/art/drive/ToiletShadowOnFloor.png",
	)
	assert_eq(
		(toilet.get_node("Bowl") as Sprite2D).texture.resource_path,
		"res://assets/art/drive/Pissbowl.png",
	)
	assert_eq(
		(toilet.get_node("Tank") as Sprite2D).texture.resource_path,
		"res://assets/art/drive/Pisstank.png",
	)
	assert_eq(
		(toilet.get_node("Seat") as Sprite2D).texture.resource_path,
		"res://assets/art/drive/Pissseat.png",
	)


func test_smoke_test_places_the_toilet_in_the_play_scene() -> void:
	var smoke_test := preload("res://scenes/smoke_test.tscn").instantiate()
	add_child_autofree(smoke_test)

	var toilet := smoke_test.get_node("PissToilet") as Node2D
	assert_eq(toilet.position, Vector2(360, 640))
	assert_eq(toilet.scale, Vector2(0.45, 0.45))
	assert_not_null(smoke_test.get_node_or_null("NegativeZone01"))
	assert_not_null(smoke_test.get_node_or_null("NegativeZone02"))


func test_level_1_starts_with_the_toilet_without_test_zone_gameplay() -> void:
	var level := LEVEL_1_SCENE.instantiate() as Main
	add_child_autofree(level)

	assert_true(level.enable_negative_zones)
	assert_gt(level.negative_zones.size(), 0)
	assert_not_null(level.get_node_or_null("PissToilet"))
	assert_false(level.get_node("NegativeZone01").visible)
	assert_false(level.get_node("NegativeZone02").visible)
	assert_not_null(level.get_node_or_null("FloorNegativeZone"))
