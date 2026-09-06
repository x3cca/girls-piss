extends Node

class_name SurfaceEffects

## Contact-reactive presentation for the bathroom artwork.
##
## This node intentionally knows nothing about collision or checkpoint rules.
## It consumes the committed LiquidStream endpoint and stamps a level-local
## texture map for each authored surface. The maps are deliberately permanent
## until reset, so old pee spots remain in the artwork instead of following the
## latest endpoint or needing a decay simulation.

signal surface_detected(surface: String, position: Vector2)

const SPLAT_TEXTURE := preload("res://assets/art/pee_splat.png")
const SURFACE_NONE := "none"
const SURFACE_BOWL := "bowl"
const SURFACE_SEAT := "seat"
const SURFACE_FLOOR := "floor"
const SURFACE_WALL := "wall"
const SURFACE_TANK := "tank"
const SURFACE_BACK_WALL := SURFACE_WALL
const SURFACES := [SURFACE_BOWL, SURFACE_SEAT, SURFACE_FLOOR, SURFACE_WALL, SURFACE_TANK]

const DEFAULT_STAIN_COLOR := Color("#f1d34f")
const DEFAULT_PRIMARY_COLOR := DEFAULT_STAIN_COLOR
const DEFAULT_STAIN_OPACITY := 0.62
const DEFAULT_STAIN_MAP_SIZE := 256
const DEFAULT_STAIN_RADIUS := 0.085
const DEFAULT_SPLAT_THRESHOLD := 0.5
const DEFAULT_SPLAT_EDGE := 0.04
const DEFAULT_ALPHA_THRESHOLD := 0.035
const DEFAULT_WALL_FLOOR_BOUNDARY := 522.0 / 1920.0
const DEFAULT_REHIT_DISTANCE := 18.0
const DEFAULT_CONTACT_SIGNAL_GAP := 0.1

@export_range(0.0, 1.0, 0.005) var alpha_threshold := DEFAULT_ALPHA_THRESHOLD
@export_range(0.0, 1.0, 0.001) var wall_floor_boundary_normalized := DEFAULT_WALL_FLOOR_BOUNDARY
@export_range(0.0, 128.0, 1.0) var rehit_distance := DEFAULT_REHIT_DISTANCE
@export_range(0.01, 0.5, 0.01) var contact_signal_gap := DEFAULT_CONTACT_SIGNAL_GAP
@export_range(32, 512, 16) var stain_map_size := DEFAULT_STAIN_MAP_SIZE
@export_range(0.01, 0.3, 0.005) var stain_radius := DEFAULT_STAIN_RADIUS
@export_range(0.0, 1.0, 0.01) var splat_threshold := DEFAULT_SPLAT_THRESHOLD
@export_range(0.0, 0.25, 0.01) var splat_edge := DEFAULT_SPLAT_EDGE
@export var stain_color := DEFAULT_STAIN_COLOR
@export_range(0.0, 1.0, 0.01) var stain_opacity := DEFAULT_STAIN_OPACITY

var stream: LiquidStream
var _connected_stream: LiquidStream
var _detected_surface := SURFACE_NONE
var _last_endpoint := Vector2.ZERO
var _has_endpoint := false
var _endpoint_active := false
var _time_since_endpoint_signal := 999999.0
var _last_endpoint_surface := SURFACE_NONE
var _surface_nodes: Dictionary = { }
var _surface_materials: Dictionary = { }
var _surface_images: Dictionary = { }
var _splat_image: Image
var _stain_images: Dictionary = { }
var _stain_textures: Dictionary = { }
var _stain_map_sizes: Dictionary = { }
var _water_nodes: Dictionary = { }
var _water_materials: Dictionary = { }
var _water_images: Dictionary = { }
var _water_textures: Dictionary = { }
var _water_map_sizes: Dictionary = { }
var _stain_stamp_counts: Dictionary = { }
var _noise_stamp_serial := 0
var _water_yellowness := 0.0
var _surface_states: Dictionary = { }
## Kept as a queryable contact history for bowl ripple tests and tooling. The
## actual visual state lives in the persistent bowl splat and water maps, not
## these positions.
var _ripples: Array[Dictionary] = []


