extends Node2D

class_name TitleComposition

## The title artwork is authored as transparent layers on a 1080x1920 canvas.
## Keeping the layers separate lets the first level remain visible underneath
## the title and leaves the small start animation easy to replace later.

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)

@export_range(0.05, 2.0, 0.05) var frame_duration := 0.5

var _frame := 0
var _frame_elapsed := 0.0
var _title_active := false
var _layout_signature := Vector2.ZERO

@onready var _start_frame_1: Node2D = $StartFrame1
@onready var _start_frame_2: Node2D = $StartFrame2


func _ready() -> void:
	_set_frame(0)
	_layout()
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	_layout()
	if not _title_active:
		return
	_frame_elapsed += maxf(delta, 0.0)
	if _frame_elapsed < frame_duration:
		return
	_frame_elapsed = fmod(_frame_elapsed, frame_duration)
	_set_frame(1 - _frame)


func show_title() -> void:
	_title_active = true
	_frame_elapsed = 0.0
	_set_frame(0)
	visible = true


func hide_title() -> void:
	_title_active = false
	visible = false


func is_title_active() -> bool:
	return _title_active


func get_frame() -> int:
	return _frame


func _set_frame(frame: int) -> void:
	_frame = posmod(frame, 2)
	if is_instance_valid(_start_frame_1):
		_start_frame_1.visible = _frame == 0
	if is_instance_valid(_start_frame_2):
		_start_frame_2.visible = _frame == 1


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if viewport_size == _layout_signature:
		return
	_layout_signature = viewport_size
	# Match the other Level 1 artwork: each transparent layer keeps its
	# authored position on the full portrait reference canvas.
	scale = Vector2(
		viewport_size.x / REFERENCE_SIZE.x,
		viewport_size.y / REFERENCE_SIZE.y,
	)
	position = Vector2.ZERO
