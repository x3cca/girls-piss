extends Node2D

class_name Main

## Playable portrait-first sample level. All world positions are derived from the
## visible rectangle, so expand stretching and taller phone ratios stay usable.
## The stream source is deliberately below the frame: the player controls the
## jet, never a visible wand or nozzle.

@onready var input_controller: InputController = $InputController
@onready var depth_map: DepthMap2D = $DepthMap
@onready var stream: LiquidStream = $LiquidStream
@onready var shape_trace: ShapeTrace = $ShapeTrace
@onready var line_recorder: PissLineRecorder = $PissLineRecorder
@onready var line_replay: PissLineReplay = $PissLineReplay
@onready var hud: StreamHUD = $HUDLayer/HUD
@onready var _hud_layer: CanvasLayer = $HUDLayer
@onready var title_screen: TitleScreen = $TitleLayer/TitleScreen
@onready var screen_overlay: ScreenOverlay = $ScreenOverlay

@export var skip_title_screen := false
@export var enable_negative_zones := true
@export var draw_neutral_canvas := true

enum State { PLAYING, REPLAYING, COMPLETE, FAILED }
const PLAYING := State.PLAYING
const REPLAYING := State.REPLAYING
const COMPLETE := State.COMPLETE
const FAILED := State.FAILED
const FAILURE := State.FAILED
const GAME_OVER := State.FAILED

const CONTACT_DURATION := 0.35
const SAFETY_COOLDOWN := 0.75
const MAX_STRIKES := 3

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
var gameplay_started := false
var initial_input_source := InputController.AimSource.KEYBOARD
@export_range(0.01, 2.0, 0.01) var negative_contact_duration := CONTACT_DURATION
@export_range(0.0, 3.0, 0.01) var safety_cooldown := SAFETY_COOLDOWN
@export_range(1, 9, 1) var max_strikes := MAX_STRIKES
var negative_zones: Array[NegativeZone] = []
var strike_count := 0
var _negative_contact_elapsed := 0.0
var _negative_contact_zone: NegativeZone
var _strike_cooldown_remaining := 0.0
var _frame_delta := 1.0 / 60.0
var _last_stream_endpoint := Vector2.ZERO
var _has_stream_endpoint := false

var strikes: int:
	get:
		return strike_count

var remaining_strikes: int:
	get:
		return maxi(max_strikes - strike_count, 0)


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
	stream.set_depth_map(depth_map)
	if enable_negative_zones:
		_collect_negative_zones()
	else:
		_disable_negative_zones()
	input_controller.set_target_position(shape_trace.get_checkpoint_position(0))
	stream.wet_target_hit.connect(_on_wet_target_hit)
	stream.drawing_point_updated.connect(_on_drawing_point_updated)
	stream.pulse_triggered.connect(_on_stream_pulse)
	input_controller.stream_hold_changed.connect(_on_stream_hold_changed)
	shape_trace.checkpoint_completed.connect(_on_checkpoint_completed)
	shape_trace.trace_completed.connect(_on_trace_completed)
	line_replay.replay_finished.connect(_on_replay_finished)
	_wire_hud()
	if not input_controller.input_detected.is_connected(_on_input_detected):
		input_controller.input_detected.connect(_on_input_detected)
	if not title_screen.transition_completed.is_connected(_on_title_transition_completed):
		title_screen.transition_completed.connect(_on_title_transition_completed)
	line_recorder.start_recording()
	_base_position = position
	_base_hud_offset = _hud_layer.offset
	_base_broad_light_energy = _broad_light.energy
	_base_broad_light_scale = _broad_light.texture_scale
	_base_impact_light_energy = _impact_light.energy
	_base_impact_light_scale = _impact_light.texture_scale
	_layout_world()
	hud.set_strikes(strike_count)
	_refresh_reticle_preview()
	if skip_title_screen:
		start_gameplay_immediately()
	else:
		input_controller.set_gameplay_input_enabled(false)
		hud.set_gameplay_controls_visible(false)
		title_screen.show_title()
	queue_redraw()


func _process(delta: float) -> void:
	_frame_delta = maxf(delta, 0.0)
	_strike_cooldown_remaining = move_toward(
		_strike_cooldown_remaining,
		0.0,
		_frame_delta,
	)
	_advance_pulse_feedback(delta)
	if state == PLAYING:
		_elapsed += delta
	_world_size = get_viewport().get_visible_rect().size
	if state == PLAYING:
		_layout_world()
		_refresh_reticle_preview()
	queue_redraw()


func _collect_negative_zones() -> void:
	negative_zones.clear()
	for node in get_tree().get_nodes_in_group("negative_zone"):
		if node is NegativeZone and not negative_zones.has(node):
			negative_zones.append(node)
	# This fallback keeps direct script-instantiated zones useful before they have
	# entered the scene tree group.
	for child in get_children():
		if child is NegativeZone and not negative_zones.has(child):
			negative_zones.append(child)


