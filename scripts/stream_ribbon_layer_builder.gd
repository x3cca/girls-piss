extends RefCounted
## Keeps the primary and secondary stream ribbon stacks on one construction
## path. Geometry and depth-band handling remain owned by LiquidStream.

func build_ribbon_set(
		meshes: Array[ArrayMesh],
		points: PackedVector2Array,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
		point_ages: PackedFloat32Array,
		point_depths: PackedFloat32Array,
		beat_bloom_width: float,
		has_depth_map: bool,
		mesh_writer: Callable,
) -> void:
	var render_depths := point_depths if has_depth_map else PackedFloat32Array()
	_write_layer(
		mesh_writer,
		meshes[0],
		points,
		beat_bloom_width,
		0.0,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
		render_depths,
		true,
	)
	_write_layer(
		mesh_writer,
		meshes[1],
		points,
		36.0,
		0.0,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
		render_depths,
	)
	_write_layer(
		mesh_writer,
		meshes[2],
		points,
		32.0,
		0.0,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
		render_depths,
	)
	_write_layer(
		mesh_writer,
		meshes[3],
		points,
		8.0,
		1.7,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
		render_depths,
	)


func _write_layer(
		mesh_writer: Callable,
		mesh: ArrayMesh,
		points: PackedVector2Array,
		width: float,
		center_offset: float,
		depth_length: float,
		ribbon_alpha: float,
		hit_target: bool,
		point_ages: PackedFloat32Array,
		point_depths: PackedFloat32Array,
		is_bloom := false,
) -> void:
	mesh_writer.call(
		mesh,
		points,
		width,
		center_offset,
		depth_length,
		ribbon_alpha,
		hit_target,
		point_ages,
		0.0,
		-1.0,
		-1.0,
		point_depths,
		is_bloom,
	)
