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

var target_points := PackedVector2Array(
	[
		# Centers match the objects in Example of play Screen.png, in the
		# same order as TARGET_TEXTURES, on the 1080x1920 reference canvas.
		Vector2(0.27, 0.53), # RedTicket
		Vector2(0.34, 0.40), # Floss
		Vector2(0.43, 0.41), # Gum
		Vector2(0.70, 0.52), # Cigarette
		Vector2(0.46, 0.80), # Lollipop
		Vector2(0.61, 0.43), # Condom
		Vector2(0.64, 0.74), # Bandaid
		Vector2(0.69, 0.61), # Fly
		Vector2(0.52, 0.59), # Straw
		Vector2(0.28, 0.65), # Tampon
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
	# Keep the same readable three-target preview as the smoke test. The first
	# target is fully visible; upcoming objects fade using ShapeTrace's shared
	# look-ahead rules instead of revealing the entire toilet pattern at once.
	shape_trace.checkpoint_look_ahead = 3
	shape_trace.target_texture = TARGET_TEXTURES[0]
	shape_trace.target_textures = TARGET_TEXTURES
	shape_trace.use_native_target_sizes = true
	# These crops are already authored at the size used by the play-screen
	# reference. Scaling them only by the viewport keeps their visual weight.
	shape_trace.native_target_scale = 1.0
	# The target sprites are gameplay markers placed over the toilet art. Keep
	# them above every toilet layer (and the lower chrome at z=6) so the authored
	# objects remain visible while their hit positions stay on the bowl.
	shape_trace.z_index = 10
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
