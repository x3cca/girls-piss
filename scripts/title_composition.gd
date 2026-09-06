extends Node2D

class_name TitleComposition

## The title artwork is authored as transparent layers on a 1080x1920 canvas.
## Keeping the layers separate lets the first level remain visible underneath
## the title and leaves the small start animation easy to replace later.

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)
const ENTRY_MARGIN := 192.0
const START_ENTRY_OFFSET := 1024.0

@export_range(0.05, 2.0, 0.05) var frame_duration := 0.5
@export_range(0.0, 2.0, 0.05) var intro_delay := 1.0
@export_range(0.1, 2.0, 0.05) var background_entry_duration := 0.85
@export_range(0.0, 1.0, 0.05) var background_entry_stagger := 0.1
@export_range(0.1, 2.0, 0.05) var title_entry_duration := 0.75
@export_range(0.0, 1.0, 0.05) var title_entry_stagger := 0.12
@export_range(0.0, 1.0, 0.05) var start_entry_delay := 0.2
@export_range(0.1, 2.0, 0.05) var start_entry_duration := 0.65

var _frame := 0
var _frame_elapsed := 0.0
var _title_active := false
var _layout_signature := Vector2.ZERO
var _intro_id := 0
var _title_entry_tween: Tween
var _start_entry_tween: Tween
var _start_frame_1_rest_position := Vector2.ZERO
var _start_frame_2_rest_position := Vector2.ZERO
var _title_flare_left_rest_rotation := 0.0
var _title_flare_right_rest_rotation := 0.0
var _title_flare_bottom_rest_rotation := 0.0
var _girls_title_rest_rotation := 0.0
var _piss_title_rest_rotation := 0.0

@onready var _start_frame_1: Node2D = $StartFrame1
@onready var _start_frame_2: Node2D = $StartFrame2
@onready var _title_flare_left: Sprite2D = $TitleFlareLeft
@onready var _title_flare_right: Sprite2D = $TitleFlareRight
@onready var _title_flare_bottom: Sprite2D = $TitleFlare3
@onready var _girls_title: Sprite2D = $GirlsTitle
@onready var _piss_title: Sprite2D = $PissTitle


func _ready() -> void:
	_start_frame_1_rest_position = _start_frame_1.position
	_start_frame_2_rest_position = _start_frame_2.position
	_title_flare_left_rest_rotation = _title_flare_left.rotation
	_title_flare_right_rest_rotation = _title_flare_right.rotation
	_title_flare_bottom_rest_rotation = _title_flare_bottom.rotation
	_girls_title_rest_rotation = _girls_title.rotation
	_piss_title_rest_rotation = _piss_title.rotation
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
	_stop_intro_tweens()
	_title_active = true
	_frame_elapsed = 0.0
	_set_frame(0)
	_reset_entry_state()
	visible = true
	_start_intro()


func hide_title() -> void:
	_stop_intro_tweens()
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


func _start_intro() -> void:
	_intro_id += 1
	var intro_id := _intro_id
	var delay_tween := create_tween()
	delay_tween.tween_interval(intro_delay)
	delay_tween.finished.connect(_on_intro_delay_finished.bind(intro_id))
	_title_entry_tween = delay_tween


