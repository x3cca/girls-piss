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
@onready var piss_toilet: PissToilet = get_node_or_null("PissToilet") as PissToilet
@onready var line_recorder: PissLineRecorder = $PissLineRecorder
@onready var line_replay: PissLineReplay = $PissLineReplay
@onready var hud: StreamHUD = $HUDLayer/HUD
@onready var _hud_layer: CanvasLayer = $HUDLayer
@onready var title_screen: TitleScreen = $TitleLayer/TitleScreen
@onready var music_controller: MusicController = $MusicController
@onready var _spray_sound: AudioStreamPlayer = $SpraySound
@onready var screen_overlay: ScreenOverlay = $ScreenOverlay
@onready var _ambient: CanvasModulate = $Ambient
@onready var surface_effects: SurfaceEffects = get_node_or_null("SurfaceEffects") as SurfaceEffects
@onready var level_1_chrome: Level1Chrome = get_node_or_null("Level1Chrome") as Level1Chrome

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
const DEBUG_INSTANT_STRIKE_ACTION := &"debug_instant_strike"
const DEBUG_INSTANT_WIN_ACTION := &"debug_instant_win"

const CONTACT_DURATION := 0.0
const SAFETY_COOLDOWN := 4.0
const MAX_STRIKES := 4
const SPRAY_SILENT_VOLUME_DB := -80.0

