extends CanvasLayer

class_name FailureTransition

signal finished

@onready var _frame: Sprite2D = $Frame

var _tween: Tween
var _center := Vector2.ZERO
var _travel := Vector2.ZERO
var _rotation_radians := 0.0


func play_snapshot(image: Image, duration: float, rotation_radians: float) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if image == null or image.is_empty():
		visible = false
		finished.emit()
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_center = viewport_size * 0.5
	_travel = Vector2(0.0, -viewport_size.y * 1.35)
	_rotation_radians = rotation_radians
	_frame.texture = ImageTexture.create_from_image(image)
	_frame.scale = viewport_size / Vector2(image.get_size())
	visible = true
	_apply_progress(0.0)
	_tween = create_tween()
	_tween.tween_method(_apply_progress, 0.0, 1.0, maxf(duration, 0.01)).set_trans(
		Tween.TRANS_EXPO,
	).set_ease(Tween.EASE_IN)
	_tween.finished.connect(_on_finished)


func _apply_progress(progress: float) -> void:
	_frame.position = _center + _travel * progress
	_frame.rotation = _rotation_radians * progress


func _on_finished() -> void:
	_tween = null
	visible = false
	finished.emit()
