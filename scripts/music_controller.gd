extends Node

class_name MusicController

const SILENT_VOLUME_DB := -80.0

## Beat events are scheduled from the audio player's playback position instead
## of the render delta, so a dropped frame cannot make the visual pulse drift
## away from the music. The defaults are tuned to the supplied gameplay loop.
signal beat_started(beat_index: int, strength: float)

@export_range(-24.0, 0.0, 0.5) var room_volume_db := 0.0
@export_range(-24.0, 0.0, 0.5) var oomph_volume_db := 0.0
@export_range(-24.0, 0.0, 0.5) var gameplay_volume_db := 0.0
@export_group("Music response")
@export_range(0.0, 1.0, 0.05) var oomph_shake_scale := 0.5
@export_range(0.0, 1.0, 0.05) var gameplay_shake_scale := 1.0
@export_group("Beat sync")
@export var beat_sync_enabled := true
@export_range(30.0, 240.0, 0.1) var gameplay_bpm := 153.0
@export_range(-1.0, 1.0, 0.001) var beat_offset_seconds := 0.06
@export_range(0.0, 1.0, 0.01) var beat_strength := 1.0

@onready var room_player: AudioStreamPlayer = $Room
@onready var oomph_player: AudioStreamPlayer = $Oomph
@onready var gameplay_player: AudioStreamPlayer = $Gameplay

var _gameplay_music_started := false
var _active_player: AudioStreamPlayer
var _active_shake_scale := 0.0
var _last_playback_position := -1.0
var _last_beat_index := -1


func _ready() -> void:
	_set_looping(room_player)
	_set_looping(oomph_player)
	_set_looping(gameplay_player)
	room_player.volume_db = room_volume_db
	oomph_player.volume_db = SILENT_VOLUME_DB
	gameplay_player.volume_db = SILENT_VOLUME_DB
	_stop_other_players(room_player)
	if not room_player.playing:
		room_player.play()
	_active_player = room_player
	_active_shake_scale = 0.0
	set_process(true)


func _process(_delta: float) -> void:
	if not beat_sync_enabled or not _gameplay_music_started:
		return
	# Both gameplay states have their own complete, more intense mix. Follow the
	# one that is currently audible instead of tying beat events to the peeing
	# track, which is stopped during the non-peeing state.
	if not is_instance_valid(_active_player) or not _active_player.playing:
		return

	_advance_beat_clock(_get_synced_playback_position())


func _advance_beat_clock(playback_position: float) -> void:
	# AudioStreamPlayer reports the position from the current loop. A decrease
	# means the gameplay loop wrapped (or was explicitly restarted), so allow
	# beat zero to fire again.
	if (
			_last_playback_position >= 0.0
			and playback_position + 0.05 < _last_playback_position
	):
		_last_beat_index = -1
	_last_playback_position = playback_position

	var beat_interval := 60.0 / maxf(gameplay_bpm, 1.0)
	var current_beat := floori(
		(playback_position - beat_offset_seconds) / beat_interval,
	)
	if current_beat < 0:
		return
	if _last_beat_index < 0:
		_last_beat_index = current_beat
		beat_started.emit(current_beat, clampf(beat_strength, 0.0, 1.0))
		return
	if current_beat <= _last_beat_index:
		return

	# Catch up after a hitch without losing the beat phase. This can emit more
	# than one event in a frame, but each event still belongs to the audio time
	# that was crossed.
	for beat_index in range(_last_beat_index + 1, current_beat + 1):
		beat_started.emit(beat_index, clampf(beat_strength, 0.0, 1.0))
	_last_beat_index = current_beat


func _get_synced_playback_position() -> float:
	# Correct the player position to the audio mix clock and output latency. This
	# keeps a visual beat event aligned with the sound coming out of the device,
	# rather than with the render frame that happened to poll the player.
	var playback_position := (
			_active_player.get_playback_position()
			+ AudioServer.get_time_since_last_mix()
			- AudioServer.get_output_latency()
	)
	var track_length := (
			_active_player.stream.get_length()
			if _active_player.stream
			else 0.0
	)
	if track_length > 0.0:
		playback_position = fmod(playback_position, track_length)
	return maxf(playback_position, 0.0)


func begin_gameplay() -> void:
	if _gameplay_music_started:
		return
	_gameplay_music_started = true
	_reset_beat_clock()
	# The room track is title-only. Start the non-peeing gameplay mix at the
	# beginning of its loop so the title can never remain the active song.
	_switch_to(oomph_player, 0.0)


func begin_gameplay_crossfade() -> void:
	# Keep the old entry point for callers from before music became exclusive.
	begin_gameplay()


func start_gameplay_immediately() -> void:
	_gameplay_music_started = true
	_reset_beat_clock()
	# This path is used by the direct-start level and also acts as a safe
	# fallback if the title transition was completed without its start signal.
	_switch_to(oomph_player, 0.0)


func set_pissing(active: bool) -> void:
	if not _gameplay_music_started:
		return
	# The bass-boosted mix is a complete peeing track, not an additive bus
	# layer. Keep exactly one gameplay track audible so the unified Master bus
	# does not change the intended balance.
	_switch_to(gameplay_player if active else oomph_player)


func get_shake_scale() -> float:
	return _active_shake_scale


func _set_looping(player: AudioStreamPlayer) -> void:
	var stream := player.stream as AudioStreamOggVorbis
	if not stream:
		return
	stream.loop = true
	stream.loop_offset = 0.0


func _switch_to(target: AudioStreamPlayer, position := -1.0) -> void:
	if target == _active_player and target.playing:
		return

	var start_position := position
	if start_position < 0.0 and is_instance_valid(_active_player):
		start_position = _active_player.get_playback_position()
	if start_position < 0.0:
		start_position = 0.0
	var target_length := target.stream.get_length() if target.stream else 0.0
	if target_length > 0.0:
		start_position = fmod(start_position, target_length)

	_stop_other_players(target)
	target.volume_db = _volume_for(target)
	target.play(start_position)
	_active_player = target
	_active_shake_scale = _shake_scale_for(target)


func _stop_other_players(keep: AudioStreamPlayer) -> void:
	for player in [room_player, oomph_player, gameplay_player]:
		if player == keep:
			continue
		player.stop()
		player.volume_db = SILENT_VOLUME_DB


func _volume_for(player: AudioStreamPlayer) -> float:
	if player == room_player:
		return room_volume_db
	if player == oomph_player:
		return oomph_volume_db
	return gameplay_volume_db


func _shake_scale_for(player: AudioStreamPlayer) -> float:
	if player == oomph_player:
		return clampf(oomph_shake_scale, 0.0, 1.0)
	if player == gameplay_player:
		return clampf(gameplay_shake_scale, 0.0, 1.0)
	return 0.0


func _reset_beat_clock() -> void:
	_last_playback_position = -1.0
	_last_beat_index = -1
