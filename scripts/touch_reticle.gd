extends Node2D

class_name TouchReticle

## Crosshair target indicator. It stays at the requested target while the stream
## eases toward it independently.

const CROSSHAIR_NEUTRAL := preload("res://assets/art/drive/Crosshair2.png")
const CROSSHAIR_NEGATIVE := preload("res://assets/art/drive/Crosshair1.png")
const CROSSHAIR_SUCCESS := preload("res://assets/art/drive/Crosshair3.png")

enum ReticleState { NEUTRAL, NEGATIVE, SUCCESS }
const NEUTRAL := ReticleState.NEUTRAL
const NEGATIVE := ReticleState.NEGATIVE
const SUCCESS := ReticleState.SUCCESS

@export var reticle_size := 48.0
@export_range(0.05, 2.0, 0.01) var success_burst_duration := 0.42
@export var neutral_texture: Texture2D = CROSSHAIR_NEUTRAL
@export var negative_texture: Texture2D = CROSSHAIR_NEGATIVE
@export var success_texture: Texture2D = CROSSHAIR_SUCCESS

@onready var _sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
var _preview_state := ReticleState.NEUTRAL
var _state := ReticleState.NEUTRAL
var _success_burst_remaining := 0.0

var state: int:
	get:
		return _state
	set(value):
		set_zone_state(value)


func _ready() -> void:
	if not is_instance_valid(_sprite):
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _sprite.texture == null:
		_sprite.texture = neutral_texture
	_apply_size()
	_apply_state_texture()
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	if _success_burst_remaining <= 0.0:
		return
	_success_burst_remaining = move_toward(
		_success_burst_remaining,
		0.0,
		maxf(delta, 0.0),
	)
	if _success_burst_remaining <= 0.0:
		_state = _preview_state
		_apply_state_texture()


func set_touch_target(target_position: Vector2, active: bool) -> void:
	set_aim_target(target_position, active)


func set_aim_target(target_position: Vector2, active: bool = true) -> void:
	visible = active
	if active:
		position = target_position


func set_zone_state(next_state: int) -> void:
	if next_state < ReticleState.NEUTRAL or next_state > ReticleState.SUCCESS:
		next_state = ReticleState.NEUTRAL
	_preview_state = next_state
	if _success_burst_remaining > 0.0:
		return
	if _state == next_state:
		return
	_state = next_state
	_apply_state_texture()


func set_reticle_state(next_state: int) -> void:
	set_zone_state(next_state)


func set_state(next_state: int) -> void:
	set_zone_state(next_state)


func get_zone_state() -> int:
	return _state


func get_state() -> int:
	return _state


func play_success_burst() -> void:
	_success_burst_remaining = success_burst_duration
	_state = ReticleState.SUCCESS
	_apply_state_texture()


func is_success_burst_active() -> bool:
	return _success_burst_remaining > 0.0


func _apply_size() -> void:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return
	var texture_width := maxf(float(_sprite.texture.get_width()), 1.0)
	_sprite.scale = Vector2.ONE * reticle_size / texture_width


func _apply_state_texture() -> void:
	if not is_instance_valid(_sprite):
		return
	var texture: Texture2D = neutral_texture
	match _state:
		ReticleState.NEGATIVE:
			texture = negative_texture
		ReticleState.SUCCESS:
			texture = success_texture
	_sprite.texture = texture
	_apply_size()
