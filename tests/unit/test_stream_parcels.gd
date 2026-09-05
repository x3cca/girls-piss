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


func test_stream_follow_has_a_small_overshoot_and_settles() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	stream.set_process(false)
	stream.input_controller = controller
	var first_target := Vector2(120.0, 500.0)
	var second_target := Vector2(600.0, 500.0)
	controller.set_target_position(first_target)
	stream._process(0.1)
	controller.set_target_position(second_target)
	stream._process(0.05)

	var accelerated_target := stream.get_stream_target_position()
	assert_true(accelerated_target.x > first_target.x)
	assert_true(accelerated_target.x < second_target.x)

	var furthest_x := accelerated_target.x
	for _frame in 180:
		stream._process(1.0 / 60.0)
		furthest_x = maxf(furthest_x, stream.get_stream_target_position().x)

	assert_true(furthest_x > second_target.x)
	assert_true(furthest_x < second_target.x + 80.0)
	assert_almost_eq(stream.get_stream_target_position().x, second_target.x, 0.5)


func test_large_aim_delta_blooms_and_staying_still_restores_accuracy() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	stream.set_process(false)
	stream.input_controller = controller
	var first_target := Vector2(240.0, 500.0)
	var jumped_target := Vector2(600.0, 500.0)
	controller.set_target_position(first_target)
	stream._process(1.0 / 60.0)
	controller.set_target_position(jumped_target)
	stream._process(1.0 / 60.0)
	var bloom_after_jump := stream.get_aim_bloom_radius()
	stream.emit_parcels(jumped_target, 0.0)
	var first_bloom_offset: Vector2 = stream.parcel_at(0)["bloom_offset"]
	stream.emit_parcels(jumped_target, 0.0)
	var same_frame_bloom_offset: Vector2 = stream.parcel_at(0)["bloom_offset"]
	stream._process(1.0 / 60.0)
	stream.emit_parcels(jumped_target, 0.0)
	var next_frame_bloom_offset: Vector2 = stream.parcel_at(0)["bloom_offset"]

	assert_true(bloom_after_jump > 0.0)
	assert_true(first_bloom_offset.length() > 0.0)
	assert_eq(first_bloom_offset, same_frame_bloom_offset)
	assert_true(next_frame_bloom_offset.length() > 0.0)
	assert_true(first_bloom_offset != next_frame_bloom_offset)
	assert_true(
		first_bloom_offset.distance_to(next_frame_bloom_offset)
			< bloom_after_jump * 0.3
	)
	for _frame in 30:
		stream._process(1.0 / 60.0)

	assert_true(stream.get_aim_bloom_radius() < bloom_after_jump)
	for _frame in 120:
		stream._process(1.0 / 60.0)
	assert_almost_eq(stream.get_aim_bloom_radius(), 0.0, 0.01)


func test_small_aim_delta_creates_less_bloom_than_a_large_delta() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	stream.set_process(false)
	stream.input_controller = controller
	controller.set_target_position(Vector2(300.0, 500.0))
	stream._process(1.0 / 60.0)
	controller.set_target_position(Vector2(320.0, 500.0))
	stream._process(1.0 / 60.0)
	var small_bloom := stream.get_aim_bloom_radius()

	stream.reset_stream()
	controller.set_target_position(Vector2(320.0, 500.0))
	stream._process(1.0 / 60.0)
	controller.set_target_position(Vector2(600.0, 500.0))
	stream._process(1.0 / 60.0)
	var large_bloom := stream.get_aim_bloom_radius()

	assert_true(small_bloom > 0.0)
	assert_true(large_bloom > small_bloom)