func _ready() -> void:
	_splat_image = SPLAT_TEXTURE.get_image()
	if _splat_image != null and not _splat_image.is_empty():
		_splat_image.convert(Image.FORMAT_RGBA8)
	_init_surface_states()
	_resolve_surface_nodes()
	# Main normally binds explicitly after it assigns the stream. This fallback
	# keeps the controller useful when a test instantiates the full scene alone.
	var owner_node := get_parent()
	if owner_node:
		var discovered_stream := owner_node.get_node_or_null("LiquidStream") as LiquidStream
		if discovered_stream:
			bind_stream(discovered_stream)
	call_deferred("_resolve_surface_nodes")


func _process(delta: float) -> void:
	_time_since_endpoint_signal += maxf(delta, 0.0)
	if not _surface_states.has(SURFACE_BOWL):
		return
	var bowl_state: Dictionary = _surface_states[SURFACE_BOWL]
	if float(bowl_state.get("ripple_strength", 0.0)) <= 0.0:
		return
	bowl_state["ripple_age"] = float(bowl_state.get("ripple_age", 0.0)) + maxf(delta, 0.0)
	_surface_states[SURFACE_BOWL] = bowl_state
	_apply_water_state(bowl_state)


func bind_stream(value: LiquidStream) -> void:
	if _connected_stream == value:
		stream = value
		return
	if is_instance_valid(_connected_stream):
		if _connected_stream.drawing_point_updated.is_connected(_on_drawing_point_updated):
			_connected_stream.drawing_point_updated.disconnect(_on_drawing_point_updated)
	_connected_stream = value
	stream = value
	if is_instance_valid(_connected_stream) and not _connected_stream.drawing_point_updated.is_connected(
		_on_drawing_point_updated,
	):
		_connected_stream.drawing_point_updated.connect(_on_drawing_point_updated)


func set_stream(value: LiquidStream) -> void:
	bind_stream(value)


func observe_drawing_point(position: Vector2, active: bool) -> void:
	_on_drawing_point_updated(position, active)


func observe_stream_endpoint(position: Vector2, active: bool) -> void:
	_on_drawing_point_updated(position, active)


func _on_drawing_point_updated(position: Vector2, active: bool) -> void:
	_ensure_surface_states()
	if not active:
		_detected_surface = SURFACE_NONE
		_has_endpoint = false
		_endpoint_active = false
		_time_since_endpoint_signal = 999999.0
		_last_endpoint_surface = SURFACE_NONE
		return
	var surface := detect_surface(position)
	_detected_surface = surface
	_last_endpoint = position
	_has_endpoint = surface != SURFACE_NONE
	if surface == SURFACE_NONE:
		_endpoint_active = false
		_time_since_endpoint_signal = 999999.0
		_last_endpoint_surface = SURFACE_NONE
		return
	var node: Sprite2D = _surface_nodes.get(surface) as Sprite2D
	if node == null:
		_endpoint_active = false
		_time_since_endpoint_signal = 999999.0
		_last_endpoint_surface = SURFACE_NONE
		return
	var state: Dictionary = _surface_states[surface]
	var continuous_contact := (
			_endpoint_active
			and _last_endpoint_surface == surface
			and bool(state["active"])
			and _time_since_endpoint_signal <= contact_signal_gap
			and (state["position"] as Vector2).distance_to(position) <= rehit_distance
	)
	var bowl_contact_started := (
			surface == SURFACE_BOWL
			and (
					not _endpoint_active
					or _last_endpoint_surface != SURFACE_BOWL
					or not bool(state["active"])
			)
	)
	if surface == SURFACE_BOWL:
		# The bowl gets ordinary splats, while a separate water map keeps the
		# ripple shader's accumulated disturbance independent of those splats.
		_stamp_surface(surface, node, position)
		_stamp_water_noise(position)
		if bowl_contact_started:
			_add_ripple(position, _water_nodes.get(SURFACE_BOWL) as Sprite2D)
	elif not continuous_contact:
		# Other surfaces, including the seat, still receive their persistent splats.
		_stamp_surface(surface, node, position)
	state["active"] = true
	state["strength"] = 1.0
	state["position"] = position
	state["uv"] = _world_to_uv(node, position)
	_surface_states[surface] = state
	_endpoint_active = true
	_time_since_endpoint_signal = 0.0
	_last_endpoint_surface = surface
	_apply_surface_state(surface, state)
	if surface == SURFACE_BOWL:
		_apply_water_state(state)
	surface_detected.emit(surface, position)


