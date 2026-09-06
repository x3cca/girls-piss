extends Node2D

class_name TitleComposition

## The title artwork is authored as transparent layers on a 1080x1920 canvas.
## Keeping the layers separate lets the first level remain visible underneath
## the title and leaves the small start animation easy to replace later.

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)

@export_range(0.05, 2.0, 0.05) var frame_duration := 0.5
@export_range(0.0, 2.0, 0.05) var intro_delay := 0.35
@export_range(0.1, 2.0, 0.05) var background_entry_duration := 0.35
@export_range(0.0, 1.0, 0.05) var background_to_title_delay := 0.25
@export_range(0.1, 2.0, 0.05) var title_entry_duration := 0.35
@export_range(0.0, 1.0, 0.05) var start_entry_delay := 0.5
@export_range(0.1, 2.0, 0.05) var start_entry_duration := 0.25

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
	modulate.a = 1.0
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
	_center_start_frames_in_title_gap()


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
	for background_layer in [_title_flare_left, _title_flare_right, _title_flare_bottom]:
		_title_entry_tween.tween_property(
			background_layer,
			"modulate:a",
			1.0,
			entry_duration,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_title_entry_tween.finished.connect(_on_background_entry_finished.bind(intro_id))


func _on_background_entry_finished(intro_id: int) -> void:
	if not _title_active or intro_id != _intro_id:
		return
	_title_entry_tween = create_tween()
	_title_entry_tween.tween_interval(maxf(background_to_title_delay, 0.0))
	_title_entry_tween.finished.connect(_on_foreground_delay_finished.bind(intro_id))


func _on_foreground_delay_finished(intro_id: int) -> void:
	if not _title_active or intro_id != _intro_id:
		return
	var entry_duration := maxf(title_entry_duration, 0.01)
	_title_entry_tween = create_tween().set_parallel(true)
	for foreground_layer in [_girls_title, _piss_title]:
		_title_entry_tween.tween_property(
			foreground_layer,
			"modulate:a",
			1.0,
			entry_duration,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
		"modulate:a",
		1.0,
		entry_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_entry_tween.tween_property(
		_start_frame_2,
		"modulate:a",
		1.0,
		entry_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_entry_state() -> void:
	# Keep every title layer at its authored position. The transition is an
	# opacity change, which eases the eye in without making the composition feel
	# like a comic-book entrance.
	_title_flare_left.offset = Vector2.ZERO
	_title_flare_right.offset = Vector2.ZERO
	_title_flare_bottom.offset = Vector2.ZERO
	_title_flare_left.rotation = _title_flare_left_rest_rotation
	_title_flare_right.rotation = _title_flare_right_rest_rotation
	_title_flare_bottom.rotation = _title_flare_bottom_rest_rotation
	_girls_title.offset = Vector2.ZERO
	_piss_title.offset = Vector2.ZERO
	_girls_title.rotation = _girls_title_rest_rotation
	_piss_title.rotation = _piss_title_rest_rotation
	_start_frame_1.position = _start_frame_1_rest_position
	_start_frame_2.position = _start_frame_2_rest_position
	_title_flare_left.modulate.a = 0.0
	_title_flare_right.modulate.a = 0.0
	_title_flare_bottom.modulate.a = 0.0
	_girls_title.modulate.a = 0.0
	_piss_title.modulate.a = 0.0
	_start_frame_1.modulate.a = 0.0
	_start_frame_2.modulate.a = 0.0


func _center_start_frames_in_title_gap() -> void:
	var title_bounds := _sprite_vertical_bounds(_piss_title)
	var gap_center := (title_bounds.y + REFERENCE_SIZE.y) * 0.5
	var frame_1_bounds := _frame_vertical_bounds(_start_frame_1)
	var frame_2_bounds := _frame_vertical_bounds(_start_frame_2)
	_start_frame_1_rest_position = Vector2(
		_start_frame_1_rest_position.x,
		gap_center - (frame_1_bounds.x + frame_1_bounds.y) * 0.5,
	)
	_start_frame_2_rest_position = Vector2(
		_start_frame_2_rest_position.x,
		gap_center - (frame_2_bounds.x + frame_2_bounds.y) * 0.5,
	)
	_start_frame_1.position = _start_frame_1_rest_position
	_start_frame_2.position = _start_frame_2_rest_position


func _frame_vertical_bounds(frame: Node2D) -> Vector2:
	var top := INF
	var bottom := -INF
	for child in frame.get_children():
		if not child is Sprite2D:
			continue
		var bounds := _sprite_vertical_bounds(child as Sprite2D)
		top = minf(top, bounds.x)
		bottom = maxf(bottom, bounds.y)
	return Vector2(top, bottom)


func _sprite_vertical_bounds(sprite: Sprite2D) -> Vector2:
	if sprite.texture == null:
		return Vector2(sprite.position.y, sprite.position.y)
	var texture_size := sprite.texture.get_size() * sprite.scale.abs()
	var origin_y := sprite.position.y + sprite.offset.y
	if sprite.centered:
		origin_y -= texture_size.y * 0.5
	return Vector2(origin_y, origin_y + texture_size.y)


func _stop_intro_tweens() -> void:
	_intro_id += 1
	if _title_entry_tween:
		_title_entry_tween.kill()
	_title_entry_tween = null
	if _start_entry_tween:
		_start_entry_tween.kill()
	_start_entry_tween = null
