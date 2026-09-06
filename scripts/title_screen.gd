extends CanvasLayer

class_name TitleScreen

## A transparent title treatment that lets the first level remain visible behind
## it. Input is intentionally handled by InputController so the same title works
## with keyboard, mouse, touch, and controllers.

signal start_requested(source: int)
signal transition_completed(source: int)
signal start_completed(source: int)
signal exit_completed(source: int)

const DEFAULT_SOURCE := 0
const CURSOR_TEXTURE: Texture2D = preload(
	"res://assets/placeholders/cursor_pixel_pack/Tiles/tile_0026.png"
)

@export var autoplay := true
@export_range(0.1, 2.0, 0.05) var entry_duration := 0.75
@export_range(0.0, 2.0, 0.05) var title_entry_delay := 1.0
@export_range(0.0, 1.0, 0.05) var start_delay := 0.2
@export_range(0.1, 1.5, 0.05) var exit_duration := 0.5

@onready var _overlay: Control = $Overlay
@onready var _composition: TitleComposition = $Overlay/TitleComposition

var active := false
var start_locked := false
var _completed := false
var _start_source := DEFAULT_SOURCE
var _exit_tween: Tween


func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if autoplay:
		show_title()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func show_title() -> void:
	if not is_instance_valid(_overlay):
		return
	if _exit_tween:
		_exit_tween.kill()
	_completed = false
	active = true
	start_locked = false
	visible = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_composition.modulate.a = 1.0
	_composition.intro_delay = title_entry_delay
	_composition.title_entry_duration = entry_duration
	_composition.start_entry_delay = start_delay
	_composition.show_title()


func request_start(source: int) -> bool:
	if not active or start_locked:
		return false
	start_locked = true
	_start_source = source
	start_requested.emit(source)

	if _exit_tween:
		_exit_tween.kill()
	_exit_tween = create_tween()
	_exit_tween.tween_property(_composition, "modulate:a", 0.0, exit_duration).set_trans(
		Tween.TRANS_QUAD,
	).set_ease(Tween.EASE_IN)
	_exit_tween.finished.connect(_finish_transition)
	return true


func skip_to_gameplay(source := DEFAULT_SOURCE) -> bool:
	if _completed and not active:
		return false
	if _exit_tween:
		_exit_tween.kill()
	_start_source = source
	start_locked = false
	_finish_transition()
	return true


func is_active() -> bool:
	return active


func is_title_active() -> bool:
	return active


func is_start_locked() -> bool:
	return start_locked


func is_transitioning() -> bool:
	return active and start_locked


func get_start_source() -> int:
	return _start_source


func _finish_transition() -> void:
	if _completed:
		return
	_completed = true
	active = false
	start_locked = false
	_composition.hide_title()
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	transition_completed.emit(_start_source)
	start_completed.emit(_start_source)
	exit_completed.emit(_start_source)