var state := PLAYING
var game_state := PLAYING
var targets: Array[WettableTarget] = []
@onready var _broad_light: PointLight2D = $BroadMoonLight
@onready var _impact_light: PointLight2D = $StreamImpactLight
## The bowl light dims with the strike art so a mistake briefly collapses the
## room around the player before the normal light returns.
@export_range(0.05, 1.0, 0.01) var strike_light_energy_scale := 0.12
@export_range(0.05, 1.0, 0.01) var strike_ambient_scale := 0.42
@export_range(0.05, 1.0, 0.01) var strike_light_duration := 0.34
## A successful checkpoint moves the impact light onto the object and gives it
## a short warm burst, making the hit readable against the brighter room.
@export_range(0.0, 3.0, 0.05) var target_hit_energy_punch := 1.15
@export_range(0.0, 2.0, 0.05) var target_hit_scale_punch := 0.55
@export_range(0.05, 1.0, 0.01) var target_hit_light_duration := 0.28
@export var target_hit_light_color := Color.WHITE
@export_range(0.0, 80.0, 0.5) var pulse_shake_strength := 19.0
@export_range(0.05, 0.5, 0.01) var pulse_shake_duration := 0.14
@export_range(0.0, 80.0, 0.5) var strike_shake_strength := 18.0
@export_range(0.05, 0.5, 0.01) var strike_shake_duration := 0.12
@export_range(0.0, 1.0, 0.05) var strike_shake_level_scale := 0.25
@export_range(-40.0, 0.0, 0.5) var spray_volume_db := -12.0
@export_range(0.01, 2.0, 0.01) var spray_fade_duration := 0.2
@export_range(0.1, 1.0, 0.01) var failure_exit_duration := 0.38
@export_range(0.0, 20.0, 0.1) var failure_exit_rotation := TAU * 3.0
@export_range(0.0, 120.0, 0.5) var failure_knock_shake_strength := 52.0
@export_range(0.05, 0.5, 0.01) var failure_knock_shake_duration := 0.16
var _world_size := Vector2(720.0, 1280.0)
var _layout_signature := Vector2.ZERO
var _elapsed := 0.0
var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _base_hud_offset := Vector2.ZERO
var _base_hud_rotation := 0.0
var _base_ambient_color := Color.WHITE
var _base_broad_light_energy := 0.0
var _base_broad_light_scale := 1.0
var _base_broad_light_color := Color.WHITE
var _base_impact_light_energy := 0.0
var _base_impact_light_scale := 1.0
var _base_impact_light_color := Color.WHITE
var _pulse_shake_remaining := 0.0
var _pulse_shake_elapsed := 0.0
var _pulse_shake_amplitude := 0.0
var _pulse_shake_phase := 0.0
var _active_shake_strength := 0.0
var _active_shake_duration := 0.0
var _strike_light_remaining := 0.0
var _target_hit_light_remaining := 0.0
var gameplay_started := false
var initial_input_source := InputController.AimSource.KEYBOARD
var _start_prompt_shown := false
## A negative-zone overlap is a strike on the first committed endpoint frame.
## Keep this exported for scene/API compatibility, but default it to zero so
## even a brief touch is fully sensitive.
@export_range(0.0, 2.0, 0.01) var negative_contact_duration := CONTACT_DURATION
@export_range(0.0, 10.0, 0.01) var safety_cooldown := SAFETY_COOLDOWN
@export_range(1, 9, 1) var max_strikes := MAX_STRIKES
var negative_zones: Array[NegativeZone] = []
var strike_count := 0
var _negative_contact_elapsed := 0.0
var _negative_contact_zone: NegativeZone
var _strike_cooldown_remaining := 0.0
var _frame_delta := 1.0 / 60.0
var _last_stream_endpoint := Vector2.ZERO
var _has_stream_endpoint := false
var _spray_fade_tween: Tween
var _failure_exit_tween: Tween
var _failure_transition_active := false
var _failure_exit_center := Vector2.ZERO
var _failure_exit_offset := Vector2.ZERO

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
	_set_spray_looping()
	_spray_sound.volume_db = SPRAY_SILENT_VOLUME_DB
	if is_instance_valid(surface_effects):
		surface_effects.bind_stream(stream)
	if enable_negative_zones:
		_collect_negative_zones()
	else:
		_disable_negative_zones()
	input_controller.set_target_position(shape_trace.get_checkpoint_position(0))
	stream.wet_target_hit.connect(_on_wet_target_hit)
	stream.drawing_point_updated.connect(_on_drawing_point_updated)
	stream.pulse_triggered.connect(_on_stream_pulse)
	if not music_controller.beat_started.is_connected(_on_music_beat):
		music_controller.beat_started.connect(_on_music_beat)
	input_controller.stream_hold_changed.connect(_on_stream_hold_changed)
	shape_trace.checkpoint_completed.connect(_on_checkpoint_completed)
	shape_trace.trace_completed.connect(_on_trace_completed)
	line_replay.replay_finished.connect(_on_replay_finished)
	_wire_hud()
	if not input_controller.input_detected.is_connected(_on_input_detected):
		input_controller.input_detected.connect(_on_input_detected)
	if is_instance_valid(level_1_chrome) and not level_1_chrome.volume_pointer_changed.is_connected(
		_on_volume_pointer_changed,
	):
		level_1_chrome.volume_pointer_changed.connect(_on_volume_pointer_changed)
	if not title_screen.transition_completed.is_connected(_on_title_transition_completed):
		title_screen.transition_completed.connect(_on_title_transition_completed)
	if not title_screen.start_requested.is_connected(_on_title_start_requested):
		title_screen.start_requested.connect(_on_title_start_requested)
	if not hud.game_over.raid_sequence_finished.is_connected(
		_on_game_over_raid_sequence_finished,
	):
		hud.game_over.raid_sequence_finished.connect(_on_game_over_raid_sequence_finished)
	if not hud.game_over.raid_knock.is_connected(_on_game_over_raid_knock):
		hud.game_over.raid_knock.connect(_on_game_over_raid_knock)
	if not hud.strike_warning.pound_triggered.is_connected(_on_strike_pound):
		hud.strike_warning.pound_triggered.connect(_on_strike_pound)
	line_recorder.start_recording()
	_base_position = position
	_base_rotation = rotation
	_base_hud_offset = _hud_layer.offset
	_base_hud_rotation = _hud_layer.rotation
	_base_ambient_color = _ambient.color
	_base_broad_light_energy = _broad_light.energy
	_base_broad_light_scale = _broad_light.texture_scale
	_base_broad_light_color = _broad_light.color
	_base_impact_light_energy = _impact_light.energy
	_base_impact_light_scale = _impact_light.texture_scale
	_base_impact_light_color = _impact_light.color
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


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("web") or not gameplay_started or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.is_action_pressed(DEBUG_INSTANT_STRIKE_ACTION):
		_debug_instant_strike()
		get_viewport().set_input_as_handled()
	elif key.is_action_pressed(DEBUG_INSTANT_WIN_ACTION):
		_debug_instant_win()
		get_viewport().set_input_as_handled()


