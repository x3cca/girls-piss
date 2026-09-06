extends GutTest

func test_depth_map_samples_red_depth_and_alpha_bounds() -> void:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0.2, 0.0, 0.0, 1.0))
	image.set_pixel(1, 0, Color(0.8, 0.0, 0.0, 0.0))
	var map := DepthMap2D.new()
	add_child_autofree(map)
	map.depth_texture = ImageTexture.create_from_image(image)
	map.world_rect = Rect2(0.0, 0.0, 20.0, 10.0)

	var valid := map.sample_world_position(Vector2(2.0, 5.0))
	var transparent := map.sample_world_position(Vector2(15.0, 5.0))
	var outside := map.sample_world_position(Vector2(20.0, 5.0))

	assert_true(valid["valid"])
	assert_almost_eq(float(valid["depth"]), 0.2, 0.01)
	assert_false(transparent["valid"])
	assert_false(outside["valid"])


func test_baker_uses_alpha_coverage_and_shallowest_overlap() -> void:
	var texture_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	texture_image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(texture_image)
	var root := Node2D.new()
	add_child_autofree(root)
	var deep := DepthTaggedSprite2D.new()
	deep.texture = texture
	deep.position = Vector2(2.0, 2.0)
	deep.depth = 0.8
	root.add_child(deep)
	var shallow := DepthTaggedSprite2D.new()
	shallow.texture = texture
	shallow.position = Vector2(2.0, 2.0)
	shallow.depth = 0.2
	root.add_child(shallow)

	var baker := DepthMapBaker.new()
	add_child_autofree(baker)
	var image := baker.bake(root, Rect2(0.0, 0.0, 4.0, 4.0), Vector2i(4, 4))

	assert_almost_eq(image.get_pixel(1, 1).r, 0.2, 0.01)
	assert_almost_eq(image.get_pixel(2, 2).r, 0.2, 0.01)


func test_depth_increases_parcel_flight_time_and_lifetime() -> void:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 1.0))
	image.set_pixel(1, 0, Color(1.0, 0.0, 0.0, 1.0))
	var map := DepthMap2D.new()
	add_child_autofree(map)
	map.depth_texture = ImageTexture.create_from_image(image)
	map.world_rect = Rect2(0.0, 0.0, 100.0, 1.0)
	var stream := preload("res://scenes/liquid_stream.tscn").instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.set_depth_map(map)
	stream.source_position = Vector2(1.0, 0.5)
	stream.stream_speed = 1000.0
	stream.depth_distance_scale = 100.0
	stream.parcel_lifetime = 0.1
	stream.emit_parcels(Vector2(99.0, 0.5), 0.0)
	var parcel := stream.parcel_at(0)

	assert_eq(parcel["launch_depth"], 0.0)
	assert_eq(parcel["target_depth"], 1.0)
	assert_true(float(parcel["flight_time"]) > 0.1)
	assert_eq(parcel["lifetime"], parcel["flight_time"])


func test_in_flight_parcel_keeps_committed_depth_after_new_target() -> void:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 1.0))
	image.set_pixel(1, 0, Color(1.0, 0.0, 0.0, 1.0))
	var map := DepthMap2D.new()
	add_child_autofree(map)
	map.depth_texture = ImageTexture.create_from_image(image)
	map.world_rect = Rect2(0.0, 0.0, 100.0, 1.0)
	var stream := preload("res://scenes/liquid_stream.tscn").instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.set_depth_map(map)
	stream.source_position = Vector2(1.0, 0.5)
	stream.stream_speed = 1000.0
	stream.depth_distance_scale = 100.0
	stream.emit_parcels(Vector2(99.0, 0.5), 0.0)
	stream.update_parcels(0.05)
	var old_parcel := stream.parcel_at(0)
	var old_depth := float(old_parcel["depth"])
	assert_true(old_depth > 0.0)

	stream.emit_parcels(Vector2(1.0, 0.5), 0.0)
	var still_flying_old_parcel := stream.parcel_at(1)

	assert_eq(still_flying_old_parcel["target_depth"], 1.0)
	assert_almost_eq(float(still_flying_old_parcel["depth"]), old_depth, 0.001)
	var committed_points := PackedVector2Array(
		[Vector2(1.0, 0.5), Vector2(99.0, 0.5)],
	)
	var committed_depths := PackedFloat32Array([0.0, 0.0])
	var split_data: Dictionary = stream._depth_band_points(committed_points, committed_depths)
	var split_points: Array = split_data["points"]
	assert_eq((split_points[0] as PackedVector2Array).size(), 2)
	assert_eq((split_points[3] as PackedVector2Array).size(), 0)


func test_ribbon_builds_depth_band_meshes_when_map_is_assigned() -> void:
	var image := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	for x in 4:
		image.set_pixel(x, 0, Color(float(x) / 3.0, 0.0, 0.0, 1.0))
	var map := DepthMap2D.new()
	add_child_autofree(map)
	map.depth_texture = ImageTexture.create_from_image(image)
	map.world_rect = Rect2(0.0, 0.0, 100.0, 1.0)
	var stream := preload("res://scenes/liquid_stream.tscn").instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.set_depth_map(map)
	stream.update_ribbon_meshes(
		PackedVector2Array([Vector2(1.0, 0.5), Vector2(50.0, 0.5), Vector2(99.0, 0.5)]),
		100.0,
		1.0,
		false,
	)

	assert_not_null(stream.get_node_or_null("BodyDepthBand0"))
	assert_not_null(stream.get_node_or_null("BodyDepthBand3"))
	assert_true((stream.get_node("BodyDepthBand0").mesh as ArrayMesh).get_surface_count() > 0)
	assert_true((stream.get_node("BodyDepthBand3").mesh as ArrayMesh).get_surface_count() > 0)
