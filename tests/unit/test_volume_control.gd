extends GutTest

const LEVEL_SCENE := preload("res://scenes/level_1.tscn")


func test_volume_control_cycles_three_even_levels_and_mute() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	var chrome := level.get_node("Level1Chrome") as Level1Chrome
	var game_bus := AudioServer.get_bus_index(&"Game")
	var original_volume_db := AudioServer.get_bus_volume_db(game_bus)
	var original_muted := AudioServer.is_bus_mute(game_bus)

	assert_eq(chrome.get_volume_level(), 3)
	assert_false(chrome.is_muted())
	assert_almost_eq(AudioServer.get_bus_volume_db(game_bus), 0.0, 0.001)

	chrome.set_volume_level(1)
	assert_eq(chrome.get_volume_level(), 1)
	assert_false(chrome.is_muted())
	assert_true((chrome.get_node("VolumeIcons/Volume1") as Sprite2D).visible)
	assert_almost_eq(AudioServer.get_bus_volume_db(game_bus), linear_to_db(1.0 / 3.0), 0.001)

	chrome.cycle_volume()
	assert_eq(chrome.get_volume_level(), 2)
	assert_true((chrome.get_node("VolumeIcons/Volume2") as Sprite2D).visible)
	assert_almost_eq(AudioServer.get_bus_volume_db(game_bus), linear_to_db(2.0 / 3.0), 0.001)

	chrome.cycle_volume()
	assert_eq(chrome.get_volume_level(), 3)
	assert_true((chrome.get_node("VolumeIcons/Volume3") as Sprite2D).visible)
	assert_almost_eq(AudioServer.get_bus_volume_db(game_bus), 0.0, 0.001)

	chrome.cycle_volume()
	assert_eq(chrome.get_volume_level(), 0)
	assert_true(chrome.is_muted())
	assert_true(AudioServer.is_bus_mute(game_bus))
	assert_true((chrome.get_node("VolumeIcons/MuteVolume") as Sprite2D).visible)
	var mute_position := (chrome.get_node("VolumeIcons/MuteVolume") as Sprite2D).position
	chrome.cycle_volume()
	assert_eq((chrome.get_node("VolumeIcons/MuteVolume") as Sprite2D).position, mute_position)

	assert_eq(chrome.get_volume_level(), 1)
	assert_false(chrome.is_muted())
	assert_false(AudioServer.is_bus_mute(game_bus))
	assert_not_null(chrome._wobble_tween)

	AudioServer.set_bus_volume_db(game_bus, original_volume_db)
	AudioServer.set_bus_mute(game_bus, original_muted)


func test_mute_click_is_consumed_without_starting_the_stream() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	await get_tree().process_frame
	var game_bus := AudioServer.get_bus_index(&"Game")
	var original_volume_db := AudioServer.get_bus_volume_db(game_bus)
	var original_muted := AudioServer.is_bus_mute(game_bus)

	var chrome := level.get_node("Level1Chrome") as Level1Chrome
	var hitbox := chrome.get_node("VolumeHitbox") as Control
	assert_eq(hitbox.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(hitbox.mouse_default_cursor_shape, Control.CURSOR_ARROW)

	chrome._on_volume_hitbox_mouse_entered()
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.position = hitbox.global_position + hitbox.size * hitbox.scale * 0.5
	mouse_down.pressed = true
	level.input_controller.handle_input_event(mouse_down)

	assert_false(level.input_controller.is_stream_input_held())
	assert_false(level.input_controller.is_pissing())
	assert_false(level.hud.aim_reticle.visible)
	chrome._on_volume_hitbox_mouse_exited()
	assert_true(level.hud.aim_reticle.visible)

	AudioServer.set_bus_volume_db(game_bus, original_volume_db)
	AudioServer.set_bus_mute(game_bus, original_muted)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func test_volume_cycle_plays_pitch_rising_orchestra_cue() -> void:
	var level := LEVEL_SCENE.instantiate() as Level1
	level.skip_title_screen = true
	add_child_autofree(level)
	var chrome := level.get_node("Level1Chrome") as Level1Chrome
	var cue := chrome.get_node("VolumeSound") as AudioStreamPlayer
	var game_bus := AudioServer.get_bus_index(&"Game")
	var original_volume_db := AudioServer.get_bus_volume_db(game_bus)
	var original_muted := AudioServer.is_bus_mute(game_bus)

	assert_eq(cue.stream.resource_path, "res://assets/audio/orchestra_hit.ogg")
	assert_eq(cue.bus, &"Master")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")))
	chrome.set_volume_level(0)
	assert_false(cue.playing)

	chrome.cycle_volume()
	assert_true(cue.playing)
	assert_almost_eq(cue.pitch_scale, Level1Chrome.VOLUME_PITCH_SCALES[1], 0.001)
	chrome.cycle_volume()
	assert_almost_eq(cue.pitch_scale, Level1Chrome.VOLUME_PITCH_SCALES[2], 0.001)
	chrome.cycle_volume()
	assert_almost_eq(cue.pitch_scale, Level1Chrome.VOLUME_PITCH_SCALES[3], 0.001)
	chrome.cycle_volume()
	assert_true(cue.playing)
	assert_almost_eq(cue.pitch_scale, Level1Chrome.MUTED_VOLUME_PITCH_SCALE, 0.001)
	assert_almost_eq(cue.volume_db, Level1Chrome.MUTED_VOLUME_SOUND_DB, 0.001)

	AudioServer.set_bus_volume_db(game_bus, original_volume_db)
	AudioServer.set_bus_mute(game_bus, original_muted)
