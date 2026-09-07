extends Node2D

class_name TitleComposition

## The title artwork is authored as transparent layers on a 1080x1920 canvas.
## Keeping the layers separate lets the first level remain visible underneath
## the title and leaves the small start animation easy to replace later.

signal start_flash_completed

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)

@export_range(0.05, 2.0, 0.05) var frame_duration := 0.5
@export_range(0.0, 2.0, 0.05) var intro_delay := 0.35
@export_range(0.1, 2.0, 0.05) var background_entry_duration := 0.35
@export_range(0.0, 1.0, 0.05) var background_to_title_delay := 0.25
@export_range(0.1, 2.0, 0.05) var title_entry_duration := 0.35
@export_range(0.0, 1.0, 0.05) var start_entry_delay := 0.5
@export_range(0.1, 2.0, 0.05) var start_entry_duration := 0.25
@export_range(0.01, 0.25, 0.01) var start_flash_duration := 0.03
@export_range(0.0, 1.0, 0.01) var start_flash_pause := 0.12
@export_range(1, 6, 1) var start_flash_count := 3
@export_range(0.0, 12.0, 0.5) var title_wobble_distance := 6.0
@export_range(0.0, 5.0, 0.1) var title_wobble_angle_degrees := 2.0
@export_range(0.0, 4.0, 0.05) var title_wobble_speed := 0.8

var _frame := 0
var _frame_elapsed := 0.0
var _title_active := false
var _layout_signature := Vector2.ZERO
var _intro_id := 0
var _title_entry_tween: Tween
var _start_entry_tween: Tween
var _start_flash_tween: Tween
var _start_flash_active := false
var _wobble_elapsed := 0.0
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
	_wobble_elapsed += maxf(delta, 0.0)
	_apply_title_wobble()
	if _start_flash_active:
		return
	_frame_elapsed += maxf(delta, 0.0)
	if _frame_elapsed < frame_duration:
		return
	_frame_elapsed = fmod(_frame_elapsed, frame_duration)
	_set_frame(1 - _frame)


func show_title() -> void:
	_stop_intro_tweens()
	_stop_start_flash()
	_title_active = true
	_frame_elapsed = 0.0
	_set_frame(0)
	_reset_entry_state()
	modulate.a = 1.0
	visible = true
	_start_intro()


func hide_title() -> void:
	_stop_intro_tweens()
	_stop_start_flash()
	_title_active = false
	visible = false


func is_title_active() -> bool:
	return _title_active


func get_frame() -> int:
	return _frame


func play_start_flash() -> bool:
	if not _title_active:
		return false
	_stop_intro_tweens()
	_stop_start_flash()
	_start_flash_active = true
	# The player can start before the title's normal entrance has reached the
	# start art. Make the feedback visible immediately in that case.
	_start_frame_1.modulate.a = 1.0
	_start_frame_2.modulate.a = 1.0

	_start_flash_tween = create_tween()
	var flash_duration := maxf(start_flash_duration, 0.01)
	for flash_index in range(maxi(start_flash_count, 1)):
		_start_flash_tween.tween_property(
			_start_frame_1,
			"modulate:a",
			0.0,
			flash_duration,
		)
		_start_flash_tween.parallel().tween_property(
			_start_frame_2,
			"modulate:a",
			0.0,
			flash_duration,
		)
		_start_flash_tween.tween_property(
			_start_frame_1,
			"modulate:a",
			1.0,
			flash_duration,
		)
		_start_flash_tween.parallel().tween_property(
			_start_frame_2,
			"modulate:a",
			1.0,
			flash_duration,
		)
	_start_flash_tween.tween_interval(maxf(start_flash_pause, 0.0))
	_start_flash_tween.finished.connect(_on_start_flash_finished)
	return true


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


func _on_start_flash_finished() -> void:
	_start_flash_tween = null
	_start_flash_active = false
	_start_frame_1.modulate.a = 1.0
	_start_frame_2.modulate.a = 1.0
	if _title_active:
		start_flash_completed.emit()


func _reset_entry_state() -> void:
	# Reset every title layer before the opacity-only entrance transition. The
	# ongoing wobble is applied separately once the title is active.
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
	_wobble_elapsed = 0.0
	_title_flare_left.modulate.a = 0.0
	_title_flare_right.modulate.a = 0.0
	_title_flare_bottom.modulate.a = 0.0
	_girls_title.modulate.a = 0.0
	_piss_title.modulate.a = 0.0
	_start_frame_1.modulate.a = 0.0
	_start_frame_2.modulate.a = 0.0


func _apply_title_wobble() -> void:
	var time := _wobble_elapsed * title_wobble_speed
	var angle := deg_to_rad(title_wobble_angle_degrees)
	_apply_sprite_wobble(_title_flare_left, time, 0.0, 0.8)
	_apply_sprite_wobble(_title_flare_right, time, 1.7, 0.9)
	_apply_sprite_wobble(_title_flare_bottom, time, 3.1, 0.7)
	_apply_sprite_wobble(_girls_title, time, 0.8, 1.0)
	_apply_sprite_wobble(_piss_title, time, 2.4, 1.1)
	_start_frame_1.position = _start_frame_1_rest_position + Vector2(
		sin(time * 0.9 + 1.2) * title_wobble_distance * 0.35,
		cos(time * 0.8 + 0.4) * title_wobble_distance * 0.25,
	)
	_start_frame_2.position = _start_frame_2_rest_position + Vector2(
		sin(time * 0.9 + 2.0) * title_wobble_distance * 0.35,
		cos(time * 0.8 + 1.1) * title_wobble_distance * 0.25,
	)

	_title_flare_left.rotation = _title_flare_left_rest_rotation + sin(time * 0.85) * angle * 0.7
	_title_flare_right.rotation = _title_flare_right_rest_rotation + sin(time * 0.9 + 1.7) * angle * 0.7
	_title_flare_bottom.rotation = _title_flare_bottom_rest_rotation + sin(time * 0.7 + 3.1) * angle * 0.7


func _apply_sprite_wobble(sprite: Sprite2D, time: float, phase: float, amplitude: float) -> void:
	sprite.offset = Vector2(
		sin(time * (0.85 + amplitude * 0.05) + phase) * title_wobble_distance * amplitude,
		cos(time * (0.7 + amplitude * 0.04) + phase * 1.23) * title_wobble_distance * amplitude * 0.6,
	)
	sprite.rotation = sin(time * (0.8 + amplitude * 0.04) + phase) * deg_to_rad(
		title_wobble_angle_degrees * amplitude,
	)


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


func _stop_start_flash() -> void:
	if _start_flash_tween:
		_start_flash_tween.kill()
	_start_flash_tween = null
	_start_flash_active = false
