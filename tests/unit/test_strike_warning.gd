extends GutTest

const WARNING_SCENE := preload("res://scenes/strike_warning.tscn")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")
const YELLOW_BUBBLE := preload("res://assets/art/drive/YellowTextBubble.png")
const YELLOW_TEXT := preload("res://assets/art/drive/YellowText.png")
const YELLOW_FX_1 := preload("res://assets/art/drive/YellowTextFX1.png")
const YELLOW_FX_2 := preload("res://assets/art/drive/YellowTextFX2.png")
const ORANGE_BUBBLE := preload("res://assets/art/drive/OrangeTextBubble.png")
const ORANGE_TEXT := preload("res://assets/art/drive/OrangeText.png")
const ORANGE_FX_1 := preload("res://assets/art/drive/OrangeTextFX1.png")
const ORANGE_FX_2 := preload("res://assets/art/drive/OrangeTextFX2.png")
const RED_BUBBLE := preload("res://assets/art/drive/RedWarningBubble.png")
const RED_TEXT_1 := preload("res://assets/art/drive/RedText1.png")
const RED_TEXT_2 := preload("res://assets/art/drive/RedText2.png")
const RED_TEXT_3 := preload("res://assets/art/drive/RedText3.png")
const RED_TEXT_4 := preload("res://assets/art/drive/RedText4.png")
const RED_FX_1 := preload("res://assets/art/drive/RedTextFX1.png")
const RED_FX_2 := preload("res://assets/art/drive/RedTextFX2.png")
const WARNING_SOUND := preload("res://assets/audio/cute_cozy_ui/Sounds/Warning.ogg")


func _make_warning() -> StrikeWarning:
	var warning := WARNING_SCENE.instantiate() as StrikeWarning
	add_child_autofree(warning)
	return warning


func test_warning_assets_are_selected_for_each_strike() -> void:
	var warning := _make_warning()

	var yellow := warning.get_warning_assets(StrikeWarning.YELLOW_WARNING)
	assert_eq(yellow["bubble"], YELLOW_BUBBLE)
	assert_eq(yellow["text"], YELLOW_TEXT)
	assert_eq(yellow["fx"], [YELLOW_FX_1, YELLOW_FX_2])

	var orange := warning.get_warning_assets(StrikeWarning.ORANGE_WARNING)
	assert_eq(orange["bubble"], ORANGE_BUBBLE)
	assert_eq(orange["text"], ORANGE_TEXT)
	assert_eq(orange["fx"], [ORANGE_FX_1, ORANGE_FX_2])

	var red := warning.get_warning_assets(StrikeWarning.RED_WARNING)
	assert_eq(red["bubble"], RED_BUBBLE)
	assert_eq(red["text"], RED_TEXT_1)
	assert_eq(red["row"], [RED_TEXT_2, RED_TEXT_3])
	assert_eq(red["emergency"], RED_TEXT_4)
	assert_eq(red["fx"], [RED_FX_1, RED_FX_2])


func test_strike_bubbles_use_the_shared_boil_material() -> void:
	var warning := _make_warning()

	for node_path in ["YellowWarning/Bubble", "OrangeWarning/Bubble", "RedWarning/Bubble"]:
		var bubble := warning.get_node(node_path) as TextureRect
		assert_not_null(bubble, "%s should be a bubble texture." % node_path)
		assert_true(bubble.material == BOIL_MATERIAL, "%s should use the boil material." % node_path)


func test_red_warning_places_its_text_in_two_rows() -> void:
	var warning := _make_warning()
	var red := warning.get_node("RedWarning") as Control
	var row := red.get_node("RedTextRow") as Control
	var text_2 := row.get_node("RedText2") as TextureRect
	var text_3 := row.get_node("RedText3") as TextureRect
	var emergency := red.get_node("RedText4") as TextureRect

	assert_gt(row.size.x, 0.0)
	assert_gt(row.size.y, 0.0)
	assert_gt(text_2.size.x, 0.0)
	assert_gt(text_3.size.x, 0.0)
	assert_gt(emergency.size.x, 0.0)
	assert_gte(text_2.position.y, 0.0)
	assert_gte(text_3.position.y, 0.0)
	assert_lte(text_2.position.y + text_2.size.y, row.size.y)
	assert_lte(text_3.position.y + text_3.size.y, row.size.y)
	assert_lte(text_2.position.x + text_2.size.x, text_3.position.x)
	assert_gt(emergency.size.x, row.size.x * 0.8)
	assert_gt(emergency.position.y, row.position.y + row.size.y)


func test_yellow_text_is_shifted_up_in_its_bubble() -> void:
	var warning := _make_warning()
	var yellow := warning.get_node("YellowWarning") as Control
	var bubble := yellow.get_node("Bubble") as TextureRect
	var text := yellow.get_node("Text") as TextureRect

	assert_lt(text.position.y, bubble.size.y * 0.25)


func test_red_first_line_is_shifted_up_above_emergency() -> void:
	var warning := _make_warning()
	var red := warning.get_node("RedWarning") as Control
	var row := red.get_node("RedTextRow") as Control
	var emergency := red.get_node("RedText4") as TextureRect

	assert_lt(row.position.y, red.size.y * 0.5)
	assert_gt(emergency.position.y, row.position.y)


func test_red_text_fx_sit_above_and_below_the_bubble() -> void:
	var warning := _make_warning()
	var red := warning.get_node("RedWarning") as Control
	var bubble := red.get_node("Bubble") as TextureRect
	var fx_above := red.get_node("TextFX2") as TextureRect
	var fx_below := red.get_node("TextFX1") as TextureRect

	assert_lte(fx_above.position.y + fx_above.size.y, bubble.position.y)
	assert_gte(fx_below.position.y, bubble.position.y + bubble.size.y)


