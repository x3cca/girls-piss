extends Control

class_name GameOver

## Authored failure treatment for an exhausted attempt.
##
## The level controller owns the FAILED state; this scene owns the presentation
## and retry affordance so the failure UI can evolve without coupling it to the
## stream or strike rules.

signal retry_pressed

const CURSOR_TEXTURE: Texture2D = preload(
	"res://assets/placeholders/cursor_pixel_pack/Tiles/tile_0026.png"
)

@export_range(0.1, 1.0, 0.05) var entry_duration := 0.35
@export_range(0.5, 1.0, 0.05) var entry_start_scale := 0.88
@export_range(0.0, 1.0, 0.05) var backdrop_opacity := 0.82
@export_range(0.0, 1.0, 0.05) var dread_opacity := 0.9
@export_range(0.0, 1.0, 0.05) var game_over_piss_opacity := 0.5

@onready var _backdrop: ColorRect = $Backdrop
@onready var _dread_frame: TextureRect = $DreadFrame
@onready var _presentation: Control = $Presentation
@onready var _game_over_piss: TextureRect = $Presentation/GameOverPiss
@onready var _retry_button: TextureButton = $Presentation/RetryButton
@onready var _failure_sound: AudioStreamPlayer = $FailureSound

var _entry_tween: Tween


func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_retry_button.pressed.connect(_on_retry_pressed)
	_backdrop.color.a = backdrop_opacity
	_dread_frame.modulate.a = dread_opacity
	_game_over_piss.modulate.a = game_over_piss_opacity
	visible = false


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func show_card() -> void:
	if _entry_tween:
		_entry_tween.kill()
	visible = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_presentation.pivot_offset = get_viewport_rect().size * 0.5
	_presentation.modulate.a = 0.0
	_presentation.scale = Vector2.ONE * entry_start_scale
	_failure_sound.play()
	_retry_button.grab_focus()
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
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_presentation.modulate = Color.WHITE
	_presentation.scale = Vector2.ONE


func is_showing() -> bool:
	return visible


func get_failure_sound() -> AudioStream:
	return _failure_sound.stream


func _on_retry_pressed() -> void:
	retry_pressed.emit()
