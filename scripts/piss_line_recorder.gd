extends Node

class_name PissLineRecorder

## Stores the endpoint path as normalized points. The recorder deliberately has
## no drawing code: the live game remains unchanged until replay begins.

@export_range(0.01, 0.2, 0.005) var sample_interval := 1.0 / 30.0
@export var minimum_point_distance := 4.0
@export var inactive_gap := 0.12

var recording := false
var _strokes: Array = []
var _current_stroke: Array = []
var _has_sample := false
var _last_sample_elapsed := 0.0
var _last_active_elapsed := 0.0
var _was_active := false


func start_recording() -> void:
	recording = true
	_strokes.clear()
	_current_stroke = []
	_has_sample = false
	_last_sample_elapsed = 0.0
	_last_active_elapsed = 0.0
	_was_active = false


func capture_point(position: Vector2, active: bool, elapsed: float) -> void:
	if not recording:
		return
	if not active:
		_was_active = false
		return

	var starts_new_stroke := (
			_was_active == false
			and not _current_stroke.is_empty()
			and elapsed - _last_active_elapsed >= inactive_gap
	)
	if starts_new_stroke:
		_finish_current_stroke()
		_has_sample = false

	var viewport_size := get_viewport().get_visible_rect().size
	var normalized := _normalize_position(position, viewport_size)
	var enough_time := (
			not _has_sample
			or elapsed - _last_sample_elapsed >= sample_interval
	)
	var far_enough := (
			not _has_sample
			or _denormalize_position(normalized, viewport_size).distance_to(
				_denormalize_position(_current_stroke.back()["position"], viewport_size),
			) >= minimum_point_distance
	)
	if enough_time and far_enough:
		_current_stroke.append(
			{
				"position": normalized,
				"timestamp": elapsed,
				# The short alias is useful to callers that prefer time terminology.
				"time": elapsed,
			},
		)
		_has_sample = true
		_last_sample_elapsed = elapsed

	_last_active_elapsed = elapsed
	_was_active = true


func finish_recording() -> void:
	if not recording:
		return
	_finish_current_stroke()
	recording = false
	_was_active = false


func get_strokes() -> Array:
	var result: Array = []
	for stroke in _strokes:
		result.append(stroke.duplicate(true))
	if not _current_stroke.is_empty():
		result.append(_current_stroke.duplicate(true))
	return result


func normalize_position(position: Vector2) -> Vector2:
	return _normalize_position(position, get_viewport().get_visible_rect().size)


func denormalize_position(position: Vector2) -> Vector2:
	return _denormalize_position(position, get_viewport().get_visible_rect().size)


func _finish_current_stroke() -> void:
	if _current_stroke.is_empty():
		return
	_strokes.append(_current_stroke.duplicate(true))
	_current_stroke = []


func _normalize_position(position: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(
		position.x / maxf(viewport_size.x, 1.0),
		position.y / maxf(viewport_size.y, 1.0),
	)


func _denormalize_position(position: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(position.x * viewport_size.x, position.y * viewport_size.y)
