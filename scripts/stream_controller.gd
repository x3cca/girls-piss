extends Node2D

class_name LiquidStream

signal wet_target_hit(target: WettableTarget, amount: float, position: Vector2, normal: Vector2)
signal drawing_point_updated(position: Vector2, active: bool)
signal pulse_triggered(amplitude: float)

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
@onready var _droplets: CPUParticles2D = $Droplets
@onready var _impact: CPUParticles2D = $ImpactBurst
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
var _double_point_ages := PackedFloat32Array()
var _preview_beat_elapsed := 0.0
var _pulses: Array[Dictionary] = []


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
	_set_live_visuals(true)
	queue_redraw()


func _process(delta: float) -> void:
	if input_controller == null:
		return
	if not _live_enabled:
		# Replay owns the only visible path after tracing completes. Keep the
		# physics chain untouched until the level is reset, but do not advance or
		# render it while the replay is on screen.
		drawing_point_updated.emit(Vector2.ZERO, false)
		return
	var is_pissing := input_controller.is_pissing()
	var target := input_controller.get_target_position()
	_update_aim_bloom(target, delta)
	if not _stream_target_initialized:
		_stream_target_position = target
		_stream_target_initialized = true
	else:
		_advance_stream_target(target, delta)
	var direction := (_stream_target_position - source_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	if is_pissing:
		update_parcels(delta)
		_update_preview_pulses(delta)
		emit_parcels(_stream_target_position, delta)
	else:
		# Releasing Space/a finger closes the stream immediately. A later press
		# starts a fresh visible jet while the crosshair keeps its position.
		_parcels.clear()
		_double_parcels.clear()
		_emission_accumulator = 0.0
		_preview_beat_elapsed = 0.0
		_pulses.clear()
	if not _double_stream_active:
		_double_parcels.clear()
	var current_samples := _build_parcel_samples(_parcels)
	_current_points = _positions_from_samples(current_samples)
	_current_point_ages = _ages_from_samples(current_samples)
	var double_samples := _build_parcel_samples(_double_parcels)
	var double_points := _positions_from_samples(double_samples)
	_double_point_ages = _ages_from_samples(double_samples)
	if _current_points.size() >= 2:
		_current_stream_direction = _tangent_for_points(_current_points, 0, direction)
	elif is_pissing:
		_current_stream_direction = direction
	_impact.spread = _impact_spread()
	var hit := _truncate_at_target(_current_points, _current_point_ages)
	var hit_target := not hit.is_empty()
	_impact.emitting = false
	if is_pissing and not hit.is_empty():
		_current_points = hit.points
		_current_point_ages = hit.ages
		_emit_hit(hit, delta)
	elif is_pissing and _current_points.size() >= 2:
		_emit_floor_impact(_current_points[_current_points.size() - 1])

	var profile := get_stream_profile()
	update_ribbon_meshes(
		_current_points,
		_path_length(_current_points),
		float(profile["ribbon_alpha"]) if is_pissing else 0.0,
		hit_target,
		_current_point_ages,
	)
	_update_double_stream_meshes(
		double_points,
		_path_length(double_points),
		float(profile["ribbon_alpha"]) if is_pissing else 0.0,
		hit_target,
		_double_point_ages,
	)
	var droplet_index := mini(8, _current_points.size() - 2)
	_droplets.position = _current_points[droplet_index] if droplet_index >= 0 else source_position
	_droplets.direction = _tangent_at(droplet_index, direction)
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
	_parcels.clear()
	_double_parcels.clear()
	_emission_accumulator = 0.0
	_current_points = PackedVector2Array()
	_current_point_ages = PackedFloat32Array()
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


func _set_live_visuals(enabled: bool) -> void:
	_edge_mesh.visible = enabled
	_body_mesh.visible = enabled
	_highlight_mesh.visible = enabled
	_double_edge_mesh.visible = enabled and _double_stream_active
	_double_body_mesh.visible = enabled and _double_stream_active
	_double_highlight_mesh.visible = enabled and _double_stream_active
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
	var travel_time := _travel_time_for_target(launch_target)
	var launch_velocity := _launch_velocity_for_target(launch_target)
	chain.push_front(
		{
			"position": source_position,
			"velocity": launch_velocity,
			"launch_velocity": launch_velocity,
			"launch_target": launch_target,
			"bloom_offset": bloom_offset,
			"age": 0.0,
			"lifetime": minf(parcel_lifetime, travel_time),
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
	_droplets.emitting = true
	var ribbon_alpha := float(profile["ribbon_alpha"])
	_edge_mesh.modulate.a = ribbon_alpha
	_body_mesh.modulate.a = ribbon_alpha
	_highlight_mesh.modulate.a = ribbon_alpha


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
		samples.append({ "position": source_position, "age": 0.0 })
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
			},
		)
	return samples


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
	return _figure_eight_offset(_bloom_angle, get_double_bloom_radius())


func _figure_eight_offset(phase: float, radius: float) -> Vector2:
	# Gerono's lemniscate traces a horizontal figure eight. Keeping the vertical
	# component at half height preserves the configured radius at the widest
	# points while the two lobes cross cleanly through the aim point.
	var horizontal := sin(phase)
	return Vector2(horizontal, horizontal * cos(phase)) * radius


func _path_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	return maxf(length, 1.0)


func _launch_velocity_for_target(target_position: Vector2) -> Vector2:
	# Pick a stable flight time, then solve the ordinary projectile equation so
	# each newly emitted parcel is aimed at the eased crosshair target.
	var offset := target_position - source_position
	var travel_time := _travel_time_for_target(target_position)
	return (offset - gravity * travel_time * travel_time * 0.5) / travel_time


func _travel_time_for_target(target_position: Vector2) -> float:
	return maxf(
		target_position.distance_to(source_position) / maxf(stream_speed, 1.0),
		0.12,
	)


func _truncate_at_target(
		points: PackedVector2Array,
		point_ages := PackedFloat32Array(),
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
		for j in range(i + 1):
			clipped.append(points[j])
			clipped_ages.append(
				point_ages[j] if j < point_ages.size() else 0.0,
			)
		var segment_length := points[i].distance_to(points[i + 1])
		var segment_fraction := 0.0
		if segment_length > 0.001:
			segment_fraction = points[i].distance_to(result.position) / segment_length
		var start_age := point_ages[i] if i < point_ages.size() else 0.0
		var end_age := point_ages[i + 1] if i + 1 < point_ages.size() else start_age
		clipped.append(result.position)
		clipped_ages.append(lerpf(start_age, end_age, clampf(segment_fraction, 0.0, 1.0)))
		return {
			"points": clipped,
			"ages": clipped_ages,
			"target": target,
			"position": result.position,
			"normal": result.normal,
		}
	return { }


func _emit_hit(hit: Dictionary, amount: float) -> void:
	var target: WettableTarget = hit.target
	var position: Vector2 = hit.position
	var normal: Vector2 = hit.normal
	_impact.position = position
	_impact.direction = normal
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
	_impact.emitting = true


func _update_double_stream_meshes(
		points: PackedVector2Array,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
		point_ages: PackedFloat32Array,
) -> void:
	var should_render := (
			_live_enabled
			and _double_stream_active
			and ribbon_alpha > 0.0
			and points.size() >= 2
	)
	_double_edge_mesh.visible = should_render
	_double_body_mesh.visible = should_render
	_double_highlight_mesh.visible = should_render
	if not should_render:
		_double_edge_mesh_resource.clear_surfaces()
		_double_body_mesh_resource.clear_surfaces()
		_double_highlight_mesh_resource.clear_surfaces()
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
) -> void:
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
	for i in points.size():
		if i > 0:
			distance += previous_point.distance_to(points[i])
			previous_point = points[i]
		var tangent := _tangent_for_points(points, i, Vector2.UP)
		var normal := Vector2(-tangent.y, tangent.x)
		var depth_fraction := clampf(distance / maxf(depth_length, 1.0), 0.0, 1.0)
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


func _tangent_at(index: int, fallback: Vector2) -> Vector2:
	return _tangent_for_points(_current_points, index, fallback)


func _tangent_for_points(points: PackedVector2Array, index: int, fallback: Vector2) -> Vector2:
	if points.size() < 2 or index < 0:
		return fallback
	var next_index := mini(index + 1, points.size() - 1)
	var previous_index := maxi(index - 1, 0)
	var tangent := points[next_index] - points[previous_index]
	return tangent.normalized() if tangent.length_squared() > 0.001 else fallback
