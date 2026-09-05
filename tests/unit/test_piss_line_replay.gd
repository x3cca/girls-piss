extends GutTest

var _completion_count := 0


func test_replay_starts_empty_and_reveals_a_timestamped_prefix_at_three_x() -> void:
	var replay := PissLineReplay.new()
	add_child_autofree(replay)
	replay.speed_multiplier = 3.0
	var strokes: Array = [[
		{"position": Vector2(0.1, 0.2), "timestamp": 0.0},
		{"position": Vector2(0.4, 0.2), "timestamp": 1.0},
	]]

	replay.play(strokes)
	assert_true(replay.is_replaying())
	assert_true(replay.revealed_strokes.is_empty())

	replay._process(0.2)
	assert_eq(replay.revealed_strokes.size(), 1)
	assert_eq(replay.revealed_strokes[0].size(), 2)
	assert_almost_eq(
		(replay.revealed_strokes[0][1]["position"] as Vector2).x,
		0.28,
		0.001,
	)


func test_final_point_is_revealed_before_completion_signal() -> void:
	var replay := PissLineReplay.new()
	add_child_autofree(replay)
	_completion_count = 0
	replay.replay_finished.connect(_on_replay_finished.bind(replay))
	replay.play([
		[
			{"position": Vector2(0.1, 0.2), "timestamp": 0.0},
			{"position": Vector2(0.4, 0.2), "timestamp": 0.5},
		]
	])
	replay._process(0.2)

	assert_eq(_completion_count, 1)
	assert_false(replay.is_replaying())
	assert_almost_eq(replay.get_duration(), 0.5 / 3.0, 0.001)


func test_replay_can_start_at_first_target_hit_without_dead_time() -> void:
	var replay := PissLineReplay.new()
	add_child_autofree(replay)
	replay.speed_multiplier = 3.0
	var strokes: Array = [[
		{"position": Vector2(0.1, 0.2), "timestamp": 0.5},
		{"position": Vector2(0.4, 0.2), "timestamp": 1.0},
		{"position": Vector2(0.7, 0.2), "timestamp": 2.0},
	]]

	replay.play(strokes, 1.0)
	assert_true(replay.is_replaying())
	assert_eq(replay.revealed_strokes.size(), 1)
	assert_eq(replay.revealed_strokes[0].size(), 2)
	assert_almost_eq(replay.get_duration(), 1.0 / 3.0, 0.001)

	replay._process(0.1)
	assert_eq(replay.revealed_strokes[0].size(), 3)
	assert_almost_eq(
		(replay.revealed_strokes[0][2]["position"] as Vector2).x,
		0.49,
		0.001,
	)


func _on_replay_finished(replay: PissLineReplay) -> void:
	_completion_count += 1
	assert_eq(replay.revealed_strokes.size(), 1)
	assert_eq(replay.revealed_strokes[0].size(), 2)