func _debug_instant_strike() -> void:
	if state != PLAYING:
		return
	# Debug strikes intentionally bypass the normal safety grace period so
	# repeated shortcut presses can exercise consecutive strike states.
	_strike_cooldown_remaining = 0.0
	_take_strike()


func _debug_instant_win() -> void:
	if state != PLAYING:
		return
	input_controller.stop_pissing()
	while state == PLAYING and shape_trace.completed_steps < shape_trace.total_steps:
		shape_trace.complete_current_checkpoint()
	# Completing a trace normally replays the recorded line before showing the
	# card. Debug win should be immediate even if the player had already drawn.
	if state == REPLAYING:
		line_replay.stop()
		_on_replay_finished()


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
	if is_instance_valid(piss_toilet):
		piss_toilet.apply_layout()
		shape_trace.target_center_position = piss_toilet.get_bowl_anchor_global()
	_align_bowl_light()
	if _layout_signature != _world_size:
		_layout_signature = _world_size
		if _impact_light:
			_impact_light.position = stream.source_position


func _align_bowl_light() -> void:
	if not is_instance_valid(_broad_light):
		return
	var bowl := get_node_or_null("PissToilet/Bowl") as Sprite2D
	if bowl:
		# PointLight2D.position is local to Main; to_local keeps this correct while
		# the root is offset by the stream-pulse camera shake.
		_broad_light.position = to_local(bowl.global_position)
		return
	_broad_light.position = Vector2(_world_size.x * 0.5, _world_size.y * 0.55)


func _wire_hud() -> void:
	hud.input_controller = input_controller
	hud.stream = stream
	hud.target_nodes = targets
	hud.show_touch_controls = input_controller.touch_controls_visible
	if is_instance_valid(hud.piss_meter):
		hud.piss_meter.input_controller = input_controller
		hud.piss_meter.stream = stream
	if not hud.retry_pressed.is_connected(_on_play_again_pressed):
		hud.retry_pressed.connect(_on_play_again_pressed)
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
		# The input that starts the title transition is the best indication of the
		# player's control scheme. Show its prompt while the title fades so the
		# controls do not wait for the transition to finish.
		hud.show_start_prompt(source)
		_start_prompt_shown = true


func _on_title_start_requested(_source: int) -> void:
	music_controller.begin_gameplay_crossfade()


func _on_volume_pointer_changed(active: bool) -> void:
	input_controller.set_pointer_input_blocked(active)
	if is_instance_valid(hud):
		hud.set_aim_pointer_blocked(active)


func _on_title_transition_completed(source: int) -> void:
	initial_input_source = source
	_start_gameplay(initial_input_source)


func start_gameplay_immediately() -> void:
	## Programmatic bypass used by direct-level startup and scene tests.
	music_controller.start_gameplay_immediately()
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
	input_controller.set_process_unhandled_input(true)
	input_controller.set_process(true)
	hud.set_gameplay_controls_visible(true)
	if not _start_prompt_shown:
		hud.show_input_prompt(source)
	_start_prompt_shown = false


func _on_stream_pulse(amplitude: float) -> void:
	var safe_amplitude := clampf(amplitude, 0.0, 1.0)
	_begin_screen_shake(pulse_shake_strength, pulse_shake_duration, safe_amplitude)


func _on_strike_pound(strike: int, _pound_index: int) -> void:
	var level := clampf(float(strike - 1), 0.0, 2.0)
	var level_multiplier := 1.0 + level * strike_shake_level_scale
	_begin_screen_shake(strike_shake_strength * level_multiplier, strike_shake_duration)


func _on_game_over_raid_knock() -> void:
	_begin_screen_shake(failure_knock_shake_strength, failure_knock_shake_duration)


func _begin_screen_shake(strength: float, duration: float, amplitude := 1.0) -> void:
	var safe_duration := maxf(duration, 0.0)
	_pulse_shake_remaining = maxf(_pulse_shake_remaining, safe_duration)
	_pulse_shake_elapsed = 0.0
	_pulse_shake_amplitude = maxf(_pulse_shake_amplitude, clampf(amplitude, 0.0, 1.0))
	_active_shake_strength = maxf(_active_shake_strength, maxf(strength, 0.0))
	_active_shake_duration = maxf(_active_shake_duration, safe_duration)
	_pulse_shake_phase += 1.618


