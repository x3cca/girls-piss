extends Main

class_name Level1

const BOWL_ART_SCALE := 0.75
# The tank remains anchored to the wall. Move the scaled bowl assembly up until
# the seat's top edge meets the tank's bottom edge in the authored artwork.
const TOILET_BOWL_OFFSET_Y := -157.875

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

var target_points := PackedVector2Array(
	[
		# Centers match the ordered objects from Example of play Screen.png,
		# then compress 25% toward the bowl center to fit the smaller bowl and
		# keep the target sprites readable beneath the seat. The whole bowl
		# assembly is then scooted upward to meet the tank.
		Vector2(0.354, 0.474), # RedTicket
		Vector2(0.398, 0.391), # Floss
		Vector2(0.456, 0.397), # Gum
		Vector2(0.628, 0.467), # Cigarette
		Vector2(0.475, 0.646), # Lollipop
		Vector2(0.571, 0.410), # Condom
		Vector2(0.589, 0.607), # Bandaid
		Vector2(0.622, 0.525), # Fly
		Vector2(0.513, 0.512), # Straw
		Vector2(0.360, 0.550), # Tampon
	],
)


func _ready() -> void:
	# Configure generated target nodes before Main starts input and chooses the
	# first checkpoint. Level 1 uses the authored floor zone; the two inherited
	# smoke-test zones are cleared below so they remain available to that test
	# scene without affecting the real level.
	draw_neutral_canvas = false
	enable_negative_zones = true
	_clear_inherited_test_zones()
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
	shape_trace.native_target_scale = BOWL_ART_SCALE
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
	var toilet := get_node_or_null("PissToilet") as Node2D
	if toilet:
		# The raw toilet art is authored for the 1080x1920 reference. Keep the
		# drain and the first target visually centered when the viewport changes.
		toilet.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.625)
		var art_scale := viewport_size.x / 1080.0
		toilet.scale = Vector2.ONE * art_scale
		for part_name in [&"Outside", &"Bowl", &"Seat"]:
			var part := toilet.get_node_or_null(NodePath(String(part_name))) as Sprite2D
			if part:
				part.scale = Vector2.ONE * BOWL_ART_SCALE
				part.position.y = TOILET_BOWL_OFFSET_Y
				if part_name == &"Outside":
					part.position.y += 32.0
		# The tank is the high wall panel in the reference composition. Its
		# authored layer is offset above the bowl rather than centered on it.
		var tank := toilet.get_node_or_null("Tank") as Sprite2D
		if tank:
			tank.position = Vector2(0.0, -900.0)
	shape_trace.target_center_position = Vector2(
		viewport_size.x * 0.5,
		viewport_size.y * 0.625,
	)
