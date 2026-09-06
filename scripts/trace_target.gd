extends Node2D

class_name TraceTarget

const ITEM_MATERIAL := preload("res://resources/materials/item_outline.tres")
## Match the item shader's source-pixel cutoff so every source pixel that is
## actually rendered is also hittable, including antialiased edges.
const DEFAULT_HIT_ALPHA_THRESHOLD := 0.001

## A lightweight sprite target used by ShapeTrace. Idle motion is deliberately
## restrained so the target feels buoyant without making its hit point unclear.

@export var bob_amplitude := 4.0
@export var bob_speed := 1.45
@export var rotation_amplitude := deg_to_rad(4.0)
@export var rotation_speed := 1.15
@export var scale_amplitude := 0.08
@export var hit_duration := 0.48
@export var hit_spin_turns := 1.35
## Health is drained by sustained stream contact. A zero damage rate is filled
## in by ShapeTrace from its authored contact duration.
@export_range(1.0, 100.0, 1.0) var max_health := 3.0
@export_range(0.0, 100.0, 0.1) var contact_damage_per_second := 0.0
## Contact spin accelerates as the remaining health gets lower.
@export var contact_spin_acceleration := 12.0
@export var max_contact_spin_speed := 28.0
## A forgiving screen-space buffer around visible pixels. Transparent padding
## remains empty beyond this buffer, unlike the old center-radius hitbox.
@export_range(0.0, 64.0, 1.0) var hitbox_padding := 24.0
@export_range(0.0, 1.0, 0.005) var hit_alpha_threshold := DEFAULT_HIT_ALPHA_THRESHOLD

var _anchor_position := Vector2.ZERO
var _center_position := Vector2.ZERO
var _phase := 0.0
var _time := 0.0
var _hit_elapsed := 0.0
var _hit_start_position := Vector2.ZERO
var _hit_start_rotation := 0.0
var _base_scale := Vector2.ONE
var _hit := false
var health := 0.0
var _contact_spin_angle := 0.0
var _contact_spin_velocity := 0.0
var _collision_polygons: Array[PackedVector2Array] = []
var _collision_mask_ready := false
var _collision_mask_texture: Texture2D
var _collision_mask_image: Image
var _collision_mask_source_rect := Rect2()
var _collision_mask_sprite_rect := Rect2()
var _collision_mask_flip_h := false
var _collision_mask_flip_v := false
var _collision_mask_threshold := -1.0

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		# Keep direct script instantiation useful in isolated tests and tools.
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.material = ITEM_MATERIAL
		add_child(_sprite)
	reset_target()


func configure(
		anchor_position: Vector2,
		center_position: Vector2,
		texture: Texture2D,
		target_size: float,
		phase: float,
) -> void:
	_anchor_position = anchor_position
	_center_position = center_position
	_phase = phase
	_sprite.texture = texture
	_collision_polygons.clear()
	_collision_mask_ready = false
	_collision_mask_texture = null
	_collision_mask_image = null
	if texture != null:
		var texture_width := maxf(float(texture.get_width()), 1.0)
		_base_scale = Vector2.ONE * target_size / texture_width
	else:
		_base_scale = Vector2.ONE
	reset_target()


func set_anchor_position(anchor_position: Vector2) -> void:
	_anchor_position = anchor_position
	if not _hit:
		position = anchor_position


func set_center_position(center_position: Vector2) -> void:
	_center_position = center_position


func trigger_hit(center_position: Vector2) -> void:
	if _hit:
		return
	_center_position = center_position
	_hit_start_position = position
	_hit_start_rotation = rotation
	_hit_elapsed = 0.0
	_hit = true


func reset_target() -> void:
	_hit = false
	health = max_health
	_contact_spin_angle = 0.0
	_contact_spin_velocity = 0.0
	_hit_elapsed = 0.0
	_time = 0.0
	position = _anchor_position
	rotation = 0.0
	scale = _base_scale
	modulate.a = 1.0
	visible = true


func is_hit() -> bool:
	return _hit


func get_health_ratio() -> float:
	return clampf(health / maxf(max_health, 0.001), 0.0, 1.0)


