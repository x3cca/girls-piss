extends GutTest

const GAME_OVER_SCENE := preload("res://scenes/game_over.tscn")
const DREAD_FRAME := preload("res://assets/art/drive/Dread vignette.png")
const GAME_OVER_ONE := preload("res://assets/art/drive/GameOver1.png")
const GAME_OVER_PISS := preload("res://assets/art/drive/GameOverPiss.png")
const GAME_OVER_TWO := preload("res://assets/art/drive/GameOver2.png")
const GAME_OVER_CHAULK := preload("res://assets/art/drive/GameOverChaulk.png")
const KICK_OUT_TEXT := preload("res://assets/art/drive/yougotkickedouttext.png")
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
const ACTION_LINES := preload("res://assets/art/drive/ActionLines.png")
const ACTION_LINES_FLIP := preload("res://assets/art/drive/actionWiggleFlipForAffect.png")


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
		"Presentation/YouGotKickedOutText",
		"Presentation/RetryButton",
	]:
		assert_eq(game_over.get_node(layer_path).material, BOIL_MATERIAL)
	for retry_text_path in [
		"Presentation/PissAgainText1",
		"Presentation/PissAgainText2",
	]:
		var retry_material := game_over.get_node(retry_text_path).material as ShaderMaterial
		assert_not_null(retry_material)
		if retry_material:
			assert_eq(retry_material.shader, BOIL_MATERIAL.shader)
			assert_eq(retry_material.get_shader_parameter("strength"), 0.0)
	assert_eq(game_over.get_node("Presentation/GameOver1").texture, GAME_OVER_ONE)
	assert_eq(game_over.get_node("Presentation/GameOverPiss").texture, GAME_OVER_PISS)
	assert_eq(game_over.get_node("Presentation/GameOver2").texture, GAME_OVER_TWO)
	assert_eq(game_over.get_node("Presentation/GameOverChaulk").texture, GAME_OVER_CHAULK)
	assert_eq(game_over.get_node("Presentation/YouGotKickedOutText").texture, KICK_OUT_TEXT)
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
	assert_eq(game_over.get_fbi_voice(), FBI_VOICE)
	assert_eq(game_over.get_door_smash(), DOOR_SMASH)
	assert_eq(game_over.get_door_kick(), DOOR_KICK)
	assert_lt(game_over.get_node("DoorSmash").volume_db, -70.0)
	var door_bang := game_over.get_node("RaidOverlay/DoorBang") as AnimatedSprite2D
	assert_almost_eq(door_bang.rotation, PI * 0.5, 0.00001)
	assert_eq(door_bang.sprite_frames.get_frame_count(&"default"), 3)
	assert_eq(door_bang.sprite_frames.get_frame_texture(&"default", 0), DOOR_BANG_ONE)
	assert_eq(door_bang.sprite_frames.get_frame_texture(&"default", 1), DOOR_BANG_TWO)
	assert_eq(door_bang.sprite_frames.get_frame_texture(&"default", 2), DOOR_BANG_THREE)
	assert_false(door_bang.visible)
	var action_lines := game_over.get_node("RaidOverlay/ActionLines") as ScreenOverlayEffect
	var action_line_frames: SpriteFrames = action_lines.get_node("AnimatedSprite2D").sprite_frames
	assert_false(action_lines.visible)
	assert_true(action_line_frames.get_animation_loop(&"default"))
	assert_eq(action_line_frames.get_frame_texture(&"default", 0), ACTION_LINES)
	assert_eq(action_line_frames.get_frame_texture(&"default", 1), ACTION_LINES_FLIP)
	assert_true(action_lines.get_node("AnimatedSprite2D").material == BOIL_MATERIAL)
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


func test_raid_knocks_start_with_fbi_voice() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame
	var door_bang := game_over.get_node("RaidOverlay/DoorBang") as AnimatedSprite2D
	var action_lines := game_over.get_node("RaidOverlay/ActionLines") as ScreenOverlayEffect
	var knock_count := [0]
	game_over.raid_knock.connect(func() -> void: knock_count[0] += 1)

	game_over.show_card()

	assert_true(door_bang.visible)
	assert_true(action_lines.visible)
	assert_eq(door_bang.frame, 0)
	assert_eq(knock_count[0], 1)
	assert_true(game_over.get_node("FbiVoice").playing)
	assert_false(game_over.get_node("DoorSmash").playing)

	await get_tree().create_timer(game_over.door_smash_delay + 0.1).timeout
	assert_true(game_over.get_node("DoorSmash").playing)

	game_over.hide_card()
	assert_false(action_lines.visible)


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


func test_failure_art_waits_for_raid_sequence_before_reveal() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame

	game_over.show_card()
	assert_true(game_over.visible)
	assert_false(game_over.get_node("Backdrop").visible)
	assert_false(game_over.get_node("DreadFrame").visible)
	assert_false(game_over.get_node("Presentation").visible)

	game_over.reveal_card()
	assert_true(game_over.get_node("Backdrop").visible)
	assert_true(game_over.get_node("DreadFrame").visible)
	assert_true(game_over.get_node("Presentation").visible)

	game_over.hide_card()


func test_retry_button_waits_then_slides_in_with_wobble() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame
	game_over.entry_duration = 0.1
	game_over.retry_reveal_delay = 1.0
	game_over.retry_slide_duration = 0.3
	game_over.retry_wobble_duration = 0.1

	var retry_button := game_over.get_node("Presentation/RetryButton") as TextureButton
	var resting_x := retry_button.position.x
	game_over.show_card()
	game_over.reveal_card()
	var viewport_width := get_viewport().get_visible_rect().size.x
	assert_almost_eq(retry_button.position.x, resting_x + viewport_width, 0.001)

	await get_tree().create_timer(0.45).timeout
	assert_almost_eq(retry_button.position.x, resting_x + viewport_width, 0.001)

	await get_tree().create_timer(0.8).timeout
	assert_lt(retry_button.position.x, viewport_width)
	assert_ne(retry_button.position.x, 0.0)

	await get_tree().create_timer(0.7).timeout
	assert_almost_eq(retry_button.position.x, resting_x, 0.001)
	game_over.hide_card()


func test_failure_art_layers_preserve_the_authored_canvas_composition() -> void:
	var game_over := GAME_OVER_SCENE.instantiate() as GameOver
	add_child_autofree(game_over)
	await get_tree().process_frame
	var presentation := game_over.get_node("Presentation") as Control
	var game_over_one := game_over.get_node("Presentation/GameOver1") as TextureRect
	var game_over_two := game_over.get_node("Presentation/GameOver2") as TextureRect

	assert_eq(game_over_one.size, presentation.size)
	assert_eq(game_over_two.size, presentation.size)
	assert_eq(game_over_one.position, Vector2.ZERO)
	assert_eq(game_over_two.position, Vector2.ZERO)
	var kick_out_text := game_over.get_node("Presentation/YouGotKickedOutText") as TextureRect
	assert_eq(kick_out_text.size, presentation.size)
	assert_eq(kick_out_text.position, Vector2.ZERO)
	var retry_button := game_over.get_node("Presentation/RetryButton") as TextureButton
	assert_lt(retry_button.size.x, presentation.size.x)
	assert_lt(retry_button.size.y, presentation.size.y)
	assert_gt(retry_button.position.y, presentation.size.y * 0.7)
