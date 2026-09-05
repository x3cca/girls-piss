extends CPUParticles2D

class_name DepthParticleEmitter

## Small reusable hook for particle emitters that live in the baked depth
## world. The emitter is clipped as a whole when its origin leaves the active
## section. The shared boil shader receives per-emitter map/depth parameters,
## while can_render_particle_position() remains available to non-shader users.

@export var depth_map: DepthMap2D
@export_range(0.0, 0.25, 0.005) var depth_epsilon := 0.02
@export var z_band_count := 4
@export var z_band_step := 10
@export var z_base_index := -1
@export var clip_to_depth_map := true
@export var source_entry_grace := 96.0
@export_range(0.0, 1.0, 0.01) var depth_scale_reduction := 0.45

var active_depth := 0.0
var _depth_context_position := Vector2.ZERO
var _allow_source_entry_grace := false
var _base_material: Material
var _depth_material: ShaderMaterial
var _base_scale_amount_min := 1.0
var _base_scale_amount_max := 1.0


func _ready() -> void:
	_base_material = material
	_base_scale_amount_min = scale_amount_min
	_base_scale_amount_max = scale_amount_max
	_apply_particle_scale()
	_apply_depth_material()


func set_depth_map(value: DepthMap2D) -> void:
	depth_map = value
	_apply_particle_scale()
	_apply_depth_material()
	_update_depth_state()


func set_active_depth(value: float) -> void:
	active_depth = clampf(value, 0.0, 1.0)
	_apply_particle_scale()
	_apply_depth_material()
	_update_depth_state()


func set_depth_context(world_position: Vector2, depth := -1.0, allow_source_grace := false) -> void:
	_depth_context_position = world_position
	_allow_source_entry_grace = allow_source_grace
	if depth >= 0.0:
		active_depth = clampf(depth, 0.0, 1.0)
	_apply_particle_scale()
	_apply_depth_material()
	_update_depth_state()


func can_render_particle_position(world_position: Vector2, particle_depth := -1.0) -> bool:
	if depth_map == null or not clip_to_depth_map:
		return true
	var required_depth := active_depth if particle_depth < 0.0 else particle_depth
	var sample := depth_map.sample_world_position(world_position)
	if not bool(sample.get("valid", false)):
		return _allow_source_entry_grace and _within_source_grace(world_position)
	# A particle from a lower section must disappear when it crosses into a
	# shallower section, where a higher sprite would occlude it.
	return float(sample.get("depth", 0.0)) + depth_epsilon >= required_depth


func apply_depth_band(depth: float) -> void:
	active_depth = clampf(depth, 0.0, 1.0)
	_apply_particle_scale()
	_update_depth_state()


func _process(_delta: float) -> void:
	_update_depth_state()


func _update_depth_state() -> void:
	if depth_map == null or not clip_to_depth_map:
		visible = true
		z_index = z_base_index
		_set_shader_clip_enabled(false)
		return
	var context := _depth_context_position
	if context == Vector2.ZERO:
		context = global_position
	visible = can_render_particle_position(context, active_depth)
	_set_shader_clip_enabled(
		visible and not (_allow_source_entry_grace and _is_invalid_map_position(context)),
	)
	if not visible:
		emitting = false
	else:
		z_index = depth_map.get_render_z_index(
			active_depth,
			z_base_index,
			z_band_count,
			z_band_step,
		)


func _apply_depth_material() -> void:
	if _base_material == null:
		_base_material = material
	if depth_map == null or not clip_to_depth_map:
		if _base_material != null:
			material = _base_material
		_depth_material = null
		return
	if _depth_material == null and _base_material is ShaderMaterial:
		_depth_material = (_base_material as ShaderMaterial).duplicate() as ShaderMaterial
	if _depth_material == null:
		return
	material = _depth_material
	_depth_material.set_shader_parameter("depth_clip_map", depth_map.depth_texture)
	_depth_material.set_shader_parameter(
		"depth_clip_rect",
		Vector4(
			depth_map.world_rect.position.x,
			depth_map.world_rect.position.y,
			depth_map.world_rect.size.x,
			depth_map.world_rect.size.y,
		),
	)
	_depth_material.set_shader_parameter("depth_clip_depth", active_depth)
	_depth_material.set_shader_parameter("depth_clip_epsilon", depth_epsilon)


func _apply_particle_scale() -> void:
	if _base_scale_amount_min <= 0.0 and _base_scale_amount_max <= 0.0:
		return
	var scale_multiplier := 1.0
	if depth_map != null and clip_to_depth_map:
		scale_multiplier = lerpf(
			1.0,
			1.0 - clampf(depth_scale_reduction, 0.0, 1.0),
			clampf(active_depth, 0.0, 1.0),
		)
	scale_amount_min = _base_scale_amount_min * scale_multiplier
	scale_amount_max = _base_scale_amount_max * scale_multiplier


func _set_shader_clip_enabled(enabled: bool) -> void:
	if _depth_material != null:
		_depth_material.set_shader_parameter("depth_clip_enabled", 1.0 if enabled else 0.0)


func _is_invalid_map_position(world_position: Vector2) -> bool:
	if depth_map == null:
		return false
	return not bool(depth_map.sample_world_position(world_position).get("valid", false))


func _within_source_grace(world_position: Vector2) -> bool:
	return world_position.distance_to(global_position) <= source_entry_grace
