extends GutTest

const MANAGER_SCRIPT := preload("res://scripts/game_audio.gd")
const DOOR_SOUND := preload("res://assets/audio/door_kick.ogg")
const SPRAY_SOUND := preload("res://assets/audio/spray_loop.ogg")


func test_scene_can_be_freed_without_restarting_music_or_cutting_off_effects() -> void:
	var manager := MANAGER_SCRIPT.new()
	add_child_autofree(manager)
	var scene := Node.new()
	add_child(scene)
	var music := manager.start_level_music()
	music.start_gameplay_immediately()
	music.oomph_player.seek(12.0)
	var effect_settings := AudioStreamPlayer.new()
	effect_settings.stream = DOOR_SOUND
	scene.add_child(effect_settings)
	var effect := manager.create_player(effect_settings, scene)
	effect.play()
	scene.queue_free()
	await get_tree().process_frame
	assert_false(is_instance_valid(scene))
	assert_eq(music.get_parent(), manager)
	assert_true(music.oomph_player.playing)
	assert_eq(music.oomph_player.playback_type, AudioServer.PLAYBACK_TYPE_STREAM)
	assert_false(music.room_player.playing, "Scene release must not restart the autoplay room track")
	assert_gte(music.oomph_player.get_playback_position(), 12.0)
	assert_eq(effect.get_parent(), manager)
	assert_true(effect.playing)
	effect.finished.emit()
	manager.reset_music()
	await get_tree().process_frame
	assert_false(is_instance_valid(effect), "Finished effects should release their players")
	assert_false(is_instance_valid(music))


func test_looping_gameplay_effects_end_with_their_scene() -> void:
	var manager := MANAGER_SCRIPT.new()
	add_child_autofree(manager)
	var scene := Node.new()
	add_child(scene)
	var spray_settings := AudioStreamPlayer.new()
	spray_settings.stream = SPRAY_SOUND
	(spray_settings.stream as AudioStreamOggVorbis).loop = true
	scene.add_child(spray_settings)
	var spray := manager.create_player(spray_settings, scene)
	spray.play()
	assert_eq(spray.playback_type, AudioServer.PLAYBACK_TYPE_STREAM)
	scene.queue_free()
	await get_tree().process_frame
	assert_false(is_instance_valid(spray), "A looping spray must not survive forever after gameplay")