func detect_surface(position: Vector2) -> String:
	_resolve_surface_nodes()
	# This is the intentional visual routing order. It makes overlap decisions
	# deterministic and follows the authored object layering before background.
	for surface in [SURFACE_TANK, SURFACE_SEAT, SURFACE_BOWL]:
		var node: Sprite2D = _surface_nodes.get(surface) as Sprite2D
		if _sprite_contains_alpha(node, position):
			return surface
	var boundary := _get_wall_floor_boundary()
	var background_surface := SURFACE_FLOOR if position.y >= boundary else SURFACE_WALL
	var background_node: Sprite2D = _surface_nodes.get(background_surface) as Sprite2D
	if _sprite_contains_alpha(background_node, position):
		return background_surface
	return SURFACE_NONE


func classify_surface(position: Vector2) -> String:
	return detect_surface(position)


func get_surface_at(position: Vector2) -> String:
	return detect_surface(position)


func get_wall_floor_boundary() -> float:
	return _get_wall_floor_boundary()


func get_detected_surface(position := Vector2.INF) -> String:
	if position != Vector2.INF:
		return detect_surface(position)
	return _detected_surface


func reset_effects() -> void:
	_ensure_surface_states()
	_detected_surface = SURFACE_NONE
	_last_endpoint = Vector2.ZERO
	_has_endpoint = false
	_endpoint_active = false
	_time_since_endpoint_signal = 999999.0
	_last_endpoint_surface = SURFACE_NONE
	_ripples.clear()
	_stain_stamp_counts.clear()
	_noise_stamp_serial = 0
	_water_yellowness = 0.0
	_clear_stain_maps()
	_clear_water_maps()
	for surface in SURFACES:
		var state: Dictionary = _surface_states[surface]
		state["active"] = false
		state["age"] = 0.0
		state["strength"] = 0.0
		state["position"] = Vector2.ZERO
		state["uv"] = Vector2(0.5, 0.5)
		state["ripple_uv"] = Vector2(0.5, 0.5)
		state["ripple_age"] = 0.0
		state["ripple_strength"] = 0.0
		_surface_states[surface] = state
		_apply_surface_state(surface, state)
		if surface == SURFACE_BOWL:
			_apply_water_state(state)


func reset() -> void:
	reset_effects()


func clear_effects() -> void:
	reset_effects()


func get_surface_state(surface: String) -> Dictionary:
	if not _surface_states.has(surface):
		return { }
	return (_surface_states[surface] as Dictionary).duplicate(true)


func is_surface_active(surface: String) -> bool:
	return bool(get_surface_state(surface).get("active", false))


func get_surface_strength(surface: String) -> float:
	return float(get_surface_state(surface).get("strength", 0.0))


func get_surface_stain_map(surface: String) -> ImageTexture:
	_resolve_surface_nodes()
	return _stain_textures.get(surface) as ImageTexture


func get_stain_map(surface: String) -> ImageTexture:
	return get_surface_stain_map(surface)


func get_surface_stain_value(surface: String, position: Vector2) -> float:
	var node: Sprite2D = get_surface_node(surface)
	var image: Image = _stain_images.get(surface) as Image
	if node == null or image == null or image.is_empty():
		return 0.0
	var uv := _world_to_uv(node, position)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return 0.0
	var pixel := Vector2i(
		clampi(floori(uv.x * image.get_width()), 0, image.get_width() - 1),
		clampi(floori(uv.y * image.get_height()), 0, image.get_height() - 1),
	)
	return image.get_pixelv(pixel).r