func _refresh_reticle_preview() -> void:
	if not is_instance_valid(hud) or not gameplay_started or state != PLAYING:
		return
	var preview_state := TouchReticle.ReticleState.NEUTRAL
	var aim_position := input_controller.get_target_position()
	# A positive target is the authoritative result if authored geometry overlaps.
	if not shape_trace.is_point_in_current_checkpoint(aim_position):
		if _negative_zone_at(aim_position) != null:
			preview_state = TouchReticle.ReticleState.NEGATIVE
	hud.set_aim_zone_state(preview_state)


func _layout_world() -> void:
	if _world_size.x <= 1.0 or _world_size.y <= 1.0:
		return
	# The source stays just below the visible rectangle; only the jet enters frame.
	stream.source_position = Vector2(_world_size.x * 0.5, _world_size.y + 48.0)
	depth_map.world_rect = Rect2(Vector2.ZERO, _world_size)
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
	if is_instance_valid(hud.piss_meter):
		hud.piss_meter.input_controller = input_controller
		hud.piss_meter.stream = stream
	hud.completion_card.play_again_pressed.connect(_on_play_again_pressed)
	if is_instance_valid(hud.piss_meter) and not hud.piss_meter.depleted.is_connected(
		_on_piss_meter_depleted,
	):
		hud.piss_meter.depleted.connect(_on_piss_meter_depleted)
	hud.set_gameplay_controls_visible(gameplay_started)


func _on_input_detected(source: int) -> void:
	if gameplay_started or not title_screen.is_active():
		return
	if title_screen.request_start(source):
		initial_input_source = source


func _on_title_transition_completed(source: int) -> void:
	initial_input_source = source
	_start_gameplay(initial_input_source)


func start_gameplay_immediately() -> void:
	## Programmatic bypass used by direct-level startup and scene tests.
	if title_screen.is_active():
		title_screen.skip_to_gameplay(InputController.AimSource.KEYBOARD)
	else:
		_start_gameplay(initial_input_source)


func _start_gameplay(source: int) -> void:
	if gameplay_started:
		return
	gameplay_started = true
	input_controller.reset_input()
	input_controller.set_target_position(shape_trace.get_checkpoint_position(0))
	input_controller.set_gameplay_input_enabled(true)
	input_controller.set_process_input(true)
	input_controller.set_process(true)
	hud.set_gameplay_controls_visible(true)
	hud.show_input_prompt(source)


func _on_stream_pulse(amplitude: float) -> void:
	var safe_amplitude := clampf(amplitude, 0.0, 1.0)
	_pulse_bloom_remaining = maxf(_pulse_bloom_remaining, pulse_bloom_duration)
	_pulse_bloom_amplitude = maxf(_pulse_bloom_amplitude, safe_amplitude)
	_pulse_shake_remaining = maxf(_pulse_shake_remaining, pulse_shake_duration)
	_pulse_shake_elapsed = 0.0
	_pulse_shake_amplitude = maxf(_pulse_shake_amplitude, safe_amplitude)
	_pulse_shake_phase += 1.618


func _advance_pulse_feedback(delta: float) -> void:
	# A first frame can be long while a scene/imported texture is settling. Keep
	# a pulse visible for at least one rendered frame instead of consuming the
	# entire shake envelope in a single hitch.
	var safe_delta := clampf(delta, 0.0, 1.0 / 30.0)
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
	# InputController can keep the visual stream alive after the first hold, but
	# contact timers and the recorder must still observe actual hold boundaries.
	var hold_active := active and input_controller.is_stream_input_held()
	# Record before observing the shape: trace_completed is synchronous, so the
	# final endpoint must be part of the replay before the state changes.
	line_recorder.capture_point(position, hold_active, _elapsed)
	evaluate_stream_endpoint(position, hold_active, _frame_delta)


func _on_stream_hold_changed(active: bool) -> void:
	if active:
		return
	# A release can be followed by a re-press before LiquidStream gets another
	# process tick. Reset contact synchronously so the two holds cannot merge.
	_reset_negative_contact()
	_has_stream_endpoint = false
	if state == PLAYING:
		shape_trace.observe_drawing_point(Vector2.ZERO, false, 0.0)
		stream.reset_stream()


func evaluate_stream_endpoint(
		position: Vector2,
		active: bool,
		delta := -1.0,
) -> void:
	## Evaluate the committed stream endpoint. The requested aim position is only
	## used by _refresh_reticle_preview; it cannot cause gameplay contact here.
	if state != PLAYING:
		return
	var contact_delta := _frame_delta if delta < 0.0 else maxf(delta, 0.0)
	_last_stream_endpoint = position
	_has_stream_endpoint = active
	var in_checkpoint := active and shape_trace.is_point_in_current_checkpoint(position)
	shape_trace.observe_drawing_point(position, active, contact_delta)
	if not active:
		_reset_negative_contact()
		return
	if in_checkpoint:
		# Positive contact takes precedence over negative geometry if an authored
		# level accidentally places the two regions on top of one another.
		_reset_negative_contact()
		return
	_observe_negative_contact(position, contact_delta)


func get_strikes() -> int:
	return strike_count


func get_remaining_strikes() -> int:
	return remaining_strikes


func get_negative_contact_elapsed() -> float:
	return _negative_contact_elapsed


