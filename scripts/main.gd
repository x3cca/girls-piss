extends Node2D
## Playable portrait-first sample level. All world positions are derived from the
## visible rectangle, so expand stretching and taller phone ratios stay usable.
## The stream source is deliberately below the frame: the player controls the
## jet, never a visible wand or nozzle.

@onready var input_controller: InputController = $InputController
@onready var pressure_model: PressureModel = $PressureModel
@onready var stream: LiquidStream = $LiquidStream
@onready var shape_trace: ShapeTrace = $ShapeTrace
@onready var line_recorder: PissLineRecorder = $PissLineRecorder
@onready var line_replay: PissLineReplay = $PissLineReplay
@onready var hud: StreamHUD = $HUDLayer/HUD

enum State { PLAYING, REPLAYING, COMPLETE }
const PLAYING := State.PLAYING
const REPLAYING := State.REPLAYING
const COMPLETE := State.COMPLETE

var state := PLAYING
var game_state := PLAYING
var targets: Array[WettableTarget] = []
@onready var _broad_light: PointLight2D = $BroadMoonLight
@onready var _impact_light: PointLight2D = $StreamImpactLight
var _world_size := Vector2(720.0, 1280.0)
var _layout_signature := Vector2.ZERO
var _elapsed := 0.0


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
	pressure_model.requested_pressure = input_controller.requested_pressure

	stream.input_controller = input_controller
	stream.pressure_model = pressure_model
	stream.wet_target_hit.connect(_on_wet_target_hit)
	stream.drawing_point_updated.connect(_on_drawing_point_updated)
	shape_trace.trace_completed.connect(_on_trace_completed)
	line_replay.replay_finished.connect(_on_replay_finished)
	_wire_hud()
	line_recorder.start_recording()
	_layout_world()
	queue_redraw()


func _process(_delta: float) -> void:
	if state == PLAYING:
		_elapsed += _delta
	_world_size = get_viewport().get_visible_rect().size
	if state == PLAYING:
		pressure_model.requested_pressure = input_controller.requested_pressure
	_layout_world()
	queue_redraw()


func _layout_world() -> void:
	if _world_size.x <= 1.0 or _world_size.y <= 1.0:
		return
	# The source stays just below the visible rectangle; only the jet enters frame.
	stream.source_position = Vector2(_world_size.x * 0.5, _world_size.y + 48.0)
	stream.minimum_length = minf(190.0, _world_size.y * 0.18)
	stream.maximum_length = minf(2200.0, _world_size.y * 1.72)
	stream.parcel_lifetime = 2.25
	input_controller.set_stream_geometry(
		stream.source_position,
		stream.minimum_length,
		stream.maximum_length,
		stream.launch_speed_min,
		stream.launch_speed_max,
		stream.gravity,
	)
	if _layout_signature != _world_size:
		_layout_signature = _world_size
		if _broad_light:
			_broad_light.position = Vector2(_world_size.x * 0.50, _world_size.y * 0.34)
		if _impact_light:
			_impact_light.position = stream.source_position


func _wire_hud() -> void:
	hud.input_controller = input_controller
	hud.pressure_model = pressure_model
	hud.stream = stream
	hud.target_nodes = targets
	hud.show_touch_controls = input_controller.touch_controls_visible
	hud.completion_card.play_again_pressed.connect(_on_play_again_pressed)


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
	_set_state(REPLAYING)
	line_recorder.finish_recording()
	input_controller.set_process_input(false)
	input_controller.set_process(false)
	pressure_model.set_process(false)
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
	_elapsed = 0.0
	shape_trace.reset_trace()
	shape_trace.set_trace_visible(true)
	line_replay.stop()
	line_recorder.start_recording()
	stream.reset_stream()
	stream.set_live_enabled(true)
	input_controller.reset_input()
	input_controller.set_process_input(true)
	input_controller.set_process(true)
	pressure_model.set_process(true)
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
