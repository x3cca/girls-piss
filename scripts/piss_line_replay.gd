extends Node2D

class_name PissLineReplay

signal replay_finished

@export_range(1.0, 30.0, 0.5) var replay_duration := 10.0
@export_range(1.0, 10.0, 0.1) var max_speed_multiplier := 3.0
@export var line_color := Color(1.0, 0.88, 0.34, 0.95)
@export var line_width := 7.0

var playing := false
var playback_time := 0.0
var revealed_strokes: Array = []

var _strokes: Array = []
var _start_timestamp := 0.0
var _final_timestamp := 0.0
var _playback_rate := 1.0
var _playback_duration := 0.0
var _finished_emitted := false


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if not playing:
		return
	playback_time += delta * _playback_rate
	if playback_time >= _final_timestamp:
		playback_time = _final_timestamp
		_update_revealed_strokes()
		playing = false
		_finished_emitted = true
		queue_redraw()
		replay_finished.emit()
		return
	_update_revealed_strokes()
	queue_redraw()


func process_frame(delta: float) -> void:
	_process(delta)


func play(strokes: Array) -> void:
	_strokes = strokes.duplicate(true)
	revealed_strokes = []
	_final_timestamp = _find_final_timestamp(_strokes)
	_start_timestamp = _find_first_timestamp(_strokes)
	var source_duration := maxf(_final_timestamp - _start_timestamp, 0.0)
	_playback_rate = minf(
		source_duration / maxf(replay_duration, 0.001),
		maxf(max_speed_multiplier, 0.001),
	)
	_playback_duration = source_duration / maxf(_playback_rate, 0.001)
	playback_time = _start_timestamp
	_finished_emitted = false
	visible = true
	_update_revealed_strokes()
	if _strokes.is_empty() or _final_timestamp <= _start_timestamp:
		playing = false
		_finished_emitted = true
		queue_redraw()
		replay_finished.emit()
		return
	playing = true
	queue_redraw()


func stop() -> void:
	playing = false
	visible = false
	_strokes.clear()
	revealed_strokes.clear()
	playback_time = 0.0
	_start_timestamp = 0.0
	_final_timestamp = 0.0
	_playback_rate = 1.0
	_playback_duration = 0.0
	_finished_emitted = false
	queue_redraw()


func is_replaying() -> bool:
	return playing


func get_duration() -> float:
	return _playback_duration


func _find_final_timestamp(strokes: Array) -> float:
	var final_timestamp := 0.0
	for stroke in strokes:
		for point in stroke:
			final_timestamp = maxf(final_timestamp, _point_timestamp(point))
	return final_timestamp


func _find_first_timestamp(strokes: Array) -> float:
	var first_timestamp := INF
	for stroke in strokes:
		for point in stroke:
			first_timestamp = minf(first_timestamp, _point_timestamp(point))
	return 0.0 if first_timestamp == INF else first_timestamp


func _update_revealed_strokes() -> void:
	revealed_strokes = []
	for stroke in _strokes:
		var prefix: Array = _prefix_for_stroke(stroke, playback_time)
		if not prefix.is_empty():
			revealed_strokes.append(prefix)


func _prefix_for_stroke(stroke: Array, time: float) -> Array:
	var prefix: Array = []
	if stroke.is_empty():
		return prefix
	for index in stroke.size():
		var point: Dictionary = stroke[index]
		var timestamp := _point_timestamp(point)
		if timestamp <= time:
			prefix.append(point.duplicate(true))
			continue
		if index > 0:
			var previous: Dictionary = stroke[index - 1]
			var previous_time := _point_timestamp(previous)
			if time <= previous_time:
				break
			var fraction := inverse_lerp(previous_time, timestamp, time)
			var previous_position: Vector2 = previous["position"]
			var current_position: Vector2 = point["position"]
			prefix.append(
				{
					"position": previous_position.lerp(
						current_position,
						clampf(fraction, 0.0, 1.0),
					),
					"timestamp": time,
					"time": time,
				},
			)
		break
	return prefix


func _point_timestamp(point: Dictionary) -> float:
	if point.has("timestamp"):
		return float(point["timestamp"])
	if point.has("time"):
		return float(point["time"])
	return 0.0


func _draw() -> void:
	if not visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	for stroke in revealed_strokes:
		var points := PackedVector2Array()
		for point in stroke:
			var normalized: Vector2 = point["position"]
			points.append(normalized * viewport_size)
		if points.size() >= 2:
			draw_polyline(points, line_color, line_width, true)
		elif points.size() == 1:
			draw_circle(points[0], line_width * 0.5, line_color)
