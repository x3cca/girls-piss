extends Node2D

class_name Level1Chrome

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)
const MIN_VOLUME_LEVEL := 1
const MAX_VOLUME_LEVEL := 3
const MUTED_VOLUME_LEVEL := 0
const VOLUME_LEVELS := [1.0 / 3.0, 2.0 / 3.0, 1.0]
const VOLUME_TEXTURES := [
	preload("res://assets/art/drive/Volume1.png"),
	preload("res://assets/art/drive/Volume2.png"),
	preload("res://assets/art/drive/Volume3.png"),
]
const MUTED_TEXTURE: Texture2D = preload("res://assets/art/drive/MuteVolumeX.svg")
const WOBBLE_ANGLE := deg_to_rad(8.0)

signal volume_changed(level: int, muted: bool)

@onready var _volume: Sprite2D = $Volume
@onready var _back_shadow: Sprite2D = $BackShadow
@onready var _back: Sprite2D = $Back
@onready var _volume_hitbox: Area2D = $VolumeHitbox
var _layout_signature := Vector2.ZERO
var _volume_level := MIN_VOLUME_LEVEL
var _master_bus_index := -1
var _wobble_tween: Tween


func _ready() -> void:
	_master_bus_index = AudioServer.get_bus_index(&"Master")
	_volume_hitbox.input_event.connect(_on_volume_hitbox_input_event)
	_volume_hitbox.mouse_entered.connect(_on_volume_hitbox_mouse_entered)
	_volume_hitbox.mouse_exited.connect(_on_volume_hitbox_mouse_exited)
	_apply_volume()
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
	_set_volume_layout(Vector2(875.0, 16.0), composition_scale)
	_volume_hitbox.position = Vector2(875.0 + 121.0, 16.0 + 90.5) * composition_scale
	_volume_hitbox.scale = composition_scale
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


func _set_volume_layout(authored_position: Vector2, composition_scale: Vector2) -> void:
	_volume.centered = true
	_volume.position = (
			authored_position + Vector2(_volume.texture.get_width(), _volume.texture.get_height()) * 0.5
	) * composition_scale
	_volume.scale = composition_scale


func cycle_volume() -> void:
	_volume_level += 1
	if _volume_level > MAX_VOLUME_LEVEL:
		_volume_level = MUTED_VOLUME_LEVEL
	_apply_volume()
	_wobble_volume()


func set_volume_level(level: int) -> void:
	_volume_level = clampi(level, MUTED_VOLUME_LEVEL, MAX_VOLUME_LEVEL)
	_apply_volume()


func get_volume_level() -> int:
	return _volume_level


func is_muted() -> bool:
	return _volume_level == MUTED_VOLUME_LEVEL


func _apply_volume() -> void:
	if not is_instance_valid(_volume):
		return
	_volume.texture = MUTED_TEXTURE if is_muted() else VOLUME_TEXTURES[_volume_level - 1]
	_layout_signature = Vector2.ZERO
	_layout()
	if _master_bus_index >= 0:
		AudioServer.set_bus_mute(_master_bus_index, is_muted())
		if not is_muted():
			AudioServer.set_bus_volume_db(
				_master_bus_index,
				linear_to_db(VOLUME_LEVELS[_volume_level - 1]),
			)
	volume_changed.emit(_volume_level, is_muted())


func _wobble_volume() -> void:
	if _wobble_tween:
		_wobble_tween.kill()
	_volume.rotation = 0.0
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(_volume, "rotation", -WOBBLE_ANGLE, 0.08)
	_wobble_tween.tween_property(_volume, "rotation", WOBBLE_ANGLE, 0.14)
	_wobble_tween.tween_property(_volume, "rotation", -WOBBLE_ANGLE * 0.45, 0.1)
	_wobble_tween.tween_property(_volume, "rotation", 0.0, 0.12)


func _on_volume_hitbox_input_event(
		_viewport: Node,
		event: InputEvent,
		_shape_idx: int,
) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cycle_volume()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		cycle_volume()
		get_viewport().set_input_as_handled()


func _on_volume_hitbox_mouse_entered() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_volume_hitbox_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
