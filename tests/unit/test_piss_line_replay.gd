extends GutTest

var _completion_count := 0


func test_replay_starts_at_the_first_point_and_scales_to_five_seconds() -> void:
	var replay := PissLineReplay.new()
	add_child_autofree(replay)
	var strokes: Array = [
		[
			{ "position": Vector2(0.1, 0.2), "timestamp": 2.0 },
			{ "position": Vector2(0.4, 0.2), "timestamp": 4.0 },
		],
	]

	replay.play(strokes)
	assert_true(replay.is_replaying())
	assert_almost_eq(replay.get_duration(), 5.0, 0.001)
	assert_eq(replay.revealed_strokes.size(), 1)
	assert_eq(replay.revealed_strokes[0].size(), 1)

	replay.process_frame(2.5)
	assert_eq(replay.revealed_strokes.size(), 1)
	assert_eq(replay.revealed_strokes[0].size(), 2)
	assert_almost_eq(
		(replay.revealed_strokes[0][1]["position"] as Vector2).x,
		0.25,
		0.001,
	)

	replay.process_frame(2.5)
	assert_false(replay.is_replaying())
	assert_eq(replay.revealed_strokes[0].size(), 2)


func test_final_point_is_revealed_before_completion_signal() -> void:
	var replay := PissLineReplay.new()
	add_child_autofree(replay)
	replay.replay_duration = 0.5
	_completion_count = 0
	replay.replay_finished.connect(_on_replay_finished.bind(replay))
	replay.play(
		[
			[
				{ "position": Vector2(0.1, 0.2), "timestamp": 0.0 },
				{ "position": Vector2(0.4, 0.2), "timestamp": 0.5 },
			],
		],
	)
	replay.process_frame(0.5)

	assert_eq(_completion_count, 1)
	assert_false(replay.is_replaying())
	assert_almost_eq(replay.get_duration(), 0.5, 0.001)


func test_excessively_long_replay_uses_the_speed_cap() -> void:
	var replay := PissLineReplay.new()
	add_child_autofree(replay)
	replay.replay_duration = 10.0
	replay.max_speed_multiplier = 3.0
	var strokes: Array = [
		[
			{ "position": Vector2(0.1, 0.2), "timestamp": 0.0 },
			{ "position": Vector2(0.4, 0.2), "timestamp": 60.0 },
		],
	]

	replay.play(strokes)
	assert_true(replay.is_replaying())
	assert_eq(replay.revealed_strokes.size(), 1)
	assert_eq(replay.revealed_strokes[0].size(), 1)
	assert_almost_eq(replay.get_duration(), 20.0, 0.001)

	replay.process_frame(10.0)
	assert_eq(replay.revealed_strokes[0].size(), 2)
	assert_almost_eq(
		(replay.revealed_strokes[0][1]["position"] as Vector2).x,
		0.25,
		0.001,
	)


func _on_replay_finished(replay: PissLineReplay) -> void:
	_completion_count += 1
	assert_eq(replay.revealed_strokes.size(), 1)
	assert_eq(replay.revealed_strokes[0].size(), 2)
