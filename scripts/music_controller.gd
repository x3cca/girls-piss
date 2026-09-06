extends Node

class_name MusicController

const SILENT_VOLUME_DB := -80.0

## Beat events are scheduled from the audio player's playback position instead
## of the render delta, so a dropped frame cannot make the visual pulse drift
## away from the music. The defaults are tuned to the supplied gameplay loop.
signal beat_started(beat_index: int, strength: float)

@export_range(0.1, 8.0, 0.05) var gameplay_crossfade_duration := 5.0
@export_range(0.1, 3.0, 0.05) var intensity_crossfade_duration := 0.45
@export_range(-24.0, 0.0, 0.5) var room_volume_db := 0.0
@export_range(-24.0, 0.0, 0.5) var oomph_volume_db := 0.0
@export_range(-24.0, 0.0, 0.5) var gameplay_volume_db := 0.0
@export_group("Beat sync")
@export var beat_sync_enabled := true
@export_range(30.0, 240.0, 0.1) var gameplay_bpm := 153.0
@export_range(-1.0, 1.0, 0.001) var beat_offset_seconds := 0.06
@export_range(0.0, 1.0, 0.01) var beat_strength := 1.0

@onready var room_player: AudioStreamPlayer = $Room
@onready var oomph_player: AudioStreamPlayer = $Oomph
@onready var gameplay_player: AudioStreamPlayer = $Gameplay

var _crossfade_tween: Tween
var _intensity_tween: Tween
var _gameplay_music_started := false
var _title_progress := 0.0
var _intensity_progress := 0.0
var _last_playback_position := -1.0
var _last_beat_index := -1


func _ready() -> void:
	_set_looping(room_player)
	_set_looping(oomph_player)
	_set_looping(gameplay_player)
	room_player.volume_db = room_volume_db
	oomph_player.volume_db = SILENT_VOLUME_DB
	gameplay_player.volume_db = SILENT_VOLUME_DB
	if not room_player.playing:
		room_player.play()
	set_process(true)


func _process(_delta: float) -> void:
	if not beat_sync_enabled or not _gameplay_music_started:
		return
	if not gameplay_player.playing:
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
			gameplay_player.get_playback_position()
			+ AudioServer.get_time_since_last_mix()
			- AudioServer.get_output_latency()
	)
	var track_length := (
			gameplay_player.stream.get_length()
			if gameplay_player.stream
			else 0.0
	)
	if track_length > 0.0:
		playback_position = fmod(playback_position, track_length)
	return maxf(playback_position, 0.0)


func begin_gameplay_crossfade() -> void:
	if _gameplay_music_started:
		return
	_gameplay_music_started = true
	if _crossfade_tween:
		_crossfade_tween.kill()

	if not room_player.playing:
		room_player.play()
	_start_gameplay_layers()
	_reset_beat_clock()
	_title_progress = 0.0
	_intensity_progress = 0.0
	_apply_title_crossfade(0.0)

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
	if _intensity_tween:
		_intensity_tween.kill()
	_gameplay_music_started = true
	_start_gameplay_layers()
	_reset_beat_clock()
	room_player.stop()
	_title_progress = 1.0
	_intensity_progress = 0.0
	_apply_title_crossfade(1.0)


func set_pissing(active: bool) -> void:
	if not _gameplay_music_started:
		return
	if _intensity_tween:
		_intensity_tween.kill()

	var target_progress := 1.0 if active else 0.0
	if is_equal_approx(_intensity_progress, target_progress):
		_apply_intensity_crossfade(target_progress)
		return

	_intensity_tween = create_tween()
	_intensity_tween.tween_method(
		_apply_intensity_crossfade,
		_intensity_progress,
		target_progress,
		intensity_crossfade_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_looping(player: AudioStreamPlayer) -> void:
	var stream := player.stream as AudioStreamOggVorbis
	if not stream:
		return
	stream.loop = true
	stream.loop_offset = 0.0


func _apply_crossfade(progress: float) -> void:
	# Keep the old helper name for callers that used the two-layer controller.
	_apply_title_crossfade(progress)


func _apply_title_crossfade(progress: float) -> void:
	_title_progress = clampf(progress, 0.0, 1.0)
	_apply_mix()


func _apply_intensity_crossfade(progress: float) -> void:
	_intensity_progress = clampf(progress, 0.0, 1.0)
	_apply_mix()


func _apply_mix() -> void:
	var gameplay_base_gain := sin(_title_progress * PI * 0.5)
	var room_gain := cos(_title_progress * PI * 0.5)
	var oomph_gain := gameplay_base_gain * cos(_intensity_progress * PI * 0.5)
	var gameplay_gain := gameplay_base_gain * sin(_intensity_progress * PI * 0.5)
	room_player.volume_db = _gain_to_db(room_gain, room_volume_db)
	oomph_player.volume_db = _gain_to_db(oomph_gain, oomph_volume_db)
	gameplay_player.volume_db = _gain_to_db(gameplay_gain, gameplay_volume_db)


func _start_gameplay_layers() -> void:
	# Start both synchronized gameplay layers together. The full layer remains
	# silent until a piss hold, so the intensity fade never seeks or lazy-loads.
	oomph_player.play(0.0)
	gameplay_player.play(0.0)


func _gain_to_db(gain: float, target_db: float) -> float:
	if gain <= 0.0001:
		return SILENT_VOLUME_DB
	return linear_to_db(gain * db_to_linear(target_db))


func _stop_room_player() -> void:
	room_player.stop()


func _reset_beat_clock() -> void:
	_last_playback_position = -1.0
	_last_beat_index = -1
