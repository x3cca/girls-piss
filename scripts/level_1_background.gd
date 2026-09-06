extends Node2D

class_name Level1Background

## Scales the supplied 1080x1920 artwork as a single portrait composition.
## Keeping these pieces separate lets the toilet and its targets sit between the
## wall and floor layers without baking gameplay into the illustration.

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)

@export var wall_y := 0.0
@export var floor_y := 522.0
@export var wall_shadow_y := 495.0

@onready var _wall: Sprite2D = $BackWall
@onready var _floor: Sprite2D = $Floor
@onready var _wall_shadow: Sprite2D = $WallShadow
@onready var _wall_paper: Sprite2D = $WallPaper
@onready var _toilet_paper: Sprite2D = $ToiletPaper
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

	# The supplied reference is exactly 9:16. Independent scaling preserves the
	# full composition when the app is expanded to a taller or wider viewport.
	var composition_scale := Vector2(
		viewport_size.x / REFERENCE_SIZE.x,
		viewport_size.y / REFERENCE_SIZE.y,
	)
	_set_sprite_layout(_wall, wall_y, composition_scale)
	_set_sprite_layout(_floor, floor_y, composition_scale)
	_set_sprite_layout(_wall_shadow, wall_shadow_y, composition_scale)
	_set_sprite_layout(_wall_paper, 118.0, composition_scale)
	_wall_paper.position.x = 887.0 * composition_scale.x
	_set_sprite_layout(_toilet_paper, 118.0, composition_scale)
	_toilet_paper.position.x = 887.0 * composition_scale.x


func _set_sprite_layout(sprite: Sprite2D, y: float, composition_scale: Vector2) -> void:
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.position.y = y * composition_scale.y
	sprite.scale = composition_scale