func _on_music_beat(_beat_index: int, strength: float) -> void:
	if not gameplay_started or state != PLAYING:
		return
	# LiquidStream owns the beat pulse so its ribbon and the camera shake are
	# driven by the same event. It emits pulse_triggered even while idle, which
	# keeps the room moving to the music before the player starts a hold.
	stream.trigger_pulse(strength)


func _advance_pulse_feedback(delta: float) -> void:
	# A first frame can be long while a scene/imported texture is settling. Keep
	# a pulse visible for at least one rendered frame instead of consuming the
	# entire shake envelope in a single hitch.
	var safe_delta := clampf(delta, 0.0, 1.0 / 30.0)
	_pulse_shake_remaining = move_toward(
		_pulse_shake_remaining,
		0.0,
		safe_delta,
	)
	if _pulse_shake_remaining > 0.0:
		_pulse_shake_elapsed += safe_delta

	_strike_light_remaining = move_toward(
		_strike_light_remaining,
		0.0,
		safe_delta,
	)
	_target_hit_light_remaining = move_toward(
		_target_hit_light_remaining,
		0.0,
		safe_delta,
	)
	var strike_amount := smoothstep(
		0.0,
		1.0,
		_strike_light_remaining / maxf(strike_light_duration, 0.001),
	)
	var target_hit_amount := smoothstep(
		0.0,
		1.0,
		_target_hit_light_remaining / maxf(target_hit_light_duration, 0.001),
	)
	_set_effect_lights_enabled(
		strike_amount <= 0.0
		and target_hit_amount > 0.0,
	)
	var light_energy_multiplier := (
			lerpf(1.0, strike_light_energy_scale, strike_amount)
			* (1.0 + target_hit_energy_punch * target_hit_amount)
	)
	var light_scale_multiplier := (
			1.0 + target_hit_scale_punch * target_hit_amount
	)
	_broad_light.energy = _base_broad_light_energy * light_energy_multiplier
	_broad_light.texture_scale = _base_broad_light_scale * light_scale_multiplier
	_broad_light.color = _base_broad_light_color.lerp(
		target_hit_light_color,
		target_hit_amount,
	)
	_impact_light.energy = _base_impact_light_energy * light_energy_multiplier
	_impact_light.texture_scale = _base_impact_light_scale * light_scale_multiplier
	_impact_light.color = _base_impact_light_color.lerp(
		target_hit_light_color,
		target_hit_amount,
	)
	if is_instance_valid(_ambient):
		_ambient.color = _base_ambient_color * lerpf(
			1.0,
			strike_ambient_scale,
			strike_amount,
		)
	var shake_offset := Vector2.ZERO
	if _pulse_shake_remaining > 0.0:
		var shake_progress := clampf(
			_pulse_shake_remaining / maxf(_active_shake_duration, 0.001),
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
		shake_offset = jitter * _active_shake_strength * _pulse_shake_amplitude * shake_envelope
	if not _failure_transition_active:
		position = _base_position + shake_offset
		# HUDLayer is a screen-space CanvasLayer. Keep it out of the world shake so
		# the crosshair stays put while the stream and negative zones can drift under
		# it, making a beat-timed miss possible.
		_hud_layer.offset = _base_hud_offset
		_hud_layer.rotation = _base_hud_rotation

	if _pulse_shake_remaining <= 0.0:
		_pulse_shake_amplitude = 0.0
		_active_shake_strength = 0.0
		_active_shake_duration = 0.0


func _reset_pulse_feedback() -> void:
	_pulse_shake_remaining = 0.0
	_pulse_shake_elapsed = 0.0
	_pulse_shake_amplitude = 0.0
	_active_shake_duration = 0.0
	_active_shake_strength = 0.0
	_strike_light_remaining = 0.0
	position = _base_position
	rotation = _base_rotation
	_hud_layer.offset = _base_hud_offset
	_hud_layer.rotation = _base_hud_rotation
	if is_instance_valid(_ambient):
		_ambient.color = _base_ambient_color
	_broad_light.energy = _base_broad_light_energy
	_broad_light.texture_scale = _base_broad_light_scale
	_broad_light.color = _base_broad_light_color
	_impact_light.energy = _base_impact_light_energy
	_impact_light.texture_scale = _base_impact_light_scale
	_impact_light.color = _base_impact_light_color


func _set_effect_lights_enabled(enabled: bool) -> void:
	if is_instance_valid(_broad_light):
		_broad_light.enabled = enabled
	if is_instance_valid(_impact_light):
		_impact_light.enabled = enabled


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
	music_controller.set_pissing(active)
	_set_spray_sound_active(active)
	if active:
		return
	# A release can be followed by a re-press before LiquidStream gets another
	# process tick. Reset contact synchronously so the two holds cannot merge.
	_reset_negative_contact()
	if is_instance_valid(surface_effects):
		surface_effects.observe_stream_endpoint(Vector2.ZERO, false)
	_has_stream_endpoint = false
	if state == PLAYING:
		shape_trace.observe_drawing_point(Vector2.ZERO, false, 0.0)
		stream.cancel_stream()


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
	# The stream reports its endpoint in the unshaken gameplay canvas. Keep that
	# coordinate in this query while the world nodes carry the beat transform;
	# the resulting displacement is what lets a hard beat turn a near miss into
	# a negative-zone contact beneath the stationary crosshair.
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
	_strike_light_remaining = strike_light_duration
	_set_effect_lights_enabled(false)
	input_controller.stop_pissing()
	stream.cancel_stream()
	hud.set_strikes(strike_count)
	if strike_count < max_strikes:
		hud.show_strike_warning(strike_count, safety_cooldown)
	if is_instance_valid(screen_overlay):
		screen_overlay.play_strike_feedback()
	stream.play_strike_flash()
	if strike_count >= max_strikes:
		_fail_attempt()


func _fail_attempt() -> void:
	if state != PLAYING:
		return
	_set_state(FAILED)
	_stop_spray_sound()
	_reset_pulse_feedback()
	_strike_light_remaining = strike_light_duration
	line_recorder.finish_recording()
	line_replay.stop()
	input_controller.set_gameplay_input_enabled(false)
	input_controller.set_process_unhandled_input(false)
	input_controller.set_process(false)
	stream.set_live_enabled(false)
	shape_trace.set_trace_visible(false)
	hud.set_aim_zone_state(TouchReticle.ReticleState.NEUTRAL)
	hud.show_game_over()
	_set_effect_lights_enabled(false)


func _on_trace_completed() -> void:
	if state != PLAYING:
		return
	_reset_pulse_feedback()
	_set_state(REPLAYING)
	_stop_spray_sound()
	line_recorder.finish_recording()
	input_controller.set_process_unhandled_input(false)
	input_controller.set_process(false)
	stream.set_live_enabled(false)
	shape_trace.set_trace_visible(false)
	hud.set_gameplay_controls_visible(false)
	if _target_hit_light_remaining <= 0.0:
		_set_effect_lights_enabled(false)
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


func _on_game_over_raid_sequence_finished() -> void:
	if state != FAILED:
		return
	_launch_failed_level()


func _launch_failed_level() -> void:
	if _failure_transition_active:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	_failure_transition_active = true
	if is_instance_valid(screen_overlay):
		screen_overlay.stop_all_effects()
	_failure_exit_center = viewport_size * 0.5
	_failure_exit_offset = Vector2(0.0, -viewport_size.y * 1.35)
	# Make the launch origin explicit so a leftover shake can never turn this
	# into a teleport. The first frame is zero movement and zero spin. Applying
	# the transform around the viewport center keeps the whole composition
	# together while it accelerates upward through several full rotations.
	_apply_failure_launch(0.0)
	_failure_exit_tween = create_tween()
	_failure_exit_tween.tween_method(
		_apply_failure_launch,
		0.0,
		1.0,
		failure_exit_duration,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func _apply_failure_launch(progress: float) -> void:
	var launch_progress := clampf(progress, 0.0, 1.0)
	var launch_angle := failure_exit_rotation * launch_progress
	var launch_offset := _failure_exit_offset * launch_progress
	# Node2D and CanvasLayer rotate around their local origins. Offset the
	# origins around the viewport center so the visible game, including its HUD,
	# performs the spin around screen center rather than the top-left corner.
	position = _failure_exit_center + launch_offset + (
		_base_position - _failure_exit_center
	).rotated(launch_angle)
	rotation = _base_rotation + launch_angle
	_hud_layer.offset = _failure_exit_center + launch_offset + (
		_base_hud_offset - _failure_exit_center
	).rotated(launch_angle)
	_hud_layer.rotation = _base_hud_rotation + launch_angle


func reset_level() -> void:
	if _failure_exit_tween:
		_failure_exit_tween.kill()
		_failure_exit_tween = null
	_failure_transition_active = false
	_set_state(PLAYING)
	_stop_spray_sound()
	_reset_pulse_feedback()
	_target_hit_light_remaining = 0.0
	strike_count = 0
	_strike_cooldown_remaining = 0.0
	_reset_negative_contact()
	if is_instance_valid(surface_effects):
		surface_effects.reset_effects()
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
	input_controller.set_process_unhandled_input(true)
	input_controller.set_process(true)
	hud.hide_completion_card()
	hud.set_strikes(strike_count)
	hud.set_aim_zone_state(TouchReticle.ReticleState.NEUTRAL)
	hud.set_gameplay_controls_visible(true)
	_set_effect_lights_enabled(false)
	if is_instance_valid(screen_overlay):
		screen_overlay.stop_all_effects()


func _set_state(next_state: int) -> void:
	state = next_state
	game_state = next_state


func _set_spray_looping() -> void:
	var spray_stream := _spray_sound.stream as AudioStreamOggVorbis
	if not spray_stream:
		return
	spray_stream.loop = true
	spray_stream.loop_offset = 0.0


func _set_spray_sound_active(active: bool) -> void:
	if not is_instance_valid(_spray_sound):
		return
	if active and gameplay_started and state == PLAYING:
		if _spray_fade_tween:
			_spray_fade_tween.kill()
		if not _spray_sound.playing:
			_spray_sound.volume_db = SPRAY_SILENT_VOLUME_DB
			_spray_sound.play()
		_spray_fade_tween = create_tween()
		_spray_fade_tween.tween_property(
			_spray_sound,
			"volume_db",
			spray_volume_db,
			spray_fade_duration,
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	_fade_spray_sound_out()


func _stop_spray_sound() -> void:
	_fade_spray_sound_out()


func _fade_spray_sound_out() -> void:
	if is_instance_valid(_spray_sound):
		if _spray_fade_tween:
			_spray_fade_tween.kill()
		if not _spray_sound.playing:
			_spray_sound.volume_db = SPRAY_SILENT_VOLUME_DB
			return
		_spray_fade_tween = create_tween()
		_spray_fade_tween.tween_property(
			_spray_sound,
			"volume_db",
			SPRAY_SILENT_VOLUME_DB,
			spray_fade_duration,
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_spray_fade_tween.tween_callback(_finish_spray_sound_fade_out)


func _finish_spray_sound_fade_out() -> void:
	if is_instance_valid(_spray_sound):
		_spray_sound.stop()
		_spray_sound.volume_db = SPRAY_SILENT_VOLUME_DB
	_spray_fade_tween = null


func _on_wet_target_hit(
		target: WettableTarget,
		amount: float,
		position: Vector2,
		normal: Vector2,
) -> void:
	if is_instance_valid(target):
		target.apply_liquid(amount, position)
		_impact_light.position = position + normal * 12.0
		_target_hit_light_remaining = target_hit_light_duration
		_set_effect_lights_enabled(true)


func _on_checkpoint_completed(_index: int) -> void:
	if state != PLAYING:
		return
	hud.play_success_burst()
	_target_hit_light_remaining = target_hit_light_duration
	var hit_light_position := shape_trace.get_checkpoint_position(_index)
	if is_instance_valid(piss_toilet):
		hit_light_position = piss_toilet.get_bowl_anchor_global()
	_impact_light.position = to_local(hit_light_position)
	_set_effect_lights_enabled(true)
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