func get_last_stream_endpoint() -> Vector2:
	return _last_stream_endpoint


func has_stream_endpoint() -> bool:
	return _has_stream_endpoint


func get_safety_cooldown_remaining() -> float:
	return _strike_cooldown_remaining


func is_attempt_failed() -> bool:
	return state == FAILED


func _observe_negative_contact(position: Vector2, delta: float) -> void:
	var zone := _negative_zone_at(position)
	if zone == null:
		_reset_negative_contact()
		return
	if _negative_contact_zone != zone:
		_negative_contact_zone = zone
		_negative_contact_elapsed = 0.0
	_negative_contact_elapsed += maxf(delta, 0.0)
	# The grace period blocks the strike, but it does not erase a contact that
	# is still being held. Once the grace period ends, an endpoint that remained
	# in the zone is immediately eligible for the next strike.
	if _strike_cooldown_remaining > 0.0:
		return
	if (
			_negative_contact_elapsed >= maxf(negative_contact_duration, 0.0)
	):
		_take_strike()


func _negative_zone_at(position: Vector2) -> NegativeZone:
	_collect_negative_zones_if_needed()
	for zone in negative_zones:
		if is_instance_valid(zone) and zone.contains_point(position):
			return zone
	return null


func _collect_negative_zones_if_needed() -> void:
	if not enable_negative_zones:
		return
	for node in get_tree().get_nodes_in_group("negative_zone"):
		if node is NegativeZone and not negative_zones.has(node):
			negative_zones.append(node)
	for child in get_children():
		if child is NegativeZone and not negative_zones.has(child):
			negative_zones.append(child)


func _disable_negative_zones() -> void:
	negative_zones.clear()
	for node in get_tree().get_nodes_in_group("negative_zone"):
		if node is NegativeZone:
			node.show_zone = false
			node.visible = false
			node.set_process(false)


func _reset_negative_contact() -> void:
	_negative_contact_elapsed = 0.0
	_negative_contact_zone = null


func _take_strike() -> void:
	if state != PLAYING or _strike_cooldown_remaining > 0.0:
		return
	strike_count = mini(strike_count + 1, max_strikes)
	_strike_cooldown_remaining = maxf(safety_cooldown, 0.0)
	_reset_negative_contact()
	hud.set_strikes(strike_count)
	if is_instance_valid(screen_overlay):
		screen_overlay.play_strike_feedback()
	stream.play_strike_flash()
	if strike_count >= max_strikes:
		_fail_attempt()


func _fail_attempt() -> void:
	if state != PLAYING:
		return
	_set_state(FAILED)
	_reset_pulse_feedback()
	line_recorder.finish_recording()
	line_replay.stop()
	input_controller.set_gameplay_input_enabled(false)
	input_controller.set_process_input(false)
	input_controller.set_process(false)
	stream.set_live_enabled(false)
	shape_trace.set_trace_visible(false)
	hud.set_aim_zone_state(TouchReticle.ReticleState.NEUTRAL)
	hud.show_failure_card()
	_impact_light.enabled = false


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


func _on_piss_meter_depleted() -> void:
	_fail_attempt()


func reset_level() -> void:
	_set_state(PLAYING)
	_reset_pulse_feedback()
	strike_count = 0
	_strike_cooldown_remaining = 0.0
	_reset_negative_contact()
	_has_stream_endpoint = false
	_last_stream_endpoint = Vector2.ZERO
	_elapsed = 0.0
	shape_trace.reset_trace()
	shape_trace.set_trace_visible(true)
	line_replay.stop()
	line_recorder.start_recording()
	stream.reset_stream()
	stream.set_live_enabled(true)
	hud.reset_piss_meter()
	input_controller.reset_input()
	input_controller.set_target_position(shape_trace.get_checkpoint_position(0))
	input_controller.set_gameplay_input_enabled(true)
	input_controller.set_process_input(true)
	input_controller.set_process(true)
	hud.hide_completion_card()
	hud.set_strikes(strike_count)
	hud.set_aim_zone_state(TouchReticle.ReticleState.NEUTRAL)
	hud.set_gameplay_controls_visible(true)
	_impact_light.enabled = true
	if is_instance_valid(screen_overlay):
		screen_overlay.stop_all_effects()


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


func _on_checkpoint_completed(_index: int) -> void:
	if state != PLAYING:
		return
	hud.play_success_burst()
	if is_instance_valid(screen_overlay):
		screen_overlay.play_success_feedback()


func _draw() -> void:
	# The depth texture supplies the optional visualization now; keep only the
	# neutral canvas and ambient specks here so gameplay never depends on debug
	# drawing.
	if not draw_neutral_canvas:
		return
	draw_rect(Rect2(Vector2.ZERO, _world_size), Color("#111a35"))
	for i in 18:
		var x := fmod(float(i * 113 + 47), maxf(_world_size.x, 1.0))
		var y := fmod(float(i * 71 + 31), maxf(_world_size.y * 0.72, 1.0))
		draw_circle(Vector2(x, y), 1.5 if i % 3 else 2.5, Color(0.48, 0.66, 0.91, 0.20))
