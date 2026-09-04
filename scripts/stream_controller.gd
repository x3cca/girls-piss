extends Node2D
class_name LiquidStream

signal wet_target_hit(target: WettableTarget, amount: float, position: Vector2, normal: Vector2)

@export var source_position := Vector2(360.0, 1090.0)
@export_range(150.0, 800.0, 1.0) var minimum_length := 150.0
@export_range(150.0, 800.0, 1.0) var maximum_length := 620.0
@export_range(16, 48, 1) var ribbon_points := 28
@export var wobble_frequency := 4.0
@export var collision_mask := 1
@export var liquid_color := Color("#57e6df")

var input_controller: InputController
var pressure_model: PressureModel

var _edge_line: Line2D
var _body_line: Line2D
var _highlight_line: Line2D
var _droplets: CPUParticles2D
var _impact: CPUParticles2D
var _time := 0.0
var _last_hit_target: Object
var _last_hit_position := Vector2.INF
var _current_points := PackedVector2Array()

func _ready() -> void:
	_edge_line = _make_line(18.0, Color("#102c4b"))
	_body_line = _make_line(12.0, liquid_color)
	_highlight_line = _make_line(3.0, Color("#b8fff4"))
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
	_droplets.color = Color("#8bf6ec")
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
	_impact.color = Color("#b8fff4")
	_impact.texture = _particle_texture()
	add_child(_impact)
	queue_redraw()

func _process(delta: float) -> void:
	if input_controller == null or pressure_model == null:
		return
	_time += delta
	var pressure := pressure_model.effective_pressure
	var direction := input_controller.aim_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	_current_points = _build_centerline(direction, pressure)
	var hit := _truncate_at_target(_current_points)
	if not hit.is_empty():
		_current_points = hit.points
		_emit_hit(hit, pressure * delta * 0.50)

	_edge_line.points = _current_points
	_body_line.points = _current_points
	_highlight_line.points = _offset_highlight(_current_points, direction)
	_droplets.position = _current_points[min(8, _current_points.size() - 1)] if not _current_points.is_empty() else source_position
	_droplets.direction = direction
	_droplets.emitting = pressure > 0.15
	queue_redraw()

func _build_centerline(direction: Vector2, pressure: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var length := lerpf(minimum_length, maximum_length, clampf(pressure, 0.0, 1.0))
	var perpendicular := Vector2(-direction.y, direction.x)
	var count := maxi(16, ribbon_points)
	for i in count:
		var t := float(i) / float(count - 1)
		var envelope := sin(t * PI) * (0.7 + pressure * 0.7)
		var lateral := sin(_time * wobble_frequency + t * 8.0) * (5.0 + 12.0 * pressure) * envelope
		points.append(source_position + direction * (length * t) + perpendicular * lateral)
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

func _offset_highlight(points: PackedVector2Array, direction: Vector2) -> PackedVector2Array:
	var offset := Vector2(-direction.y, direction.x) * 1.5
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result

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

func _draw() -> void:
	# Nozzle and a small halo establish the source without competing with the ribbon.
	draw_circle(source_position, 22.0, Color("#102c4b"))
	draw_circle(source_position, 14.0, Color("#2e7890"))
	draw_circle(source_position + Vector2(0.0, -2.0), 7.0, Color("#b8fff4"))