func apply_contact(delta: float) -> bool:
	## Damage the item and build rotational momentum for as long as the stream
	## endpoint remains over its generous polygon hitbox.
	if _hit:
		return false
	var safe_delta := maxf(delta, 0.0)
	if safe_delta <= 0.0:
		return health <= 0.0
	health = maxf(
		health - contact_damage_per_second * safe_delta,
		0.0,
	)
	var damage_progress := 1.0 - get_health_ratio()
	var acceleration := contact_spin_acceleration * (1.0 + damage_progress * 3.0)
	_contact_spin_velocity = minf(
		_contact_spin_velocity + acceleration * safe_delta,
		max_contact_spin_speed,
	)
	_contact_spin_angle += _contact_spin_velocity * safe_delta
	return health <= 0.0


func configure_contact_duration(duration: float, force := false) -> void:
	if contact_damage_per_second > 0.0 and not force:
		return
	contact_damage_per_second = max_health / maxf(duration, 0.001)


func has_collision_mask() -> bool:
	return not _get_collision_polygons().is_empty()


func contains_point(world_position: Vector2) -> bool:
	## Test against collision polygons generated once from the item's alpha
	## silhouette. Sprite2D's transform is used so bobbing, rotation, and scale
	## affect the hitbox exactly as they affect the rendered item.
	if not is_instance_valid(_sprite):
		return false
	var polygons := _get_collision_polygons()
	if polygons.is_empty():
		return false
	var local_point := _sprite.to_local(world_position)
	var inside := false
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(local_point, polygon):
			# Opaque-to-polygons can return inner contours for holes. Toggling
			# keeps those holes empty while still supporting separate item parts.
			inside = not inside
	if inside:
		return true
	if hitbox_padding <= 0.0:
		return false
	for polygon in polygons:
		if _point_is_within_polygon_padding(world_position, polygon):
			return true
	return false


func _get_collision_polygons() -> Array[PackedVector2Array]:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return []
	var texture := _sprite.texture
	if _collision_mask_texture != texture or _collision_mask_image == null:
		_collision_mask_texture = texture
		_collision_mask_image = texture.get_image()
	var image := _collision_mask_image
	if image == null or image.is_empty():
		return []
	var source_rect := _get_source_rect(image)
	var sprite_rect := _sprite.get_rect()
	if (
		_collision_mask_ready
		and _collision_mask_texture == texture
		and _collision_mask_source_rect == source_rect
		and _collision_mask_sprite_rect == sprite_rect
		and _collision_mask_flip_h == _sprite.flip_h
		and _collision_mask_flip_v == _sprite.flip_v
		and is_equal_approx(_collision_mask_threshold, hit_alpha_threshold)
	):
		return _collision_polygons

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, hit_alpha_threshold)
	var source_polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(
		source_rect,
		2.0,
	)
	_collision_polygons.clear()
	for source_polygon in source_polygons:
		var local_polygon := PackedVector2Array()
		for source_point in source_polygon:
			var sprite_uv := Vector2(
				(source_point.x - source_rect.position.x) / source_rect.size.x,
				(source_point.y - source_rect.position.y) / source_rect.size.y,
			)
			if _sprite.flip_h:
				sprite_uv.x = 1.0 - sprite_uv.x
			if _sprite.flip_v:
				sprite_uv.y = 1.0 - sprite_uv.y
			local_polygon.append(sprite_rect.position + sprite_uv * sprite_rect.size)
		if local_polygon.size() >= 3:
			_collision_polygons.append(local_polygon)
	_collision_mask_ready = true
	_collision_mask_texture = texture
	_collision_mask_source_rect = source_rect
	_collision_mask_sprite_rect = sprite_rect
	_collision_mask_flip_h = _sprite.flip_h
	_collision_mask_flip_v = _sprite.flip_v
	_collision_mask_threshold = hit_alpha_threshold
	return _collision_polygons


func _get_source_rect(image: Image) -> Rect2:
	var source_rect := Rect2(Vector2.ZERO, Vector2(image.get_width(), image.get_height()))
	if _sprite.region_enabled:
		return _sprite.region_rect
	var frame_size := source_rect.size / Vector2(_sprite.hframes, _sprite.vframes)
	return Rect2(Vector2(_sprite.frame_coords) * frame_size, frame_size)


func _point_is_within_polygon_padding(
		world_point: Vector2,
		polygon: PackedVector2Array,
) -> bool:
	for index in polygon.size():
		var edge_start := _sprite.to_global(polygon[index])
		var edge_end := _sprite.to_global(polygon[(index + 1) % polygon.size()])
		if _distance_to_segment(world_point, edge_start, edge_end) <= hitbox_padding:
			return true
	return false


