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


func test_authored_child_layout_survives_multiple_root_scales() -> void:
	var toilet := TOILET_SCENE.instantiate() as PissToilet
	add_child_autofree(toilet)
	var authored_positions := {
		"Outside": Vector2(0.0, -125.875),
		"Bowl": Vector2(0.0, -236.125),
		"Tank": Vector2(0.0, -900.0),
		"Seat": Vector2(0.0, -236.875),
	}
	for part_name in authored_positions:
		assert_eq((toilet.get_node(part_name) as Sprite2D).position, authored_positions[part_name])
	toilet.apply_layout()
	for part_name in authored_positions:
		assert_eq((toilet.get_node(part_name) as Sprite2D).position, authored_positions[part_name])
	assert_eq(toilet.get_bowl_anchor_local(), authored_positions["Bowl"])
	for root_scale in [0.6666667, 0.45, 1.15]:
		toilet.scale = Vector2.ONE * root_scale
		toilet.apply_layout()
		assert_eq((toilet.get_node("Bowl") as Sprite2D).position, authored_positions["Bowl"])
		assert_eq((toilet.get_node("Seat") as Sprite2D).position, authored_positions["Seat"])


func test_level_1_and_smoke_test_share_internal_toilet_layout() -> void:
	var level := LEVEL_1_SCENE.instantiate() as Level1
	var smoke := preload("res://scenes/smoke_test.tscn").instantiate() as Main
	add_child_autofree(level)
	add_child_autofree(smoke)

	var level_toilet := level.get_node("PissToilet") as PissToilet
	var smoke_toilet := smoke.get_node("PissToilet") as PissToilet
	level_toilet.apply_layout()
	smoke_toilet.apply_layout()
	for part_name in ["Outside", "Bowl", "Tank", "Seat"]:
		var level_part := level_toilet.get_node(part_name) as Sprite2D
		var smoke_part := smoke_toilet.get_node(part_name) as Sprite2D
		assert_eq(level_part.position, smoke_part.position)
		assert_eq(level_part.scale, smoke_part.scale)


func test_level_1_targets_and_floor_zone_follow_the_bowl_anchor() -> void:
	var level := LEVEL_1_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	level.set_process(false)
	level.get_node("LiquidStream").set_process(false)

	var toilet := level.get_node("PissToilet") as PissToilet
	var bowl_anchor := toilet.get_bowl_anchor_global()
	var floor_zone := level.get_node("FloorNegativeZone") as NegativeZone
	assert_eq(level.shape_trace.target_center_position, bowl_anchor)
	assert_false(floor_zone.contains_point(bowl_anchor))
	assert_eq(
		floor_zone.excluded_normalized_points,
		toilet.get_floor_exclusion_normalized(get_viewport().get_visible_rect().size),
	)

	var target := level.shape_trace._targets[0]
	level.shape_trace.complete_current_checkpoint()
	assert_eq(target._center_position, bowl_anchor)
	assert_eq(level.get_node("StreamImpactLight").global_position, bowl_anchor)

	# This sample is just beyond the right side of the generated opening while
	# still inside the authored floor polygon.
	var outside_cutout := toilet.to_global(
		toilet.get_bowl_anchor_local() + Vector2(410.0, 38.835),
	)
	level.evaluate_stream_endpoint(outside_cutout, true, 0.0)
	assert_eq(level.get_strikes(), 1)


func _visible_edge_in_parent(sprite: Sprite2D, top_edge: bool, threshold: float) -> float:
	var image := sprite.texture.get_image()
	var min_y := image.get_height()
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > threshold:
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var image_origin := sprite.offset
	if sprite.centered:
		image_origin -= Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * 0.5
	var edge := min_y if top_edge else max_y + 1
	return sprite.position.y + (image_origin.y + edge) * sprite.scale.y