func test_orange_text_is_shifted_up_in_its_bubble() -> void:
	var warning := _make_warning()
	var yellow_text := warning.get_node("YellowWarning/Text") as TextureRect
	var orange_text := warning.get_node("OrangeWarning/Text") as TextureRect

	assert_lt(orange_text.position.y, yellow_text.position.y)


func test_default_warning_duration_is_four_seconds() -> void:
	var warning := _make_warning()

	assert_eq(warning.warning_duration, 4.0)


func test_warning_is_visible_immediately_and_expires_after_cooldown() -> void:
	var warning := _make_warning()
	warning.show_warning(StrikeWarning.YELLOW_WARNING, 0.75)

	assert_eq(warning.get_active_warning(), StrikeWarning.YELLOW_WARNING)
	assert_true(warning.is_warning_visible(StrikeWarning.YELLOW_WARNING))
	warning.process_frame(0.74)
	assert_true(warning.is_warning_visible(StrikeWarning.YELLOW_WARNING))
	warning.process_frame(0.01)
	assert_eq(warning.get_active_warning(), 0)
	assert_false(warning.is_warning_visible(StrikeWarning.YELLOW_WARNING))


func test_warning_entrance_shake_decays_to_a_resting_position() -> void:
	var warning := _make_warning()
	warning.show_warning(StrikeWarning.YELLOW_WARNING, 1.0)
	var entering_position := warning.yellow_warning.position

	warning.process_frame(warning.entrance_shake_duration)
	var resting_position := warning.yellow_warning.position

	assert_gt(entering_position.distance_to(resting_position), warning.entrance_shake_amplitude * 0.8)
	assert_eq(warning.yellow_warning.rotation, 0.0)


func test_warning_panels_match_the_authored_top_right_composition() -> void:
	var warning := _make_warning()
	var viewport_size := warning.get_viewport_rect().size
	var bubble_width := clampf(
		viewport_size.x * warning.bubble_width_ratio,
		warning.min_bubble_width,
		warning.max_bubble_width,
	)
	var expected_position := Vector2(
		viewport_size.x - maxf(viewport_size.x * warning.right_margin_ratio, 8.0) - bubble_width,
		maxf(viewport_size.y * warning.top_margin_ratio, 8.0),
	)

	for strike in [StrikeWarning.YELLOW_WARNING, StrikeWarning.ORANGE_WARNING, StrikeWarning.RED_WARNING]:
		warning.show_warning(strike, 1.0)
		warning.process_frame(warning.entrance_shake_duration)
		var panel := warning._warning_for(strike)
		assert_almost_eq(panel.position.x, expected_position.x, 0.5)
		assert_almost_eq(panel.position.y, expected_position.y, 0.5)
		assert_almost_eq(panel.scale.x, bubble_width / panel.size.x, 0.001)
		assert_almost_eq(panel.scale.y, panel.scale.x, 0.001)


func test_first_three_warnings_use_their_own_panel() -> void:
	var warning := _make_warning()
	for strike in [1, 2, 3]:
		warning.show_warning(strike, 1.0)
		assert_eq(warning.get_active_warning(), strike)
		assert_true(warning.is_warning_visible(strike))
		for other_strike in [1, 2, 3]:
			if other_strike != strike:
				assert_false(warning.is_warning_visible(other_strike))


func test_fourth_strike_is_not_a_warning() -> void:
	var warning := _make_warning()
	warning.show_warning(4, 1.0)

	assert_eq(warning.get_active_warning(), 0)
	assert_false(warning.yellow_warning.visible)
	assert_false(warning.orange_warning.visible)
	assert_false(warning.red_warning.visible)


func test_each_warning_plays_its_three_pound_variant() -> void:
	var warning := _make_warning()
	var variants := {
		StrikeWarning.YELLOW_WARNING: [
			"LightPounds",
			"res://assets/audio/wall/wall_pound_light.ogg",
		],
		StrikeWarning.ORANGE_WARNING: [
			"MediumPounds",
			"res://assets/audio/wall/wall_pound_medium.ogg",
		],
		StrikeWarning.RED_WARNING: [
			"HeavyPounds",
			"res://assets/audio/wall/wall_pound_heavy.ogg",
		],
	}

	for strike in variants:
		warning.show_warning(strike, 4.0)
		var player := warning.get_node(variants[strike][0]) as AudioStreamPlayer
		var warning_sound := warning.get_node("WarningSound") as AudioStreamPlayer
		assert_eq(player.stream.resource_path, variants[strike][1])
		assert_almost_eq(player.stream.get_length(), 0.6, 0.01)
		assert_true(player.playing)
		assert_eq(warning_sound.stream, WARNING_SOUND)
		assert_true(warning_sound.playing)
		warning.hide_warning()
		assert_false(player.playing)
		assert_false(warning_sound.playing)


func test_each_pound_emits_on_the_wall_pound_timeline() -> void:
	var warning := _make_warning()
	var pounds: Array[int] = []
	warning.pound_triggered.connect(
		func(_strike: int, pound_index: int): pounds.append(pound_index),
	)
	warning.show_warning(StrikeWarning.YELLOW_WARNING, 1.0)

	warning.process_frame(StrikeWarning.POUND_TIMINGS[0] - 0.001)
	assert_eq(pounds, [])
	warning.process_frame(0.001)
	assert_eq(pounds, [0])
	warning.process_frame(StrikeWarning.POUND_TIMINGS[1] - StrikeWarning.POUND_TIMINGS[0])
	assert_eq(pounds, [0, 1])
	warning.process_frame(StrikeWarning.POUND_TIMINGS[2] - StrikeWarning.POUND_TIMINGS[1])
	assert_eq(pounds, [0, 1, 2])
