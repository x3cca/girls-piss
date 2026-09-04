extends Node2D

class_name LiquidStream

signal wet_target_hit(target: WettableTarget, amount: float, position: Vector2, normal: Vector2)

@export var source_position := Vector2(360.0, 1320.0)
@export_range(150.0, 800.0, 1.0) var minimum_length := 150.0
@export_range(150.0, 1200.0, 1.0) var maximum_length := 620.0
@export_range(24, 32, 1) var ribbon_points := 28
@export var launch_speed_min := 560.0
@export var launch_speed_max := 1120.0
@export var gravity := Vector2(0.0, 360.0)
@export var parcel_lifetime := 1.35
@export_range(32, 128, 1) var max_parcels := 96
@export var collision_mask := 1
@export var liquid_color := Color("#f1d34f")
@export var normal_emission_rate := 60.0
@export var sputtering_emission_rate := 10.0
@export var sputter_burst_min_interval := 0.16
@export var sputter_burst_max_interval := 1.35

var input_controller: InputController
var pressure_model: PressureModel

@onready var _edge_line: Line2D = $EdgeRibbon
@onready var _body_line: Line2D = $BodyRibbon
@onready var _highlight_line: Line2D = $HighlightRibbon
@onready var _droplets: CPUParticles2D = $Droplets
@onready var _impact: CPUParticles2D = $ImpactBurst
@onready var _sputter_burst: CPUParticles2D = $SputterBurst
var _parcels: Array[Dictionary] = []
var _emission_accumulator := 0.0
var _sputter_accumulator := 0.0
var _last_hit_target: Object
var _last_hit_position := Vector2.INF
var _current_points := PackedVector2Array()


func _ready() -> void:
	var width_curve := _width_curve()
	_edge_line.width_curve = width_curve
	_body_line.width_curve = width_curve
	_highlight_line.width_curve = width_curve
	queue_redraw()


func _process(delta: float) -> void:
	if input_controller == null or pressure_model == null:
		return
	var pressure := pressure_model.effective_pressure
	var direction := input_controller.aim_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	update_parcels(delta)
	var sputter_intensity := pressure_model.sputter_intensity
	if pressure_model.exhausted:
		_emission_accumulator = 0.0
	else:
		emit_parcels(direction, pressure, delta, sputter_intensity)
	_current_points = _build_parcel_centerline(direction, pressure)
	var hit := _truncate_at_target(_current_points)
	if not hit.is_empty():
		_current_points = hit.points
		_emit_hit(hit, pressure * delta * 0.50)

	_edge_line.points = _current_points
	_body_line.points = _current_points
	_highlight_line.points = _offset_highlight(_current_points)
	var droplet_index := mini(8, _current_points.size() - 2)
	_droplets.position = _current_points[droplet_index] if droplet_index >= 0 else source_position
	_droplets.direction = _tangent_at(droplet_index, direction)
	_update_sputter_effects(delta, direction, sputter_intensity, pressure_model.exhausted)
	queue_redraw()


func update_parcels(delta: float) -> void:
	# Parcels are independent. Once emitted, their launch velocity never reads the
	# input controller again; only gravity changes that parcel's velocity.
	for parcel in _parcels:
		var velocity: Vector2 = parcel["velocity"]
		parcel["position"] = parcel["position"] + velocity * delta + gravity * (delta * delta * 0.5)
		parcel["velocity"] = velocity + gravity * delta
		parcel["age"] = float(parcel["age"]) + delta


func emit_parcels(
		direction: Vector2,
		pressure: float,
		delta: float,
		sputter_intensity := 0.0,
) -> void:
	var speed := lerpf(launch_speed_min, launch_speed_max, clampf(pressure, 0.0, 1.0))
	var emission_rate := lerpf(
		normal_emission_rate,
		sputtering_emission_rate,
		clampf(sputter_intensity, 0.0, 1.0),
	)
	_emission_accumulator += delta
	var interval := 1.0 / maxf(emission_rate, 1.0)
	var emitted := 0
	var launch_velocity := direction * speed
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
			},
		)
		parcel_index += 1
	var stream_age := lerpf(minimum_length, maximum_length, clampf(pressure, 0.0, 1.0)) / maxf(
		speed,
		1.0,
	)
	var lifetime := minf(parcel_lifetime, stream_age)
	while (
			not _parcels.is_empty()
			and (float(_parcels.back()["age"]) > lifetime or _parcels.size() > max_parcels)
	):
		_parcels.pop_back()


