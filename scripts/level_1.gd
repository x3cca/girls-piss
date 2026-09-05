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
	preload("res://assets/art/drive/Toilet paper.png"),
	preload("res://assets/art/drive/Fly.png"),
	preload("res://assets/art/drive/Straw.png"),
	preload("res://assets/art/drive/Tampon.png"),
]

var target_points := PackedVector2Array(
	[
		Vector2(0.19, 0.40),
		Vector2(0.34, 0.40),
		Vector2(0.51, 0.40),
		Vector2(0.72, 0.49),
		Vector2(0.27, 0.55),
		Vector2(0.62, 0.55),
		Vector2(0.30, 0.63),
		Vector2(0.52, 0.64),
		Vector2(0.76, 0.65),
		Vector2(0.50, 0.73),
		Vector2(0.36, 0.76),
	]
)


func _ready() -> void:
	# Configure generated target nodes before Main starts input and chooses the
	# first checkpoint. The test zones remain authored in smoke_test, but Level 1
	# intentionally starts with the open space around the toilet neutral.
	draw_neutral_canvas = false
	shape_trace.normalized_points = target_points
	shape_trace.closed_path = false
	shape_trace.show_outline = false
	shape_trace.checkpoint_look_ahead = TARGET_TEXTURES.size()
	shape_trace.look_ahead_opacity = 1.0
	shape_trace.look_ahead_opacity_falloff = 1.0
	shape_trace.target_texture = TARGET_TEXTURES[0]
	shape_trace.target_textures = TARGET_TEXTURES
	shape_trace.use_native_target_sizes = true
	shape_trace.native_target_scale = 0.56
	shape_trace.z_index = 4
	shape_trace.rebuild_targets()
	if is_instance_valid(depth_map):
		depth_map.debug_visualization = false
	var depth_environment := get_node_or_null("DepthEnvironment")
	if depth_environment:
		depth_environment.visible = false
	super._ready()
	_layout_level1()


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
		# The tank is the high wall panel in the reference composition. Its
		# authored layer is offset above the bowl rather than centered on it.
		var tank := toilet.get_node_or_null("Tank") as Sprite2D
		if tank:
			tank.position = Vector2(0.0, -900.0)
	shape_trace.target_center_position = Vector2(
		viewport_size.x * 0.5,
		viewport_size.y * 0.625,
	)
