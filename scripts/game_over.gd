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
@export_range(0.0, 3.0, 0.05) var retry_reveal_delay := 1.0
@export_range(0.1, 1.0, 0.05) var retry_slide_duration := 0.45
@export_range(0.0, 40.0, 1.0) var retry_wobble_distance := 14.0
@export_range(0.05, 1.0, 0.05) var retry_wobble_duration := 0.12
@export_range(0.0, 2.0, 0.05) var door_smash_delay := 0.9
@export_range(0.0, 2.0, 0.05) var launch_delay_after_door := 0.92

const DOOR_KNOCK_OFFSETS := [0.0, 0.19, 0.54]
const DOOR_BANG_HOLD_AFTER_LAST := 0.18
const DOOR_BANG_VERTICAL_ANCHORS := [0.0, 1.0, 0.5]
const DOOR_BANG_ROW_FRAME_ORDER := [1, 2, 0]
const DOOR_BANG_ROW_WIDTH_RATIO := 0.9
const DOOR_BANG_ROW_HEIGHT_RATIO := 0.29
const DOOR_BANG_ROW_GAP := 12.0
const REFERENCE_VIEWPORT_SIZE := Vector2(1080.0, 1920.0)
const RETRY_ARROW_DESIGN_POSITION := Vector2(167.0, 1494.0)
const RETRY_ARROW_DESIGN_SIZE := Vector2(748.0, 420.0)
const RETRY_TEXT_ONE_DESIGN_POSITION := Vector2(292.0, 1645.0)
const RETRY_TEXT_ONE_DESIGN_SIZE := Vector2(556.0, 193.0)
const RETRY_TEXT_TWO_DESIGN_POSITION := Vector2(295.0, 1639.0)
const RETRY_TEXT_TWO_DESIGN_SIZE := Vector2(556.0, 197.0)

@onready var _backdrop: ColorRect = $Backdrop
@onready var _dread_frame: TextureRect = $DreadFrame
@onready var _presentation: Control = $Presentation
@onready var _game_over_one: TextureRect = $Presentation/GameOver1
@onready var _game_over_piss: TextureRect = $Presentation/GameOverPiss
@onready var _game_over_two: TextureRect = $Presentation/GameOver2
@onready var _game_over_chalk: TextureRect = $Presentation/GameOverChaulk
@onready var _kick_out_text: TextureRect = $Presentation/YouGotKickedOutText
@onready var _retry_button: TextureButton = $Presentation/RetryButton
@onready var _piss_again_text_one: TextureRect = $Presentation/PissAgainText1
@onready var _piss_again_text_two: TextureRect = $Presentation/PissAgainText2
@onready var _action_lines: ScreenOverlayEffect = $RaidOverlay/ActionLines
@onready var _door_bang: AnimatedSprite2D = $RaidOverlay/DoorBang
@onready var _fbi_voice: AudioStreamPlayer = $FbiVoice
@onready var _door_smash: AudioStreamPlayer = $DoorSmash
@onready var _door_kick: AudioStreamPlayer = $DoorKick

var _entry_tween: Tween
var _retry_tween: Tween
var _raid_sequence_tween: Tween
var _door_knock_tween: Tween
var _card_revealed := false
var _door_bang_layout_size := Vector2.ZERO
var _door_bang_frame_positions: Array[Vector2] = []
var _card_art_layout_size := Vector2.ZERO
var _retry_horizontal_offset := 0.0
var _retry_button_base_position := Vector2.ZERO
var _piss_again_text_one_base_position := Vector2.ZERO
var _piss_again_text_two_base_position := Vector2.ZERO


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
	_action_lines.stop()
	_door_bang.visible = false
	_layout_card_art()
	_layout_door_bang()
	visible = false
	set_process(false)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_layout_card_art()
		_layout_door_bang()


func show_card() -> void:
	if _entry_tween:
		_entry_tween.kill()
		_entry_tween = null
	_stop_raid_sequence()
	_stop_retry_animation()
	visible = true
	set_process(true)
	_card_revealed = false
	_set_card_art_visible(false)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_presentation.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_presentation.modulate.a = 0.0
	_presentation.scale = Vector2.ONE * entry_start_scale
	_layout_card_art()
	_set_retry_affordance_position(_get_retry_entry_offset())
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
	_layout_card_art()
	_presentation.modulate.a = 0.0
	_presentation.scale = Vector2.ONE * entry_start_scale
	_entry_tween = create_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(_presentation, "modulate:a", 1.0, entry_duration)
	_entry_tween.tween_property(_presentation, "scale", Vector2.ONE, entry_duration).set_trans(
		Tween.TRANS_BACK,
	).set_ease(Tween.EASE_OUT)
	_entry_tween.finished.connect(_on_entry_animation_finished)


func _on_entry_animation_finished() -> void:
	_entry_tween = null
	_action_lines.stop()
	_start_retry_animation()