func get_surface_stain_count(surface: String) -> int:
	return int(_stain_stamp_counts.get(surface, 0))


func get_stain_count(surface: String) -> int:
	return get_surface_stain_count(surface)


func get_ripple_count() -> int:
	return _ripples.size()


func get_bowl_ripple_count() -> int:
	return get_ripple_count()


func get_ripples() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for ripple in _ripples:
		copy.append(ripple.duplicate(true))
	return copy


func get_bowl_ripples() -> Array[Dictionary]:
	return get_ripples()


func get_surface_node(surface: String) -> Sprite2D:
	_resolve_surface_nodes()
	return _surface_nodes.get(surface) as Sprite2D


func get_surface_material(surface: String) -> ShaderMaterial:
	_resolve_surface_nodes()
	return _surface_materials.get(surface) as ShaderMaterial


func get_surface_materials() -> Dictionary:
	_resolve_surface_nodes()
	return _surface_materials.duplicate()


func get_water_material(surface := SURFACE_BOWL) -> ShaderMaterial:
	_resolve_surface_nodes()
	return _water_materials.get(surface) as ShaderMaterial


func set_meter_progress(progress: float) -> void:
	# Meter progress is full at 1.0 and empty at 0.0, so yellow grows toward
	# depletion while the water remains clear at the start of an attempt.
	_water_yellowness = 1.0 - clampf(progress, 0.0, 1.0)
	for material_variant in _water_materials.values():
		var material := material_variant as ShaderMaterial
		if material:
			material.set_shader_parameter("water_yellowness", _water_yellowness)


func get_water_yellowness() -> float:
	return _water_yellowness


func set_surface_nodes(
		bowl: Sprite2D,
		seat: Sprite2D,
		floor: Sprite2D,
		wall: Sprite2D,
		tank: Sprite2D,
) -> void:
	_surface_nodes = {
		SURFACE_BOWL: bowl,
		SURFACE_SEAT: seat,
		SURFACE_FLOOR: floor,
		SURFACE_WALL: wall,
		SURFACE_TANK: tank,
	}
	_water_nodes.clear()
	_water_materials.clear()
	_prepare_materials()
	_prepare_water_material()


func _init_surface_states() -> void:
	_surface_states.clear()
	_ensure_surface_states()


func _ensure_surface_states() -> void:
	for surface in SURFACES:
		if _surface_states.has(surface):
			continue
		_surface_states[surface] = {
			"active": false,
			"age": 0.0,
			"strength": 0.0,
			"position": Vector2.ZERO,
			"uv": Vector2(0.5, 0.5),
			"ripple_uv": Vector2(0.5, 0.5),
			"ripple_age": 0.0,
			"ripple_strength": 0.0,
		}


func _resolve_surface_nodes() -> void:
	var owner_node := get_parent()
	if owner_node == null:
		return
	var toilet := owner_node.get_node_or_null("PissToilet")
	var background := owner_node.get_node_or_null("Level1Background")
	var bowl := toilet.get_node_or_null("Bowl") as Sprite2D if toilet else null
	var bowl_water := toilet.get_node_or_null("BowlWater") as Sprite2D if toilet else null
	var seat := toilet.get_node_or_null("Seat") as Sprite2D if toilet else null
	var tank := toilet.get_node_or_null("Tank") as Sprite2D if toilet else null
	var floor := background.get_node_or_null("Floor") as Sprite2D if background else null
	var wall := background.get_node_or_null("BackWall") as Sprite2D if background else null
	if bowl or bowl_water or seat or floor or wall or tank:
		_surface_nodes = {
			# Bowl splats and surface detection use the full authored silhouette.
			SURFACE_BOWL: bowl,
			SURFACE_SEAT: seat,
			SURFACE_FLOOR: floor,
			SURFACE_WALL: wall,
			SURFACE_TANK: tank,
		}
		_water_nodes = { SURFACE_BOWL: bowl_water }
		_prepare_materials()
		_prepare_water_material()


