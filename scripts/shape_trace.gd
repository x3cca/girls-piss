extends Node2D

class_name ShapeTrace

const TRACE_TARGET_SCENE := preload("res://scenes/trace_target.tscn")

## An authored, ordered trace made from ordered sprite checkpoints.
## Points are stored in viewport-normalized coordinates so the same level content
## remains useful when the portrait viewport is resized.

signal trace_completed
signal checkpoint_completed(index: int)

@export var normalized_points := PackedVector2Array(
	[
		Vector2(0.50, 0.34),
		Vector2(0.69, 0.43),
		Vector2(0.69, 0.62),
		Vector2(0.50, 0.72),
		Vector2(0.31, 0.62),
		Vector2(0.31, 0.43),
	],
)
@export var closed_path := true
@export var show_outline := false
## Number of upcoming target sprites to keep visible. One means only the
## current checkpoint is shown as the target to hit.
@export_range(1, 8, 1) var checkpoint_look_ahead := 1
## The first checkpoint after the current one is shown at this opacity; each
## additional visible checkpoint halves that opacity again.
@export_range(0.0, 1.0, 0.05) var look_ahead_opacity := 0.25
@export_range(0.1, 1.0, 0.05) var look_ahead_opacity_falloff := 0.5
## Legacy size helper retained for authoring tools. Hit detection uses the
## configured target sprite's polygon mask and never falls back to this radius.
@export_range(0.01, 0.25, 0.005) var checkpoint_radius_fraction := 0.06
@export_range(0.01, 2.0, 0.01) var checkpoint_contact_duration := 0.35
@export var outline_color := Color(0.83, 0.78, 0.38, 0.24)
@export var completed_color := Color(1.0, 0.91, 0.35, 0.92)
@export var checkpoint_color := Color(1.0, 0.93, 0.54, 0.34)
@export var completed_checkpoint_color := Color(1.0, 0.96, 0.68, 0.95)
@export var outline_width := 3.0
@export var completed_width := 6.0
@export var target_texture: Texture2D
@export var target_textures: Array[Texture2D] = []
@export var target_size := 48.0
## Level artwork can keep each target's authored proportions while scaling the
## 1080px reference layout down to the live viewport.
@export var use_native_target_sizes := false
@export_range(0.05, 2.0, 0.01) var native_target_scale := 1.0
@export var target_center_position := Vector2(-1.0, -1.0)

var completed_steps := 0
var total_steps: int:
	get:
		return normalized_points.size()

var _has_previous_endpoint := false
var _previous_endpoint := Vector2.ZERO
var _completion_emitted := false
var _targets: Array[TraceTarget] = []
var _checkpoint_contact_elapsed := 0.0
var _contact_checkpoint := -1


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


func process_frame(delta: float) -> void:
	_process(delta)


func rebuild_targets() -> void:
	## Recreate the generated target nodes after a level assigns its art set.
	## This is also useful to tools that author a trace after the scene is ready.
	for target in _targets:
		if is_instance_valid(target):
			target.free()
	_targets.clear()
	_sync_target_sprites()
	_update_target_visibility()
	queue_redraw()


func reset_trace() -> void:
	_sync_target_sprites()
	completed_steps = 0
	_has_previous_endpoint = false
	_previous_endpoint = Vector2.ZERO
	_completion_emitted = false
	_reset_checkpoint_contact()
	for target in _targets:
		target.reset_target()
	_update_target_visibility()
	queue_redraw()


