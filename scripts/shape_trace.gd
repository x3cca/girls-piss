extends Node2D

class_name ShapeTrace

const TRACE_TARGET_SCENE := preload("res://scenes/trace_target.tscn")

## An authored, ordered trace made from forgiving circular checkpoints.
## Points are stored in viewport-normalized coordinates so the same level content
## remains useful when the portrait viewport is resized.

signal trace_completed

@export var normalized_points := PackedVector2Array([
	Vector2(0.50, 0.34),
	Vector2(0.69, 0.43),
	Vector2(0.69, 0.62),
	Vector2(0.50, 0.72),
	Vector2(0.31, 0.62),
	Vector2(0.31, 0.43),
])
@export var closed_path := true
## Number of upcoming target sprites to keep visible. One means only the
## current checkpoint is shown as the target to hit.
@export_range(1, 8, 1) var checkpoint_look_ahead := 1
## The first checkpoint after the current one is shown at this opacity; each
## additional visible checkpoint halves that opacity again.
@export_range(0.0, 1.0, 0.05) var look_ahead_opacity := 0.25
@export_range(0.1, 1.0, 0.05) var look_ahead_opacity_falloff := 0.5
@export_range(0.01, 0.25, 0.005) var checkpoint_radius_fraction := 0.06
@export var outline_color := Color(0.83, 0.78, 0.38, 0.24)
@export var completed_color := Color(1.0, 0.91, 0.35, 0.92)
@export var checkpoint_color := Color(1.0, 0.93, 0.54, 0.34)
@export var completed_checkpoint_color := Color(1.0, 0.96, 0.68, 0.95)
@export var outline_width := 3.0
@export var completed_width := 6.0
@export var target_texture: Texture2D
@export var target_size := 48.0
@export var target_center_position := Vector2(-1.0, -1.0)

var completed_steps := 0
var total_steps: int:
	get:
		return normalized_points.size()

var _has_previous_endpoint := false
var _previous_endpoint := Vector2.ZERO
var _completion_emitted := false
var _targets: Array[TraceTarget] = []


func _ready() -> void:
	_sync_target_sprites()
	_update_target_visibility()
	queue_redraw()


func _process(_delta: float) -> void:
	_sync_target_sprites()
	var center := target_center_position
	if center.x < 0.0 or center.y < 0.0:
		center = get_viewport().get_visible_rect().get_center()
	for index in _targets.size():
		_targets[index].set_anchor_position(get_checkpoint_position(index))
		_targets[index].set_center_position(center)
	_update_target_visibility()


func reset_trace() -> void:
	_sync_target_sprites()
	completed_steps = 0
	_has_previous_endpoint = false
	_previous_endpoint = Vector2.ZERO
	_completion_emitted = false
	for target in _targets:
		target.reset_target()
	_update_target_visibility()
	queue_redraw()


func observe_drawing_point(position: Vector2, active: bool) -> void:
	## Observe the stream endpoint without requiring the endpoint to land exactly
	## on a checkpoint. Inactive frames intentionally break the segment so a new
	## stream cannot jump across the shape after a pause.
	_sync_target_sprites()
	if not active or normalized_points.is_empty() or completed_steps >= total_steps:
		_has_previous_endpoint = false
		return

	var checkpoint_position := get_checkpoint_position(completed_steps)
	var radius := get_checkpoint_radius()
	var reached := position.distance_to(checkpoint_position) <= radius
	if not reached and _has_previous_endpoint:
		reached = _segment_intersects_circle(
			_previous_endpoint,
			position,
			checkpoint_position,
			radius,
		)
	if reached:
		if completed_steps < _targets.size():
			_targets[completed_steps].trigger_hit(_get_target_center())
		completed_steps += 1
		if completed_steps >= total_steps and not _completion_emitted:
			_completion_emitted = true
			trace_completed.emit()
		_update_target_visibility()

	_previous_endpoint = position
	_has_previous_endpoint = true
	queue_redraw()


