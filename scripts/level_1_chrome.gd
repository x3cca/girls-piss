extends Node2D

class_name Level1Chrome

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)
const MIN_VOLUME_LEVEL := 1
const MAX_VOLUME_LEVEL := 3
const MUTED_VOLUME_LEVEL := 0
const VOLUME_LEVELS := [1.0 / 3.0, 2.0 / 3.0, 1.0]
const VOLUME_PITCH_SCALES := [0.0, 1.0, 1.122462, 1.259921]
const MUTED_VOLUME_SOUND_DB := -18.0
const MUTED_VOLUME_PITCH_SCALE := 0.5
const GAME_AUDIO_BUS := &"Game"
const VOLUME_HITBOX_POSITION := Vector2(875.0, 16.0)
const VOLUME_HITBOX_SIZE := Vector2(242.0, 181.0)
const CURSOR_TEXTURE: Texture2D = preload(
	"res://assets/placeholders/cursor_pixel_pack/Tiles/tile_0026.png"
)
const WOBBLE_ANGLE := deg_to_rad(8.0)

signal volume_changed(level: int, muted: bool)
signal volume_pointer_changed(active: bool)

@onready var _volume_icons: Node2D = $VolumeIcons
@onready var _volume_sprites: Array[Sprite2D] = [
	$VolumeIcons/Volume1,
	$VolumeIcons/Volume2,
	$VolumeIcons/Volume3,
]
@onready var _mute_volume: Sprite2D = $VolumeIcons/MuteVolume
@onready var _volume_sound: AudioStreamPlayer = $VolumeSound
@onready var _back_shadow: Sprite2D = $BackShadow
@onready var _back: Sprite2D = $Back
@onready var _volume_hitbox: Control = $VolumeHitbox
var _layout_signature := Vector2.ZERO
var _volume_level := MAX_VOLUME_LEVEL
var _game_bus_index := -1
var _wobble_tween: Tween
var _volume_pointer_active := false


func _ready() -> void:
	_game_bus_index = _ensure_game_audio_bus()
	_route_game_audio_players()
	_volume_hitbox.gui_input.connect(_on_volume_hitbox_gui_input)
	_volume_hitbox.mouse_entered.connect(_on_volume_hitbox_mouse_entered)
	_volume_hitbox.mouse_exited.connect(_on_volume_hitbox_mouse_exited)
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_apply_volume()
	_layout()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


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
	_volume_icons.scale = composition_scale
	_volume_hitbox.position = VOLUME_HITBOX_POSITION * composition_scale
	_volume_hitbox.size = VOLUME_HITBOX_SIZE
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


func cycle_volume() -> void:
	_volume_level += 1
	if _volume_level > MAX_VOLUME_LEVEL:
		_volume_level = MUTED_VOLUME_LEVEL
	_apply_volume()
	_play_volume_sound()
	_wobble_volume()


func set_volume_level(level: int) -> void:
	_volume_level = clampi(level, MUTED_VOLUME_LEVEL, MAX_VOLUME_LEVEL)
	_apply_volume()


func get_volume_level() -> int:
	return _volume_level


func is_muted() -> bool:
	return _volume_level == MUTED_VOLUME_LEVEL


func _apply_volume() -> void:
	if not is_instance_valid(_volume_icons):
		return
	for index in _volume_sprites.size():
		_volume_sprites[index].visible = not is_muted() and index == _volume_level - 1
	_mute_volume.visible = is_muted()
	if _game_bus_index >= 0:
		AudioServer.set_bus_mute(_game_bus_index, is_muted())
		if not is_muted():
			AudioServer.set_bus_volume_db(
				_game_bus_index,
				linear_to_db(VOLUME_LEVELS[_volume_level - 1]),
			)
	volume_changed.emit(_volume_level, is_muted())


func _play_volume_sound() -> void:
	if not is_instance_valid(_volume_sound):
		return
	if is_muted():
		_volume_sound.volume_db = MUTED_VOLUME_SOUND_DB
		_volume_sound.pitch_scale = MUTED_VOLUME_PITCH_SCALE
	else:
		_volume_sound.volume_db = 0.0
		_volume_sound.pitch_scale = VOLUME_PITCH_SCALES[_volume_level]
	_volume_sound.play()


func _ensure_game_audio_bus() -> int:
	var bus_index := AudioServer.get_bus_index(GAME_AUDIO_BUS)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, GAME_AUDIO_BUS)
	AudioServer.set_bus_send(bus_index, &"Master")
	return bus_index


func _route_game_audio_players() -> void:
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		if is_instance_valid(player) and player != _volume_sound:
			player.bus = GAME_AUDIO_BUS


func _wobble_volume() -> void:
	if _wobble_tween:
		_wobble_tween.kill()
	for sprite in _volume_sprites:
		sprite.rotation = 0.0
	_mute_volume.rotation = 0.0
	_wobble_tween = create_tween()
	var active_sprite: Sprite2D = _mute_volume if is_muted() else _volume_sprites[_volume_level - 1]
	_wobble_tween.tween_property(active_sprite, "rotation", -WOBBLE_ANGLE, 0.08)
	_wobble_tween.tween_property(active_sprite, "rotation", WOBBLE_ANGLE, 0.14)
	_wobble_tween.tween_property(active_sprite, "rotation", -WOBBLE_ANGLE * 0.45, 0.1)
	_wobble_tween.tween_property(active_sprite, "rotation", 0.0, 0.12)


func _on_volume_hitbox_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cycle_volume()
		_volume_hitbox.accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		cycle_volume()
		_volume_hitbox.accept_event()


func _on_volume_hitbox_mouse_entered() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _volume_pointer_active:
		return
	_volume_pointer_active = true
	volume_pointer_changed.emit(true)


func _on_volume_hitbox_mouse_exited() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not _volume_pointer_active:
		return
	_volume_pointer_active = false
	volume_pointer_changed.emit(false)
