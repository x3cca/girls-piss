extends Control

class_name CompletionCard

signal play_again_pressed

const CURSOR_TEXTURE: Texture2D = preload(
	"res://assets/placeholders/cursor_pixel_pack/Tiles/tile_0026.png"
)

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const RETRY_FINAL_POSITION := Vector2(167.0, 1494.0)

@export_range(0.05, 2.0, 0.01) var good_job_fade_duration := 0.42
@export_range(0.0, 1.0, 0.01) var star_entry_delay := 0.12
@export_range(0.05, 2.0, 0.01) var star_entry_duration := 0.58
@export_range(1.0, 5.0, 0.1) var star_start_scale := 2.8
@export_range(0.0, 1.0, 0.01) var credits_start_delay := 0.1
@export_range(0.05, 2.0, 0.01) var credit_fade_duration := 0.34
@export_range(0.05, 1.0, 0.01) var credit_stagger := 0.23
@export_range(0.0, 1.0, 0.01) var retry_entry_delay := 0.14
@export_range(0.05, 2.0, 0.01) var retry_slide_duration := 0.62
@export_range(0.0, 12.0, 0.1) var retry_shake_degrees := 3.5
@export_range(0.0, 1.0, 0.05) var backdrop_opacity := 0.68
@export_range(0.0, 1.0, 0.05) var vignette_opacity := 0.34

@onready var _backdrop: ColorRect = $Backdrop
@onready var _dread_frame: TextureRect = $DreadFrame
@onready var _presentation: Control = $Presentation
@onready var _art_root: Control = $Presentation/Art
@onready var _good_job_group: Control = $Presentation/Art/GoodJobGroup
@onready var _bowl_water: Sprite2D = $Presentation/Art/GoodJobGroup/BowlWater
@onready var _good_job_sticker: Control = $Presentation/Art/GoodJobGroup/GoodJobSticker
@onready var _good_job_text: TextureRect = $Presentation/Art/GoodJobGroup/GoodJobSticker/GoodJobText
@onready var _retry_group: Control = $Presentation/Art/PissAgainGroup
@onready var _retry_button: Button = $PlayAgainButton
@onready var _piss_again_arrow_one: TextureRect = (
		$Presentation/Art/PissAgainGroup/PissAgainArrow1
)
@onready var _piss_again_arrow_two: TextureRect = (
		$Presentation/Art/PissAgainGroup/PissAgainArrow2
)
@onready var _piss_again_text_one: TextureRect = (
		$Presentation/Art/PissAgainGroup/PissAgainText1
)
@onready var _piss_again_text_two: TextureRect = (
		$Presentation/Art/PissAgainGroup/PissAgainText2
)
@onready var _win_sound: AudioStreamPlayer = $WinSound
@onready var _star_sound: AudioStreamPlayer = $StarSound
@onready var _credit_chunks: Array[CanvasItem] = [
	$Presentation/Art/Credits/PissListQuote,
	$Presentation/Art/Credits/DottyCredit,
	$Presentation/Art/Credits/PissingAloneQuote,
	$Presentation/Art/Credits/SleepyStarDropsCredit,
	$Presentation/Art/Credits/GirlPissGirlBossQuote,
	$Presentation/Art/Credits/RayCredit,
	$Presentation/Art/Credits/MusicCredit,
]

var failure_state := false
var _animation_tween: Tween
var _layout_signature := Vector2.ZERO
var _bowl_elapsed := 0.0


func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_retry_button.pressed.connect(_on_play_again_pressed)
	_retry_button.mouse_entered.connect(_set_retry_text_hovered.bind(true))
	_retry_button.mouse_exited.connect(_set_retry_text_hovered.bind(false))
	_retry_button.focus_entered.connect(_set_retry_text_hovered.bind(true))
	_retry_button.focus_exited.connect(_set_retry_text_hovered.bind(false))
	_backdrop.color.a = backdrop_opacity
	_dread_frame.modulate.a = vignette_opacity
	_presentation.modulate = Color.WHITE
	_set_retry_text_hovered(false)
	_reset_animation_state()
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_layout_card()
		_bowl_elapsed += _delta
		_set_bowl_elapsed(_bowl_elapsed)


func show_card() -> void:
	_show_card(false)


func show_failure_card() -> void:
	_show_card(true)


func is_failure_card() -> bool:
	return failure_state


func hide_card() -> void:
	_kill_animation()
	_win_sound.stop()
	_star_sound.stop()
	visible = false
	set_process(false)
	failure_state = false
	_reset_animation_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _show_card(next_failure_state: bool) -> void:
	_kill_animation()
	_win_sound.stop()
	_star_sound.stop()
	failure_state = next_failure_state
	visible = true
	set_process(true)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_layout_card()
	_reset_animation_state()
	_retry_button.grab_focus()
	if not failure_state:
		_win_sound.play()
	_start_reveal_sequence()