func get_checkpoint_position(index: int) -> Vector2:
	if normalized_points.is_empty():
		return Vector2.ZERO
	var point_index := clampi(index, 0, normalized_points.size() - 1)
	return normalized_to_viewport(normalized_points[point_index])


func get_checkpoint_radius() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return minf(viewport_size.x, viewport_size.y) * checkpoint_radius_fraction


func normalized_to_viewport(point: Vector2) -> Vector2:
	return point * get_viewport().get_visible_rect().size


func set_trace_visible(trace_visible: bool) -> void:
	visible = trace_visible


func _segment_intersects_circle(
		segment_start: Vector2,
		segment_end: Vector2,
		circle_center: Vector2,
		radius: float,
) -> bool:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return segment_start.distance_to(circle_center) <= radius
	var fraction := clampf(
		(circle_center - segment_start).dot(segment) / length_squared,
		0.0,
		1.0,
	)
	var closest := segment_start + segment * fraction
	return closest.distance_to(circle_center) <= radius


func _draw() -> void:
	var point_count := normalized_points.size()
	if point_count == 0:
		return

	var points := PackedVector2Array()
	for normalized_point in normalized_points:
		points.append(normalized_to_viewport(normalized_point))
	var segment_count := maxi(point_count - 1, 0)
	if closed_path:
		points.append(points[0])
		segment_count = point_count
	if point_count >= 2:
		draw_polyline(points, outline_color, outline_width, true)
		for segment_index in range(segment_count):
			var segment_completed := (
				segment_index < completed_steps - 1
				or (
					closed_path
					and completed_steps >= point_count
					and segment_index == point_count - 1
				)
			)
			if segment_completed:
				draw_line(
					points[segment_index],
					points[segment_index + 1],
					completed_color,
					completed_width,
					true,
				)

	var font := ThemeDB.fallback_font
	var viewport_size := get_viewport().get_visible_rect().size
	draw_string(
		font,
		Vector2(0.0, viewport_size.y * 0.16),
		"STEP %d / %d" % [completed_steps, point_count],
		HORIZONTAL_ALIGNMENT_CENTER,
		viewport_size.x,
		20,
		completed_color if completed_steps > 0 else outline_color.lightened(0.25),
	)


func _sync_target_sprites() -> void:
	if _targets.size() == normalized_points.size():
		return
	for target in _targets:
		if is_instance_valid(target):
			target.free()
	_targets.clear()
	for index in normalized_points.size():
		var target := TRACE_TARGET_SCENE.instantiate() as TraceTarget
		target.name = "TraceTarget%02d" % (index + 1)
		add_child(target)
		target.configure(
			normalized_to_viewport(normalized_points[index]),
			_get_target_center(),
			target_texture,
			target_size,
			float(index) * 0.91,
		)
		_targets.append(target)


func _update_target_visibility() -> void:
	var look_ahead := maxi(checkpoint_look_ahead, 1)
	var last_visible_index := mini(completed_steps + look_ahead - 1, _targets.size() - 1)
	for index in _targets.size():
		var target := _targets[index]
		if target.is_hit():
			# Let a completed target remain visible while it swirls into the bowl.
			continue
		var is_in_look_ahead := index >= completed_steps and index <= last_visible_index
		target.visible = is_in_look_ahead
		if not is_in_look_ahead:
			continue
		var steps_ahead := index - completed_steps
		var target_opacity := 1.0
		if steps_ahead > 0:
			target_opacity = look_ahead_opacity * pow(
				look_ahead_opacity_falloff,
				steps_ahead - 1,
			)
		var target_modulate := target.modulate
		target_modulate.a = target_opacity
		target.modulate = target_modulate


func _get_target_center() -> Vector2:
	if target_center_position.x >= 0.0 and target_center_position.y >= 0.0:
		return target_center_position
	return get_viewport().get_visible_rect().get_center()
