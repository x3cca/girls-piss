extends GutTest

const PROMPT_SCENE := preload("res://scenes/input_prompt.tscn")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")


func test_prompt_mappings_use_the_requested_kenney_assets() -> void:
	var prompt := PROMPT_SCENE.instantiate() as InputPrompt
	add_child_autofree(prompt)

	assert_eq(prompt.get_texture_paths(InputPrompt.PromptSource.KEYBOARD), [
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_w.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_a.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_s.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_d.png",
		"res://assets/placeholders/input_prompts/Keyboard & Mouse/Default/keyboard_space.png",
	])
	assert_eq(prompt.get_texture_paths(InputPrompt.PromptSource.MOUSE).size(), 1)
	assert_eq(prompt.get_texture_paths(InputPrompt.PromptSource.TOUCH).size(), 1)
	assert_eq(prompt.get_texture_paths(InputPrompt.PromptSource.CONTROLLER).size(), 2)
	assert_eq(
		InputPrompt.ACTION_LABEL_PATHS["aim"],
		"res://assets/placeholders/input_prompts/aim.png",
	)
	assert_eq(
		InputPrompt.ACTION_LABEL_PATHS["piss"],
		"res://assets/placeholders/input_prompts/piss.png",
	)


func test_prompt_reuses_one_node_and_applies_boil_material_to_icons() -> void:
	var prompt := PROMPT_SCENE.instantiate() as InputPrompt
	prompt.enter_duration = 0.01
	prompt.hold_duration = 0.05
	prompt.hide_duration = 0.01
	add_child_autofree(prompt)

	prompt.show_prompt(InputPrompt.PromptSource.KEYBOARD)
	assert_true(prompt.is_showing())
	assert_eq(prompt.get_current_texture_paths().size(), 5)
	assert_eq(prompt.icon_row.get_child_count(), 2)
	assert_true(prompt.icon_row is VBoxContainer)
	assert_eq(prompt.aim_icon_row.get_child_count(), 4)
	assert_eq(prompt.piss_icon_row.get_child_count(), 1)
	for icon in prompt.aim_icon_row.get_children():
		assert_true(icon.material == BOIL_MATERIAL)
	for icon in prompt.piss_icon_row.get_children():
		assert_true(icon.material == BOIL_MATERIAL)

	prompt.show_prompt(InputPrompt.PromptSource.CONTROLLER)
	assert_eq(prompt.get_current_texture_paths().size(), 2)
	assert_eq(prompt.aim_icon_row.get_child_count(), 1)
	assert_eq(prompt.piss_icon_row.get_child_count(), 1)

	prompt.hide_prompt()
	assert_false(prompt.is_showing())


func test_prompt_holds_then_slides_and_fades_out() -> void:
	var prompt := PROMPT_SCENE.instantiate() as InputPrompt
	prompt.enter_duration = 0.01
	prompt.hold_duration = 0.05
	prompt.hide_duration = 0.01
	add_child_autofree(prompt)

	prompt.show_prompt(InputPrompt.PromptSource.TOUCH)
	await get_tree().create_timer(0.5).timeout
	assert_false(prompt.is_showing())
