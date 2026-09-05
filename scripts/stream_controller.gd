extends Node2D

class_name LiquidStream

signal wet_target_hit(target: WettableTarget, amount: float, position: Vector2, normal: Vector2)
signal drawing_point_updated(position: Vector2, active: bool)
signal pulse_triggered(amplitude: float)

const COLLISION_TARGET_HIT := "target_hit"
const COLLISION_IN_BOUNDS_MISS := "in_bounds_miss"
const COLLISION_OUT_OF_BOUNDS_MISS := "out_of_bounds_miss"
const STRIKE_FLASH_DURATION := 0.24
const TARGET_HIT := COLLISION_TARGET_HIT
const IN_BOUNDS_MISS := COLLISION_IN_BOUNDS_MISS
const OUT_OF_BOUNDS_MISS := COLLISION_OUT_OF_BOUNDS_MISS

@export var source_position := Vector2(360.0, 1320.0)
@export var stream_speed := 920.0
@export var target_follow_stiffness := 135.0
@export var target_follow_damping := 17.0
@export var target_follow_max_speed := 2500.0
@export var bloom_radius_per_pixel := 0.54
@export var bloom_decay_rate := 130.0
@export var max_bloom_radius := 224.0
@export var bloom_width_scale := 0.16
@export var bloom_swirl_speed := 7.0
@export var bloom_swirl_acceleration := 28.0
@export var double_stream_start_radius := 180.0
@export var double_stream_release_radius := 72.0
@export var double_bloom_radius_multiplier := 3.0
@export_range(24, 32, 1) var ribbon_points := 28
@export var gravity := Vector2(0.0, 360.0)
@export var parcel_lifetime := 2.25
@export_range(32, 128, 1) var max_parcels := 96
@export var collision_mask := 1
## Assigned by the owning level. Keeping this as runtime state avoids writing a
## null Node reference into every instanced stream scene.
var depth_map: DepthMap2D
@export var source_entry_grace := 96.0
@export var depth_distance_scale := 720.0
@export_range(1, 8, 1) var depth_band_count := 4
@export var depth_band_z_step := 10
@export var depth_ribbon_z_offset := -1
@export var liquid_color := Color("#f1d34f")
@export var stream_tile_length := 96.0
@export var source_width_scale := 1.65
@export var distal_width_scale := 0.55
@export var distal_fade_start := 0.78
@export_range(0.1, 1.0, 0.01) var distal_end_alpha := 0.5
@export var normal_emission_rate := 60.0
@export var pulse_preview_enabled := true
@export_range(30.0, 240.0, 1.0) var pulse_preview_bpm := 120.0
@export_range(1.0, 3.0, 0.01) var pulse_width_multiplier := 2.0
@export_range(0.01, 0.2, 0.005) var pulse_width_seconds := 0.06

var input_controller: InputController

@onready var _edge_mesh: MeshInstance2D = $EdgeRibbon
@onready var _body_mesh: MeshInstance2D = $BodyRibbon
@onready var _highlight_mesh: MeshInstance2D = $HighlightRibbon
@onready var _double_edge_mesh: MeshInstance2D = $DoubleEdgeRibbon
@onready var _double_body_mesh: MeshInstance2D = $DoubleBodyRibbon
@onready var _double_highlight_mesh: MeshInstance2D = $DoubleHighlightRibbon
@onready var _droplets: DepthParticleEmitter = $Droplets
@onready var _impact: DepthParticleEmitter = $ImpactBurst
var _edge_mesh_resource := ArrayMesh.new()
var _body_mesh_resource := ArrayMesh.new()
var _highlight_mesh_resource := ArrayMesh.new()
var _double_edge_mesh_resource := ArrayMesh.new()
var _double_body_mesh_resource := ArrayMesh.new()
var _double_highlight_mesh_resource := ArrayMesh.new()
var _parcels: Array[Dictionary] = []
var _double_parcels: Array[Dictionary] = []
var _emission_accumulator := 0.0
var _current_points := PackedVector2Array()
var _current_point_depths := PackedFloat32Array()
var _stream_target_position := Vector2.ZERO
var _stream_target_velocity := Vector2.ZERO
var _stream_target_initialized := false
var _current_stream_direction := Vector2.UP
var _live_enabled := true
var _last_input_target := Vector2.ZERO
var _input_target_initialized := false
var _aim_bloom_radius := 0.0
var _bloom_angle := 0.0
var _bloom_spin_velocity := 0.0
var _bloom_offset := Vector2.ZERO
var _double_stream_active := false
var _current_point_ages := PackedFloat32Array()
var _double_point_depths := PackedFloat32Array()
var _double_point_ages := PackedFloat32Array()
var _preview_beat_elapsed := 0.0
var _pulses: Array[Dictionary] = []
var _depth_band_nodes: Dictionary = {}
var _depth_band_resources: Dictionary = {}
var _stream_hold_was_active := false
var _strike_flash_remaining := 0.0


func _ready() -> void:
	_edge_mesh.mesh = _edge_mesh_resource
	_body_mesh.mesh = _body_mesh_resource
	_highlight_mesh.mesh = _highlight_mesh_resource
	_double_edge_mesh.mesh = _double_edge_mesh_resource
	_double_body_mesh.mesh = _double_body_mesh_resource
	_double_highlight_mesh.mesh = _double_highlight_mesh_resource
	_edge_mesh.modulate = Color("#493719")
	_body_mesh.modulate = liquid_color
	_highlight_mesh.modulate = Color("#fff3a0")
	_double_edge_mesh.modulate = Color("#493719")
	_double_body_mesh.modulate = liquid_color
	_double_highlight_mesh.modulate = Color("#fff3a0")
	_configure_depth_particles()
	_ensure_depth_band_nodes()
	_apply_depth_render_order()
	_set_live_visuals(true)
	queue_redraw()


func set_depth_map(value: DepthMap2D) -> void:
	depth_map = value
	_configure_depth_particles()
	_ensure_depth_band_nodes()
	_apply_depth_render_order()
	_set_depth_base_visibility()
	queue_redraw()


func get_depth_map() -> DepthMap2D:
	return depth_map


func sample_stream_position(world_position: Vector2) -> Dictionary:
	## A stream-facing query that preserves the old 2D behavior when no map is
	## assigned. The raw map itself remains intentionally classification-free.
	if depth_map == null:
		return {"valid": true, "depth": 0.0}
	var sample := depth_map.sample_world_position(world_position)
	if bool(sample.get("valid", false)):
		return sample
	if world_position.distance_to(source_position) <= source_entry_grace:
		var entry_position := depth_map.clamp_world_position(world_position)
		var entry_sample := depth_map.sample_world_position(entry_position)
		if bool(entry_sample.get("valid", false)):
			return entry_sample
	return sample


