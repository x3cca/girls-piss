extends Control

class_name StreamHUD

var input_controller: InputController
var pressure_model: PressureModel
var stream: LiquidStream
var target_nodes: Array[WettableTarget] = []
var show_touch_controls := false
var safe_margin := 28.0
@onready var carrot_aim_control: CarrotAimControl = $CarrotAimControl
@onready var pressure_fader: PressureFader = $PressureFader
var _wired_input_controller: InputController


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_layout_controls()


func _process(_delta: float) -> void:
	process_frame(_delta)


func process_frame(_delta: float) -> void:
	if input_controller:
		show_touch_controls = input_controller.touch_controls_visible
	_wire_input_controller()
	_layout_controls()
	carrot_aim_control.visible = true
	pressure_fader.visible = show_touch_controls
	if pressure_model:
		pressure_fader.set_pressure(pressure_model.requested_pressure)
	queue_redraw()


func _wire_input_controller() -> void:
	if input_controller == _wired_input_controller:
		return
	if is_instance_valid(_wired_input_controller):
		if _wired_input_controller.aim_angle_changed.is_connected(carrot_aim_control.set_aim_angle):
			_wired_input_controller.aim_angle_changed.disconnect(carrot_aim_control.set_aim_angle)
		if carrot_aim_control.swayed_aim_angle_changed.is_connected(
			_wired_input_controller.set_swayed_aim_angle,
		):
			carrot_aim_control.swayed_aim_angle_changed.disconnect(
				_wired_input_controller.set_swayed_aim_angle,
			)
	_wired_input_controller = input_controller
	if not is_instance_valid(_wired_input_controller):
		return
	if not carrot_aim_control.aim_angle_changed.is_connected(_wired_input_controller.set_aim_angle):
		carrot_aim_control.aim_angle_changed.connect(_wired_input_controller.set_aim_angle)
	if not _wired_input_controller.aim_angle_changed.is_connected(carrot_aim_control.set_aim_angle):
		_wired_input_controller.aim_angle_changed.connect(carrot_aim_control.set_aim_angle)
		if not carrot_aim_control.swayed_aim_angle_changed.is_connected(
			_wired_input_controller.set_swayed_aim_angle,
		):
			carrot_aim_control.swayed_aim_angle_changed.connect(
				_wired_input_controller.set_swayed_aim_angle,
			)
	carrot_aim_control.set_aim_angle(_wired_input_controller.get_aim_angle())


func _layout_controls() -> void:
	var viewport := get_viewport_rect()
	var safe := viewport.grow(-minf(safe_margin, minf(viewport.size.x, viewport.size.y) * 0.04))
	if is_instance_valid(carrot_aim_control):
		# The control fills the safe rectangle invisibly so touch/mouse X is the
		# input. The authored carrot sprite itself stays centered on the screen.
		carrot_aim_control.position = safe.position
		carrot_aim_control.size = safe.size
		carrot_aim_control.track_y = safe.size.y - 32.0
		carrot_aim_control.carrot_base_y = safe.size.y - 32.0
		carrot_aim_control.set_aim_angle(carrot_aim_control.get_aim_angle())
	if is_instance_valid(pressure_fader):
		pressure_fader.position = safe.position
		pressure_fader.size = safe.size
		pressure_fader.set_track_bounds(178.0, safe.size.y - 188.0, 72.0)


func _draw() -> void:
	var viewport := get_viewport_rect()
	var safe := viewport.grow(-minf(safe_margin, minf(viewport.size.x, viewport.size.y) * 0.04))
	var font := ThemeDB.fallback_font
	var small := 16
	var medium := 22
	# Header and compact pressure cards.
	draw_string(
		font,
		safe.position + Vector2(0, 24),
		"PISSER",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		medium,
		Color("#fff0a0"),
	)
	draw_string(
		font,
		safe.position + Vector2(0, 48),
		"aim • squeeze • soak",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		small,
		Color("#b2a77a"),
	)
	_draw_meter(
		Rect2(safe.position + Vector2(0, 72), Vector2(196, 18)),
		pressure_model.requested_pressure if pressure_model else 0.0,
		Color("#f1d34f"),
		"PRESSURE",
	)
	_draw_meter(
		Rect2(safe.position + Vector2(218, 72), Vector2(196, 18)),
		pressure_model.reserve if pressure_model else 0.0,
		Color("#c3b57a"),
		"RESERVE",
	)
	if pressure_model and pressure_model.exhausted:
		draw_string(
			font,
			safe.position + Vector2(0, 120),
			"RECOVERING",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			small,
			Color("#ffbf7a"),
		)
	else:
		draw_string(
			font,
			safe.position + Vector2(0, 120),
			"W / S  pressure     A / D  aim",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			small,
			Color("#b2a77a"),
		)

	# Small target progress tags remain readable on wide and tall portrait ratios.
	for index in target_nodes.size():
		var target := target_nodes[index]
		if is_instance_valid(target):
			var label_position := target.position + Vector2(
				-target.target_size.x * 0.5,
				-target.target_size.y * 0.5 - 16.0,
			)
			draw_string(
				font,
				label_position,
				"TARGET %02d  %d%%" % [index + 1, roundi(target.wetness * 100.0)],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color("#d5c77f"),
			)


func _draw_meter(rect: Rect2, value: float, color: Color, title: String) -> void:
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		rect.position + Vector2(0, -7),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("#8396bb"),
	)
	draw_style_box(_box(Color(0.06, 0.09, 0.18, 0.85), 7), rect)
	var fill := rect.grow(-3.0)
	fill.size.x *= clampf(value, 0.0, 1.0)
	if fill.size.x > 0:
		draw_style_box(_box(color, 5), fill)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
