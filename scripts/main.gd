extends Node2D
## Playable portrait-first sample level. All world positions are derived from the
## visible rectangle, so expand stretching and taller phone ratios stay usable.
## The stream source is deliberately below the frame: the player controls the
## jet, never a visible wand or nozzle.

@onready var input_controller: InputController = $InputController
@onready var stream: LiquidStream = $LiquidStream
@onready var shape_trace: ShapeTrace = $ShapeTrace
@onready var line_recorder: PissLineRecorder = $PissLineRecorder
@onready var line_replay: PissLineReplay = $PissLineReplay
@onready var hud: StreamHUD = $HUDLayer/HUD
@onready var _hud_layer: CanvasLayer = $HUDLayer

enum State { PLAYING, REPLAYING, COMPLETE }
const PLAYING := State.PLAYING
const REPLAYING := State.REPLAYING
const COMPLETE := State.COMPLETE

var state := PLAYING
var game_state := PLAYING
var targets: Array[WettableTarget] = []
@onready var _broad_light: PointLight2D = $BroadMoonLight
@onready var _impact_light: PointLight2D = $StreamImpactLight
@export_range(0.0, 1.0, 0.01) var pulse_bloom_energy_punch := 0.18
@export_range(0.0, 1.0, 0.01) var pulse_bloom_scale_punch := 0.12
@export_range(0.05, 1.0, 0.01) var pulse_bloom_duration := 0.22
@export_range(0.0, 20.0, 0.1) var pulse_shake_strength := 2.5
@export_range(0.05, 0.5, 0.01) var pulse_shake_duration := 0.14
var _world_size := Vector2(720.0, 1280.0)
var _layout_signature := Vector2.ZERO
var _elapsed := 0.0
var _base_position := Vector2.ZERO
var _base_hud_offset := Vector2.ZERO
var _base_broad_light_energy := 0.0
var _base_broad_light_scale := 1.0
var _base_impact_light_energy := 0.0
var _base_impact_light_scale := 1.0
var _pulse_bloom_remaining := 0.0
var _pulse_bloom_amplitude := 0.0
var _pulse_shake_remaining := 0.0
var _pulse_shake_elapsed := 0.0
var _pulse_shake_amplitude := 0.0
var _pulse_shake_phase := 0.0


func _ready() -> void:
	# WettableTarget remains a reusable scene, but the tracing level has no soak
	# objectives or rectangular target plots.
	targets = []
	for child in get_children():
		if child is WettableTarget:
			child.visible = false
			var collision_body := child.get_node_or_null("CollisionBody") as CollisionObject2D
			if collision_body:
				collision_body.collision_layer = 0
	stream.input_controller = input_controller
	input_controller.set_target_position(shape_trace.get_checkpoint_position(0))
	stream.wet_target_hit.connect(_on_wet_target_hit)
	stream.drawing_point_updated.connect(_on_drawing_point_updated)
	stream.pulse_triggered.connect(_on_stream_pulse)
	shape_trace.trace_completed.connect(_on_trace_completed)
	line_replay.replay_finished.connect(_on_replay_finished)
	_wire_hud()
	line_recorder.start_recording()
	_base_position = position
	_base_hud_offset = _hud_layer.offset
	_base_broad_light_energy = _broad_light.energy
	_base_broad_light_scale = _broad_light.texture_scale
	_base_impact_light_energy = _impact_light.energy
	_base_impact_light_scale = _impact_light.texture_scale
	_layout_world()
	queue_redraw()


func _process(delta: float) -> void:
	_advance_pulse_feedback(delta)
	if state == PLAYING:
		_elapsed += delta
	_world_size = get_viewport().get_visible_rect().size
	if state == PLAYING:
		_layout_world()
	queue_redraw()


func _layout_world() -> void:
	if _world_size.x <= 1.0 or _world_size.y <= 1.0:
		return
	# The source stays just below the visible rectangle; only the jet enters frame.
	stream.source_position = Vector2(_world_size.x * 0.5, _world_size.y + 48.0)
	if _layout_signature != _world_size:
		_layout_signature = _world_size
		if _broad_light:
			_broad_light.position = Vector2(_world_size.x * 0.50, _world_size.y * 0.34)
		if _impact_light:
			_impact_light.position = stream.source_position


func _wire_hud() -> void:
	hud.input_controller = input_controller
	hud.stream = stream
	hud.target_nodes = targets
	hud.show_touch_controls = input_controller.touch_controls_visible
	hud.completion_card.play_again_pressed.connect(_on_play_again_pressed)


func _on_stream_pulse(amplitude: float) -> void:
	var safe_amplitude := clampf(amplitude, 0.0, 1.0)
	_pulse_bloom_remaining = maxf(_pulse_bloom_remaining, pulse_bloom_duration)
	_pulse_bloom_amplitude = maxf(_pulse_bloom_amplitude, safe_amplitude)
	_pulse_shake_remaining = maxf(_pulse_shake_remaining, pulse_shake_duration)
	_pulse_shake_elapsed = 0.0
	_pulse_shake_amplitude = maxf(_pulse_shake_amplitude, safe_amplitude)
	_pulse_shake_phase += 1.618