func observe_drawing_point(
		position: Vector2,
		active: bool,
		contact_delta := -1.0,
) -> void:
	## Observe the stream endpoint without requiring the endpoint to land exactly
	## on a checkpoint. Gameplay passes a non-negative delta and requires sustained
	## contact. A negative delta retains the original immediate observation mode for
	## tools and older direct callers that do not simulate time.
	_sync_target_sprites()
	if not active or normalized_points.is_empty() or completed_steps >= total_steps:
		_has_previous_endpoint = false
		_reset_checkpoint_contact()
		return

	if contact_delta >= 0.0:
		_observe_sustained_contact(position, contact_delta)
		_previous_endpoint = position
		_has_previous_endpoint = true
		queue_redraw()
		return

	# Legacy immediate mode also keeps exact sprite segment crossing useful for
	# editor tools.
	var target := _current_target()
	var reached := _target_contains_point(target, position)
	if not reached and _has_previous_endpoint:
		reached = _target_intersects_segment(target, _previous_endpoint, position)
	if reached:
		complete_current_checkpoint()

	_previous_endpoint = position
	_has_previous_endpoint = true
	queue_redraw()


func is_point_in_current_checkpoint(position: Vector2) -> bool:
	if normalized_points.is_empty() or completed_steps >= total_steps:
		return false
	return _target_contains_point(_current_target(), position)


func get_checkpoint_contact_elapsed() -> float:
	return _checkpoint_contact_elapsed


func get_checkpoint_contact_progress() -> float:
	return clampf(
		_checkpoint_contact_elapsed / maxf(checkpoint_contact_duration, 0.001),
		0.0,
		1.0,
	)


func complete_current_checkpoint() -> bool:
	if normalized_points.is_empty() or completed_steps >= total_steps:
		return false
	var completed_index := completed_steps
	if completed_index < _targets.size():
		_targets[completed_index].trigger_hit(_get_target_center())
	completed_steps += 1
	_reset_checkpoint_contact()
	checkpoint_completed.emit(completed_index)
	if completed_steps >= total_steps and not _completion_emitted:
		_completion_emitted = true
		trace_completed.emit()
	_update_target_visibility()
	return true


func _observe_sustained_contact(position: Vector2, delta: float) -> void:
	if not is_point_in_current_checkpoint(position):
		_reset_checkpoint_contact()
		return
	var target := _current_target()
	if not is_instance_valid(target):
		_reset_checkpoint_contact()
		return
	if _contact_checkpoint != completed_steps:
		_contact_checkpoint = completed_steps
		_checkpoint_contact_elapsed = 0.0
	var safe_delta := maxf(delta, 0.0)
	_checkpoint_contact_elapsed += safe_delta
	if target.apply_contact(safe_delta):
		complete_current_checkpoint()


func _reset_checkpoint_contact() -> void:
	_checkpoint_contact_elapsed = 0.0
	_contact_checkpoint = -1


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


func _current_target() -> TraceTarget:
	if completed_steps < 0 or completed_steps >= _targets.size():
		return null
	return _targets[completed_steps]


func _target_contains_point(
		target: TraceTarget,
		position: Vector2,
) -> bool:
	return is_instance_valid(target) and target.contains_point(position)


func _target_intersects_segment(
		target: TraceTarget,
		segment_start: Vector2,
		segment_end: Vector2,
) -> bool:
	return (
		is_instance_valid(target)
		and target.intersects_segment(segment_start, segment_end)
	)


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
	if show_outline and point_count >= 2:
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
		var texture := target_texture
		if index < target_textures.size() and target_textures[index] != null:
			texture = target_textures[index]
		if texture == null:
			# Keep direct/tool-created ShapeTrace nodes on the same exact sprite
			# polygon-mask path as scene-authored targets.
			var default_sprite := target.get_node_or_null("Sprite") as Sprite2D
			texture = default_sprite.texture if default_sprite else null
		add_child(target)
		target.configure(
			normalized_to_viewport(normalized_points[index]),
			_get_target_center(),
			texture,
			_get_target_size(texture),
			float(index) * 0.91,
		)
		target.configure_contact_duration(checkpoint_contact_duration, true)
		_targets.append(target)


func _get_target_size(texture: Texture2D) -> float:
	if not use_native_target_sizes or texture == null:
		return target_size
	var viewport_width := get_viewport().get_visible_rect().size.x
	var reference_scale := viewport_width / 1080.0
	return float(texture.get_width()) * native_target_scale * reference_scale


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
