extends GutTest

var _completion_count := 0


func test_ordered_progress_does_not_reset_or_skip_a_checkpoint() -> void:
	var trace := ShapeTrace.new()
	add_child_autofree(trace)
	trace.normalized_points = PackedVector2Array(
		[
			Vector2(0.25, 0.25),
			Vector2(0.50, 0.25),
			Vector2(0.75, 0.25),
		],
	)
	trace.target_texture = _solid_texture()
	trace.rebuild_targets()
	var first := trace.get_checkpoint_position(0)
	var second := trace.get_checkpoint_position(1)
	var third := trace.get_checkpoint_position(2)

	trace.observe_drawing_point(first, true)
	assert_eq(trace.completed_steps, 1)
	trace.observe_drawing_point(Vector2(12.0, 900.0), true)
	assert_eq(trace.completed_steps, 1)
	trace.observe_drawing_point(second, true)
	assert_eq(trace.completed_steps, 2)
	# Revisiting the completed point cannot advance the ordered next step.
	trace.observe_drawing_point(first, true)
	assert_eq(trace.completed_steps, 2)
	trace.observe_drawing_point(third, true)
	assert_eq(trace.completed_steps, 3)


func test_segment_crossing_detects_a_checkpoint_between_endpoint_samples() -> void:
	var trace := ShapeTrace.new()
	add_child_autofree(trace)
	trace.normalized_points = PackedVector2Array(
		[
			Vector2(0.50, 0.50),
			Vector2(0.80, 0.80),
		],
	)
	trace.target_texture = _solid_texture()
	trace.rebuild_targets()
	var checkpoint := trace.get_checkpoint_position(0)
	var radius := trace.get_checkpoint_radius()

	trace.observe_drawing_point(checkpoint + Vector2(-radius * 2.0, 0.0), true)
	trace.observe_drawing_point(checkpoint + Vector2(radius * 2.0, 0.0), true)

	assert_eq(trace.completed_steps, 1)


func test_completion_emits_once_until_trace_is_reset() -> void:
	var trace := ShapeTrace.new()
	add_child_autofree(trace)
	trace.normalized_points = PackedVector2Array([Vector2(0.5, 0.5)])
	trace.target_texture = _solid_texture()
	trace.rebuild_targets()
	_completion_count = 0
	trace.trace_completed.connect(_on_trace_completed)
	var checkpoint := trace.get_checkpoint_position(0)

	trace.observe_drawing_point(checkpoint, true)
	trace.observe_drawing_point(checkpoint, true)
	assert_eq(_completion_count, 1)

	trace.reset_trace()
	trace.observe_drawing_point(checkpoint, true)
	assert_eq(_completion_count, 2)


func test_checkpoint_look_ahead_one_only_shows_the_current_target() -> void:
	var trace := ShapeTrace.new()
	add_child_autofree(trace)
	trace.normalized_points = PackedVector2Array(
		[
			Vector2(0.25, 0.25),
			Vector2(0.50, 0.50),
			Vector2(0.75, 0.75),
		],
	)
	trace.checkpoint_look_ahead = 1
	trace.process_frame(0.0)

	assert_true(trace._targets[0].visible)
	assert_false(trace._targets[1].visible)
	assert_false(trace._targets[2].visible)

	trace.checkpoint_look_ahead = 2
	trace.process_frame(0.0)
	assert_true(trace._targets[0].visible)
	assert_true(trace._targets[1].visible)
	assert_false(trace._targets[2].visible)


func test_checkpoint_look_ahead_fades_visible_future_targets() -> void:
	var trace := ShapeTrace.new()
	add_child_autofree(trace)
	trace.normalized_points = PackedVector2Array(
		[
			Vector2(0.20, 0.20),
			Vector2(0.35, 0.35),
			Vector2(0.50, 0.50),
			Vector2(0.65, 0.65),
		],
	)
	trace.checkpoint_look_ahead = 3
	trace.process_frame(0.0)

	assert_almost_eq(trace._targets[0].modulate.a, 1.0, 0.001)
	assert_almost_eq(trace._targets[1].modulate.a, 0.25, 0.001)
	assert_almost_eq(trace._targets[2].modulate.a, 0.125, 0.001)
	assert_false(trace._targets[3].visible)


func _on_trace_completed() -> void:
	_completion_count += 1


func _solid_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
