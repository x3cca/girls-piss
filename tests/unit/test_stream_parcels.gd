extends GutTest

const STREAM_SCENE := preload("res://scenes/liquid_stream.tscn")


func test_new_aim_only_changes_newly_emitted_parcel() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.gravity = Vector2.ZERO
	stream.source_position = Vector2.ZERO
	stream.emit_parcels(Vector2.UP, 0.8, 0.0)
	stream.update_parcels(0.1)
	var old_position: Vector2 = stream.parcel_at(0)["position"]
	var old_launch_velocity: Vector2 = stream.parcel_at(0)["launch_velocity"]

	stream.emit_parcels(Vector2.RIGHT, 0.1, 0.0)
	var new_launch_velocity: Vector2 = stream.parcel_at(0)["launch_velocity"]
	var old_parcel: Dictionary = stream.parcel_at(1)

	assert_eq(new_launch_velocity, Vector2.RIGHT * 616.0)
	assert_eq(old_parcel["launch_velocity"], old_launch_velocity)
	assert_eq(old_parcel["position"], old_position)


func test_sputter_profile_reduces_continuity_and_increases_bursts() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var normal := stream.get_sputter_profile(0.0, false)
	var low_pressure := stream.get_sputter_profile(0.65, false)
	var exhausted := stream.get_sputter_profile(1.0, true)

	assert_true(float(normal["emission_rate"]) > float(low_pressure["emission_rate"]))
	assert_true(float(low_pressure["burst_amount"]) > float(normal["burst_amount"]))
	assert_true(float(exhausted["burst_amount"]) > float(low_pressure["burst_amount"]))
	assert_eq(float(exhausted["emission_rate"]), 0.0)
	assert_eq(float(exhausted["ribbon_alpha"]), 0.0)


func test_custom_mesh_tapers_and_fades_at_distal_end() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var points := PackedVector2Array(
		[Vector2(0.0, 0.0), Vector2(0.0, -100.0), Vector2(0.0, -200.0)]
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


func test_perspective_arc_is_zero_centered_and_subtle_off_center() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.ribbon_points = 3
	var parcels: Array[Dictionary] = [
		{ "position": Vector2(0.0, 0.0), "launch_velocity": Vector2.UP },
		{ "position": Vector2(0.0, -100.0), "launch_velocity": Vector2.UP },
		{ "position": Vector2(0.0, -200.0), "launch_velocity": Vector2.UP },
	]
	stream.set_parcel_chain(parcels)
	var centered := stream.build_parcel_centerline(Vector2.UP, 0.55)
	var old_path_after_aim_change := stream.build_parcel_centerline(Vector2.RIGHT, 0.55)
	for parcel in parcels:
		parcel["launch_velocity"] = Vector2.RIGHT
	stream.set_parcel_chain(parcels)
	var off_center := stream.build_parcel_centerline(Vector2.RIGHT, 0.55)

	assert_almost_eq(centered[1].x, 0.0, 0.001)
	assert_almost_eq(old_path_after_aim_change[1].x, 0.0, 0.001)
	assert_true(off_center[1].x > 0.0)
	assert_true(off_center[1].x <= stream.perspective_arc_strength)