func _prepare_materials() -> void:
	for surface in SURFACES:
		var node: Sprite2D = _surface_nodes.get(surface) as Sprite2D
		if node == null:
			continue
		var material := node.material as ShaderMaterial
		if material == null:
			continue
		# Scene subresources are already distinct, but duplicating here also makes
		# the controller safe when a caller supplies a shared material resource.
		if _surface_materials.get(surface) != material:
			material = material.duplicate() as ShaderMaterial
			node.material = material
		_surface_materials[surface] = material
		_prepare_stain_map(surface, node)
		_set_common_material_parameters(surface, material)
		if not _surface_states.has(surface):
			_surface_states[surface] = {
				"active": false,
				"age": 0.0,
				"strength": 0.0,
				"position": Vector2.ZERO,
				"uv": Vector2(0.5, 0.5),
				"ripple_uv": Vector2(0.5, 0.5),
				"ripple_age": 0.0,
				"ripple_strength": 0.0,
			}
		_apply_surface_state(surface, _surface_states[surface])


func _set_common_material_parameters(surface: String, material: ShaderMaterial) -> void:
	var stain_map: ImageTexture = _stain_textures.get(surface) as ImageTexture
	if stain_map != null:
		material.set_shader_parameter("stain_map", stain_map)
	material.set_shader_parameter("splat_threshold", splat_threshold)
	material.set_shader_parameter("splat_edge", splat_edge)
	material.set_shader_parameter("stain_color", stain_color)
	material.set_shader_parameter("stain_opacity", stain_opacity)
	if surface == SURFACE_BOWL:
		_set_bowl_water_mask(material, _surface_nodes.get(SURFACE_BOWL) as Sprite2D)
	# Keep a stable material-level label available for deterministic inspection.
	material.resource_name = "SurfaceEffect_%s" % surface.capitalize()


func _set_bowl_water_mask(material: ShaderMaterial, bowl: Sprite2D) -> void:
	var water_node := _water_nodes.get(SURFACE_BOWL) as Sprite2D
	if bowl == null or bowl.texture == null or water_node == null or water_node.texture == null:
		material.set_shader_parameter("water_mask_enabled", 0.0)
		return
	material.set_shader_parameter("water_mask", water_node.texture)
	material.set_shader_parameter("water_mask_uv_transform", _water_mask_uv_transform(bowl, water_node))
	material.set_shader_parameter("water_mask_enabled", 1.0)


func _prepare_water_material() -> void:
	var node := _water_nodes.get(SURFACE_BOWL) as Sprite2D
	if node == null:
		return
	var material := node.material as ShaderMaterial
	if material == null:
		return
	# Keep the water material independent from the material resource used by the
	# completion card and from any other scene instance.
	if _water_materials.get(SURFACE_BOWL) != material:
		material = material.duplicate() as ShaderMaterial
		node.material = material
	_water_materials[SURFACE_BOWL] = material
	_prepare_water_map(node)
	_set_water_material_parameters(material)
	_apply_water_state(_surface_states.get(SURFACE_BOWL, { }))


func _set_water_material_parameters(material: ShaderMaterial) -> void:
	var water_texture: ImageTexture = _water_textures.get(SURFACE_BOWL) as ImageTexture
	if water_texture != null:
		material.set_shader_parameter("water_noise_map", water_texture)
	var map_size: Vector2i = _water_map_sizes.get(SURFACE_BOWL, Vector2i(1, 1))
	material.set_shader_parameter(
		"water_noise_map_texel_size",
		Vector2(1.0 / maxf(map_size.x, 1), 1.0 / maxf(map_size.y, 1)),
	)
	material.set_shader_parameter("water_yellowness", _water_yellowness)
	material.resource_name = "SurfaceEffect_BowlWater"


