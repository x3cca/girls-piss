extends GutTest

func test_web_audio_preloader_keeps_all_runtime_streams_ready() -> void:
	assert_eq(AudioPreloader.STREAMS.size(), 15)

	var expected_paths := [
		"res://assets/audio/beer_can_open_and_drink.ogg",
		"res://assets/audio/door_kick.ogg",
		"res://assets/audio/fbi_door_smash.ogg",
		"res://assets/audio/fbi_open_up_voice.ogg",
		"res://assets/audio/orchestra_hit.ogg",
		"res://assets/audio/cute_cozy_ui/Sounds/Confirm.ogg",
		"res://assets/audio/cute_cozy_ui/Sounds/Success.ogg",
		"res://assets/audio/cute_cozy_ui/Sounds/Unlock.ogg",
		"res://assets/audio/cute_cozy_ui/Sounds/Warning.ogg",
		"res://assets/audio/wall/wall_pound_heavy.ogg",
		"res://assets/audio/wall/wall_pound_light.ogg",
		"res://assets/audio/wall/wall_pound_medium.ogg",
		"res://assets/audio/zombie_disko_bass_boosted.ogg",
		"res://assets/audio/zombie_disko_oomph.ogg",
		"res://assets/audio/zombie_disko_room.ogg",
	]

	for index in AudioPreloader.STREAMS.size():
		var stream := AudioPreloader.STREAMS[index]
		assert_not_null(stream)
		assert_eq(stream.resource_path, expected_paths[index])

	var preloader := get_tree().root.get_node_or_null("AudioResources")
	assert_not_null(preloader)
	if preloader:
		for stream in AudioPreloader.STREAMS:
			assert_true(preloader.is_stream_warmed(stream))

		var extra_player := AudioStreamPlayer.new()
		extra_player.stream = load("res://assets/audio/zombie_disko.ogg") as AudioStream
		add_child_autofree(extra_player)
		assert_true(preloader.is_stream_warmed(extra_player.stream))
