extends Main

class_name Level1

const TARGET_TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/drive/RedTicket.png"),
	preload("res://assets/art/drive/Floss.png"),
	preload("res://assets/art/drive/Gum.png"),
	preload("res://assets/art/drive/Cigarette.png"),
	preload("res://assets/art/drive/Lollipop.png"),
	preload("res://assets/art/drive/Condom.png"),
	preload("res://assets/art/drive/Bandaid.png"),
	preload("res://assets/art/drive/Fly.png"),
	preload("res://assets/art/drive/Straw.png"),
	preload("res://assets/art/drive/Tampon.png"),
]
const TOILET_COMPOSITION_SCALE := 1.25

var target_offsets := PackedVector2Array(
	[
		Vector2(-157.68, -132.045), # RedTicket
		Vector2(-110.16, -291.405), # Floss
		Vector2(-47.52, -279.885), # Gum
		Vector2(138.24, -145.485), # Cigarette
		Vector2(-27.0, 198.195), # Lollipop
		Vector2(76.68, -254.925), # Condom
		Vector2(96.12, 123.315), # Bandaid
		Vector2(131.76, -34.125), # Fly
		Vector2(14.04, -59.085), # Straw
		Vector2(-151.2, 13.875), # Tampon
	],
)

var target_points := PackedVector2Array()


func _ready() -> void:
	# Configure generated target nodes before Main starts input and chooses the
	# first checkpoint. Level 1 uses the authored floor zone; the two inherited
	# smoke-test zones are cleared below so they remain available to that test
	# scene without affecting the real level.
	draw_neutral_canvas = false
	enable_negative_zones = true
	_clear_inherited_test_zones()
	_layout_level1()
	shape_trace.normalized_points = target_points
	shape_trace.closed_path = false
	shape_trace.show_outline = false
	# Level 1 reveals only the current object. The player discovers the ordered
	# pattern one target at a time instead of seeing the next objects in advance.
	shape_trace.checkpoint_look_ahead = 1
	shape_trace.target_texture = TARGET_TEXTURES[0]
	shape_trace.target_textures = TARGET_TEXTURES
	shape_trace.use_native_target_sizes = true
	# These crops are already authored at the size used by the play-screen
	# reference. Scaling them only by the viewport keeps their visual weight.
	var toilet := get_node_or_null("PissToilet") as PissToilet
	shape_trace.native_target_scale = toilet.get_bowl_art_scale() if toilet else 1.0
	# The target sprites sit inside the toilet: above the bowl (z=1) but below
	# the seat/lid (z=3), so the authored seat edge can naturally overlap them.
	shape_trace.z_index = 2
	# The replay line is also world-space artwork. Keep it above the toilet and
	# targets so the recorded path remains visible during the completion pause.
	line_replay.z_index = 11
	shape_trace.rebuild_targets()
	if is_instance_valid(depth_map):
		depth_map.debug_visualization = false
	var depth_environment := get_node_or_null("DepthEnvironment")
	if depth_environment:
		depth_environment.visible = false
	super._ready()
	_layout_level1()


func _clear_inherited_test_zones() -> void:
	for zone_name in [&"NegativeZone01", &"NegativeZone02"]:
		var test_zone := get_node_or_null(NodePath(String(zone_name))) as NegativeZone
		if not test_zone:
			continue
		test_zone.normalized_points = PackedVector2Array()
		test_zone.show_zone = false
		test_zone.visible = false


func _process(delta: float) -> void:
	super._process(delta)
	_layout_level1()


func _layout_level1() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var toilet := get_node_or_null("PissToilet") as PissToilet
	if toilet:
		# The raw toilet art is authored for the 1080x1920 reference. The complete
		# toilet composition is intentionally 25% larger in the play screen.
		# Keep the drain and the first target visually centered when the viewport
		# changes.
		toilet.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.625)
		var art_scale := viewport_size.x / 1080.0 * TOILET_COMPOSITION_SCALE
		toilet.scale = Vector2.ONE * art_scale
		toilet.apply_layout()
		var target_local_points := PackedVector2Array()
		for offset in target_offsets:
			target_local_points.append(toilet.get_bowl_anchor_local() + offset)
		var next_target_points := toilet.to_viewport_normalized(
			target_local_points,
			viewport_size,
		)
		if target_points != next_target_points:
			target_points = next_target_points
			shape_trace.normalized_points = target_points
		var floor_zone := get_node_or_null("FloorNegativeZone") as NegativeZone
		if floor_zone:
			var next_exclusion := toilet.get_floor_exclusion_normalized(
				viewport_size,
			)
			if floor_zone.excluded_normalized_points != next_exclusion:
				floor_zone.excluded_normalized_points = next_exclusion
		shape_trace.target_center_position = toilet.get_bowl_anchor_global()
	else:
		target_points = PackedVector2Array()
	_align_bowl_light()
