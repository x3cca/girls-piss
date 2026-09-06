extends Node

class_name MusicController

const SILENT_VOLUME_DB := -80.0

@export_range(0.1, 8.0, 0.05) var gameplay_crossfade_duration := 5.0
@export_range(-24.0, 0.0, 0.5) var room_volume_db := 0.0
@export_range(-24.0, 0.0, 0.5) var gameplay_volume_db := -2.0

@onready var room_player: AudioStreamPlayer = $Room
@onready var gameplay_player: AudioStreamPlayer = $Gameplay

var _crossfade_tween: Tween
var _gameplay_music_started := false


func _ready() -> void:
	_set_looping(room_player)
	_set_looping(gameplay_player)
	room_player.volume_db = room_volume_db
	gameplay_player.volume_db = SILENT_VOLUME_DB
	if not room_player.playing:
		room_player.play()


func begin_gameplay_crossfade() -> void:
	if _gameplay_music_started:
		return
	_gameplay_music_started = true
	if _crossfade_tween:
		_crossfade_tween.kill()

	if not room_player.playing:
		room_player.play()
	gameplay_player.play(0.0)
	_apply_crossfade(0.0)

	# Tween a normalized mix value and convert to amplitude gains. Tweening dB
	# values directly creates a large quiet dip in the middle of the overlap.
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_method(
		_apply_crossfade,
		0.0,
		1.0,
		gameplay_crossfade_duration,
	)
	_crossfade_tween.tween_callback(_stop_room_player)


func start_gameplay_immediately() -> void:
	if _crossfade_tween:
		_crossfade_tween.kill()
	_gameplay_music_started = true
	gameplay_player.play(0.0)
	room_player.stop()
	room_player.volume_db = SILENT_VOLUME_DB
	gameplay_player.volume_db = gameplay_volume_db


func _set_looping(player: AudioStreamPlayer) -> void:
	var stream := player.stream as AudioStreamOggVorbis
	if not stream:
		return
	stream.loop = true
	stream.loop_offset = 0.0


func _apply_crossfade(progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 1.0)
	var room_gain := cos(safe_progress * PI * 0.5)
	var gameplay_gain := sin(safe_progress * PI * 0.5)
	room_player.volume_db = _gain_to_db(room_gain, room_volume_db)
	gameplay_player.volume_db = _gain_to_db(gameplay_gain, gameplay_volume_db)


func _gain_to_db(gain: float, target_db: float) -> float:
	if gain <= 0.0001:
		return SILENT_VOLUME_DB
	return linear_to_db(gain * db_to_linear(target_db))


func _stop_room_player() -> void:
	room_player.stop()
