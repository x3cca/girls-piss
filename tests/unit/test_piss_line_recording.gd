extends GutTest

func test_recorder_thins_samples_normalizes_positions_and_splits_gaps() -> void:
	var recorder := PissLineRecorder.new()
	add_child_autofree(recorder)
	recorder.sample_interval = 0.1
	recorder.minimum_point_distance = 4.0
	recorder.inactive_gap = 0.15
	recorder.start_recording()
	var viewport_size := get_viewport().get_visible_rect().size

	recorder.capture_point(Vector2(100.0, 200.0), true, 0.0)
	recorder.capture_point(Vector2(102.0, 200.0), true, 0.1)
	recorder.capture_point(Vector2(110.0, 200.0), true, 0.1)
	recorder.capture_point(Vector2.ZERO, false, 0.2)
	recorder.capture_point(Vector2.ZERO, false, 0.4)
	recorder.capture_point(Vector2(300.0, 400.0), true, 0.4)
	recorder.finish_recording()

	var strokes := recorder.get_strokes()
	assert_eq(strokes.size(), 2)
	assert_eq(strokes[0].size(), 2)
	assert_eq(strokes[1].size(), 1)
	assert_almost_eq(
		(strokes[0][0]["position"] as Vector2).x,
		100.0 / viewport_size.x,
		0.0001,
	)
	assert_eq(float(strokes[0][1]["timestamp"]), 0.1)


func test_inactive_frames_do_not_add_points() -> void:
	var recorder := PissLineRecorder.new()
	add_child_autofree(recorder)
	recorder.start_recording()
	recorder.capture_point(Vector2(10.0, 10.0), false, 0.0)
	recorder.capture_point(Vector2(20.0, 20.0), false, 1.0)
	recorder.finish_recording()

	assert_true(recorder.get_strokes().is_empty())


func test_normalized_points_reconstruct_in_the_current_viewport() -> void:
	var recorder := PissLineRecorder.new()
	add_child_autofree(recorder)
	var original := Vector2(123.0, 456.0)

	assert_almost_eq(
		recorder.denormalize_position(recorder.normalize_position(original)).x,
		original.x,
		0.001,
	)
	assert_almost_eq(
		recorder.denormalize_position(recorder.normalize_position(original)).y,
		original.y,
		0.001,
	)
