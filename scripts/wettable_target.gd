extends Node2D
class_name WettableTarget

signal wetness_changed(value: float)
signal soaked

@export var target_size := Vector2(172.0, 112.0)
@export var base_color := Color("#5f668e")
@export var accent_color := Color("#63d8d3")
@export var required_liquid := 1.0

var wetness := 0.0
var _soaked_emitted := false

func _ready() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("wet_target", self)
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = target_size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)
	queue_redraw()

func apply_liquid(amount: float, hit_position: Vector2) -> void:
	if amount <= 0.0 or wetness >= 1.0:
		return
	var previous := wetness
	wetness = clampf(wetness + amount / maxf(required_liquid, 0.001), 0.0, 1.0)
	if not is_equal_approx(previous, wetness):
		wetness_changed.emit(wetness)
		queue_redraw()
	if wetness >= 1.0 and not _soaked_emitted:
		_soaked_emitted = true
		soaked.emit()

func _draw() -> void:
	var rect := Rect2(-target_size * 0.5, target_size)
	# A crisp pixel/flat silhouette with a restrained wet fill.
	draw_style_box(_make_box(base_color.darkened(0.35), 14.0), rect.grow(5.0))
	draw_style_box(_make_box(base_color, 10.0), rect)
	if wetness > 0.0:
		var wet_rect := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * wetness))
		wet_rect.position.y = rect.end.y - wet_rect.size.y
		draw_style_box(_make_box(accent_color, 10.0), wet_rect)
		draw_line(Vector2(rect.position.x + 18.0, rect.end.y - 14.0), Vector2(rect.end.x - 18.0, rect.end.y - 14.0), Color(1, 1, 1, 0.18), 2.0)

func _make_box(color: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius)
	box.corner_radius_top_right = int(radius)
	box.corner_radius_bottom_left = int(radius)
	box.corner_radius_bottom_right = int(radius)
	return box