func hide_card() -> void:
	if _entry_tween:
		_entry_tween.kill()
		_entry_tween = null
	_stop_raid_sequence()
	_stop_retry_animation()
	visible = false
	set_process(false)
	_card_revealed = false
	_set_card_art_visible(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_presentation.modulate = Color.WHITE
	_presentation.scale = Vector2.ONE
	_set_retry_affordance_position(0.0)


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


func _start_retry_animation() -> void:
	_entry_tween = null
	if not visible or not _card_revealed:
		return
	_stop_retry_animation()
	_set_retry_affordance_position(_get_retry_entry_offset())
	_retry_tween = create_tween()
	_retry_tween.tween_interval(maxf(retry_reveal_delay, 0.0))
	_retry_tween.tween_method(
		_set_retry_affordance_position,
		_get_retry_entry_offset(),
		0.0,
		retry_slide_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_retry_tween.tween_method(
		_set_retry_affordance_position,
		0.0,
		-retry_wobble_distance,
		retry_wobble_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_retry_tween.tween_method(
		_set_retry_affordance_position,
		-retry_wobble_distance,
		retry_wobble_distance * 0.7,
		retry_wobble_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_retry_tween.tween_method(
		_set_retry_affordance_position,
		retry_wobble_distance * 0.7,
		-retry_wobble_distance * 0.35,
		retry_wobble_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_retry_tween.tween_method(
		_set_retry_affordance_position,
		-retry_wobble_distance * 0.35,
		0.0,
		retry_wobble_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_retry_tween.finished.connect(_on_retry_animation_finished)


func _on_retry_animation_finished() -> void:
	_retry_tween = null
	if visible and _card_revealed:
		_retry_button.grab_focus()


func _stop_retry_animation() -> void:
	if _retry_tween:
		_retry_tween.kill()
		_retry_tween = null


func _get_retry_entry_offset() -> float:
	return get_viewport().get_visible_rect().size.x


func _set_retry_affordance_position(horizontal_offset: float) -> void:
	_retry_horizontal_offset = horizontal_offset
	_retry_button.position.x = _retry_button_base_position.x + horizontal_offset
	_piss_again_text_one.position.x = _piss_again_text_one_base_position.x + horizontal_offset
	_piss_again_text_two.position.x = _piss_again_text_two_base_position.x + horizontal_offset


func _layout_card_art() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if viewport_size == _card_art_layout_size:
		return
	_card_art_layout_size = viewport_size
	_layout_control(_game_over_one, Vector2.ZERO, viewport_size)
	_layout_control(_game_over_piss, Vector2.ZERO, viewport_size)
	_layout_control(_game_over_two, Vector2.ZERO, viewport_size)
	_layout_control(_game_over_chalk, Vector2.ZERO, viewport_size)
	_layout_control(_kick_out_text, Vector2.ZERO, viewport_size)
	var reference_scale := minf(
		viewport_size.x / REFERENCE_VIEWPORT_SIZE.x,
		viewport_size.y / REFERENCE_VIEWPORT_SIZE.y,
	)
	var reference_origin := (
			viewport_size - REFERENCE_VIEWPORT_SIZE * reference_scale
	) * 0.5
	var retry_arrow_position := reference_origin + RETRY_ARROW_DESIGN_POSITION * reference_scale
	var retry_text_one_position := (
			reference_origin + RETRY_TEXT_ONE_DESIGN_POSITION * reference_scale
	)
	var retry_text_two_position := (
			reference_origin + RETRY_TEXT_TWO_DESIGN_POSITION * reference_scale
	)
	_layout_control(
		_retry_button,
		retry_arrow_position,
		RETRY_ARROW_DESIGN_SIZE * reference_scale,
	)
	_layout_control(
		_piss_again_text_one,
		retry_text_one_position,
		RETRY_TEXT_ONE_DESIGN_SIZE * reference_scale,
	)
	_layout_control(
		_piss_again_text_two,
		retry_text_two_position,
		RETRY_TEXT_TWO_DESIGN_SIZE * reference_scale,
	)
	_retry_button_base_position = retry_arrow_position
	_piss_again_text_one_base_position = retry_text_one_position
	_piss_again_text_two_base_position = retry_text_two_position
	_set_retry_affordance_position(_retry_horizontal_offset)


func _layout_control(control: Control, position: Vector2, size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.position = position
	control.size = size


func _start_raid_sequence() -> void:
	# Explicitly reset the player so a repeated failure/retry can never resume a
	# stale decoder position. The visual knock FX start with the voice; the
	# existing smash recording waits until the voice has finished because it
	# contains overlapping room/vocal material rather than isolated knocks.
	_fbi_voice.stop()
	_fbi_voice.play(0.0)
	_action_lines.play()
	_start_door_bang_fx()
	_raid_sequence_tween = create_tween()
	_raid_sequence_tween.tween_interval(maxf(door_smash_delay, 0.0))
	_raid_sequence_tween.tween_callback(_play_door_smash_audio)
	_raid_sequence_tween.tween_interval(maxf(launch_delay_after_door, 0.0))
	_raid_sequence_tween.tween_callback(_finish_raid_sequence)


func _stop_raid_sequence() -> void:
	if _raid_sequence_tween:
		_raid_sequence_tween.kill()
		_raid_sequence_tween = null
	if _door_knock_tween:
		_door_knock_tween.kill()
		_door_knock_tween = null
	_fbi_voice.stop()
	_door_smash.stop()
	_door_kick.stop()
	_action_lines.stop()
	_hide_door_bang()


func _play_door_smash() -> void:
	_play_door_smash_audio()
	_start_door_bang_fx()


func _play_door_smash_audio() -> void:
	_door_smash.stop()
	_door_smash.play(0.0)


func _start_door_bang_fx() -> void:
	_door_bang.visible = true
	_show_door_bang_frame(0)
	if _door_knock_tween:
		_door_knock_tween.kill()
	_door_knock_tween = create_tween()
	for frame_index in range(1, DOOR_KNOCK_OFFSETS.size()):
		_door_knock_tween.tween_interval(
			DOOR_KNOCK_OFFSETS[frame_index] - DOOR_KNOCK_OFFSETS[frame_index - 1],
		)
		_door_knock_tween.tween_callback(_show_door_bang_frame.bind(frame_index))
	_door_knock_tween.tween_interval(DOOR_BANG_HOLD_AFTER_LAST)
	_door_knock_tween.tween_callback(_hide_door_bang)

func _show_door_bang_frame(frame_index: int) -> void:
	if not _door_bang.visible:
		return
	_door_bang.frame = frame_index
	_position_door_bang_frame(frame_index)
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
	if viewport_size == _door_bang_layout_size:
		return
	_door_bang_layout_size = viewport_size
	# Each source frame is a separate authored impact. They are played in
	# sequence, but each one gets its own slot in the horizontal row instead of
	# sharing the same center point. The authored vertical order is top, bottom,
	# middle for DoorBang1, DoorBang2, DoorBang3 respectively. Horizontally, the
	# authored order is right, left, middle.
	var frame_sizes: Array[Vector2] = []
	var total_frame_width := 0.0
	var max_frame_height := 0.0
	var frame_count := _door_bang.sprite_frames.get_frame_count(&"default")
	var rotation_cosine := absf(cos(_door_bang.rotation))
	var rotation_sine := absf(sin(_door_bang.rotation))
	for frame_index in range(frame_count):
		var texture := _door_bang.sprite_frames.get_frame_texture(&"default", frame_index)
		var texture_size := texture.get_size()
		var frame_size := Vector2(
			texture_size.x * rotation_cosine + texture_size.y * rotation_sine,
			texture_size.x * rotation_sine + texture_size.y * rotation_cosine,
		)
		frame_sizes.append(frame_size)
		total_frame_width += frame_size.x
		max_frame_height = maxf(max_frame_height, frame_size.y)
	if frame_sizes.is_empty() or max_frame_height <= 0.0:
		return

	var unscaled_row_width := total_frame_width + DOOR_BANG_ROW_GAP * (frame_count - 1)
	var scale_factor := minf(
		viewport_size.x * DOOR_BANG_ROW_WIDTH_RATIO / unscaled_row_width,
		viewport_size.y * DOOR_BANG_ROW_HEIGHT_RATIO / max_frame_height,
	)
	scale_factor = maxf(scale_factor, 0.1)
	_door_bang.scale = Vector2.ONE * scale_factor

	var row_height := max_frame_height * scale_factor
	var row_gap := DOOR_BANG_ROW_GAP * scale_factor
	var row_width := total_frame_width * scale_factor + row_gap * (frame_count - 1)
	var row_left := (viewport_size.x - row_width) * 0.5
	var row_top := viewport_size.y - row_height
	_door_bang_frame_positions.clear()
	_door_bang_frame_positions.resize(frame_count)
	for row_slot in range(frame_count):
		var frame_index := row_slot
		if row_slot < DOOR_BANG_ROW_FRAME_ORDER.size():
			frame_index = DOOR_BANG_ROW_FRAME_ORDER[row_slot]
		var frame_size := frame_sizes[frame_index] * scale_factor
		var vertical_anchor := 0.5
		if frame_index < DOOR_BANG_VERTICAL_ANCHORS.size():
			vertical_anchor = DOOR_BANG_VERTICAL_ANCHORS[frame_index]
		_door_bang_frame_positions[frame_index] = Vector2(
			row_left + frame_size.x * 0.5,
			row_top + (row_height - frame_size.y) * vertical_anchor + frame_size.y * 0.5,
		)
		row_left += frame_size.x + row_gap
	_position_door_bang_frame(_door_bang.frame)


func _position_door_bang_frame(frame_index: int) -> void:
	if frame_index < 0 or frame_index >= _door_bang_frame_positions.size():
		return
	_door_bang.position = _door_bang_frame_positions[frame_index]