func get_sputter_profile(intensity: float, is_exhausted: bool) -> Dictionary:
	var sputter := clampf(intensity, 0.0, 1.0)
	var fade := clampf((sputter - 0.68) / 0.32, 0.0, 1.0)
	return {
		"ambient_amount": roundi(lerpf(7.0, 14.0, sputter)),
		"ambient_lifetime": lerpf(0.42, 0.28, sputter),
		"ambient_velocity_min": lerpf(28.0, 52.0, sputter),
		"ambient_velocity_max": lerpf(64.0, 112.0, sputter),
		"burst_amount": roundi(lerpf(3.0, 28.0, sputter)),
		"burst_velocity_min": lerpf(20.0, 78.0, sputter),
		"burst_velocity_max": lerpf(48.0, 156.0, sputter),
		"burst_interval": lerpf(sputter_burst_max_interval, sputter_burst_min_interval, sputter),
		"emission_rate": 0.0 if is_exhausted else lerpf(
			normal_emission_rate,
			sputtering_emission_rate,
			sputter,
		),
		"ribbon_alpha": 0.0 if is_exhausted else 1.0 - fade * 0.62,
	}


func _update_sputter_effects(
		delta: float,
		direction: Vector2,
		intensity: float,
		is_exhausted: bool,
) -> void:
	var profile := get_sputter_profile(intensity, is_exhausted)
	_droplets.position = source_position
	_droplets.direction = direction
	_droplets.amount = int(profile["ambient_amount"])
	_droplets.lifetime = float(profile["ambient_lifetime"])
	_droplets.initial_velocity_min = float(profile["ambient_velocity_min"])
	_droplets.initial_velocity_max = float(profile["ambient_velocity_max"])
	_droplets.emitting = true
	_sputter_burst.position = source_position
	_sputter_burst.direction = direction
	_sputter_burst.amount = int(profile["burst_amount"])
	_sputter_burst.initial_velocity_min = float(profile["burst_velocity_min"])
	_sputter_burst.initial_velocity_max = float(profile["burst_velocity_max"])
	_sputter_accumulator += delta
	var burst_interval := float(profile["burst_interval"])
	if intensity < 0.05:
		_sputter_accumulator = 0.0
	elif _sputter_accumulator >= burst_interval:
		_sputter_accumulator = fmod(_sputter_accumulator, burst_interval)
		_sputter_burst.restart()
	var ribbon_alpha := float(profile["ribbon_alpha"])
	_edge_line.modulate.a = ribbon_alpha
	_body_line.modulate.a = ribbon_alpha
	_highlight_line.modulate.a = ribbon_alpha


func _build_parcel_centerline(_direction: Vector2, _pressure: float) -> PackedVector2Array:
	# Render a capped sample of the moving parcel chain. The visible ribbon is an
	# interpolation of locked-in parcels, not a fresh curve from the current aim.
	var points := PackedVector2Array()
	if _parcels.is_empty():
		points.append(source_position)
		return points
	points.append(_parcels[0]["position"])
	var point_count := mini(ribbon_points, _parcels.size())
	for i in range(1, point_count):
		var fraction := float(i) / float(maxi(point_count - 1, 1))
		var parcel_index := clampi(
			roundi(fraction * float(_parcels.size() - 1)),
			0,
			_parcels.size() - 1,
		)
		points.append(_parcels[parcel_index]["position"])
	return points


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
	if target != _last_hit_target or _last_hit_position.distance_to(position) > 16.0:
		_impact.position = position
		_impact.direction = normal
		_impact.restart()
	_last_hit_target = target
	_last_hit_position = position
	wet_target_hit.emit(target, amount, position, normal)


func _offset_highlight(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		var tangent := _tangent_at(i, Vector2.UP)
		result.append(points[i] + Vector2(-tangent.y, tangent.x) * 1.2)
	return result


func _tangent_at(index: int, fallback: Vector2) -> Vector2:
	if _current_points.size() < 2 or index < 0:
		return fallback
	var next_index := mini(index + 1, _current_points.size() - 1)
	var previous_index := maxi(index - 1, 0)
	var tangent := _current_points[next_index] - _current_points[previous_index]
	return tangent.normalized() if tangent.length_squared() > 0.001 else fallback


func _width_curve() -> Curve:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.0
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.68, 0.86))
	curve.add_point(Vector2(1.0, 0.18))
	return curve
