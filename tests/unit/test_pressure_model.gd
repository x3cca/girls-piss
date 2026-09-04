extends GutTest

func test_pressure_has_no_reserve_limit() -> void:
	var model := PressureModel.new()
	add_child_autofree(model)
	model.set_process(false)
	model.requested_pressure = 1.0
	model.advance(10.0)

	assert_eq(model.effective_pressure, 1.0)
	model.requested_pressure = 0.15
	model.advance(10.0)
	assert_eq(model.effective_pressure, 0.15)


func test_pressure_is_clamped_to_the_playable_range() -> void:
	var model := PressureModel.new()
	add_child_autofree(model)
	model.set_process(false)
	model.requested_pressure = -4.0
	model.advance(0.1)
	assert_eq(model.requested_pressure, 0.15)

	model.requested_pressure = 4.0
	model.advance(0.1)
	assert_eq(model.requested_pressure, 1.0)
