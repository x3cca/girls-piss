extends Node

## Players are created here before playback starts. Scenes retain references,
## while this autoload owns playback independently of scene lifetime.
const MUSIC_SCENE: PackedScene = preload("res://scenes/music_controller.tscn")

var music: MusicController
var _scene_players: Dictionary = { }


func _exit_tree() -> void:
	for player in find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	_scene_players.clear()
	music = null


func start_level_music() -> MusicController:
	reset_music()
	music = MUSIC_SCENE.instantiate() as MusicController
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	return music


func create_player(settings: AudioStreamPlayer, scene_owner: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = settings.name
	player.stream = settings.stream
	player.bus = settings.bus
	player.volume_db = settings.volume_db
	player.pitch_scale = settings.pitch_scale
	player.max_polyphony = settings.max_polyphony
	player.mix_target = settings.mix_target
	player.playback_type = settings.playback_type
	if _is_looping(player.stream):
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	var owner_id := scene_owner.get_instance_id()
	if not _scene_players.has(owner_id):
		_scene_players[owner_id] = []
		scene_owner.tree_exiting.connect(_release_scene_players.bind(owner_id), CONNECT_ONE_SHOT)
	_scene_players[owner_id].append(player)
	return player


func _release_scene_players(owner_id: int) -> void:
	var players: Array = _scene_players.get(owner_id, [])
	_scene_players.erase(owner_id)
	for player: AudioStreamPlayer in players:
		if not is_instance_valid(player):
			continue
		if player.playing and not _is_looping(player.stream):
			player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
		else:
			player.stop()
			player.queue_free()


func reset_music() -> void:
	if is_instance_valid(music):
		for player in [music.room_player, music.oomph_player, music.gameplay_player]:
			player.stop()
		music.queue_free()
	music = null


func _is_looping(stream: AudioStream) -> bool:
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamMP3:
		return (stream as AudioStreamMP3).loop
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return false
