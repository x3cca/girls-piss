extends Node2D

class_name TouchReticle

## Raw touch target indicator. It follows the finger directly; the stream/player
## aim uses a separate smoothed value.

@export var reticle_size := 48.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_apply_size()
	visible = false


func set_touch_target(target_position: Vector2, active: bool) -> void:
	visible = active
	if active:
		position = target_position


func _apply_size() -> void:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return
	var texture_width := maxf(float(_sprite.texture.get_width()), 1.0)
	_sprite.scale = Vector2.ONE * reticle_size / texture_width