func _apply_surface_state(surface: String, state: Dictionary) -> void:
	var material: ShaderMaterial = _surface_materials.get(surface) as ShaderMaterial
	if material == null:
		return
	var stain_map: ImageTexture = _stain_textures.get(surface) as ImageTexture
	if stain_map != null:
		material.set_shader_parameter("stain_map", stain_map)


func _apply_water_state(state: Dictionary) -> void:
	var material: ShaderMaterial = _water_materials.get(SURFACE_BOWL) as ShaderMaterial
	if material == null:
		return
	var water_texture: ImageTexture = _water_textures.get(SURFACE_BOWL) as ImageTexture
	if water_texture != null:
		material.set_shader_parameter("water_noise_map", water_texture)
	material.set_shader_parameter("water_yellowness", _water_yellowness)
	material.set_shader_parameter("ripple_age", state.get("ripple_age", 0.0))


func _add_ripple(position: Vector2, node: Sprite2D) -> void:
	# Keep one impact ripple. The persistent water texture is updated separately
	# for every committed stream chunk.
	_ripples.clear()
	var ripple_uv := _world_to_uv(node, position)
	_ripples.append(
		{
			"position": position,
			"uv": ripple_uv,
			"age": 0.0,
			"strength": 1.0,
		},
	)
	var state: Dictionary = _surface_states[SURFACE_BOWL]
	state["ripple_uv"] = ripple_uv
	state["ripple_age"] = 0.0
	state["ripple_strength"] = 1.0
	_surface_states[SURFACE_BOWL] = state


func _stamp_water_noise(position: Vector2) -> void:
	var node := _water_nodes.get(SURFACE_BOWL) as Sprite2D
	if node == null:
		return
	_prepare_water_map(node)
	var noise_image: Image = _water_images.get(SURFACE_BOWL) as Image
	var noise_texture: ImageTexture = _water_textures.get(SURFACE_BOWL) as ImageTexture
	if noise_image == null or noise_texture == null or noise_image.is_empty():
		return
	var uv := _world_to_uv(node, position)
	var radius := clampf(stain_radius * 0.55, 0.004, 0.25)
	var stamp_width := maxi(1, ceili(radius * 2.0 * noise_image.get_width()))
	var stamp_height := maxi(1, ceili(radius * 2.0 * noise_image.get_height()))
	var center := Vector2(
		uv.x * noise_image.get_width() - 0.5,
		uv.y * noise_image.get_height() - 0.5,
	)
	var half_width := stamp_width * 0.5
	var half_height := stamp_height * 0.5
	var min_x := maxi(0, floori(center.x - half_width))
	var max_x := mini(noise_image.get_width() - 1, ceili(center.x + half_width))
	var min_y := maxi(0, floori(center.y - half_height))
	var max_y := mini(noise_image.get_height() - 1, ceili(center.y + half_height))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var local := Vector2(
				((x + 0.5) - (center.x - half_width)) / stamp_width * 2.0 - 1.0,
				((y + 0.5) - (center.y - half_height)) / stamp_height * 2.0 - 1.0,
			)
			var distance := local.length()
			if distance > 1.0:
				continue
			var edge := 1.0 - smoothstep(0.0, 1.0, distance)
			var noise := _stamp_noise(Vector2i(x, y), _noise_stamp_serial)
			var value := (0.25 + noise * 0.75) * edge
			var current := noise_image.get_pixel(x, y).r
			var updated := maxf(current, value)
			if updated > current:
				noise_image.set_pixel(x, y, Color(updated, 0.0, 0.0, 1.0))
	_noise_stamp_serial += 1
	noise_texture.update(noise_image)


func _stamp_noise(pixel: Vector2i, serial: int) -> float:
	var value := sin(
		float(pixel.x) * 12.9898
		+ float(pixel.y) * 78.233
		+ float(serial) * 37.719,
	) * 43758.5453
	return value - floorf(value)