func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var fraction := clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0,
	)
	return point.distance_to(segment_start + segment * fraction)


func intersects_segment(world_start: Vector2, world_end: Vector2) -> bool:
	## Preserve crossing detection for direct/tool callers with polygon edge
	## tests. Normal gameplay normally uses the exact endpoint test above for
	## sustained contact.
	var polygons := _get_collision_polygons()
	if polygons.is_empty():
		return false
	if contains_point(world_start) or contains_point(world_end):
		return true
	var local_start := _sprite.to_local(world_start)
	var local_end := _sprite.to_local(world_end)
	for polygon in polygons:
		for index in polygon.size():
			var local_edge_start := polygon[index]
			var local_edge_end := polygon[(index + 1) % polygon.size()]
			if _segments_intersect(
				local_start,
				local_end,
				local_edge_start,
				local_edge_end,
			):
				return true
			if hitbox_padding <= 0.0:
				continue
			var world_edge_start := _sprite.to_global(local_edge_start)
			var world_edge_end := _sprite.to_global(local_edge_end)
			if _segments_within_distance(
				world_start,
				world_end,
				world_edge_start,
				world_edge_end,
				hitbox_padding,
			):
				return true
	return false


func _segments_intersect(
		first_start: Vector2,
		first_end: Vector2,
		second_start: Vector2,
		second_end: Vector2,
) -> bool:
	var first_vector := first_end - first_start
	var second_vector := second_end - second_start
	var denominator := _cross(first_vector, second_vector)
	var between_starts := second_start - first_start
	if absf(denominator) <= 0.0001:
		return (
			absf(_cross(between_starts, first_vector)) <= 0.0001
			and (
				_point_is_on_segment(second_start, first_start, first_end)
				or _point_is_on_segment(second_end, first_start, first_end)
				or _point_is_on_segment(first_start, second_start, second_end)
				or _point_is_on_segment(first_end, second_start, second_end)
			)
		)
	var first_fraction := _cross(between_starts, second_vector) / denominator
	var second_fraction := _cross(between_starts, first_vector) / denominator
	return (
		first_fraction >= 0.0
		and first_fraction <= 1.0
		and second_fraction >= 0.0
		and second_fraction <= 1.0
	)


func _point_is_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> bool:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_squared_to(segment_start) <= 0.0001
	var fraction := (point - segment_start).dot(segment) / length_squared
	return fraction >= 0.0 and fraction <= 1.0


func _cross(first: Vector2, second: Vector2) -> float:
	return first.x * second.y - first.y * second.x


func _segments_within_distance(
		first_start: Vector2,
		first_end: Vector2,
		second_start: Vector2,
		second_end: Vector2,
		max_distance: float,
) -> bool:
	if _segments_intersect(first_start, first_end, second_start, second_end):
		return true
	return (
		_distance_to_segment(first_start, second_start, second_end) <= max_distance
		or _distance_to_segment(first_end, second_start, second_end) <= max_distance
		or _distance_to_segment(second_start, first_start, first_end) <= max_distance
		or _distance_to_segment(second_end, first_start, first_end) <= max_distance
	)


func _process(delta: float) -> void:
	_time += delta
	if _hit:
		_advance_hit(delta)
		return

	var bob_wave := sin(_time * bob_speed + _phase)
	position = _anchor_position + Vector2(0.0, bob_wave * bob_amplitude)
	rotation = sin(_time * rotation_speed + _phase) * rotation_amplitude + _contact_spin_angle
	scale = _base_scale * (1.0 + bob_wave * scale_amplitude)


func process_frame(delta: float) -> void:
	_process(delta)


func _advance_hit(delta: float) -> void:
	_hit_elapsed += delta
	var progress := clampf(_hit_elapsed / maxf(hit_duration, 0.001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var start_offset := _hit_start_position - _center_position
	var swirl_angle := TAU * hit_spin_turns * eased
	position = _center_position + start_offset.rotated(swirl_angle) * (1.0 - eased)
	rotation = _hit_start_rotation + swirl_angle
	scale = _base_scale * (1.0 - eased)
	modulate.a = 1.0 - eased
	if progress >= 1.0:
		visible = false
