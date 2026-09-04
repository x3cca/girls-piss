extends GutTest


func test_target_has_subtle_idle_float_motion() -> void:
	var target := TraceTarget.new()
	add_child_autofree(target)
	target.configure(Vector2(120.0, 180.0), Vector2(360.0, 640.0), null, 48.0, 0.0)
	target.set_process(false)

	var start_position := target.position
	target._process(0.5)

	assert_true(absf(target.position.y - start_position.y) < target.bob_amplitude)
	assert_true(not is_equal_approx(target.rotation, 0.0))
	assert_true(not is_equal_approx(target.scale.x, 1.0))


func test_target_swirl_finishes_at_the_center_and_hides() -> void:
	var target := TraceTarget.new()
	add_child_autofree(target)
	var center := Vector2(360.0, 640.0)
	target.configure(Vector2(120.0, 180.0), center, null, 48.0, 0.0)
	target.set_process(false)
	target.trigger_hit(center)
	target._process(target.hit_duration)

	assert_true(target.is_hit())
	assert_true(target.position.distance_to(center) < 0.001)
	assert_false(target.visible)
	assert_true(target.scale.length() < 0.001)