func _prepare_stain_map(surface: String, node: Sprite2D) -> void:
	if node.texture == null:
		return
	var source_size := node.texture.get_size()
	var map_size := _get_stain_map_size(source_size)
	var stain_image: Image = _stain_images.get(surface) as Image
	if stain_image == null or _stain_map_sizes.get(surface) != map_size:
		stain_image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
		stain_image.fill(Color(0.0, 0.0, 0.0, 1.0))
		_stain_images[surface] = stain_image
		_stain_map_sizes[surface] = map_size
		_stain_textures[surface] = ImageTexture.create_from_image(stain_image)
	else:
		var stain_texture: ImageTexture = _stain_textures.get(surface) as ImageTexture
		if stain_texture == null:
			_stain_textures[surface] = ImageTexture.create_from_image(stain_image)


func _prepare_water_map(node: Sprite2D) -> void:
	if node == null or node.texture == null:
		return
	var source_size := node.texture.get_size()
	var map_size := _get_stain_map_size(source_size)
	var water_image: Image = _water_images.get(SURFACE_BOWL) as Image
	if water_image == null or _water_map_sizes.get(SURFACE_BOWL) != map_size:
		water_image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
		water_image.fill(Color(0.0, 0.0, 0.0, 1.0))
		_water_images[SURFACE_BOWL] = water_image
		_water_map_sizes[SURFACE_BOWL] = map_size
		_water_textures[SURFACE_BOWL] = ImageTexture.create_from_image(water_image)
	else:
		var water_texture: ImageTexture = _water_textures.get(SURFACE_BOWL) as ImageTexture
		if water_texture == null:
			_water_textures[SURFACE_BOWL] = ImageTexture.create_from_image(water_image)


func _get_stain_map_size(source_size: Vector2) -> Vector2i:
	var largest_dimension := maxf(source_size.x, source_size.y)
	var scale := minf(1.0, float(stain_map_size) / maxf(largest_dimension, 1.0))
	return Vector2i(
		maxi(1, ceili(source_size.x * scale)),
		maxi(1, ceili(source_size.y * scale)),
	)


func _stamp_surface(surface: String, node: Sprite2D, position: Vector2) -> void:
	_prepare_stain_map(surface, node)
	var stain_image: Image = _stain_images.get(surface) as Image
	var stain_texture: ImageTexture = _stain_textures.get(surface) as ImageTexture
	if (
			stain_image == null
			or stain_texture == null
			or stain_image.is_empty()
			or _splat_image == null
			or _splat_image.is_empty()
	):
		return
	var uv := _world_to_uv(node, position)
	var radius := clampf(stain_radius, 0.005, 0.5)
	var stamp_width := maxi(1, ceili(radius * 2.0 * stain_image.get_width()))
	var stamp_height := maxi(1, ceili(radius * 2.0 * stain_image.get_height()))
	var center := Vector2(
		uv.x * stain_image.get_width() - 0.5,
		uv.y * stain_image.get_height() - 0.5,
	)
	var half_width := stamp_width * 0.5
	var half_height := stamp_height * 0.5
	var min_x := maxi(0, floori(center.x - half_width))
	var max_x := mini(stain_image.get_width() - 1, ceili(center.x + half_width))
	var min_y := maxi(0, floori(center.y - half_height))
	var max_y := mini(stain_image.get_height() - 1, ceili(center.y + half_height))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var splat_uv := Vector2(
				((x + 0.5) - (center.x - half_width)) / stamp_width,
				((y + 0.5) - (center.y - half_height)) / stamp_height,
			)
			if splat_uv.x < 0.0 or splat_uv.x >= 1.0 or splat_uv.y < 0.0 or splat_uv.y >= 1.0:
				continue
			var splat_pixel := Vector2i(
				clampi(floori(splat_uv.x * _splat_image.get_width()), 0, _splat_image.get_width() - 1),
				clampi(floori(splat_uv.y * _splat_image.get_height()), 0, _splat_image.get_height() - 1),
			)
			var splat_alpha := _splat_image.get_pixelv(splat_pixel).a
			if splat_alpha <= 0.01:
				continue
			var current := stain_image.get_pixel(x, y).r
			var updated := maxf(current, splat_alpha)
			if updated > current:
				stain_image.set_pixel(x, y, Color(updated, 0.0, 0.0, 1.0))
	stain_texture.update(stain_image)
	_stain_stamp_counts[surface] = int(_stain_stamp_counts.get(surface, 0)) + 1


