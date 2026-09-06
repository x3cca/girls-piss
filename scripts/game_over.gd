extends Control

class_name GameOver

## Authored failure treatment for an exhausted attempt.
##
## The level controller owns the FAILED state; this scene owns the presentation
## and retry affordance so the failure UI can evolve without coupling it to the
## stream or strike rules.

signal retry_pressed

const MESSAGE_BASE_SIZE := Vector2(320.0, 211.159)

@export_range(0.1, 1.0, 0.05) var entry_duration := 0.35
@export_range(0.5, 1.0, 0.05) var entry_start_scale := 0.88
@export_range(0.0, 1.0, 0.05) var backdrop_opacity := 0.82
@export_range(0.0, 1.0, 0.05) var dread_opacity := 0.9

@onready var _backdrop: ColorRect = $Backdrop
@onready var _dread_frame: TextureRect = $DreadFrame
@onready var _presentation: Control = $Presentation
@onready var _title: Label = $Presentation/GameOverTitle
@onready var _message: Control = $Presentation/EmergencyMessage
@onready var _fx_one: TextureRect = $Presentation/FXOne
@onready var _fx_two: TextureRect = $Presentation/FXTwo
@onready var _retry_button: Button = $Presentation/RetryButton
@onready var _failure_sound: AudioStreamPlayer = $FailureSound

var _entry_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_retry_button.pressed.connect(_on_retry_pressed)
	_backdrop.color.a = backdrop_opacity
	_dread_frame.modulate.a = dread_opacity
	visible = false
	_layout()


func _process(_delta: float) -> void:
	_layout()


func show_card() -> void:
	if _entry_tween:
		_entry_tween.kill()
	visible = true
	_layout()
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
	_presentation.modulate = Color.WHITE
	_presentation.scale = Vector2.ONE


func is_showing() -> bool:
	return visible


func get_message_texture() -> Texture2D:
	return $Presentation/EmergencyMessage/Bubble.texture


func get_failure_sound() -> AudioStream:
	return _failure_sound.stream


func _on_retry_pressed() -> void:
	retry_pressed.emit()


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var message_width := clampf(viewport_size.x * 0.9, 320.0, 520.0)
	var message_scale := message_width / MESSAGE_BASE_SIZE.x
	var message_height := MESSAGE_BASE_SIZE.y * message_scale
	var message_position := Vector2(
		(viewport_size.x - message_width) * 0.5,
		viewport_size.y * 0.2,
	)
	_message.position = message_position
	_message.scale = Vector2.ONE * message_scale

	_title.position = Vector2(0.0, maxf(message_position.y - 92.0, 28.0))
	_title.size = Vector2(viewport_size.x, 64.0)
	_retry_button.position = Vector2(
		(viewport_size.x - 240.0) * 0.5,
		message_position.y + message_height + 34.0,
	)
	_retry_button.size = Vector2(240.0, 58.0)

	_fx_one.position = message_position + Vector2(-12.0, 22.0)
	_fx_one.size = Vector2(92.0, 66.0)
	_fx_one.rotation = deg_to_rad(-12.0)
	_fx_two.position = message_position + Vector2(message_width - 64.0, message_height - 56.0)
	_fx_two.size = Vector2(72.0, 74.0)
	_fx_two.rotation = deg_to_rad(14.0)
