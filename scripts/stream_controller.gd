extends Node2D

class_name LiquidStream

signal wet_target_hit(target: WettableTarget, amount: float, position: Vector2, normal: Vector2)
signal drawing_point_updated(position: Vector2, active: bool)

@export var source_position := Vector2(360.0, 1320.0)
@export var stream_speed := 920.0
@export var target_smoothing_speed := 8.0
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

var input_controller: InputController

@onready var _edge_mesh: MeshInstance2D = $EdgeRibbon
@onready var _body_mesh: MeshInstance2D = $BodyRibbon
@onready var _highlight_mesh: MeshInstance2D = $HighlightRibbon
@onready var _droplets: CPUParticles2D = $Droplets
@onready var _impact: CPUParticles2D = $ImpactBurst
var _edge_mesh_resource := ArrayMesh.new()
var _body_mesh_resource := ArrayMesh.new()
var _highlight_mesh_resource := ArrayMesh.new()
var _parcels: Array[Dictionary] = []
var _emission_accumulator := 0.0
var _current_points := PackedVector2Array()
var _stream_target_position := Vector2.ZERO
var _stream_target_initialized := false
var _live_enabled := true


func _ready() -> void:
	_edge_mesh.mesh = _edge_mesh_resource
	_body_mesh.mesh = _body_mesh_resource
	_highlight_mesh.mesh = _highlight_mesh_resource
	_edge_mesh.modulate = Color("#493719")
	_body_mesh.modulate = liquid_color
	_highlight_mesh.modulate = Color("#fff3a0")
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
	if not _stream_target_initialized:
		_stream_target_position = target
		_stream_target_initialized = true
	else:
		var target_weight := 1.0 - exp(-target_smoothing_speed * delta)
		_stream_target_position = _stream_target_position.lerp(target, target_weight)
	var direction := (_stream_target_position - source_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	if is_pissing:
		update_parcels(delta)
		emit_parcels(_stream_target_position, delta)
	else:
		# Releasing Space/a finger closes the stream immediately. A later press
		# starts a fresh visible jet while the crosshair keeps its position.
		_parcels.clear()
		_emission_accumulator = 0.0
	_current_points = build_parcel_centerline()
	var hit := _truncate_at_target(_current_points)
	var hit_target := not hit.is_empty()
	_impact.emitting = false
	if is_pissing and not hit.is_empty():
		_current_points = hit.points
		_emit_hit(hit, delta)
	elif is_pissing and _current_points.size() >= 2:
		_emit_floor_impact(_current_points[_current_points.size() - 1])

	var profile := get_stream_profile()
	update_ribbon_meshes(
		_current_points,
		_path_length(_current_points),
		float(profile["ribbon_alpha"]) if is_pissing else 0.0,
		hit_target,
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


func set_live_enabled(enabled: bool) -> void:
	_live_enabled = enabled
	_set_live_visuals(enabled)
	if not enabled:
		drawing_point_updated.emit(Vector2.ZERO, false)


func is_live_enabled() -> bool:
	return _live_enabled


func get_stream_target_position() -> Vector2:
	return _stream_target_position


func reset_stream() -> void:
	_parcels.clear()
	_emission_accumulator = 0.0
	_current_points = PackedVector2Array()
	_stream_target_position = Vector2.ZERO
	_stream_target_initialized = false
	_impact.emitting = false
	_droplets.emitting = false
	queue_redraw()


func _set_live_visuals(enabled: bool) -> void:
	_edge_mesh.visible = enabled
	_body_mesh.visible = enabled
	_highlight_mesh.visible = enabled
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
	for parcel in _parcels:
		var velocity: Vector2 = parcel["velocity"]
		parcel["position"] = parcel["position"] + velocity * delta + gravity * (delta * delta * 0.5)
		parcel["velocity"] = velocity + gravity * delta
		parcel["age"] = float(parcel["age"]) + delta


func parcel_at(index: int) -> Dictionary:
	return _parcels[index]


func set_parcel_chain(parcels: Array[Dictionary]) -> void:
	_parcels = parcels.duplicate(true)


func emit_parcels(
		target_position: Vector2,
		delta: float,
) -> void:
	_emission_accumulator += delta
	var interval := 1.0 / maxf(normal_emission_rate, 1.0)
	var emitted := 0
	var travel_time := _travel_time_for_target(target_position)
	var launch_velocity := _launch_velocity_for_target(target_position)
	while _emission_accumulator >= interval and emitted < 4:
		_emission_accumulator -= interval
		emitted += 1
	# Always emit at least one parcel per rendered frame. This keeps the source
	# continuous on high-refresh displays while the accumulator catches up on
	# slower frames.
	emitted = maxi(emitted, 1)
	var parcel_index := 0
	while parcel_index < emitted:
		_parcels.push_front(
			{
				"position": source_position,
				"velocity": launch_velocity,
				"launch_velocity": launch_velocity,
				"age": 0.0,
				"lifetime": minf(parcel_lifetime, travel_time),
			},
		)
		parcel_index += 1
	while (
			not _parcels.is_empty()
			and (
				float(_parcels.back()["age"]) > float(_parcels.back().get("lifetime", parcel_lifetime))
				or _parcels.size() > max_parcels
			)
	):
		_parcels.pop_back()


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
	var points := PackedVector2Array()
	if _parcels.is_empty():
		points.append(source_position)
		return points
	var point_count := mini(ribbon_points, _parcels.size())
	for i in point_count:
		var fraction := float(i) / float(maxi(point_count - 1, 1))
		var parcel_index := clampi(
			roundi(fraction * float(_parcels.size() - 1)),
			0,
			_parcels.size() - 1,
		)
		points.append(_parcels[parcel_index]["position"])
	return points


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

func _truncate_at_target(points: PackedVector2Array) -> Dictionary:
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
		for j in range(i + 1):
			clipped.append(points[j])
		clipped.append(result.position)
		return {
			"points": clipped,
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


func update_ribbon_meshes(
		points: PackedVector2Array,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
) -> void:
	_set_ribbon_mesh(_edge_mesh_resource, points, 36.0, 0.0, depth_length, ribbon_alpha, hit_target)
	_set_ribbon_mesh(_body_mesh_resource, points, 32.0, 0.0, depth_length, ribbon_alpha, hit_target)
	_set_ribbon_mesh(
		_highlight_mesh_resource,
		points,
		8.0,
		1.7,
		depth_length,
		ribbon_alpha,
		hit_target,
	)


func _set_ribbon_mesh(
		mesh: ArrayMesh,
		points: PackedVector2Array,
		base_width: float,
		center_offset: float,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
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