func classify_stream_result(position: Vector2, target: WettableTarget = null) -> String:
	var sample := sample_stream_position(position)
	if not bool(sample.get("valid", false)):
		return COLLISION_OUT_OF_BOUNDS_MISS
	if target != null:
		return COLLISION_TARGET_HIT
	return COLLISION_IN_BOUNDS_MISS


func get_depth_band_at(world_position: Vector2) -> int:
	var sample := sample_stream_position(world_position)
	if not bool(sample.get("valid", false)):
		return -1
	return depth_map.get_depth_band(float(sample.get("depth", 0.0)), depth_band_count) if depth_map else 0


func _process(delta: float) -> void:
	if input_controller == null:
		return
	_advance_strike_flash(delta)
	if not _live_enabled:
		# Replay owns the only visible path after tracing completes. Keep the
		# physics chain untouched until the level is reset, but do not advance or
		# render it while the replay is on screen.
		drawing_point_updated.emit(Vector2.ZERO, false)
		return
	# The input controller keeps its public visual-start state persistent for
	# compatibility, but gameplay streams are hold-based. A release must clear
	# the old parcel chain so the next hold gets a fresh endpoint path.
	var is_pissing := input_controller.is_stream_input_held()
	var target := input_controller.get_target_position()
	_update_aim_bloom(target, delta)
	if is_pissing and not _stream_hold_was_active:
		_start_stream_hold(target)
	if not _stream_target_initialized:
		_stream_target_position = target
		_stream_target_initialized = true
	else:
		_advance_stream_target(target, delta)
	var direction := (_stream_target_position - source_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	if is_pissing:
		_stream_hold_was_active = true
		update_parcels(delta)
		_update_preview_pulses(delta)
		emit_parcels(_stream_target_position, delta)
	else:
		# Releasing Space/a finger closes the stream immediately. A later press
		# starts a fresh visible jet while the crosshair keeps its position. Reset
		# the inertial target too; otherwise the next endpoint inherits the prior
		# hold's momentum and can skip a checkpoint.
		if _stream_hold_was_active:
			reset_stream()
		_stream_hold_was_active = false
	if not _double_stream_active:
		_double_parcels.clear()
	var current_samples := _build_parcel_samples(_parcels)
	_current_points = _positions_from_samples(current_samples)
	_current_point_depths = _depths_from_samples(current_samples)
	_current_point_ages = _ages_from_samples(current_samples)
	var double_samples := _build_parcel_samples(_double_parcels)
	var double_points := _positions_from_samples(double_samples)
	_double_point_depths = _depths_from_samples(double_samples)
	_double_point_ages = _ages_from_samples(double_samples)
	if _current_points.size() >= 2:
		_current_stream_direction = _tangent_for_points(_current_points, 0, direction)
	elif is_pissing:
		_current_stream_direction = direction
	_impact.spread = _impact_spread()
	var hit := _truncate_at_target(
		_current_points,
		_current_point_ages,
		_current_point_depths,
	)
	var hit_target: bool = hit.get("classification", "") == COLLISION_TARGET_HIT
	_impact.emitting = false
	if is_pissing and not hit.is_empty():
		_current_points = hit.points
		_current_point_depths = hit.depths
		_current_point_ages = hit.ages
		if hit_target:
			_emit_hit(hit, delta)
		else:
			_emit_floor_impact(hit.position)
	elif is_pissing and _current_points.size() >= 2:
		_emit_floor_impact(_current_points[_current_points.size() - 1])

	var profile := get_stream_profile()
	update_ribbon_meshes(
		_current_points,
		_path_length(_current_points),
		float(profile["ribbon_alpha"]) if is_pissing else 0.0,
		hit_target,
		_current_point_ages,
		_current_point_depths,
	)
	_update_double_stream_meshes(
		double_points,
		_path_length(double_points),
		float(profile["ribbon_alpha"]) if is_pissing else 0.0,
		hit_target,
		_double_point_ages,
		_double_point_depths,
	)
	var droplet_index := mini(8, _current_points.size() - 2)
	_droplets.position = _current_points[droplet_index] if droplet_index >= 0 else source_position
	_droplets.direction = _tangent_at(droplet_index, direction)
	_set_droplet_depth(_droplets.global_position)
	_update_stream_effects(direction, is_pissing)
	var endpoint_active := is_pissing and _current_points.size() >= 2
	if endpoint_active:
		drawing_point_updated.emit(_current_points[_current_points.size() - 1], true)
	else:
		drawing_point_updated.emit(Vector2.ZERO, false)
	queue_redraw()


func process_frame(delta: float) -> void:
	_process(delta)


func set_live_enabled(enabled: bool) -> void:
	_live_enabled = enabled
	_set_live_visuals(enabled)
	if not enabled:
		drawing_point_updated.emit(Vector2.ZERO, false)


func is_live_enabled() -> bool:
	return _live_enabled


func get_stream_target_position() -> Vector2:
	return _stream_target_position


func get_current_stream_endpoint() -> Vector2:
	if _current_points.size() < 2:
		return Vector2.ZERO
	return _current_points[_current_points.size() - 1]


func has_active_stream_endpoint() -> bool:
	return (
			_live_enabled
			and input_controller != null
			and input_controller.is_stream_input_held()
			and _current_points.size() >= 2
	)


func get_stream_target_speed() -> float:
	return _stream_target_velocity.length()


func get_aim_bloom_radius() -> float:
	return _aim_bloom_radius


func get_aim_bloom_offset() -> Vector2:
	return _bloom_offset


func is_double_stream_active() -> bool:
	return _double_stream_active


func get_double_bloom_radius() -> float:
	return _aim_bloom_radius * double_bloom_radius_multiplier


func get_current_stream_direction() -> Vector2:
	return _current_stream_direction


func set_current_stream_direction(direction: Vector2) -> void:
	_current_stream_direction = direction


func trigger_pulse(amplitude := 1.0) -> void:
	## Starts a width pulse at the source. Music can call this once per beat.
	var pulse_amplitude := clampf(amplitude, 0.0, 1.0)
	_pulses.append(
		{
			"age": 0.0,
			"amplitude": pulse_amplitude,
		},
	)
	_prune_pulses()
	pulse_triggered.emit(pulse_amplitude)


func reset_stream() -> void:
	_stream_hold_was_active = false
	_strike_flash_remaining = 0.0
	modulate = Color.WHITE
	_parcels.clear()
	_double_parcels.clear()
	_emission_accumulator = 0.0
	_current_points = PackedVector2Array()
	_current_point_depths = PackedFloat32Array()
	_current_point_ages = PackedFloat32Array()
	_double_point_depths = PackedFloat32Array()
	_double_point_ages = PackedFloat32Array()
	_preview_beat_elapsed = 0.0
	_pulses.clear()
	_stream_target_position = Vector2.ZERO
	_stream_target_velocity = Vector2.ZERO
	_stream_target_initialized = false
	_current_stream_direction = Vector2.UP
	_last_input_target = Vector2.ZERO
	_input_target_initialized = false
	_aim_bloom_radius = 0.0
	_bloom_angle = 0.0
	_bloom_spin_velocity = 0.0
	_bloom_offset = Vector2.ZERO
	_double_stream_active = false
	_impact.emitting = false
	_droplets.emitting = false
	queue_redraw()


func _start_stream_hold(target: Vector2) -> void:
	# The first parcel of a hold must begin at the aim position that caused the
	# hold. Do not carry idle cursor easing or aim bloom into the first shot.
	_stream_target_position = target
	_stream_target_velocity = Vector2.ZERO
	_stream_target_initialized = true
	_aim_bloom_radius = 0.0
	_bloom_angle = 0.0
	_bloom_spin_velocity = 0.0
	_bloom_offset = Vector2.ZERO
	_double_stream_active = false
	_last_input_target = target
	_input_target_initialized = true


func play_strike_flash() -> void:
	_strike_flash_remaining = STRIKE_FLASH_DURATION
	_apply_strike_flash()


func is_strike_flash_active() -> bool:
	return _strike_flash_remaining > 0.0


func _advance_strike_flash(delta: float) -> void:
	if _strike_flash_remaining <= 0.0:
		modulate = Color.WHITE
		return
	_strike_flash_remaining = move_toward(
		_strike_flash_remaining,
		0.0,
		maxf(delta, 0.0),
	)
	_apply_strike_flash()
	if _strike_flash_remaining <= 0.0:
		modulate = Color.WHITE


func _apply_strike_flash() -> void:
	var progress := clampf(
		_strike_flash_remaining / STRIKE_FLASH_DURATION,
		0.0,
		1.0,
	)
	var envelope := sin(progress * PI)
	# CanvasItem modulation is multiplicative, so values above 1 briefly
	# brighten every ribbon and depth-band copy of the stream.
	modulate = Color(
		1.0 + 0.8 * envelope,
		1.0 + 0.35 * envelope,
		1.0 + 0.08 * envelope,
		1.0,
	)


func _set_live_visuals(enabled: bool) -> void:
	_edge_mesh.visible = enabled
	_body_mesh.visible = enabled
	_highlight_mesh.visible = enabled
	_double_edge_mesh.visible = enabled and _double_stream_active
	_double_body_mesh.visible = enabled and _double_stream_active
	_double_highlight_mesh.visible = enabled and _double_stream_active
	_set_depth_base_visibility()
	if not enabled:
		_hide_depth_band_group("")
		_hide_depth_band_group("double_")
	_droplets.visible = enabled
	_impact.visible = enabled
	if not enabled:
		_droplets.emitting = false
		_impact.emitting = false
	else:
		# The stream only starts when Space/a finger is held.
		_droplets.emitting = false


func update_parcels(delta: float) -> void:
	# Parcels are independent. Once emitted, their launch velocity never reads the
	# input controller again; only gravity changes that parcel's velocity.
	_advance_parcel_chain(_parcels, delta)
	_advance_parcel_chain(_double_parcels, delta)
	_advance_pulses(delta)


func _advance_parcel_chain(chain: Array[Dictionary], delta: float) -> void:
	for parcel in chain:
		var velocity: Vector2 = parcel["velocity"]
		parcel["position"] = parcel["position"] + velocity * delta + gravity * (delta * delta * 0.5)
		parcel["velocity"] = velocity + gravity * delta
		parcel["age"] = float(parcel["age"]) + delta
		parcel["depth"] = _parcel_depth(parcel)


func parcel_at(index: int) -> Dictionary:
	return _parcels[index]


func double_parcel_at(index: int) -> Dictionary:
	return _double_parcels[index]


func set_parcel_chain(parcels: Array[Dictionary]) -> void:
	_parcels = parcels.duplicate(true)


func emit_parcels(
		target_position: Vector2,
		delta: float,
) -> void:
	_emission_accumulator += delta
	var interval := 1.0 / maxf(normal_emission_rate, 1.0)
	var emitted := 0
	while _emission_accumulator >= interval and emitted < 4:
		_emission_accumulator -= interval
		emitted += 1
	# Always emit at least one parcel per rendered frame. This keeps the source
	# continuous on high-refresh displays while the accumulator catches up on
	# slower frames.
	emitted = maxi(emitted, 1)
	var parcel_index := 0
	while parcel_index < emitted:
		var primary_offset := _bloom_offset
		var secondary_offset := Vector2.ZERO
		if _double_stream_active:
			# The two branches sit on opposite sides of the same rotating bloom,
			# giving them separate targets instead of drawing one copied ribbon.
			primary_offset = _double_bloom_offset()
			secondary_offset = -primary_offset
		_emit_parcel(_parcels, target_position + primary_offset, primary_offset)
		if _double_stream_active:
			_emit_parcel(
				_double_parcels,
				target_position + secondary_offset,
				secondary_offset,
			)
		parcel_index += 1
	_prune_parcel_chain(_parcels)
	_prune_parcel_chain(_double_parcels)


func _emit_parcel(
		chain: Array[Dictionary],
		launch_target: Vector2,
		bloom_offset: Vector2,
) -> void:
	var launch_sample := _sample_depth_for_stream_effects(source_position)
	var target_sample := sample_stream_position(launch_target)
	var launch_depth := float(launch_sample.get("depth", 0.0))
	var target_depth := float(target_sample.get("depth", launch_depth))
	var travel_time := _travel_time_for_target(launch_target, launch_depth, target_depth)
	var launch_velocity := _launch_velocity_for_target(launch_target)
	chain.push_front(
		{
			"position": source_position,
			"velocity": launch_velocity,
			"launch_velocity": launch_velocity,
			"launch_target": launch_target,
			"bloom_offset": bloom_offset,
			"launch_depth": launch_depth,
			"target_depth": target_depth,
			"depth": launch_depth,
			"flight_time": travel_time,
			"age": 0.0,
			# A parcel must live through the calculated flight, but it should be
			# removed as soon as it reaches its committed target instead of
			# overshooting the cursor when the configured default is longer.
			"lifetime": travel_time,
		},
	)


func _prune_parcel_chain(chain: Array[Dictionary]) -> void:
	while (
			not chain.is_empty()
			and (
					float(chain.back()["age"])
					> float(chain.back().get("lifetime", parcel_lifetime))
					or chain.size() > max_parcels
			)
	):
		chain.pop_back()


func _update_preview_pulses(delta: float) -> void:
	if not pulse_preview_enabled:
		return
	var interval := 60.0 / maxf(pulse_preview_bpm, 1.0)
	_preview_beat_elapsed += maxf(delta, 0.0)
	while _preview_beat_elapsed >= interval:
		_preview_beat_elapsed -= interval
		trigger_pulse()


func _prune_pulses() -> void:
	var pulse_lifetime := parcel_lifetime + pulse_width_seconds * 3.0
	while (
			not _pulses.is_empty()
			and float(_pulses[0]["age"]) > pulse_lifetime
	):
		_pulses.pop_front()


func _advance_pulses(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	for pulse in _pulses:
		pulse["age"] = float(pulse["age"]) + safe_delta
	_prune_pulses()


func _pulse_width_multiplier_for_age(age: float) -> float:
	if _pulses.is_empty():
		return 1.0
	var width := maxf(pulse_width_seconds, 0.001)
	var multiplier := 1.0
	for pulse in _pulses:
		var pulse_age := float(pulse["age"])
		var distance_from_peak := (age - pulse_age) / width
		var influence := exp(-0.5 * distance_from_peak * distance_from_peak)
		var pulse_multiplier := lerpf(
			1.0,
			pulse_width_multiplier,
			influence * float(pulse["amplitude"]),
		)
		multiplier = maxf(multiplier, pulse_multiplier)
	return multiplier


func get_stream_profile() -> Dictionary:
	## Every active stream has the same continuous output. The crosshair controls
	## the target position, never a separate pressure mode.
	return {
		"ambient_amount": 7,
		"ambient_lifetime": 0.42,
		"ambient_velocity_min": 28.0,
		"ambient_velocity_max": 64.0,
		"emission_rate": normal_emission_rate,
		"ribbon_alpha": 1.0,
	}


func _update_stream_effects(direction: Vector2, is_pissing: bool) -> void:
	var profile := get_stream_profile()
	if not is_pissing:
		_droplets.emitting = false
		_edge_mesh.modulate.a = 1.0
		_body_mesh.modulate.a = 1.0
		_highlight_mesh.modulate.a = 1.0
		return
	_droplets.position = source_position
	_droplets.direction = direction
	_droplets.amount = int(profile["ambient_amount"])
	_droplets.lifetime = float(profile["ambient_lifetime"])
	_droplets.initial_velocity_min = float(profile["ambient_velocity_min"])
	_droplets.initial_velocity_max = float(profile["ambient_velocity_max"])
	_set_droplet_depth(source_position)
	_droplets.emitting = true
	var ribbon_alpha := float(profile["ribbon_alpha"])
	_edge_mesh.modulate.a = ribbon_alpha
	_body_mesh.modulate.a = ribbon_alpha
	_highlight_mesh.modulate.a = ribbon_alpha


func _configure_depth_particles() -> void:
	if _droplets == null or _impact == null:
		return
	_droplets.set_depth_map(depth_map)
	_impact.set_depth_map(depth_map)
	_droplets.source_entry_grace = source_entry_grace
	_impact.source_entry_grace = source_entry_grace
	_droplets.z_band_count = depth_band_count
	_impact.z_band_count = depth_band_count
	_droplets.z_band_step = depth_band_z_step
	_impact.z_band_step = depth_band_z_step


func _set_droplet_depth(world_position: Vector2) -> void:
	if _droplets == null:
		return
	var sample := sample_stream_position(world_position)
	_droplets.set_depth_context(
		world_position,
		float(sample.get("depth", 0.0)),
		world_position.distance_to(source_position) <= source_entry_grace,
	)


func _set_impact_depth(world_position: Vector2) -> void:
	if _impact == null:
		return
	var sample := sample_stream_position(world_position)
	_impact.set_depth_context(world_position, float(sample.get("depth", 0.0)))


func _apply_depth_render_order() -> void:
	var renderables := [
		_edge_mesh,
		_body_mesh,
		_highlight_mesh,
		_double_edge_mesh,
		_double_body_mesh,
		_double_highlight_mesh,
	]
	for renderable in renderables:
		if renderable == null:
			continue
		if depth_map == null:
			renderable.z_index = 0
		else:
			renderable.z_index = depth_map.get_render_z_index(
			0.5,
			depth_ribbon_z_offset,
			depth_band_count,
			depth_band_z_step,
		)


func _ensure_depth_band_nodes() -> void:
	if depth_map == null:
		return
	var specs := [
		{"key": "edge", "node": _edge_mesh},
		{"key": "body", "node": _body_mesh},
		{"key": "highlight", "node": _highlight_mesh},
		{"key": "double_edge", "node": _double_edge_mesh},
		{"key": "double_body", "node": _double_body_mesh},
		{"key": "double_highlight", "node": _double_highlight_mesh},
	]
	for spec in specs:
		var key: String = spec["key"]
		if _depth_band_nodes.has(key):
			continue
		var base_node: MeshInstance2D = spec["node"]
		var nodes: Array[MeshInstance2D] = []
		var resources: Array[ArrayMesh] = []
		for band in depth_band_count:
			var band_node := MeshInstance2D.new()
			band_node.name = "%sDepthBand%d" % [key.capitalize(), band]
			band_node.texture_filter = base_node.texture_filter
			band_node.texture_repeat = base_node.texture_repeat
			band_node.texture = base_node.texture
			band_node.material = base_node.material
			band_node.modulate = base_node.modulate
			band_node.self_modulate = base_node.self_modulate
			band_node.z_as_relative = true
			band_node.visible = false
			add_child(band_node)
			nodes.append(band_node)
			var band_mesh := ArrayMesh.new()
			band_node.mesh = band_mesh
			resources.append(band_mesh)
		_depth_band_nodes[key] = nodes
		_depth_band_resources[key] = resources
	_set_depth_base_visibility()


func _set_depth_base_visibility() -> void:
	var use_bands := depth_map != null and not _depth_band_nodes.is_empty()
	_edge_mesh.visible = _live_enabled and not use_bands
	_body_mesh.visible = _live_enabled and not use_bands
	_highlight_mesh.visible = _live_enabled and not use_bands
	_double_edge_mesh.visible = _live_enabled and _double_stream_active and not use_bands
	_double_body_mesh.visible = _live_enabled and _double_stream_active and not use_bands
	_double_highlight_mesh.visible = _live_enabled and _double_stream_active and not use_bands


func _depth_band_points(
		points: PackedVector2Array,
		point_depths := PackedFloat32Array(),
) -> Dictionary:
	var band_points: Array = []
	var band_depths: Array = []
	for band in depth_band_count:
		band_points.append(PackedVector2Array())
		band_depths.append(PackedFloat32Array())
	var previous_band := -1
	var previous_point := Vector2.ZERO
	var previous_depth := 0.0
	for index in points.size():
		var point_depth := -1.0
		if index < point_depths.size():
			point_depth = point_depths[index]
		var sample := sample_stream_position(points[index])
		if point_depth < 0.0:
			point_depth = float(sample.get("depth", 0.0))
		var band := _get_render_depth_band(points[index], point_depth)
		if band < 0:
			previous_band = -1
			continue
		if previous_band >= 0 and previous_band != band:
			# Duplicate the transition endpoint into both meshes so the split does
			# not leave a visible gap when a ribbon crosses a section boundary.
			var old_points: PackedVector2Array = band_points[previous_band]
			old_points.append(points[index])
			band_points[previous_band] = old_points
			var old_depths: PackedFloat32Array = band_depths[previous_band]
			old_depths.append(point_depth)
			band_depths[previous_band] = old_depths
			var new_points: PackedVector2Array = band_points[band]
			new_points.append(previous_point)
			band_points[band] = new_points
			var new_depths: PackedFloat32Array = band_depths[band]
			new_depths.append(previous_depth)
			band_depths[band] = new_depths
		var current_points: PackedVector2Array = band_points[band]
		if current_points.is_empty() or current_points[current_points.size() - 1] != points[index]:
			current_points.append(points[index])
		band_points[band] = current_points
		var current_depths: PackedFloat32Array = band_depths[band]
		if current_depths.is_empty() or current_points.size() > current_depths.size():
			current_depths.append(point_depth)
		band_depths[band] = current_depths
		previous_band = band
		previous_point = points[index]
		previous_depth = point_depth
	return {"points": band_points, "depths": band_depths}


func _get_render_depth_band(world_position: Vector2, committed_depth := -1.0) -> int:
	if depth_map == null:
		return 0
	var sample := sample_stream_position(world_position)
	if not bool(sample.get("valid", false)):
		return -1
	var depth := float(sample.get("depth", 0.0)) if committed_depth < 0.0 else committed_depth
	return depth_map.get_depth_band(depth, depth_band_count)


func _update_depth_banded_ribbons(
		prefix: String,
		points: PackedVector2Array,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
		point_ages: PackedFloat32Array,
		point_depths := PackedFloat32Array(),
) -> void:
	var style_specs := [
		{"key": "%sedge" % prefix, "width": 36.0, "offset": 0.0},
		{"key": "%sbody" % prefix, "width": 32.0, "offset": 0.0},
		{"key": "%shighlight" % prefix, "width": 8.0, "offset": 1.7},
	]
	var split_data := _depth_band_points(points, point_depths)
	var split_points: Array = split_data["points"]
	var split_depths: Array = split_data["depths"]
	var render_metrics := _depth_render_metrics(points, depth_length, point_depths)
	for spec in style_specs:
		var key: String = spec["key"]
		if not _depth_band_resources.has(key):
			continue
		var resources: Array = _depth_band_resources[key]
		var nodes: Array = _depth_band_nodes[key]
		for band in depth_band_count:
			var band_mesh: ArrayMesh = resources[band]
			var band_node: MeshInstance2D = nodes[band]
			var base_node: MeshInstance2D = _base_ribbon_node_for_key(key)
			band_node.modulate = base_node.modulate
			band_node.self_modulate = base_node.self_modulate
			band_mesh.clear_surfaces()
			var band_path: PackedVector2Array = split_points[band]
			var band_path_depths: PackedFloat32Array = split_depths[band]
			if band_path.size() < 2:
				band_node.visible = false
				continue
			var band_ages := PackedFloat32Array()
			for point in band_path:
				var source_index := points.find(point)
				band_ages.append(
					point_ages[source_index] if source_index >= 0 and source_index < point_ages.size() else 0.0,
				)
			var band_start_index := points.find(band_path[0])
			var band_distance_offset := _distance_through_points(points, band_start_index)
			_set_ribbon_mesh(
				band_mesh,
				band_path,
				float(spec["width"]),
				float(spec["offset"]),
				depth_length,
				ribbon_alpha,
				hit_target,
				band_ages,
				band_distance_offset,
				float(render_metrics["depth_origin"]),
				float(render_metrics["effective_length"]),
				band_path_depths,
			)
			band_node.z_index = depth_map.get_render_z_index(
				float(band) / float(maxi(depth_band_count - 1, 1)),
				depth_ribbon_z_offset,
				depth_band_count,
				depth_band_z_step,
			)
			band_node.visible = _live_enabled and ribbon_alpha > 0.0


func _base_ribbon_node_for_key(key: String) -> MeshInstance2D:
	match key:
		"edge":
			return _edge_mesh
		"body":
			return _body_mesh
		"highlight":
			return _highlight_mesh
		"double_edge":
			return _double_edge_mesh
		"double_body":
			return _double_body_mesh
		"double_highlight":
			return _double_highlight_mesh
	return _body_mesh


func build_parcel_centerline() -> PackedVector2Array:
	## Render the moving parcel chain. Each parcel is a committed sample of the
	## target and gravity at the instant it was emitted, so old stream segments do
	## not bend when the crosshair moves.
	return _build_parcel_centerline(_parcels)


func build_double_parcel_centerline() -> PackedVector2Array:
	return _build_parcel_centerline(_double_parcels)


func _build_parcel_centerline(chain: Array[Dictionary]) -> PackedVector2Array:
	return _positions_from_samples(_build_parcel_samples(chain))


func _build_parcel_samples(chain: Array[Dictionary]) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	if chain.is_empty():
		samples.append({ "position": source_position, "age": 0.0, "depth": 0.0 })
		return samples
	var point_count := mini(ribbon_points, chain.size())
	for i in point_count:
		var fraction := float(i) / float(maxi(point_count - 1, 1))
		var parcel_index := clampi(
			roundi(fraction * float(chain.size() - 1)),
			0,
			chain.size() - 1,
		)
		var parcel: Dictionary = chain[parcel_index]
		samples.append(
			{
				"position": parcel["position"],
				"age": float(parcel.get("age", 0.0)),
				"depth": _parcel_depth(parcel),
			},
		)
	return samples


func _parcel_depth(parcel: Dictionary) -> float:
	if not parcel.has("launch_depth") and not parcel.has("target_depth"):
		return clampf(float(parcel.get("depth", 0.0)), 0.0, 1.0)
	var launch_depth := float(parcel.get("launch_depth", 0.0))
	var target_depth := float(parcel.get("target_depth", launch_depth))
	var flight_time := maxf(float(parcel.get("flight_time", parcel_lifetime)), 0.001)
	var progress := clampf(float(parcel.get("age", 0.0)) / flight_time, 0.0, 1.0)
	return clampf(lerpf(launch_depth, target_depth, progress), 0.0, 1.0)


func _positions_from_samples(samples: Array[Dictionary]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for sample in samples:
		points.append(sample["position"])
	return points


func _ages_from_samples(samples: Array[Dictionary]) -> PackedFloat32Array:
	var ages := PackedFloat32Array()
	for sample in samples:
		ages.append(float(sample["age"]))
	return ages


func _depths_from_samples(samples: Array[Dictionary]) -> PackedFloat32Array:
	var depths := PackedFloat32Array()
	for sample in samples:
		depths.append(clampf(float(sample.get("depth", 0.0)), 0.0, 1.0))
	return depths


func _advance_stream_target(target: Vector2, delta: float) -> void:
	# An under-damped spring gives the stream acceleration and braking. The visible
	# overshoot sells mass and momentum, while damping brings it back to the
	# crosshair instead of letting a quick drag fling it away indefinitely.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.0:
		var step := minf(remaining, 1.0 / 60.0)
		var displacement := target - _stream_target_position
		var acceleration := displacement * target_follow_stiffness
		acceleration -= _stream_target_velocity * target_follow_damping
		_stream_target_velocity += acceleration * step
		_stream_target_velocity = _stream_target_velocity.limit_length(target_follow_max_speed)
		_stream_target_position += _stream_target_velocity * step
		remaining -= step


func _update_aim_bloom(target: Vector2, delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_aim_bloom_radius = move_toward(
		_aim_bloom_radius,
		0.0,
		bloom_decay_rate * safe_delta,
	)
	if not _input_target_initialized:
		_last_input_target = target
		_input_target_initialized = true
	else:
		var aim_delta := target - _last_input_target
		var movement := aim_delta.length()
		if movement > 0.0:
			_aim_bloom_radius = minf(
				_aim_bloom_radius + movement * bloom_radius_per_pixel,
				max_bloom_radius,
			)
			# Gently steer the bloom toward the direction of the aim change. From
			# there it keeps orbiting instead of teleporting between landing spots.
			_bloom_angle = lerp_angle(
				_bloom_angle,
				aim_delta.angle(),
				clampf(movement / 600.0, 0.0, 0.15),
			)
		_last_input_target = target

	var target_spin := bloom_swirl_speed if _aim_bloom_radius > 0.001 else 0.0
	_bloom_spin_velocity = move_toward(
		_bloom_spin_velocity,
		target_spin,
		bloom_swirl_acceleration * safe_delta,
	)
	_bloom_angle += _bloom_spin_velocity * safe_delta
	_bloom_offset = _figure_eight_offset(_bloom_angle, _aim_bloom_radius)
	if not _double_stream_active and _aim_bloom_radius >= double_stream_start_radius:
		_double_stream_active = true
	elif _double_stream_active and _aim_bloom_radius <= double_stream_release_radius:
		_double_stream_active = false


func _impact_spread() -> float:
	return clampf(100.0 + _aim_bloom_radius * 0.35, 100.0, 180.0)


func _double_bloom_offset() -> Vector2:
	# The double stream uses opposite points on a rotating ring. Unlike the
	# figure-eight aim bloom, the branch separation must stay exactly at the
	# configured radius so both ribbons remain predictably spaced.
	return Vector2.from_angle(_bloom_angle) * get_double_bloom_radius()


func _figure_eight_offset(phase: float, radius: float) -> Vector2:
	# Gerono's lemniscate traces a horizontal figure eight. Keeping the vertical
	# component at half height preserves the configured radius at the widest
	# points while the two lobes cross cleanly through the aim point.
	var horizontal := sin(phase)
	if absf(horizontal) < 0.000001:
		horizontal = 0.0
	return Vector2(horizontal, horizontal * cos(phase)) * radius


func _path_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	return maxf(length, 1.0)


func _sample_depth_for_stream_effects(world_position: Vector2) -> Dictionary:
	if depth_map == null:
		return {"valid": true, "depth": 0.0}
	var sample := depth_map.sample_world_position(world_position)
	if bool(sample.get("valid", false)):
		return sample
	# The nozzle begins just below the portrait frame. Treat this entry point as
	# the camera-facing surface (depth zero), otherwise every target would be
	# measured backward from the deepest edge of the baked map.
	if world_position.distance_to(source_position) <= source_entry_grace:
		return {"valid": true, "depth": 0.0}
	return sample


func _depth_render_metrics(
		points: PackedVector2Array,
		depth_length: float,
		point_depths := PackedFloat32Array(),
) -> Dictionary:
	var origin := 0.0
	var effective_length := maxf(depth_length, 1.0)
	if depth_map == null or points.is_empty():
		return {
			"depth_origin": origin,
			"effective_length": effective_length,
		}
	if point_depths.size() >= points.size():
		origin = clampf(float(point_depths[0]), 0.0, 1.0)
		var target_depth := clampf(float(point_depths[points.size() - 1]), 0.0, 1.0)
		effective_length += absf(target_depth - origin) * maxf(depth_distance_scale, 0.0)
		return {
			"depth_origin": origin,
			"effective_length": maxf(effective_length, 1.0),
		}
	var origin_sample := _sample_depth_for_stream_effects(points[0])
	var target_sample := _sample_depth_for_stream_effects(points[points.size() - 1])
	origin = float(origin_sample.get("depth", 0.0))
	var target_depth := float(target_sample.get("depth", origin))
	effective_length += absf(target_depth - origin) * maxf(depth_distance_scale, 0.0)
	return {
		"depth_origin": origin,
		"effective_length": maxf(effective_length, 1.0),
	}


func _distance_through_points(points: PackedVector2Array, end_index: int) -> float:
	if end_index <= 0:
		return 0.0
	var distance := 0.0
	var safe_end := mini(end_index, points.size() - 1)
	for index in range(1, safe_end + 1):
		distance += points[index - 1].distance_to(points[index])
	return distance


func _launch_velocity_for_target(target_position: Vector2) -> Vector2:
	# Pick a stable flight time, then solve the ordinary projectile equation so
	# each newly emitted parcel is aimed at the eased crosshair target.
	var offset := target_position - source_position
	var launch_sample := _sample_depth_for_stream_effects(source_position)
	var target_sample := sample_stream_position(target_position)
	var travel_time := _travel_time_for_target(
		 target_position,
		 float(launch_sample.get("depth", 0.0)),
		 float(target_sample.get("depth", launch_sample.get("depth", 0.0))),
	)
	return (offset - gravity * travel_time * travel_time * 0.5) / travel_time


func _travel_time_for_target(
		target_position: Vector2,
		launch_depth := 0.0,
		target_depth := 0.0,
	) -> float:
	var screen_distance := target_position.distance_to(source_position)
	var depth_distance := absf(target_depth - launch_depth) * maxf(depth_distance_scale, 0.0)
	var effective_distance := screen_distance + depth_distance
	return maxf(effective_distance / maxf(stream_speed, 1.0), 0.12)


func get_effective_travel_distance(
		target_position: Vector2,
		launch_depth := 0.0,
		target_depth := 0.0,
	) -> float:
	var screen_distance := target_position.distance_to(source_position)
	var depth_distance := absf(target_depth - launch_depth) * maxf(depth_distance_scale, 0.0)
	return screen_distance + depth_distance


func get_parcel_flight_time(parcel: Dictionary) -> float:
	return float(parcel.get("flight_time", parcel.get("lifetime", parcel_lifetime)))


func _truncate_at_target(
		points: PackedVector2Array,
		point_ages := PackedFloat32Array(),
		point_depths := PackedFloat32Array(),
) -> Dictionary:
	if points.size() < 2:
		return { }
	var space := get_world_2d().direct_space_state
	for i in range(points.size() - 1):
		var query := PhysicsRayQueryParameters2D.create(points[i], points[i + 1], collision_mask)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var result := space.intersect_ray(query)
		if result.is_empty():
			continue
		var collider: Object = result.get("collider")
		var target: WettableTarget = null
		if collider != null and collider.has_meta("wet_target"):
			target = collider.get_meta("wet_target") as WettableTarget
		if target == null:
			continue
		var clipped := PackedVector2Array()
		var clipped_ages := PackedFloat32Array()
		var clipped_depths := PackedFloat32Array()
		for j in range(i + 1):
			clipped.append(points[j])
			clipped_ages.append(
				point_ages[j] if j < point_ages.size() else 0.0,
			)
			clipped_depths.append(
				point_depths[j]
				if j < point_depths.size()
				else float(sample_stream_position(points[j]).get("depth", 0.0)),
			)
		var segment_length := points[i].distance_to(points[i + 1])
		var segment_fraction := 0.0
		if segment_length > 0.001:
			segment_fraction = points[i].distance_to(result.position) / segment_length
		var start_age := point_ages[i] if i < point_ages.size() else 0.0
		var end_age := point_ages[i + 1] if i + 1 < point_ages.size() else start_age
		var start_depth := (
			point_depths[i]
			if i < point_depths.size()
			else float(sample_stream_position(points[i]).get("depth", 0.0))
		)
		var end_depth := (
			point_depths[i + 1]
			if i + 1 < point_depths.size()
			else start_depth
		)
		clipped.append(result.position)
		clipped_ages.append(lerpf(start_age, end_age, clampf(segment_fraction, 0.0, 1.0)))
		clipped_depths.append(lerpf(start_depth, end_depth, clampf(segment_fraction, 0.0, 1.0)))
		var classification := classify_stream_result(result.position, target)
		return {
			"points": clipped,
			"ages": clipped_ages,
			"depths": clipped_depths,
			"target": target,
			"position": result.position,
			"normal": result.normal,
			"classification": classification,
		}
	return { }


func _emit_hit(hit: Dictionary, amount: float) -> void:
	var target: WettableTarget = hit.target
	var position: Vector2 = hit.position
	var normal: Vector2 = hit.normal
	_impact.position = position
	_impact.direction = normal
	_set_impact_depth(position)
	_impact.emitting = true
	wet_target_hit.emit(target, amount, position, normal)


func _emit_floor_impact(position: Vector2) -> void:
	# A miss still lands on the implicit floor at the stream endpoint. Keep the
	# impact emitter running continuously and use the backwards tangent as the
	# visual splash normal without inventing a second collision path.
	var endpoint_index := _current_points.size() - 1
	var normal := -_tangent_at(endpoint_index, Vector2.UP)
	_impact.position = position
	_impact.direction = normal
	if classify_stream_result(position) == COLLISION_OUT_OF_BOUNDS_MISS:
		_impact.emitting = false
		return
	_set_impact_depth(position)
	_impact.emitting = true


func _update_double_stream_meshes(
		points: PackedVector2Array,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
		point_ages: PackedFloat32Array,
		point_depths := PackedFloat32Array(),
) -> void:
	var should_render := (
			_live_enabled
			and _double_stream_active
			and ribbon_alpha > 0.0
			and points.size() >= 2
	)
	_double_edge_mesh.visible = should_render and depth_map == null
	_double_body_mesh.visible = should_render and depth_map == null
	_double_highlight_mesh.visible = should_render and depth_map == null
	if not should_render:
		_double_edge_mesh_resource.clear_surfaces()
		_double_body_mesh_resource.clear_surfaces()
		_double_highlight_mesh_resource.clear_surfaces()
		_hide_depth_band_group("double_")
		return
	if depth_map != null:
		_set_ribbon_mesh(_double_edge_mesh_resource, points, 36.0, 0.0, depth_length, ribbon_alpha, hit_target, point_ages, 0.0, -1.0, -1.0, point_depths)
		_set_ribbon_mesh(_double_body_mesh_resource, points, 32.0, 0.0, depth_length, ribbon_alpha, hit_target, point_ages, 0.0, -1.0, -1.0, point_depths)
		_set_ribbon_mesh(_double_highlight_mesh_resource, points, 8.0, 1.7, depth_length, ribbon_alpha, hit_target, point_ages, 0.0, -1.0, -1.0, point_depths)
		_update_depth_banded_ribbons(
			"double_",
			points,
			depth_length,
			ribbon_alpha,
			hit_target,
			point_ages,
			point_depths,
		)
		return

	_set_ribbon_mesh(
		_double_edge_mesh_resource,
		points,
		36.0,
		0.0,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
	)
	_set_ribbon_mesh(
		_double_body_mesh_resource,
		points,
		32.0,
		0.0,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
	)
	_set_ribbon_mesh(
		_double_highlight_mesh_resource,
		points,
		8.0,
		1.7,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
	)


func update_ribbon_meshes(
		points: PackedVector2Array,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
		point_ages := PackedFloat32Array(),
		point_depths := PackedFloat32Array(),
) -> void:
	if depth_map != null:
		_set_ribbon_mesh(_edge_mesh_resource, points, 36.0, 0.0, depth_length, ribbon_alpha, hit_target, point_ages, 0.0, -1.0, -1.0, point_depths)
		_set_ribbon_mesh(_body_mesh_resource, points, 32.0, 0.0, depth_length, ribbon_alpha, hit_target, point_ages, 0.0, -1.0, -1.0, point_depths)
		_set_ribbon_mesh(_highlight_mesh_resource, points, 8.0, 1.7, depth_length, ribbon_alpha, hit_target, point_ages, 0.0, -1.0, -1.0, point_depths)
		_update_depth_banded_ribbons(
			"",
			points,
			depth_length,
			ribbon_alpha,
			hit_target,
			point_ages,
			point_depths,
		)
		return
	_set_ribbon_mesh(
		_edge_mesh_resource,
		points,
		36.0,
		0.0,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
	)
	_set_ribbon_mesh(
		_body_mesh_resource,
		points,
		32.0,
		0.0,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
	)
	_set_ribbon_mesh(
		_highlight_mesh_resource,
		points,
		8.0,
		1.7,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
	)


func _set_ribbon_mesh(
		mesh: ArrayMesh,
		points: PackedVector2Array,
		base_width: float,
		center_offset: float,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
		point_ages: PackedFloat32Array = PackedFloat32Array(),
		global_distance_offset := 0.0,
		depth_origin := -1.0,
		effective_depth_length := -1.0,
		point_depths := PackedFloat32Array(),
) -> void:
	mesh.clear_surfaces()
	if points.size() < 2:
		return

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var distance := 0.0
	var previous_point := points[0]
	var render_depth_origin := depth_origin
	var render_length := effective_depth_length
	if depth_map != null:
		var render_metrics := _depth_render_metrics(points, depth_length, point_depths)
		if render_depth_origin < 0.0:
			render_depth_origin = float(render_metrics["depth_origin"])
		if render_length <= 0.0:
			render_length = float(render_metrics["effective_length"])
	for i in points.size():
		if i > 0:
			distance += previous_point.distance_to(points[i])
			previous_point = points[i]
		var tangent := _tangent_for_points(points, i, Vector2.UP)
		var normal := Vector2(-tangent.y, tangent.x)
		var effective_distance := distance + global_distance_offset
		if depth_map != null:
			var point_depth := render_depth_origin
			if i < point_depths.size():
				point_depth = point_depths[i]
			else:
				var point_sample := _sample_depth_for_stream_effects(points[i])
				point_depth = float(point_sample.get("depth", render_depth_origin))
			effective_distance += absf(point_depth - render_depth_origin) * maxf(depth_distance_scale, 0.0)
		var depth_fraction := clampf(
			effective_distance / maxf(render_length if depth_map != null else depth_length, 1.0),
			0.0,
			1.0,
		)
		var perspective_fraction := smoothstep(0.0, 1.0, depth_fraction)
		var width_scale := lerpf(source_width_scale, distal_width_scale, perspective_fraction)
		var width := base_width * width_scale
		# Fast aim changes do not make the whole jet fat. They make its landing end
		# bloom outward, keeping the source readable while showing lost control
		# where accuracy matters.
		var distal_bloom := smoothstep(0.25, 1.0, depth_fraction)
		width += _aim_bloom_radius * bloom_width_scale * distal_bloom
		if i < point_ages.size():
			width *= _pulse_width_multiplier_for_age(point_ages[i])
		var fade := 1.0
		if not hit_target:
			var distal_fade := smoothstep(distal_fade_start, 1.0, depth_fraction)
			fade = lerpf(1.0, distal_end_alpha, distal_fade)
		var alpha := clampf(fade * ribbon_alpha, 0.0, 1.0)
		var center := points[i] + normal * center_offset
		var left := center - normal * width * 0.5
		var right := center + normal * width * 0.5
		vertices.append(Vector3(left.x, left.y, 0.0))
		vertices.append(Vector3(right.x, right.y, 0.0))
		uvs.append(Vector2(0.0, distance / maxf(stream_tile_length, 1.0)))
		uvs.append(Vector2(1.0, distance / maxf(stream_tile_length, 1.0)))
		colors.append(Color(1.0, 1.0, 1.0, alpha))
		colors.append(Color(1.0, 1.0, 1.0, alpha))
	for i in range(points.size() - 1):
		var current := i * 2
		var next := (i + 1) * 2
		indices.append(current)
		indices.append(next)
		indices.append(current + 1)
		indices.append(current + 1)
		indices.append(next)
		indices.append(next + 1)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _hide_depth_band_group(prefix: String) -> void:
	for key in ["%sedge" % prefix, "%sbody" % prefix, "%shighlight" % prefix]:
		if not _depth_band_resources.has(key):
			continue
		for band_mesh in _depth_band_resources[key]:
			band_mesh.clear_surfaces()
		for band_node in _depth_band_nodes[key]:
			band_node.visible = false


func _tangent_at(index: int, fallback: Vector2) -> Vector2:
	return _tangent_for_points(_current_points, index, fallback)


func _tangent_for_points(points: PackedVector2Array, index: int, fallback: Vector2) -> Vector2:
	if points.size() < 2 or index < 0:
		return fallback
	var next_index := mini(index + 1, points.size() - 1)
	var previous_index := maxi(index - 1, 0)
	var tangent := points[next_index] - points[previous_index]
	return tangent.normalized() if tangent.length_squared() > 0.001 else fallback
