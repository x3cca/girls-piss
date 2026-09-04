extends GutTest


func test_overdrive_drains_reserve_at_configured_rate() -> void:
	var model := PressureModel.new()
	add_child_autofree(model)
	model.set_process(false)
	model.reserve = 1.0
	model.requested_pressure = 1.0
	model.advance(1.0)

	assert_almost_eq(model.reserve, 0.78, 0.001)
	assert_false(model.exhausted)


func test_exhaustion_forces_weak_output_then_unlocks_after_recovery() -> void:
	var model := PressureModel.new()
	add_child_autofree(model)
	model.set_process(false)
	model.reserve = 0.0
	model.requested_pressure = 1.0
	model.advance(0.01)

	assert_true(model.exhausted)
	assert_almost_eq(model.effective_pressure, 0.25, 0.001)

	model.advance(2.0)
	assert_false(model.exhausted)
	assert_eq(model.effective_pressure, 1.0)
