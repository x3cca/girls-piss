extends GutTest

const GAME_OVER_SCENE := preload("res://scenes/game_over.tscn")
const DREAD_FRAME := preload("res://assets/art/drive/Dread vignette.png")
const RED_BUBBLE := preload("res://assets/art/drive/RedWarningBubble.png")
const FAILURE_SOUND := preload("res://assets/audio/cute_cozy_ui/Sounds/Failure.wav")


func test_game_over_starts_hidden_and_uses_authored_failure_assets() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)

	assert_false(game_over.visible)
	assert_eq(game_over.get_node("DreadFrame").texture, DREAD_FRAME)
	assert_eq(game_over.get_message_texture(), RED_BUBBLE)
	assert_eq(game_over.get_failure_sound(), FAILURE_SOUND)
	assert_eq(game_over.get_node("Presentation/RetryButton").text, "TRY AGAIN")


func test_show_card_reveals_retry_state_and_emits_retry() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame
	var retry_button := game_over.get_node("Presentation/RetryButton") as Button
	var retry_count := [0]
	game_over.retry_pressed.connect(func() -> void: retry_count[0] += 1)

	game_over.show_card()
	assert_true(game_over.is_showing())
	assert_true(retry_button.visible)

	retry_button.pressed.emit()
	assert_eq(retry_count[0], 1)

	game_over.hide_card()
	assert_false(game_over.is_showing())