func test_extreme_bloom_starts_a_double_stream_until_it_settles() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	var controller := InputController.new()
	add_child_autofree(controller)
	controller.set_process(false)
	stream.set_process(false)
	stream.input_controller = controller
	controller.set_target_position(Vector2(100.0, 500.0))
	stream._process(1.0 / 60.0)
	controller.set_target_position(Vector2(720.0, 500.0))
	stream._process(1.0 / 60.0)

	assert_true(stream.get_aim_bloom_radius() >= stream.double_stream_start_radius)
	assert_true(stream.is_double_stream_active())
	stream.emit_parcels(stream.get_stream_target_position(), 0.0)
	var primary_parcel := stream.parcel_at(0)
	var secondary_parcel := stream.double_parcel_at(0)
	var primary_offset: Vector2 = primary_parcel["bloom_offset"]
	var secondary_offset: Vector2 = secondary_parcel["bloom_offset"]
	assert_almost_eq(primary_offset.length(), stream.get_double_bloom_radius(), 0.01)
	assert_almost_eq(secondary_offset.length(), stream.get_double_bloom_radius(), 0.01)
	assert_almost_eq(primary_offset.distance_to(secondary_offset), stream.get_double_bloom_radius() * 2.0, 0.01)
	assert_true(primary_parcel["launch_target"] != secondary_parcel["launch_target"])
	for _frame in 60:
		stream._process(1.0 / 60.0)
	assert_true(stream.get_aim_bloom_radius() > stream.double_stream_release_radius)
	assert_true(stream.is_double_stream_active())
	for _frame in 60:
		stream._process(1.0 / 60.0)
	assert_true(stream.get_aim_bloom_radius() <= stream.double_stream_release_radius)
	assert_false(stream.is_double_stream_active())


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


func test_beat_pulse_travels_with_parcel_age() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.pulse_width_seconds = 0.025
	stream.trigger_pulse()
	var points := PackedVector2Array(
		[Vector2(0.0, 0.0), Vector2(0.0, -100.0), Vector2(0.0, -200.0)],
	)
	var ages := PackedFloat32Array([0.0, 0.1, 0.2])

	stream.update_ribbon_meshes(points, 200.0, 1.0, false, ages)
	var body_mesh := stream.get_node("BodyRibbon") as MeshInstance2D
	var initial_vertices: PackedVector3Array = (
		(body_mesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var initial_widths := _mesh_widths(initial_vertices)

	stream.update_parcels(0.1)
	stream.update_ribbon_meshes(points, 200.0, 1.0, false, ages)
	var traveled_vertices: PackedVector3Array = (
		(body_mesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var traveled_widths := _mesh_widths(traveled_vertices)

	assert_true(initial_widths[0] > initial_widths[1])
	assert_true(traveled_widths[1] > traveled_widths[0])
	assert_true(traveled_widths[1] > traveled_widths[2])
	assert_true(initial_widths[0] > initial_widths[2])


func test_beat_pulse_affects_all_live_ribbon_layers() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.trigger_pulse()
	var points := PackedVector2Array(
		[Vector2(0.0, 0.0), Vector2(0.0, -100.0), Vector2(0.0, -200.0)],
	)
	var ages := PackedFloat32Array([0.0, 0.1, 0.2])
	stream.update_ribbon_meshes(points, 200.0, 1.0, false, ages)

	for node_path in ["EdgeRibbon", "BodyRibbon", "HighlightRibbon"]:
		var mesh := stream.get_node(node_path).mesh as ArrayMesh
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var widths := _mesh_widths(vertices)
		assert_true(widths[0] > widths[2], "%s should carry the pulse." % node_path)


func test_reset_stream_clears_beat_pulses() -> void:
	var stream := STREAM_SCENE.instantiate() as LiquidStream
	add_child_autofree(stream)
	stream.trigger_pulse()
	var points := PackedVector2Array(
		[Vector2(0.0, 0.0), Vector2(0.0, -100.0)],
	)
	var ages := PackedFloat32Array([0.0, 0.2])
	stream.update_ribbon_meshes(points, 100.0, 1.0, false, ages)
	var pulsed_vertices: PackedVector3Array = (
		(stream.get_node("BodyRibbon").mesh as ArrayMesh).surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX
		]
	)
	var pulsed_width := _mesh_widths(pulsed_vertices)[0]

	stream.reset_stream()
	stream.update_ribbon_meshes(points, 100.0, 1.0, false, ages)
	var reset_vertices: PackedVector3Array = (
		(stream.get_node("BodyRibbon").mesh as ArrayMesh).surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX
		]
	)
	var reset_width := _mesh_widths(reset_vertices)[0]

	assert_true(pulsed_width > reset_width)


func _mesh_widths(vertices: PackedVector3Array) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for index in range(0, vertices.size(), 2):
		widths.append(
			Vector2(vertices[index].x, vertices[index].y).distance_to(
				Vector2(vertices[index + 1].x, vertices[index + 1].y),
			)
		)
	return widths