func _advance_pulse_feedback(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_pulse_bloom_remaining = move_toward(
		_pulse_bloom_remaining,
		0.0,
		safe_delta,
	)
	_pulse_shake_remaining = move_toward(
		_pulse_shake_remaining,
		0.0,
		safe_delta,
	)
	if _pulse_shake_remaining > 0.0:
		_pulse_shake_elapsed += safe_delta

	var bloom_progress := clampf(
		_pulse_bloom_remaining / maxf(pulse_bloom_duration, 0.001),
		0.0,
		1.0,
	)
	var bloom_envelope := smoothstep(0.0, 1.0, bloom_progress)
	var bloom_amount := bloom_envelope * _pulse_bloom_amplitude
	_broad_light.energy = _base_broad_light_energy * (
			1.0 + pulse_bloom_energy_punch * bloom_amount
	)
	_broad_light.texture_scale = _base_broad_light_scale * (
			1.0 + pulse_bloom_scale_punch * bloom_amount
	)
	_impact_light.energy = _base_impact_light_energy * (
			1.0 + pulse_bloom_energy_punch * 1.35 * bloom_amount
	)
	_impact_light.texture_scale = _base_impact_light_scale * (
			1.0 + pulse_bloom_scale_punch * 1.35 * bloom_amount
	)

	var shake_offset := Vector2.ZERO
	if _pulse_shake_remaining > 0.0:
		var shake_progress := clampf(
			_pulse_shake_remaining / maxf(pulse_shake_duration, 0.001),
			0.0,
			1.0,
		)
		var shake_envelope := smoothstep(0.0, 1.0, shake_progress)
		var shake_time := _pulse_shake_elapsed
		var jitter := Vector2(
			sin(shake_time * 78.0 + _pulse_shake_phase) * 0.75
			+ sin(shake_time * 131.0 + _pulse_shake_phase * 1.7) * 0.25,
			cos(shake_time * 91.0 + _pulse_shake_phase * 0.7) * 0.75
			+ cos(shake_time * 147.0 + _pulse_shake_phase * 1.3) * 0.25,
		)
		shake_offset = (
				jitter * pulse_shake_strength * _pulse_shake_amplitude * shake_envelope
		)
	position = _base_position + shake_offset
	_hud_layer.offset = _base_hud_offset + shake_offset

	if _pulse_bloom_remaining <= 0.0:
		_pulse_bloom_amplitude = 0.0
	if _pulse_shake_remaining <= 0.0:
		_pulse_shake_amplitude = 0.0


func _reset_pulse_feedback() -> void:
	_pulse_bloom_remaining = 0.0
	_pulse_bloom_amplitude = 0.0
	_pulse_shake_remaining = 0.0
	_pulse_shake_elapsed = 0.0
	_pulse_shake_amplitude = 0.0
	position = _base_position
	_hud_layer.offset = _base_hud_offset
	_broad_light.energy = _base_broad_light_energy
	_broad_light.texture_scale = _base_broad_light_scale
	_impact_light.energy = _base_impact_light_energy
	_impact_light.texture_scale = _base_impact_light_scale


func _on_drawing_point_updated(position: Vector2, active: bool) -> void:
	if state != PLAYING:
		return
	# Record before observing the shape: trace_completed is synchronous, so the
	# final endpoint must be part of the replay before the state changes.
	line_recorder.capture_point(position, active, _elapsed)
	shape_trace.observe_drawing_point(position, active)


func _on_trace_completed() -> void:
	if state != PLAYING:
		return
	_reset_pulse_feedback()
	_set_state(REPLAYING)
	line_recorder.finish_recording()
	input_controller.set_process_input(false)
	input_controller.set_process(false)
	stream.set_live_enabled(false)
	shape_trace.set_trace_visible(false)
	hud.set_gameplay_controls_visible(false)
	_impact_light.enabled = false
	line_replay.play(line_recorder.get_strokes())


func _on_replay_finished() -> void:
	if state != REPLAYING:
		return
	_set_state(COMPLETE)
	hud.show_completion_card()


func _on_play_again_pressed() -> void:
	reset_level()


func reset_level() -> void:
	_set_state(PLAYING)
	_reset_pulse_feedback()
	_elapsed = 0.0
	shape_trace.reset_trace()
	shape_trace.set_trace_visible(true)
	line_replay.stop()
	line_recorder.start_recording()
	stream.reset_stream()
	stream.set_live_enabled(true)
	input_controller.reset_input()
	input_controller.set_target_position(shape_trace.get_checkpoint_position(0))
	input_controller.set_process_input(true)
	input_controller.set_process(true)
	hud.hide_completion_card()
	hud.set_gameplay_controls_visible(true)
	_impact_light.enabled = true


func _set_state(next_state: int) -> void:
	state = next_state
	game_state = next_state


func _on_wet_target_hit(
		target: WettableTarget,
		amount: float,
		position: Vector2,
		normal: Vector2,
) -> void:
	if is_instance_valid(target):
		target.apply_liquid(amount, position)
		_impact_light.position = position + normal * 12.0


func _draw() -> void:
	# Low-contrast bands give the stream readable depth without painted textures.
	draw_rect(Rect2(Vector2.ZERO, _world_size), Color("#111a35"))
	for band in 8:
		var top := float(band) / 8.0 * _world_size.y
		var color := Color(0.08 + band * 0.006, 0.11 + band * 0.007, 0.22 + band * 0.012, 1.0)
		draw_rect(Rect2(0.0, top, _world_size.x, _world_size.y / 8.0 + 1.0), color)
	for i in 18:
		var x := fmod(float(i * 113 + 47), maxf(_world_size.x, 1.0))
		var y := fmod(float(i * 71 + 31), maxf(_world_size.y * 0.72, 1.0))
		draw_circle(Vector2(x, y), 1.5 if i % 3 else 2.5, Color(0.48, 0.66, 0.91, 0.20))
