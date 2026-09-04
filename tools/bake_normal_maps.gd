@tool
extends SceneTree
## Offline alpha-silhouette normal baker.
## Run with: godot --headless --script res://tools/bake_normal_maps.gd
## Generated files are intentionally excluded from the input walk, making a
## second run deterministic and safe.

const ART_ROOT := "res://assets/art"
const NORMAL_SUFFIX := "_normal.png"
const RESOURCE_SUFFIX := "_canvas_texture.tres"
const HEIGHT_RADIUS := 2
const NORMAL_STRENGTH := 1.35


func _init() -> void:
	var files: Array[String] = []
	_collect_pngs(ART_ROOT, files)
	files.sort()
	for source_path in files:
		_bake(source_path)
	quit()


func _collect_pngs(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_pngs(path, output)
		elif entry.to_lower().ends_with(".png") and not entry.to_lower().ends_with(NORMAL_SUFFIX):
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _bake(source_path: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if image == null or image.is_empty():
		push_warning("Normal baker could not read %s" % source_path)
		return
	var normal := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var gx := _sobel_x(image, x, y)
			var gy := _sobel_y(image, x, y)
			var n := Vector3(-gx * NORMAL_STRENGTH, -gy * NORMAL_STRENGTH, 1.0).normalized()
			var alpha := image.get_pixel(x, y).a
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, alpha))
	var stem := source_path.get_basename()
	var normal_path := stem + NORMAL_SUFFIX
	normal.save_png(ProjectSettings.globalize_path(normal_path))

	var canvas := CanvasTexture.new()
	canvas.diffuse_texture = load(source_path)
	canvas.normal_texture = load(normal_path)
	var resource_path := stem + RESOURCE_SUFFIX
	var error := ResourceSaver.save(canvas, resource_path)
	if error != OK:
		push_warning("Could not save CanvasTexture %s (%s)" % [resource_path, error])


func _height(image: Image, x: int, y: int) -> float:
	var total := 0.0
	var weight_total := 0.0
	for oy in range(-HEIGHT_RADIUS, HEIGHT_RADIUS + 1):
		for ox in range(-HEIGHT_RADIUS, HEIGHT_RADIUS + 1):
			var distance := float(ox * ox + oy * oy)
			var weight := exp(-distance / 3.0)
			var px := clampi(x + ox, 0, image.get_width() - 1)
			var py := clampi(y + oy, 0, image.get_height() - 1)
			total += image.get_pixel(px, py).a * weight
			weight_total += weight
	return total / maxf(weight_total, 0.001)


func _sobel_x(image: Image, x: int, y: int) -> float:
	var right := _height(image, x + 1, y - 1)
	right += 2.0 * _height(image, x + 1, y)
	right += _height(image, x + 1, y + 1)
	var left := _height(image, x - 1, y - 1)
	left += 2.0 * _height(image, x - 1, y)
	left += _height(image, x - 1, y + 1)
	return (right - left) / 8.0


func _sobel_y(image: Image, x: int, y: int) -> float:
	var down := _height(image, x - 1, y + 1)
	down += 2.0 * _height(image, x, y + 1)
	down += _height(image, x + 1, y + 1)
	var up := _height(image, x - 1, y - 1)
	up += 2.0 * _height(image, x, y - 1)
	up += _height(image, x + 1, y - 1)
	return (down - up) / 8.0
