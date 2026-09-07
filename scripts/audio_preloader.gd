extends Node

class_name AudioPreloader

## Known audio used by the playable web build. Keeping these as compile-time
## preloads makes the current streams available before any scene asks to play
## them and keeps them discoverable by the scene-filtered Web export.
const STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/beer_can_open_and_drink.ogg"),
	preload("res://assets/audio/door_kick.ogg"),
	preload("res://assets/audio/fbi_door_smash.ogg"),
	preload("res://assets/audio/fbi_open_up_voice.ogg"),
	preload("res://assets/audio/orchestra_hit.ogg"),
	preload("res://assets/audio/cute_cozy_ui/Sounds/Confirm.ogg"),
	preload("res://assets/audio/cute_cozy_ui/Sounds/Success.ogg"),
	preload("res://assets/audio/cute_cozy_ui/Sounds/Unlock.ogg"),
	preload("res://assets/audio/cute_cozy_ui/Sounds/Warning.ogg"),
	preload("res://assets/audio/wall/wall_pound_heavy.ogg"),
	preload("res://assets/audio/wall/wall_pound_light.ogg"),
	preload("res://assets/audio/wall/wall_pound_medium.ogg"),
	preload("res://assets/audio/zombie_disko_bass_boosted.ogg"),
	preload("res://assets/audio/zombie_disko_oomph.ogg"),
	preload("res://assets/audio/zombie_disko_room.ogg"),
]

const SILENT_VOLUME_DB := -80.0

var _warmup_players: Array[AudioStreamPlayer] = []
var _warmed_stream_keys: Dictionary = { }


func _ready() -> void:
	get_tree().node_added.connect(_on_tree_node_added)
	for stream in STREAMS:
		warm_stream(stream)
	# The main scene is loaded after autoloads enter the tree. This catches its
	# audio players as well as players created later by another scene or system.
	call_deferred("_warm_existing_audio_players")
	# A scene-filtered export only contains packed files, so this discovers any
	# additional audio assets that were added to the game and made it into Web's
	# PCK without requiring this registry to be edited for every new sound.
	if OS.has_feature("web"):
		_warm_audio_directory("res://assets/audio")


func warm_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	var stream_key := _stream_key(stream)
	if _warmed_stream_keys.has(stream_key):
		return
	_warmed_stream_keys[stream_key] = true

	# Web's default Sample playback creates its browser-side sample on first
	# play. Start each stream once at silence so gameplay cues do not pay that
	# cost on their first audible play. Keep the players alive so the streams
	# remain strongly referenced for the lifetime of the game.
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SILENT_VOLUME_DB
	player.bus = &"Master"
	add_child(player)
	player.play()
	player.stop()
	_warmup_players.append(player)


func is_stream_warmed(stream: AudioStream) -> bool:
	return stream != null and _warmed_stream_keys.has(_stream_key(stream))


func _on_tree_node_added(node: Node) -> void:
	if node is AudioStreamPlayer:
		warm_stream((node as AudioStreamPlayer).stream)


func _warm_existing_audio_players() -> void:
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		warm_stream((node as AudioStreamPlayer).stream)


func _warm_audio_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		var resource_path := path.path_join(file_name)
		if file_name.to_lower().ends_with(".import"):
			resource_path = resource_path.trim_suffix(".import")
		if not _is_audio_path(resource_path):
			continue
		warm_stream(load(resource_path) as AudioStream)
	for directory_name in directory.get_directories():
		_warm_audio_directory(path.path_join(directory_name))


func _is_audio_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension in ["ogg", "mp3", "wav"]


func _stream_key(stream: AudioStream) -> String:
	if not stream.resource_path.is_empty():
		return stream.resource_path
	return "instance:%s" % stream.get_instance_id()
