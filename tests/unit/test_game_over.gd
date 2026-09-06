extends GutTest

const GAME_OVER_SCENE := preload("res://scenes/game_over.tscn")
const DREAD_FRAME := preload("res://assets/art/drive/Dread vignette.png")
const GAME_OVER_ONE := preload("res://assets/art/drive/GameOver1.png")
const GAME_OVER_PISS := preload("res://assets/art/drive/GameOverPiss.png")
const GAME_OVER_TWO := preload("res://assets/art/drive/GameOver2.png")
const GAME_OVER_CHAULK := preload("res://assets/art/drive/GameOverChaulk.png")
const PISS_AGAIN_ARROW_ONE := preload("res://assets/art/drive/PissAgainArrow1.png")
const PISS_AGAIN_ARROW_TWO := preload("res://assets/art/drive/PissAgainArrow2.png")
const FAILURE_SOUND := preload("res://assets/audio/cute_cozy_ui/Sounds/Failure.wav")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")


func test_game_over_starts_hidden_and_uses_authored_failure_assets() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)

	assert_false(game_over.visible)
	assert_eq(game_over.get_node("DreadFrame").texture, DREAD_FRAME)
	for layer_path in [
		"DreadFrame",
		"Presentation/GameOver1",
		"Presentation/GameOverPiss",
		"Presentation/GameOver2",
		"Presentation/GameOverChaulk",
		"Presentation/RetryButton",
	]:
		assert_eq(game_over.get_node(layer_path).material, BOIL_MATERIAL)
	assert_eq(game_over.get_node("Presentation/GameOver1").texture, GAME_OVER_ONE)
	assert_eq(game_over.get_node("Presentation/GameOverPiss").texture, GAME_OVER_PISS)
	assert_eq(game_over.get_node("Presentation/GameOver2").texture, GAME_OVER_TWO)
	assert_eq(game_over.get_node("Presentation/GameOverChaulk").texture, GAME_OVER_CHAULK)
	assert_almost_eq(game_over.get_node("Presentation/GameOverPiss").modulate.a, 0.5, 0.001)
	assert_lt(
		game_over.get_node("Presentation/GameOver1").z_index,
		game_over.get_node("Presentation/GameOverPiss").z_index,
	)
	assert_lt(
		game_over.get_node("Presentation/GameOverPiss").z_index,
		game_over.get_node("Presentation/GameOver2").z_index,
	)
	assert_gt(
		game_over.get_node("Presentation/GameOverChaulk").z_index,
		game_over.get_node("Presentation/GameOverPiss").z_index,
	)
	assert_false(game_over.has_node("Presentation/EmergencyMessage"))
	assert_eq(game_over.get_failure_sound(), FAILURE_SOUND)
	var retry_button := game_over.get_node("Presentation/RetryButton") as TextureButton
	assert_eq(retry_button.texture_normal, PISS_AGAIN_ARROW_ONE)
	assert_eq(retry_button.texture_hover, PISS_AGAIN_ARROW_TWO)


func test_show_card_reveals_retry_state_and_emits_retry() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame
	var retry_button := game_over.get_node("Presentation/RetryButton") as TextureButton
	var retry_count := [0]
	game_over.retry_pressed.connect(func() -> void: retry_count[0] += 1)

	game_over.show_card()
	assert_true(game_over.is_showing())
	assert_true(retry_button.visible)

	retry_button.pressed.emit()
	assert_eq(retry_count[0], 1)

	game_over.hide_card()
	assert_false(game_over.is_showing())
