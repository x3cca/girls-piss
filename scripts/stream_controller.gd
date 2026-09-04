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

var input_controller: InputController
var pressure_model: PressureModel

var _edge_line: Line2D
var _body_line: Line2D
var _highlight_line: Line2D
var _droplets: CPUParticles2D
var _impact: CPUParticles2D
var _parcels: Array[Dictionary] = []
var _emission_accumulator := 0.0
var _last_hit_target: Object
var _last_hit_position := Vector2.INF
var _current_points := PackedVector2Array()

func _ready() -> void:
	_edge_line = _make_line(14.0, Color("#493719"))
	_body_line = _make_line(9.0, liquid_color)
	_highlight_line = _make_line(2.5, Color("#fff3a0"))
	add_child(_edge_line)
	add_child(_body_line)
	add_child(_highlight_line)

	_droplets = CPUParticles2D.new()
	_droplets.amount = 7
	_droplets.lifetime = 0.42
	_droplets.randomness = 0.55
	_droplets.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	_droplets.direction = Vector2.UP
	_droplets.spread = 38.0
	_droplets.initial_velocity_min = 28.0
	_droplets.initial_velocity_max = 64.0
	_droplets.gravity = Vector2(0.0, 38.0)
	_droplets.scale_amount_min = 0.45
	_droplets.scale_amount_max = 0.9
	_droplets.color = Color("#f7e479")
	_droplets.texture = _particle_texture()
	_droplets.emitting = true
	add_child(_droplets)

	_impact = CPUParticles2D.new()
	_impact.amount = 18
	_impact.lifetime = 0.33
	_impact.one_shot = true
	_impact.explosiveness = 0.92
	_impact.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	_impact.direction = Vector2.DOWN
	_impact.spread = 100.0
	_impact.initial_velocity_min = 24.0
	_impact.initial_velocity_max = 75.0
	_impact.gravity = Vector2(0.0, 120.0)
	_impact.scale_amount_min = 0.4
	_impact.scale_amount_max = 1.1
	_impact.color = Color("#fff0a0")
	_impact.texture = _particle_texture()
	add_child(_impact)
	queue_redraw()

func _process(delta: float) -> void:
	if input_controller == null or pressure_model == null:
		return
	var pressure := pressure_model.effective_pressure
	var direction := input_controller.aim_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	_update_parcels(delta)
	_emit_parcels(direction, pressure, delta)
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
	_droplets.emitting = pressure > 0.15
	queue_redraw()

func _update_parcels(delta: float) -> void:
	# Parcels are independent. Once emitted, their launch velocity never reads the
	# input controller again; only gravity changes that parcel's velocity.
	for parcel in _parcels:
		var velocity: Vector2 = parcel["velocity"]
		parcel["position"] = parcel["position"] + velocity * delta + gravity * (delta * delta * 0.5)
		parcel["velocity"] = velocity + gravity * delta
		parcel["age"] = float(parcel["age"]) + delta

func _emit_parcels(direction: Vector2, pressure: float, delta: float) -> void:
	var speed := lerpf(launch_speed_min, launch_speed_max, clampf(pressure, 0.0, 1.0))
	_emission_accumulator += delta
	var interval := 1.0 / 60.0
	var emitted := 0
	var launch_velocity := direction * speed
	while _emission_accumulator >= interval and emitted < 4:
		_emission_accumulator -= interval
		emitted += 1
	# Always emit at least one parcel per rendered frame. This keeps the source
	# continuous on high-refresh displays while the accumulator catches up on
	# slower frames.
	emitted = maxi(emitted, 1)
	for _i in emitted:
		_parcels.push_front({"position": source_position, "velocity": launch_velocity, "launch_velocity": launch_velocity, "age": 0.0})
	var stream_age := lerpf(minimum_length, maximum_length, clampf(pressure, 0.0, 1.0)) / maxf(speed, 1.0)
	var lifetime := minf(parcel_lifetime, stream_age)
	while not _parcels.is_empty() and (float(_parcels.back()["age"]) > lifetime or _parcels.size() > max_parcels):
		_parcels.pop_back()

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
		var parcel_index := clampi(roundi(fraction * float(_parcels.size() - 1)), 0, _parcels.size() - 1)
		points.append(_parcels[parcel_index]["position"])
	return points

func _truncate_at_target(points: PackedVector2Array) -> Dictionary:
	if points.size() < 2:
		return {}
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
		return {"points": clipped, "target": target, "position": result.position, "normal": result.normal}
	return {}

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

func _make_line(width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 1.0
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.68, 0.86))
	curve.add_point(Vector2(1.0, 0.18))
	line.width_curve = curve
	return line

func _particle_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 12
	texture.height = 12
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
