extends GutTest

var _completion_count := 0


func test_ordered_progress_does_not_reset_or_skip_a_checkpoint() -> void:
	var trace := ShapeTrace.new()
	add_child_autofree(trace)
	trace.normalized_points = PackedVector2Array([
		Vector2(0.25, 0.25),
		Vector2(0.50, 0.25),
		Vector2(0.75, 0.25),
	])
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
	trace.normalized_points = PackedVector2Array([
		Vector2(0.50, 0.50),
		Vector2(0.80, 0.80),
	])
	var checkpoint := trace.get_checkpoint_position(0)
	var radius := trace.get_checkpoint_radius()

	trace.observe_drawing_point(checkpoint + Vector2(-radius * 2.0, 0.0), true)
	trace.observe_drawing_point(checkpoint + Vector2(radius * 2.0, 0.0), true)

	assert_eq(trace.completed_steps, 1)


func test_completion_emits_once_until_trace_is_reset() -> void:
	var trace := ShapeTrace.new()
	add_child_autofree(trace)
	trace.normalized_points = PackedVector2Array([Vector2(0.5, 0.5)])
	_completion_count = 0
	trace.trace_completed.connect(_on_trace_completed)
	var checkpoint := trace.get_checkpoint_position(0)

	trace.observe_drawing_point(checkpoint, true)
	trace.observe_drawing_point(checkpoint, true)
	assert_eq(_completion_count, 1)

	trace.reset_trace()
	trace.observe_drawing_point(checkpoint, true)
	assert_eq(_completion_count, 2)


func _on_trace_completed() -> void:
	_completion_count += 1
