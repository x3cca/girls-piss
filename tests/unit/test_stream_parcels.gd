extends GutTest

const STREAM_SCENE := preload("res://scenes/liquid_stream.tscn")


func test_new_target_only_changes_newly_emitted_parcel() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.gravity = Vector2.ZERO
	stream.stream_speed = 1000.0
	stream.source_position = Vector2.ZERO
	stream.emit_parcels(Vector2(0.0, -200.0), 0.0)
	stream.update_parcels(0.1)
	var old_position: Vector2 = stream.parcel_at(0)["position"]
	var old_launch_velocity: Vector2 = stream.parcel_at(0)["launch_velocity"]

	stream.emit_parcels(Vector2(200.0, 0.0), 0.0)
	var new_launch_velocity: Vector2 = stream.parcel_at(0)["launch_velocity"]
	var old_parcel: Dictionary = stream.parcel_at(1)

	assert_eq(new_launch_velocity, Vector2(1000.0, 0.0))
	assert_eq(old_parcel["launch_velocity"], old_launch_velocity)
	assert_eq(old_parcel["position"], old_position)
	assert_eq(stream.build_parcel_centerline()[1], old_position)


func test_parcel_centerline_uses_committed_positions() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.source_position = Vector2(360.0, 1328.0)
	var target := Vector2(520.0, 180.0)
	stream.set_parcel_chain(
		[
			{"position": stream.source_position},
			{"position": target},
		],
	)
	var points := stream.build_parcel_centerline()

	assert_eq(points[0], stream.source_position)
	assert_eq(points[points.size() - 1], target)


func test_stream_target_eases_when_crosshair_moves() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	stream.set_process(false)
	stream.input_controller = controller
	stream.source_position = Vector2(360.0, 1328.0)
	var first_target := Vector2(250.0, 420.0)
	var second_target := Vector2(540.0, 260.0)
	controller.set_target_position(first_target)
	stream._process(0.1)
	controller.set_target_position(second_target)
	stream._process(0.1)

	var eased_target := stream.get_stream_target_position()
	assert_true(eased_target != second_target)
	assert_true(eased_target.distance_to(second_target) < first_target.distance_to(second_target))


func test_stream_profile_is_fixed_for_every_shot() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var profile := stream.get_stream_profile()

	assert_eq(float(profile["emission_rate"]), stream.normal_emission_rate)
	assert_eq(float(profile["ribbon_alpha"]), 1.0)


func test_custom_mesh_tapers_and_fades_at_distal_end() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var points := PackedVector2Array(
		[Vector2(0.0, 0.0), Vector2(0.0, -100.0), Vector2(0.0, -200.0)],
	)
	stream.update_ribbon_meshes(points, 200.0, 1.0, false)

	var body_mesh := stream.get_node("BodyRibbon") as MeshInstance2D
	var arrays: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var near_width := Vector2(vertices[0].x, vertices[0].y).distance_to(
		Vector2(vertices[1].x, vertices[1].y),
	)
	var far_width := Vector2(vertices[4].x, vertices[4].y).distance_to(
		Vector2(vertices[5].x, vertices[5].y),
	)

	assert_eq(vertices.size(), 6)
	assert_true(near_width > far_width)
	assert_true(colors[0].a > colors[4].a)
	assert_true(colors[4].a > 0.0)
	assert_almost_eq(colors[4].a, stream.distal_end_alpha, 0.01)
