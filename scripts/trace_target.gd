extends Node2D

class_name TraceTarget

const BOIL_MATERIAL := preload("res://resources/materials/boil_effect.tres")

## A lightweight sprite target used by ShapeTrace. Idle motion is deliberately
## restrained so the target feels buoyant without making its hit point unclear.

@export var bob_amplitude := 4.0
@export var bob_speed := 1.45
@export var rotation_amplitude := deg_to_rad(4.0)
@export var rotation_speed := 1.15
@export var scale_amplitude := 0.08
@export var hit_duration := 0.48
@export var hit_spin_turns := 1.35

var _anchor_position := Vector2.ZERO
var _center_position := Vector2.ZERO
var _phase := 0.0
var _time := 0.0
var _hit_elapsed := 0.0
var _hit_start_position := Vector2.ZERO
var _hit_start_rotation := 0.0
var _base_scale := Vector2.ONE
var _hit := false

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		# Keep direct script instantiation useful in isolated tests and tools.
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.material = BOIL_MATERIAL
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
	_hit_elapsed = 0.0
	_time = 0.0
	position = _anchor_position
	rotation = 0.0
	scale = _base_scale
	modulate.a = 1.0
	visible = true


func is_hit() -> bool:
	return _hit


func _process(delta: float) -> void:
	_time += delta
	if _hit:
		_advance_hit(delta)
		return

	var bob_wave := sin(_time * bob_speed + _phase)
	position = _anchor_position + Vector2(0.0, bob_wave * bob_amplitude)
	rotation = sin(_time * rotation_speed + _phase) * rotation_amplitude
	scale = _base_scale * (1.0 + bob_wave * scale_amplitude)


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
