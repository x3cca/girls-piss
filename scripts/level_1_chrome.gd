extends Node2D

class_name Level1Chrome

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)

@onready var _volume: Sprite2D = $Volume
@onready var _back_shadow: Sprite2D = $BackShadow
@onready var _back: Sprite2D = $Back
var _layout_signature := Vector2.ZERO


func _ready() -> void:
	_layout()


func _process(_delta: float) -> void:
	_layout()


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if viewport_size == _layout_signature:
		return
	_layout_signature = viewport_size
	var composition_scale := Vector2(
		viewport_size.x / REFERENCE_SIZE.x,
		viewport_size.y / REFERENCE_SIZE.y,
	)
	_set_sprite_layout(_volume, Vector2(875.0, 16.0), composition_scale)
	_set_sprite_layout(_back_shadow, Vector2(816.0, 1690.0), composition_scale)
	_set_sprite_layout(_back, Vector2(824.0, 1698.0), composition_scale)


func _set_sprite_layout(
		sprite: Sprite2D,
		authored_position: Vector2,
		composition_scale: Vector2,
) -> void:
	sprite.centered = false
	sprite.position = authored_position * composition_scale
	sprite.scale = composition_scale
