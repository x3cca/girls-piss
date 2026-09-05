@tool
extends Node

class_name DepthMapBaker

## Editor/offline baker for tagged environment sprites.
##
## The implementation intentionally samples the sprite images directly instead
## of rendering a second viewport. That keeps alpha coverage deterministic and
## makes overlapping sprites obey one simple rule: the smallest depth wins.

@export var source_root: Node
@export var output_path := "res://resources/depth_map_baked.png"
@export var bake_world_rect := Rect2(0.0, 0.0, 720.0, 1280.0)
@export var bake_size := Vector2i(720, 1280)
@export var minimum_depth := 0.0
@export var maximum_depth := 1.0
@export_range(0.0, 1.0, 0.01) var alpha_threshold := 0.01
var _sprite_images: Dictionary = {}


func bake(
		root: Node,
		world_rect: Rect2 = Rect2(0.0, 0.0, 720.0, 1280.0),
		output_size: Vector2i = Vector2i(720, 1280),
) -> Image:
	var safe_size := Vector2i(maxi(output_size.x, 1), maxi(output_size.y, 1))
	var result := Image.create(safe_size.x, safe_size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(0.0, 0.0, 0.0, 0.0))
	if root == null:
		return result
	var sprites: Array[DepthTaggedSprite2D] = []
	_collect_tagged_sprites(root, sprites)
	if sprites.is_empty():
		return result
	_sprite_images.clear()
	for sprite in sprites:
		if sprite.texture != null:
			_sprite_images[sprite] = sprite.texture.get_image()
	for y in safe_size.y:
		for x in safe_size.x:
			var world_position := Vector2(
				world_rect.position.x + (float(x) + 0.5) / float(safe_size.x) * world_rect.size.x,
				world_rect.position.y + (float(y) + 0.5) / float(safe_size.y) * world_rect.size.y,
			)
			var has_coverage := false
			var shallowest_depth := 1.0
			for sprite in sprites:
				if not sprite.contributes_to_bounds or sprite.texture == null:
					continue
				var alpha := _sample_sprite_alpha(sprite, world_position)
				if alpha <= alpha_threshold:
					continue
				has_coverage = true
				shallowest_depth = minf(shallowest_depth, _normalized_depth(sprite.depth))
			if has_coverage:
				result.set_pixel(x, y, Color(shallowest_depth, 0.0, 0.0, 1.0))
	return result


func bake_depth_texture(
		root: Node,
		world_rect: Rect2 = Rect2(0.0, 0.0, 720.0, 1280.0),
		output_size: Vector2i = Vector2i(720, 1280),
) -> ImageTexture:
	return ImageTexture.create_from_image(bake(root, world_rect, output_size))


func bake_to_file(
		root: Node = null,
		world_rect: Rect2 = Rect2(),
		output_size: Vector2i = Vector2i.ZERO,
		path: String = "",
) -> Error:
	var actual_root := source_root if root == null else root
	var actual_rect := bake_world_rect if world_rect.size == Vector2.ZERO else world_rect
	var actual_size := bake_size if output_size == Vector2i.ZERO else output_size
	var actual_path := output_path if path.is_empty() else path
	var image := bake(actual_root, actual_rect, actual_size)
	return image.save_png(actual_path)


func bake_scene() -> Error:
	return bake_to_file()


func _collect_tagged_sprites(node: Node, output: Array[DepthTaggedSprite2D]) -> void:
	if node is DepthTaggedSprite2D:
		output.append(node as DepthTaggedSprite2D)
	for child in node.get_children():
		_collect_tagged_sprites(child, output)


func _normalized_depth(value: float) -> float:
	return clampf(
		(value - minimum_depth) / maxf(maximum_depth - minimum_depth, 0.001),
		0.0,
		1.0,
	)


func _sample_sprite_alpha(sprite: DepthTaggedSprite2D, world_position: Vector2) -> float:
	var image: Image = _sprite_images.get(sprite)
	if image == null:
		image = sprite.texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var local := sprite.to_local(world_position)
	var rect := sprite.get_rect()
	if not rect.has_point(local):
		return 0.0
	var uv := Vector2(
		(local.x - rect.position.x) / maxf(rect.size.x, 0.001),
		(local.y - rect.position.y) / maxf(rect.size.y, 0.001),
	)
	if sprite.flip_h:
		uv.x = 1.0 - uv.x
	if sprite.flip_v:
		uv.y = 1.0 - uv.y
	var source_rect := Rect2(Vector2.ZERO, Vector2(image.get_width(), image.get_height()))
	if sprite.region_enabled:
		source_rect = sprite.region_rect
	var pixel := Vector2i(
		clampi(floori(source_rect.position.x + uv.x * source_rect.size.x), 0, image.get_width() - 1),
		clampi(floori(source_rect.position.y + uv.y * source_rect.size.y), 0, image.get_height() - 1),
	)
	return image.get_pixelv(pixel).a