func _start_reveal_sequence() -> void:
	_animation_tween = create_tween()
	# The completed pile and its hand-lettered title arrive first as one soft
	# reveal. The star then punches in independently, like a sticker slapped on
	# top of the finished composition.
	_animation_tween.tween_property(
		_good_job_group,
		"modulate:a",
		1.0,
		good_job_fade_duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_interval(star_entry_delay)
	if not failure_state:
		_animation_tween.tween_callback(_play_star_sound)
	_animation_tween.set_parallel(true)
	_animation_tween.tween_property(
		_good_job_sticker,
		"modulate:a",
		1.0,
		star_entry_duration * 0.42,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_property(
		_good_job_sticker,
		"scale",
		Vector2.ONE,
		star_entry_duration,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation_tween.set_parallel(false)
	_animation_tween.tween_interval(credits_start_delay)

	# Use delayed parallel property tweeners so each credit overlaps the previous
	# fade instead of waiting for the whole list item to finish.
	_animation_tween.set_parallel(true)
	for index in _credit_chunks.size():
		_animation_tween.tween_property(
			_credit_chunks[index],
			"modulate:a",
			1.0,
			credit_fade_duration,
		).set_delay(float(index) * credit_stagger).set_trans(
			Tween.TRANS_SINE,
		).set_ease(Tween.EASE_OUT)
	_animation_tween.set_parallel(false)
	_animation_tween.tween_interval(
		credit_fade_duration + float(maxi(_credit_chunks.size() - 1, 0)) * credit_stagger
		+ retry_entry_delay,
	)

	_animation_tween.set_parallel(true)
	_animation_tween.tween_property(
		_retry_group,
		"modulate:a",
		1.0,
		retry_slide_duration * 0.45,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_property(
		_retry_group,
		"position",
		RETRY_FINAL_POSITION,
		retry_slide_duration,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_method(
		_set_retry_shake,
		0.0,
		1.0,
		retry_slide_duration,
	)
	_animation_tween.set_parallel(false)


func _reset_animation_state() -> void:
	_layout_card()
	_bowl_elapsed = 0.0
	_set_bowl_elapsed(0.0)
	_backdrop.color.a = backdrop_opacity
	_dread_frame.modulate.a = vignette_opacity
	_good_job_group.modulate.a = 0.0
	_good_job_sticker.modulate.a = 0.0
	_good_job_sticker.scale = Vector2.ONE * star_start_scale
	_good_job_text.modulate.a = 1.0
	for credit in _credit_chunks:
		credit.modulate.a = 0.0
	_retry_group.modulate.a = 0.0
	_retry_group.position = RETRY_FINAL_POSITION + Vector2(DESIGN_SIZE.x + 32.0, 0.0)
	_retry_group.rotation = 0.0
	_set_retry_text_hovered(false)


func _set_bowl_elapsed(value: float) -> void:
	var material := _bowl_water.material as ShaderMaterial
	if material:
		material.set_shader_parameter("ripple_age", value)


func _play_star_sound() -> void:
	_star_sound.stop()
	_star_sound.play()


func _set_retry_shake(progress: float) -> void:
	var fade_out := 1.0 - clampf(progress, 0.0, 1.0)
	_retry_group.rotation = sin(progress * TAU * 2.0) * deg_to_rad(retry_shake_degrees) * fade_out


func _kill_animation() -> void:
	if _animation_tween:
		_animation_tween.kill()
		_animation_tween = null


func _on_play_again_pressed() -> void:
	play_again_pressed.emit()


func _set_retry_text_hovered(hovered: bool) -> void:
	if not is_instance_valid(_piss_again_text_one):
		return
	_piss_again_arrow_one.visible = not hovered
	_piss_again_arrow_two.visible = hovered
	_piss_again_text_one.visible = not hovered
	_piss_again_text_two.visible = hovered


func _layout_card() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if viewport_size == _layout_signature:
		return
	_layout_signature = viewport_size
	# Keep all authored placements in the 1080x1920 coordinate system used by the
	# reference art, then scale the complete stack as one sticker sheet.
	var art_scale := maxf(
		viewport_size.x / DESIGN_SIZE.x,
		viewport_size.y / DESIGN_SIZE.y,
	)
	_art_root.scale = Vector2.ONE * art_scale
	_art_root.position = (viewport_size - DESIGN_SIZE * art_scale) * 0.5
	_retry_button.position = _art_root.position + RETRY_FINAL_POSITION * art_scale
	_retry_button.size = Vector2(748.0, 420.0) * art_scale