func _on_intro_delay_finished(intro_id: int) -> void:
	if not _title_active or intro_id != _intro_id:
		return
	var entry_duration := maxf(background_entry_duration, 0.01)
	_title_entry_tween = create_tween().set_parallel(true)
	_title_entry_tween.tween_property(
		_title_flare_left,
		"offset",
		Vector2.ZERO,
		entry_duration,
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_title_entry_tween.tween_property(
		_title_flare_left,
		"rotation",
		_title_flare_left_rest_rotation,
		entry_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_title_entry_tween.tween_property(
		_title_flare_right,
		"offset",
		Vector2.ZERO,
		entry_duration,
	).set_delay(title_entry_stagger * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(
		Tween.EASE_OUT,
	)
	_title_entry_tween.tween_property(
		_title_flare_right,
		"rotation",
		_title_flare_right_rest_rotation,
		entry_duration,
	).set_delay(background_entry_stagger).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT,
	)
	_title_entry_tween.tween_property(
		_title_flare_bottom,
		"offset",
		Vector2.ZERO,
		entry_duration,
	).set_delay(title_entry_stagger).set_trans(Tween.TRANS_BOUNCE).set_ease(
		Tween.EASE_OUT,
	)
	_title_entry_tween.tween_property(
		_title_flare_bottom,
		"rotation",
		_title_flare_bottom_rest_rotation,
		entry_duration,
	).set_delay(background_entry_stagger * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT,
	)
	_title_entry_tween.finished.connect(_on_background_entry_finished.bind(intro_id))


func _on_background_entry_finished(intro_id: int) -> void:
	if not _title_active or intro_id != _intro_id:
		return
	var entry_duration := maxf(title_entry_duration, 0.01)
	_title_entry_tween = create_tween().set_parallel(true)
	_title_entry_tween.tween_property(
		_girls_title,
		"offset",
		Vector2.ZERO,
		entry_duration,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title_entry_tween.tween_property(
		_girls_title,
		"rotation",
		_girls_title_rest_rotation,
		entry_duration,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title_entry_tween.tween_property(
		_piss_title,
		"offset",
		Vector2.ZERO,
		entry_duration,
	).set_delay(title_entry_stagger).set_trans(Tween.TRANS_BOUNCE).set_ease(
		Tween.EASE_OUT,
	)
	_title_entry_tween.tween_property(
		_piss_title,
		"rotation",
		_piss_title_rest_rotation,
		entry_duration,
	).set_delay(title_entry_stagger).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT,
	)
	_title_entry_tween.finished.connect(_on_title_entry_finished.bind(intro_id))


func _on_title_entry_finished(intro_id: int) -> void:
	if not _title_active or intro_id != _intro_id:
		return
	var delay_tween := create_tween()
	delay_tween.tween_interval(start_entry_delay)
	delay_tween.finished.connect(_on_start_entry_delay_finished.bind(intro_id))
	_start_entry_tween = delay_tween


func _on_start_entry_delay_finished(intro_id: int) -> void:
	if not _title_active or intro_id != _intro_id:
		return
	var entry_duration := maxf(start_entry_duration, 0.01)
	_start_entry_tween = create_tween().set_parallel(true)
	_start_entry_tween.tween_property(
		_start_frame_1,
		"position",
		_start_frame_1_rest_position,
		entry_duration,
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_start_entry_tween.tween_property(
		_start_frame_2,
		"position",
		_start_frame_2_rest_position,
		entry_duration,
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _reset_entry_state() -> void:
	# Offset animates the artwork while preserving the authored sprite positions.
	# This keeps the 1080x1920 composition stable across viewport resizes.
	_title_flare_left.rotation = _title_flare_left_rest_rotation + TAU * 1.15 - 0.35
	_title_flare_right.rotation = _title_flare_right_rest_rotation - TAU * 0.95 + 0.45
	_title_flare_bottom.rotation = _title_flare_bottom_rest_rotation + TAU * 1.35 - 0.25
	_set_offscreen_offset(_title_flare_left, Vector2.LEFT)
	_set_offscreen_offset(_title_flare_right, Vector2.RIGHT)
	_set_offscreen_offset(_title_flare_bottom, Vector2.DOWN)
	_girls_title.rotation = _girls_title_rest_rotation - 0.08
	_piss_title.rotation = _piss_title_rest_rotation + 0.1
	_set_offscreen_offset(_girls_title, Vector2.LEFT)
	_set_offscreen_offset(_piss_title, Vector2.RIGHT)
	# The two title layers arrive from opposite sides before the start prompt
	# rises into its authored position from below the reference canvas.
	_start_frame_1.position = _start_frame_1_rest_position + Vector2(0.0, START_ENTRY_OFFSET)
	_start_frame_2.position = _start_frame_2_rest_position + Vector2(0.0, START_ENTRY_OFFSET)


func _set_offscreen_offset(sprite: Sprite2D, direction: Vector2) -> void:
	# Offset is local to the rotated sprite. Aim the offset in screen space so
	# even a spinning layer's furthest corner stays outside the viewport.
	var texture_radius := Vector2(sprite.texture.get_size()).length()
	var distance := 0.0
	if direction.x < -0.5:
		distance = sprite.position.x + texture_radius + ENTRY_MARGIN
	elif direction.x > 0.5:
		distance = REFERENCE_SIZE.x - sprite.position.x + texture_radius + ENTRY_MARGIN
	else:
		distance = REFERENCE_SIZE.y - sprite.position.y + texture_radius + ENTRY_MARGIN
	sprite.offset = (direction.normalized() * distance).rotated(-sprite.rotation)


func _stop_intro_tweens() -> void:
	_intro_id += 1
	if _title_entry_tween:
		_title_entry_tween.kill()
	_title_entry_tween = null
	if _start_entry_tween:
		_start_entry_tween.kill()
	_start_entry_tween = null
