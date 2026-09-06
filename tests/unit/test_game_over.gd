extends GutTest

const GAME_OVER_SCENE := preload("res://scenes/game_over.tscn")
const DREAD_FRAME := preload("res://assets/art/drive/Dread vignette.png")
const GAME_OVER_ONE := preload("res://assets/art/drive/GameOver1.png")
const GAME_OVER_PISS := preload("res://assets/art/drive/GameOverPiss.png")
const GAME_OVER_TWO := preload("res://assets/art/drive/GameOver2.png")
const GAME_OVER_CHAULK := preload("res://assets/art/drive/GameOverChaulk.png")
const PISS_AGAIN_ARROW_ONE := preload("res://assets/art/drive/PissAgainArrow1.png")
const PISS_AGAIN_ARROW_TWO := preload("res://assets/art/drive/PissAgainArrow2.png")
const PISS_AGAIN_TEXT_ONE := preload("res://assets/art/drive/PissAgainText1.png")
const PISS_AGAIN_TEXT_TWO := preload("res://assets/art/drive/PissAgainText2.png")
const DOOR_BANG_ONE := preload("res://assets/art/drive/DoorBang1.png")
const DOOR_BANG_TWO := preload("res://assets/art/drive/DoorBang2.png")
const DOOR_BANG_THREE := preload("res://assets/art/drive/DoorBang3.png")
const FBI_VOICE := preload("res://assets/audio/fbi_open_up_voice.ogg")
const DOOR_SMASH := preload("res://assets/audio/fbi_door_smash.ogg")
const DOOR_KICK := preload("res://assets/audio/door_kick.ogg")
const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")


func test_game_over_starts_hidden_and_uses_authored_failure_assets() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame

	assert_false(game_over.visible)
	assert_eq(game_over.layer, -1)
	assert_eq(
		(game_over.get_node("Backdrop") as ColorRect).size,
		get_viewport().get_visible_rect().size,
	)
	assert_eq(game_over.get_node("DreadFrame").texture, DREAD_FRAME)
	for layer_path in [
		"DreadFrame",
		"Presentation/GameOver1",
		"Presentation/GameOverPiss",
		"Presentation/GameOver2",
		"Presentation/GameOverChaulk",
		"Presentation/RetryButton",
		"Presentation/PissAgainText1",
		"Presentation/PissAgainText2",
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
	assert_false(game_over.has_node("FailureSound"))
	assert_eq(game_over.get_fbi_voice(), FBI_VOICE)
	assert_eq(game_over.get_door_smash(), DOOR_SMASH)
	assert_eq(game_over.get_door_kick(), DOOR_KICK)
	var door_bang := game_over.get_node("RaidOverlay/DoorBang") as AnimatedSprite2D
	assert_almost_eq(door_bang.rotation, PI * 0.5, 0.00001)
	assert_eq(door_bang.sprite_frames.get_frame_count(&"default"), 3)
	assert_eq(door_bang.sprite_frames.get_frame_texture(&"default", 0), DOOR_BANG_ONE)
	assert_eq(door_bang.sprite_frames.get_frame_texture(&"default", 1), DOOR_BANG_TWO)
	assert_eq(door_bang.sprite_frames.get_frame_texture(&"default", 2), DOOR_BANG_THREE)
	assert_false(door_bang.visible)
	var retry_button := game_over.get_node("Presentation/RetryButton") as TextureButton
	assert_eq(retry_button.texture_normal, PISS_AGAIN_ARROW_ONE)
	assert_eq(retry_button.texture_hover, PISS_AGAIN_ARROW_TWO)
	assert_eq(retry_button.mouse_default_cursor_shape, Control.CURSOR_ARROW)
	assert_eq(game_over.get_node("Presentation/PissAgainText1").texture, PISS_AGAIN_TEXT_ONE)
	assert_eq(game_over.get_node("Presentation/PissAgainText2").texture, PISS_AGAIN_TEXT_TWO)
	assert_true(game_over.get_node("Presentation/PissAgainText1").visible)
	assert_false(game_over.get_node("Presentation/PissAgainText2").visible)


func test_door_bang_hides_after_the_impact_animation() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame
	var door_bang := game_over.get_node("RaidOverlay/DoorBang") as AnimatedSprite2D
	var knock_count := [0]
	game_over.raid_knock.connect(func() -> void: knock_count[0] += 1)

	game_over._play_door_smash()
	assert_true(door_bang.visible)
	await get_tree().create_timer(0.8).timeout

	assert_false(door_bang.visible)
	assert_eq(knock_count[0], 3)


func test_retry_text_tracks_hover_state() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	var retry_button := game_over.get_node("Presentation/RetryButton") as TextureButton
	var text_one := game_over.get_node("Presentation/PissAgainText1") as TextureRect
	var text_two := game_over.get_node("Presentation/PissAgainText2") as TextureRect

	retry_button.mouse_entered.emit()
	assert_false(text_one.visible)
	assert_true(text_two.visible)

	retry_button.mouse_exited.emit()
	assert_true(text_one.visible)
	assert_false(text_two.visible)


func test_show_card_reveals_retry_state_and_emits_retry() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame
	var retry_button := game_over.get_node("Presentation/RetryButton") as TextureButton
	var retry_count := [0]
	game_over.retry_pressed.connect(func() -> void: retry_count[0] += 1)

	game_over.show_card()
	assert_true(game_over.is_showing())
	assert_eq(Input.get_mouse_mode(), Input.MOUSE_MODE_VISIBLE)
	assert_true(retry_button.visible)

	retry_button.pressed.emit()
	assert_eq(retry_count[0], 1)

	game_over.hide_card()
	assert_false(game_over.is_showing())
