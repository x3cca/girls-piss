extends GutTest

const APP_SCENE := preload("res://scenes/app.tscn")


func test_title_starts_level_1_without_placeholder_menu() -> void:
	var app := APP_SCENE.instantiate() as App
	add_child_autofree(app)

	assert_true(app._title_screen.is_active())
	assert_eq(app.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_null(app._active_level)
	assert_true(app._menu_music.playing)
	app._title_screen.skip_to_gameplay(InputController.AimSource.KEYBOARD)
	await get_tree().process_frame
	var level := app._active_level as Level1
	assert_not_null(level)
	assert_eq(app._active_screen, level)
	assert_null(app._main_menu)
	assert_true(level.attempt_active)
	assert_true(level.input_controller.is_gameplay_input_enabled())
	assert_true(level.input_controller.is_processing_unhandled_input())
	assert_false(app._menu_music.playing)
	assert_false(app.get_node("BackdropWorld").visible)
	assert_lt(app.get_node("BackdropWorld").z_index, 0)
	for sprite_path in [
		"BackdropWorld/Level1Background/BackWall",
		"BackdropWorld/Level1Background/Floor",
		"BackdropWorld/PissToilet/Bowl",
		"BackdropWorld/PissToilet/Tank",
		"BackdropWorld/PissToilet/Seat",
	]:
		var sprite := app.get_node(sprite_path) as Sprite2D
		var material := sprite.material as ShaderMaterial
		var stain_map := material.get_shader_parameter("stain_map") as Texture2D
		assert_not_null(stain_map)
		assert_eq(stain_map.get_image().get_pixel(0, 0), Color.BLACK)


func test_failure_bakes_level_and_retries_from_dedicated_screen() -> void:
	var app := APP_SCENE.instantiate() as App
	add_child_autofree(app)
	app._title_screen.skip_to_gameplay(InputController.AimSource.KEYBOARD)
	await get_tree().process_frame
	var level := app._active_level as Level1
	for _strike in level.max_strikes:
		level._strike_cooldown_remaining = 0.0
		level._take_strike()
	assert_eq(level.state, Main.FAILED)
	assert_true(level._final_strike_pending)
	level._on_strike_warning_finished(level.strike_count)
	assert_true(level.hud.game_over.is_showing())
	assert_gt(level.hud.game_over.layer, (level.get_node("HUDLayer") as CanvasLayer).layer)
	var raid_audio: Array[AudioStreamPlayer] = [
		level.hud.game_over._fbi_voice,
		level.hud.game_over._door_smash,
		level.hud.game_over._door_kick,
	]
	level.hud.game_over._play_door_smash_audio()
	assert_true(raid_audio[0].playing)
	assert_false(raid_audio[2].playing, "The door crash waits until the raid finishes")
	level.hud.game_over._finish_raid_sequence()
	assert_true(raid_audio[2].playing, "The game-over route must trigger the door crash")
	assert_gt(raid_audio[2].volume_db, -70.0)
	var music := level.music_controller
	var playing_track := music._active_player
	assert_true(playing_track.playing)
	await get_tree().process_frame
	var failure := app._active_screen as FailureScreen
	assert_not_null(failure)
	assert_null(app._active_level)
	assert_true(failure.game_over.is_showing())
	assert_true(failure.game_over.get_node("Presentation").visible)
	assert_false(failure.transition.visible)
	assert_null(app._results_screen)
	assert_eq(GameAudio.music, music)
	await get_tree().process_frame
	assert_false(is_instance_valid(level))
	assert_true(music.is_inside_tree())
	assert_eq(music._active_player, playing_track)
	assert_true(playing_track.playing)
	assert_false(app._menu_music.playing)
	for player in raid_audio:
		assert_true(player.playing, "%s should finish across the game-over transition" % player.name)
		assert_false(player.stream_paused)
		assert_eq(player.get_parent(), GameAudio)

	failure.retry_requested.emit()
	var retry_level := app._active_level as Level1
	assert_not_null(retry_level)
	assert_true(retry_level.attempt_active)
	assert_true(retry_level.input_controller.is_gameplay_input_enabled())
	assert_ne(retry_level.music_controller, music)
	assert_true(retry_level.music_controller.oomph_player.playing)
	assert_eq(GameAudio.music, retry_level.music_controller)
	await get_tree().process_frame
	assert_false(is_instance_valid(music))
	for player in raid_audio:
		assert_true(player.playing, "Retry should let the raid sound finish naturally")


func test_failure_transition_throws_a_baked_frame() -> void:
	var transition := preload("res://scenes/failure_transition.tscn").instantiate() as FailureTransition
	add_child_autofree(transition)
	var frame := Image.create(540, 960, false, Image.FORMAT_RGBA8)
	frame.fill(Color.RED)
	transition.play_snapshot(frame, 0.2, TAU * 3.0)
	assert_true(transition.visible)
	assert_not_null((transition.get_node("Frame") as Sprite2D).texture)
	transition._apply_progress(1.0)
	assert_lt((transition.get_node("Frame") as Sprite2D).position.y, 0.0)
	assert_almost_eq((transition.get_node("Frame") as Sprite2D).rotation, TAU * 3.0, 0.001)


func test_completion_keeps_original_card_and_retry_in_level() -> void:
	var app := APP_SCENE.instantiate() as App
	add_child_autofree(app)
	app._start_level(&"level_1", InputController.AimSource.KEYBOARD)
	var level := app._active_level as Level1
	level._debug_instant_win()
	level._on_replay_finished()
	await get_tree().process_frame
	assert_eq(app._active_screen, level)
	assert_eq(level.state, Main.COMPLETE)
	assert_true(level.hud.completion_card.visible)
	assert_eq(level.hud.completion_card._credit_chunks.size(), 7)
	level.hud.completion_card.get_node("PlayAgainButton").pressed.emit()
	assert_eq(level.state, Main.PLAYING)
	assert_true(level.attempt_active)
	assert_false(level.hud.completion_card.visible)
	assert_eq(level.shape_trace.completed_steps, 0)


func test_credits_return_to_menu_and_escape_exits_gameplay() -> void:
	var app := APP_SCENE.instantiate() as App
	add_child_autofree(app)
	app._show_main_menu()
	app._main_menu.get_node("Content/Column/CreditsButton").pressed.emit()
	assert_true(app._active_screen is CreditsScene)
	app._active_screen.emit_signal("back_requested")
	await get_tree().process_frame
	assert_true(app._active_screen is MainMenu)
	app._main_menu.get_node("Content/Column/PlayButton").pressed.emit()
	assert_true(app._active_screen is Level1)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	app._unhandled_input(cancel)
	await get_tree().process_frame
	assert_true(app._active_screen is MainMenu)
	assert_null(app._active_level)
	assert_true(app._menu_music.playing)
