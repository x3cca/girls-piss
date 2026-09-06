extends CanvasLayer

class_name GameOver

## Authored failure treatment for an exhausted attempt.
##
## The level controller owns the FAILED state; this scene owns the presentation
## and retry affordance so the failure UI can evolve without coupling it to the
## stream or strike rules.

signal retry_pressed
signal raid_sequence_finished
signal raid_knock

const CURSOR_TEXTURE: Texture2D = preload(
	"res://assets/placeholders/cursor_pixel_pack/Tiles/tile_0026.png"
)

@export_range(0.1, 1.0, 0.05) var entry_duration := 0.35
@export_range(0.5, 1.0, 0.05) var entry_start_scale := 0.88
@export_range(0.0, 1.0, 0.05) var backdrop_opacity := 0.82
@export_range(0.0, 1.0, 0.05) var dread_opacity := 0.9
@export_range(0.0, 1.0, 0.05) var game_over_piss_opacity := 0.5
@export_range(0.0, 2.0, 0.05) var door_bang_delay := 1.1
@export_range(0.0, 2.0, 0.05) var launch_delay_after_door := 0.92
@export_range(0.0, 0.2, 0.01) var door_smash_audio_delay := 0.06

const DOOR_KNOCK_OFFSETS := [0.0, 0.19, 0.54]
const DOOR_BANG_HOLD_AFTER_LAST := 0.18

@onready var _backdrop: ColorRect = $Backdrop
@onready var _dread_frame: TextureRect = $DreadFrame
@onready var _presentation: Control = $Presentation
@onready var _game_over_piss: TextureRect = $Presentation/GameOverPiss
@onready var _retry_button: TextureButton = $Presentation/RetryButton
@onready var _piss_again_text_one: TextureRect = $Presentation/PissAgainText1
@onready var _piss_again_text_two: TextureRect = $Presentation/PissAgainText2
@onready var _door_bang: AnimatedSprite2D = $RaidOverlay/DoorBang
@onready var _fbi_voice: AudioStreamPlayer = $FbiVoice
@onready var _door_smash: AudioStreamPlayer = $DoorSmash
@onready var _door_kick: AudioStreamPlayer = $DoorKick

var _entry_tween: Tween
var _raid_sequence_tween: Tween
var _door_knock_tween: Tween
var _door_smash_delay_tween: Tween
var _card_revealed := false


func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_retry_button.pressed.connect(_on_retry_pressed)
	_retry_button.mouse_entered.connect(_set_retry_text_hovered.bind(true))
	_retry_button.mouse_exited.connect(_set_retry_text_hovered.bind(false))
	_retry_button.focus_entered.connect(_set_retry_text_hovered.bind(true))
	_retry_button.focus_exited.connect(_set_retry_text_hovered.bind(false))
	_set_retry_text_hovered(false)
	_backdrop.color.a = backdrop_opacity
	_dread_frame.modulate.a = dread_opacity
	_game_over_piss.modulate.a = game_over_piss_opacity
	_door_bang.visible = false
	_layout_door_bang()
	visible = false
	set_process(false)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_layout_door_bang()


func show_card() -> void:
	if _entry_tween:
		_entry_tween.kill()
	_stop_raid_sequence()
	visible = true
	set_process(true)
	_card_revealed = false
	_set_card_art_visible(false)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_presentation.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_presentation.modulate.a = 0.0
	_presentation.scale = Vector2.ONE * entry_start_scale
	_retry_button.grab_focus()
	_start_raid_sequence()


func reveal_card() -> void:
	## Keep the expensive full-screen failure art culled while the raid audio and
	## knock sprites play underneath the live level. Reveal it only when that
	## sequence is complete, on the same frame that the level begins its exit
	## launch.
	if not visible or _card_revealed:
		return
	_card_revealed = true
	_set_card_art_visible(true)
	_presentation.modulate.a = 0.0
	_presentation.scale = Vector2.ONE * entry_start_scale
	_entry_tween = create_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(_presentation, "modulate:a", 1.0, entry_duration)
	_entry_tween.tween_property(_presentation, "scale", Vector2.ONE, entry_duration).set_trans(
		Tween.TRANS_BACK,
	).set_ease(Tween.EASE_OUT)


