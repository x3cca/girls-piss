@tool
extends Node2D

class_name DepthMap2D

## Runtime view of the baked environment depth texture.
##
## The texture stores normalized depth in red and the playable liquid mask in
## alpha.  This class deliberately does not decide what a miss means; callers
## can use the two values to make that decision for their own gameplay.

@export var depth_texture: Texture2D:
	set(value):
		depth_texture = value
		_cached_image = null
		_debug_texture = null
		queue_redraw()
@export var world_rect := Rect2(0.0, 0.0, 720.0, 1280.0):
	set(value):
		world_rect = value
		queue_redraw()
@export var debug_visualization := false:
	set(value):
		debug_visualization = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var debug_alpha := 0.22

var _cached_image: Image
var _debug_texture: ImageTexture


func _ready() -> void:
	_refresh_cached_image()
	queue_redraw()


func _process(_delta: float) -> void:
	# A map can be assigned after the node enters the tree by a parent scene.
	# Refreshing here is cheap because the image is only rebuilt when the texture
	# resource changes.
	_refresh_cached_image()


func sample_world_position(world_position: Vector2) -> Dictionary:
	## Return only data from the baked map. Bounds classification belongs to the
	## gameplay system using the map.
	if not world_rect.has_point(world_position):
		return {"valid": false, "depth": 0.0}
	_refresh_cached_image()
	if _cached_image == null or _cached_image.is_empty():
		return {"valid": false, "depth": 0.0}
	var uv := Vector2(
		(world_position.x - world_rect.position.x) / maxf(world_rect.size.x, 0.001),
		(world_position.y - world_rect.position.y) / maxf(world_rect.size.y, 0.001),
	)
	var pixel := Vector2i(
		clampi(floori(uv.x * float(_cached_image.get_width())), 0, _cached_image.get_width() - 1),
		clampi(floori(uv.y * float(_cached_image.get_height())), 0, _cached_image.get_height() - 1),
	)
	var color := _cached_image.get_pixelv(pixel)
	return {"valid": color.a > 0.001, "depth": clampf(color.r, 0.0, 1.0)}


func world_position_to_uv(world_position: Vector2) -> Vector2:
	return Vector2(
		(world_position.x - world_rect.position.x) / maxf(world_rect.size.x, 0.001),
		(world_position.y - world_rect.position.y) / maxf(world_rect.size.y, 0.001),
	)


func clamp_world_position(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, world_rect.position.x, world_rect.end.x - 0.001),
		clampf(world_position.y, world_rect.position.y, world_rect.end.y - 0.001),
	)


func get_depth_band(depth: float, band_count := 4) -> int:
	var safe_count := maxi(band_count, 1)
	return mini(safe_count - 1, maxi(0, floori(clampf(depth, 0.0, 0.999999) * safe_count)))


func get_render_z_index(depth: float, base_z_index := 0, band_count := 4, band_step := 10) -> int:
	## Shallower sections have the greater CanvasItem z-index and draw last.
	var band := get_depth_band(depth, band_count)
	return base_z_index + (maxi(band_count, 1) - 1 - band) * band_step


func has_texture() -> bool:
	_refresh_cached_image()
	return _cached_image != null and not _cached_image.is_empty()


func _refresh_cached_image() -> void:
	if depth_texture == null:
		_cached_image = null
		return
	if _cached_image != null and not _cached_image.is_empty():
		return
	_cached_image = depth_texture.get_image()
	if _cached_image != null and not _cached_image.is_empty():
		_cached_image.convert(Image.FORMAT_RGBA8)


func _build_debug_texture() -> ImageTexture:
	_refresh_cached_image()
	if _cached_image == null or _cached_image.is_empty():
		return null
	var image := Image.create(
		_cached_image.get_width(),
		_cached_image.get_height(),
		false,
		Image.FORMAT_RGBA8,
	)
	for y in _cached_image.get_height():
		for x in _cached_image.get_width():
			var source := _cached_image.get_pixel(x, y)
			var depth := clampf(source.r, 0.0, 1.0)
			# A cool-to-warm ramp makes adjacent depth bands legible at a glance.
			var color := Color(
				lerpf(0.10, 0.85, depth),
				lerpf(0.18, 0.25, 1.0 - depth),
				lerpf(0.42, 0.12, depth),
				source.a * debug_alpha,
			)
			image.set_pixel(x, y, color)
	_debug_texture = ImageTexture.create_from_image(image)
	return _debug_texture


func _draw() -> void:
	if not debug_visualization:
		return
	# Draw the baked texture directly for the runtime overlay. Building a
	# per-pixel false-colour copy here would stall the first frame on the full
	# portrait map; the red depth channel plus alpha already exposes both the
	# section transitions and invalid pixels.
	if depth_texture != null:
		draw_texture_rect(
			depth_texture,
			world_rect,
			false,
			Color(0.42, 0.62, 0.92, debug_alpha),
		)
	# The surrounding canvas remains visibly outside the playable mask.
	draw_rect(world_rect, Color(0.32, 0.42, 0.70, 0.16), false, 2.0)
