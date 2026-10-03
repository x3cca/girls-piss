extends Control

class_name CreditsScene

signal back_requested

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const MIN_BACK_BUTTON_SIZE := Vector2(220.0, 80.0)

@export_range(0.0, 1.0, 0.01) var backdrop_opacity := 0.68
@export_range(0.0, 1.0, 0.05) var vignette_opacity := 0.34
@export_range(0.05, 2.0, 0.01) var credit_fade_duration := 0.34
@export_range(0.05, 1.0, 0.01) var credit_stagger := 0.23
@export_range(0.0, 64.0, 1.0) var back_button_font_size := 30.0

@onready var _backdrop: ColorRect = $Backdrop
@onready var _dread_frame: TextureRect = $DreadFrame
@onready var _art_root: Control = $Presentation/Art
@onready var _back_button: Button = $BackButton
@onready var _credit_chunks: Array[CanvasItem] = [
	$Presentation/Art/Credits/PissListQuote,
	$Presentation/Art/Credits/DottyCredit,
	$Presentation/Art/Credits/PissingAloneQuote,
	$Presentation/Art/Credits/SleepyStarDropsCredit,
	$Presentation/Art/Credits/GirlPissGirlBossQuote,
	$Presentation/Art/Credits/RayCredit,
	$Presentation/Art/Credits/MusicCredit,
]

var _reveal_tween: Tween
var _layout_signature := Vector2.ZERO


func _ready() -> void:
	_back_button.pressed.connect(_on_back_button_pressed)
	_backdrop.color.a = backdrop_opacity
	_dread_frame.modulate.a = vignette_opacity
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_layout_credits()
	_start_reveal()
	_back_button.grab_focus()
	set_process(true)


func _process(_delta: float) -> void:
	if visible:
		_layout_credits()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func show_credits() -> void:
	_kill_reveal()
	visible = true
	set_process(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_layout_signature = Vector2.ZERO
	_layout_credits()
	_start_reveal()
	_back_button.grab_focus()


func hide_credits() -> void:
	_kill_reveal()
	visible = false
	set_process(false)


func _start_reveal() -> void:
	for credit in _credit_chunks:
		credit.modulate.a = 0.0
	_reveal_tween = create_tween()
	_reveal_tween.set_parallel(true)
	for index in _credit_chunks.size():
		_reveal_tween.tween_property(
			_credit_chunks[index],
			"modulate:a",
			1.0,
			credit_fade_duration,
		).set_delay(float(index) * credit_stagger).set_trans(
			Tween.TRANS_SINE,
		).set_ease(Tween.EASE_OUT)
	_reveal_tween.set_parallel(false)
	_reveal_tween.finished.connect(_on_reveal_finished)


func _on_reveal_finished() -> void:
	_reveal_tween = null


func _kill_reveal() -> void:
	if _reveal_tween:
		_reveal_tween.kill()
		_reveal_tween = null


func _layout_credits() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if viewport_size == _layout_signature:
		return
	_layout_signature = viewport_size
	var art_scale := maxf(
		viewport_size.x / DESIGN_SIZE.x,
		viewport_size.y / DESIGN_SIZE.y,
	)
	_art_root.scale = Vector2.ONE * art_scale
	_art_root.position = (viewport_size - DESIGN_SIZE * art_scale) * 0.5
	var button_width := minf(
		maxf(MIN_BACK_BUTTON_SIZE.x, viewport_size.x * 0.38),
		viewport_size.x - 32.0,
	)
	var button_height := maxf(MIN_BACK_BUTTON_SIZE.y, 100.0 * art_scale)
	_back_button.size = Vector2(button_width, button_height)
	_back_button.position = Vector2(
		(viewport_size.x - button_width) * 0.5,
		viewport_size.y - button_height - maxf(24.0, 48.0 * art_scale),
	)
	_back_button.add_theme_font_size_override(
		"font_size",
		roundi(clampf(back_button_font_size * art_scale, 22.0, 42.0)),
	)


func _on_back_button_pressed() -> void:
	back_requested.emit()
