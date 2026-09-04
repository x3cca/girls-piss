extends Control

class_name ScreenOverlayEffect

## Full-viewport animated sprite effect used by [ScreenOverlay].
##
## The sprite is deliberately stretched independently on each axis. Overlay
## art therefore fills the visible viewport on portrait, desktop, and expanded
## aspect ratios without affecting the gameplay world.

signal effect_finished(effect: ScreenOverlayEffect)

@export var animation_name: StringName = &"default"
@export_range(0.01, 8.0, 0.01, "or_greater") var speed_scale := 1.0
@export var autoplay := false
@export_group("Opacity sine wave")
@export var opacity_sine_enabled := false:
	set(value):
		opacity_sine_enabled = value
		set_process(value)
		if is_node_ready():
			_update_opacity()
@export_range(0.01, 8.0, 0.01, "or_greater") var opacity_sine_frequency := 1.0
@export_range(0.0, 1.0, 0.01) var opacity_sine_min := 0.0
@export_range(0.0, 1.0, 0.01) var opacity_sine_max := 1.0
@export_range(-6.28319, 6.28319, 0.01) var opacity_sine_phase := 0.0
@export var opacity := 1.0
@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		if is_instance_valid(_sprite):
			_sprite.sprite_frames = value
			_update_sprite_transform()

var _sprite: AnimatedSprite2D
var _has_finished := false
var _opacity_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = $AnimatedSprite2D
	if sprite_frames:
		_sprite.sprite_frames = sprite_frames
	_sprite.animation = animation_name
	_sprite.speed_scale = speed_scale
	_sprite.centered = false
	_sprite.position = Vector2.ZERO
	resized.connect(_on_resized)
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	set_process(opacity_sine_enabled)
	_update_sprite_transform()
	_update_opacity()
	if autoplay:
		play()


func _process(delta: float) -> void:
	advance_opacity(delta)


func advance_opacity(delta: float) -> void:
	_opacity_time += delta
	_update_opacity()


func play() -> void:
	if not is_instance_valid(_sprite):
		return
	_has_finished = false
	_opacity_time = 0.0
	visible = true
	_sprite.animation = animation_name
	_sprite.speed_scale = speed_scale
	_sprite.frame = 0
	_update_sprite_transform()
	_update_opacity()
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(animation_name):
		_finish()
		return
	if _sprite.sprite_frames.get_frame_count(animation_name) == 0:
		_finish()
		return
	_sprite.play()


func stop() -> void:
	if is_instance_valid(_sprite):
		_sprite.stop()
	visible = false


func update_layout() -> void:
	_update_sprite_transform()


func _on_resized() -> void:
	_update_sprite_transform()


func _on_frame_changed() -> void:
	_update_sprite_transform()


func _on_animation_finished() -> void:
	_finish()


func _finish() -> void:
	if _has_finished:
		return
	_has_finished = true
	effect_finished.emit(self)


func _update_opacity() -> void:
	var alpha := opacity
	if opacity_sine_enabled:
		var wave := (
				sin(_opacity_time * TAU * opacity_sine_frequency + opacity_sine_phase) + 1.0
		) * 0.5
		alpha = lerpf(opacity_sine_min, opacity_sine_max, wave) * opacity
	self_modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))


func _update_sprite_transform() -> void:
	if not is_instance_valid(_sprite) or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(_sprite.animation):
		return
	var frame_count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	if frame_count == 0:
		return
	var texture := _sprite.sprite_frames.get_frame_texture(
		_sprite.animation,
		_sprite.frame,
	)
	if texture == null:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	_sprite.centered = false
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2(
		size.x / texture_size.x,
		size.y / texture_size.y,
	)