func hide_card() -> void:
	if _entry_tween:
		_entry_tween.kill()
		_entry_tween = null
	_stop_raid_sequence()
	visible = false
	set_process(false)
	_card_revealed = false
	_set_card_art_visible(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_presentation.modulate = Color.WHITE
	_presentation.scale = Vector2.ONE


func is_showing() -> bool:
	return visible


func get_fbi_voice() -> AudioStream:
	return _fbi_voice.stream


func get_door_smash() -> AudioStream:
	return _door_smash.stream


func get_door_kick() -> AudioStream:
	return _door_kick.stream


func play_door_kick() -> void:
	_door_kick.play()


func _on_retry_pressed() -> void:
	retry_pressed.emit()


func _set_retry_text_hovered(hovered: bool) -> void:
	_piss_again_text_one.visible = not hovered
	_piss_again_text_two.visible = hovered


func _start_raid_sequence() -> void:
	_fbi_voice.play()
	_raid_sequence_tween = create_tween()
	_raid_sequence_tween.tween_interval(maxf(door_bang_delay, 0.0))
	_raid_sequence_tween.tween_callback(_play_door_smash)
	_raid_sequence_tween.tween_interval(maxf(launch_delay_after_door, 0.0))
	_raid_sequence_tween.tween_callback(_finish_raid_sequence)


func _stop_raid_sequence() -> void:
	if _raid_sequence_tween:
		_raid_sequence_tween.kill()
		_raid_sequence_tween = null
	if _door_knock_tween:
		_door_knock_tween.kill()
		_door_knock_tween = null
	if _door_smash_delay_tween:
		_door_smash_delay_tween.kill()
		_door_smash_delay_tween = null
	_fbi_voice.stop()
	_door_smash.stop()
	_door_kick.stop()
	_hide_door_bang()


func _play_door_smash() -> void:
	_door_bang.visible = true
	_show_door_bang_frame(0)
	# Put the authored impact art just ahead of the clip. This compensates for
	# the audio output path without changing the relative spacing of the three
	# knock cues.
	_door_smash_delay_tween = create_tween()
	_door_smash_delay_tween.tween_interval(maxf(door_smash_audio_delay, 0.0))
	_door_smash_delay_tween.tween_callback(_play_delayed_door_smash)
	_door_knock_tween = create_tween()
	for frame_index in range(1, DOOR_KNOCK_OFFSETS.size()):
		_door_knock_tween.tween_interval(
			DOOR_KNOCK_OFFSETS[frame_index] - DOOR_KNOCK_OFFSETS[frame_index - 1],
		)
		_door_knock_tween.tween_callback(_show_door_bang_frame.bind(frame_index))
	_door_knock_tween.tween_interval(DOOR_BANG_HOLD_AFTER_LAST)
	_door_knock_tween.tween_callback(_hide_door_bang)


func _play_delayed_door_smash() -> void:
	_door_smash_delay_tween = null
	_door_smash.play()


func _show_door_bang_frame(frame_index: int) -> void:
	if not _door_bang.visible:
		return
	_door_bang.frame = frame_index
	# The three authored frames now correspond one-to-one with the three knocks
	# in the audio clip, so each one can kick the camera independently.
	raid_knock.emit()


func _hide_door_bang() -> void:
	_door_bang.stop()
	_door_bang.visible = false


func _finish_raid_sequence() -> void:
	_hide_door_bang()
	_raid_sequence_tween = null
	set_process(false)
	reveal_card()
	raid_sequence_finished.emit()


func _set_card_art_visible(enabled: bool) -> void:
	_backdrop.visible = enabled
	_dread_frame.visible = enabled
	_presentation.visible = enabled


func _layout_door_bang() -> void:
	if not is_instance_valid(_door_bang):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	# The source frames have different crops. Size against the largest rotated
	# frame so every impact stays centered and visible along the bottom edge.
	var scale_factor := minf(
		viewport_size.x * 0.72 / 469.0,
		viewport_size.y * 0.29 / 370.0,
	)
	scale_factor = maxf(scale_factor, 0.1)
	_door_bang.scale = Vector2.ONE * scale_factor
	_door_bang.position = Vector2(
		viewport_size.x * 0.5,
		viewport_size.y - 370.0 * scale_factor * 0.5,
	)
