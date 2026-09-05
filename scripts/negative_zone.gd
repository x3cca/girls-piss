extends Area2D

class_name NegativeZone

## An authored bad area. Points are stored in viewport-normalized coordinates so
## the same zone remains useful when the portrait viewport is resized.

@export var normalized_points := PackedVector2Array(
	[
		Vector2(0.05, 0.10),
		Vector2(0.30, 0.10),
		Vector2(0.26, 0.30),
		Vector2(0.07, 0.30),
	],
)
@export var zone_color := Color(0.86, 0.20, 0.34, 0.16)
@export var outline_color := Color(1.0, 0.34, 0.46, 0.42)
@export var outline_width := 3.0
@export var show_zone := true

var _viewport_signature := Vector2.ZERO
var _normalized_signature := PackedVector2Array()
var _viewport_polygon := PackedVector2Array()
var _polygon_node: Polygon2D
var _collision_polygon: CollisionPolygon2D


func _ready() -> void:
	add_to_group("negative_zone")
	monitoring = false
	monitorable = false
	_collision_polygon = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	_polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	_sync_polygon()


func _process(_delta: float) -> void:
	_sync_polygon()


func process_frame(_delta: float) -> void:
	_sync_polygon()


func contains_point(world_position: Vector2) -> bool:
	_sync_polygon()
	if _viewport_polygon.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(to_local(world_position), _viewport_polygon)


func is_point_inside(world_position: Vector2) -> bool:
	return contains_point(world_position)


func get_polygon() -> PackedVector2Array:
	_sync_polygon()
	return _viewport_polygon.duplicate()


func _sync_polygon() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = Vector2(720.0, 1280.0)
	if (
			_viewport_signature == viewport_size
			and _normalized_signature == normalized_points
			and _viewport_polygon.size() == normalized_points.size()
	):
		return
	_viewport_signature = viewport_size
	_normalized_signature = normalized_points.duplicate()
	_viewport_polygon = PackedVector2Array()
	for point in normalized_points:
		_viewport_polygon.append(point * viewport_size)
	if _polygon_node:
		_polygon_node.polygon = _viewport_polygon
		_polygon_node.color = zone_color
		_polygon_node.visible = show_zone
	if _collision_polygon:
		_collision_polygon.polygon = _viewport_polygon
	queue_redraw()


func _draw() -> void:
	if not show_zone or _viewport_polygon.size() < 2:
		return
	draw_polyline(_closed_polygon(), outline_color, outline_width, true)


func _closed_polygon() -> PackedVector2Array:
	var closed := _viewport_polygon.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