func _clear_stain_maps() -> void:
	for surface in SURFACES:
		var stain_image: Image = _stain_images.get(surface) as Image
		var stain_texture: ImageTexture = _stain_textures.get(surface) as ImageTexture
		if stain_image == null or stain_texture == null:
			continue
		stain_image.fill(Color(0.0, 0.0, 0.0, 1.0))
		stain_texture.update(stain_image)


func _clear_water_maps() -> void:
	for water_image_variant in _water_images.values():
		var water_image := water_image_variant as Image
		if water_image == null or water_image.is_empty():
			continue
		water_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	var water_texture: ImageTexture = _water_textures.get(SURFACE_BOWL) as ImageTexture
	var water_image: Image = _water_images.get(SURFACE_BOWL) as Image
	if water_texture != null and water_image != null:
		water_texture.update(water_image)


func _get_wall_floor_boundary() -> float:
	var floor: Sprite2D = _surface_nodes.get(SURFACE_FLOOR) as Sprite2D
	if floor != null and floor.texture != null:
		var local_top := Vector2.ZERO if not floor.centered else Vector2(
			0.0,
			-floor.texture.get_height() * 0.5,
		)
		return floor.to_global(local_top).y
	var owner_node := get_parent()
	var viewport_size := Vector2(540.0, 960.0)
	var viewport := get_viewport()
	if viewport:
		viewport_size = viewport.get_visible_rect().size
	if owner_node and owner_node.has_method("get_world_size"):
		viewport_size = owner_node.get_world_size()
	return viewport_size.y * wall_floor_boundary_normalized


func _world_to_uv(sprite: Sprite2D, position: Vector2) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2(0.5, 0.5)
	var local := sprite.to_local(position)
	var texture_size := sprite.texture.get_size()
	if sprite.centered:
		local += texture_size * 0.5
	var uv := Vector2(
		local.x / maxf(texture_size.x, 0.001),
		local.y / maxf(texture_size.y, 0.001),
	)
	if sprite.flip_h:
		uv.x = 1.0 - uv.x
	if sprite.flip_v:
		uv.y = 1.0 - uv.y
	return uv


func _water_mask_uv_transform(bowl: Sprite2D, water: Sprite2D) -> Vector4:
	var center := _world_to_uv(water, bowl.to_global(Vector2.ZERO))
	var x_sample := _world_to_uv(
		water,
		bowl.to_global(Vector2(bowl.texture.get_width() * 0.5, 0.0)),
	)
	var y_sample := _world_to_uv(
		water,
		bowl.to_global(Vector2(0.0, bowl.texture.get_height() * 0.5)),
	)
	var scale := Vector2(
		(x_sample.x - center.x) * 2.0,
		(y_sample.y - center.y) * 2.0,
	)
	var offset := center - scale * 0.5
	return Vector4(scale.x, scale.y, offset.x, offset.y)


func _sprite_contains_alpha(sprite: Sprite2D, position: Vector2) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var uv := _world_to_uv(sprite, position)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return false
	var image: Image = _image_for_texture(sprite.texture)
	if image == null or image.is_empty():
		return false
	var pixel := Vector2i(
		clampi(floori(uv.x * image.get_width()), 0, image.get_width() - 1),
		clampi(floori(uv.y * image.get_height()), 0, image.get_height() - 1),
	)
	return image.get_pixelv(pixel).a > alpha_threshold


func _image_for_texture(texture: Texture2D) -> Image:
	var key := texture.get_instance_id()
	if _surface_images.has(key):
		return _surface_images[key] as Image
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	_surface_images[key] = image
	return image
